extends SceneTree
## The alt route's new hospital (scenes/environment/alt_hospital.tscn in map_alt.tscn, built by
## tools/blender/build_alt_hospital.py): four storeys and a helipad in place of the old hospital, which the main
## map keeps. Its floors and stairs carry you; the way up zig-zags, every storey blocking one stair, so the
## navigation from the door to the roof goes round each storey; its register and notice send you up to the roof,
## where the helicopter flies you out. Nothing is saved: the story's save points at a throwaway file.

const MAP_ALT := "res://scenes/chapters/alt_route/map_alt.tscn"
const MAP := "res://scenes/chapters/main/map.tscn"
const THROWAWAY := "user://test_alt_hospital_story.json"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func wait_until(ready: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if ready.call():
			return true
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second
	return bool(ready.call())


## What is straight below a point: [hit position, collider] or [].
func down(world: World3D, from: Vector3, reach: float = 3.0) -> Array:
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * reach)
	var hit := world.direct_space_state.intersect_ray(ray)
	return [] if hit.is_empty() else [hit.position, hit.collider]


func path_length(points: PackedVector3Array) -> float:
	var length := 0.0
	for index in range(1, points.size()):
		length += points[index - 1].distance_to(points[index])
	return length


func run() -> void:
	var map := (load(MAP_ALT) as PackedScene).instantiate() as Node3D
	for node in map.find_children("*", "", true, false):
		if "persist_progress" in node:
			node.set("persist_progress", false)
		if "progress_save_path" in node:
			node.set("progress_save_path", THROWAWAY)
		if "cache_navigation" in node:
			node.set("cache_navigation", false)
	root.add_child(map)
	current_scene = map
	for i in 5:
		await physics_frame
	var hospital := map.get_node("Buildings/NeighborhoodHospital") as Node3D
	check(hospital.has_method("storey_at") and hospital.scene_file_path.ends_with("alt_hospital.tscn"), "the alt map's hospital is the new one")
	check(FileAccess.get_file_as_string(MAP).contains("res://scenes/environment/story_hospital.tscn"), "the main map keeps the old hospital")
	var world := hospital.get_world_3d()
	var markers: Dictionary = hospital.get("markers")
	var levels: Array = markers.levels

	# Floors: tile underfoot on every storey, at its height, in the lobby, the corridor and both stair landings.
	for storey in levels.size():
		var floor_y := float(levels[storey])
		for name: String in ["landing_A%d" % storey, "landing_B%d" % storey]:
			var at: Vector3 = hospital.call("point", StringName(name))
			var hit := down(world, at + Vector3.UP * 1.0)
			check(not hit.is_empty() and absf(hit[0].y - at.y) < 0.05 and str((hit[1] as Node).get_meta("surface", "")) == "tile",
				"storey %d: the floor at %s holds you, tiled" % [storey, name])
		var corridor := hospital.to_global(Vector3(0.0, floor_y + 1.0, -8.7))
		var hit := down(world, corridor)
		check(not hit.is_empty() and absf(hit[0].y - floor_y) < 0.05, "storey %d: the corridor floor is at %.2f m" % [storey, floor_y])
	var roof := down(world, hospital.call("point", &"helipad") + Vector3.UP * 1.0)
	check(not roof.is_empty() and str((roof[1] as Node).get_meta("surface", "")) == "concrete", "the helipad holds you, concrete underfoot")
	# Stairs: each tread of stair B's first flight is a step higher than the last.
	var core: Dictionary = markers.cores.B
	var treads: Array[float] = []
	for k in range(1, 10):
		var x := float(core.landing_end) + float(core.s) * 0.3 * (k - 0.5)
		var hit := down(world, hospital.to_global(Vector3(x, float(levels[0]) + 2.5, -7.6)))
		treads.append(-1.0 if hit.is_empty() else hit[0].y)
	var steady := true
	for k in range(1, treads.size()):
		steady = steady and absf(treads[k] - treads[k - 1] - 0.19) < 0.02
	check(steady, "stair B climbs in steps of 0.19 m (%s)" % str(treads.map(func(v: float) -> String: return "%.2f" % v)))
	# The balustrade at the top of stair B keeps you out of the well on floor 4.
	var guard := PhysicsRayQueryParameters3D.create(hospital.to_global(Vector3(14.6, float(levels[3]) + 0.8, -7.6)),
		hospital.to_global(Vector3(16.4, float(levels[3]) + 0.8, -7.6)))
	check(not world.direct_space_state.intersect_ray(guard).is_empty(), "a balustrade closes the top of stair B on floor 4")

	# Each floor its own: the lobby rises through floor 2 to the atrium's ceiling, a glass balustrade round the
	# gallery; the heap over stair B stops you though only its rubble shows; each floor has its own colour.
	var lobby_point: Vector3 = hospital.call("point", &"lobby")
	var atrium := down(world, lobby_point + Vector3.UP * (float(levels[1]) - float(levels[0]) + 1.0), 6.0)
	check(not atrium.is_empty() and absf(atrium[0].y - lobby_point.y) < 0.05, "floor 2 is open over the lobby, down to the lobby's floor")
	var gallery := world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
		hospital.to_global(Vector3(3.0, float(levels[1]) + 0.8, -8.7)), hospital.to_global(Vector3(3.0, float(levels[1]) + 0.8, -5.0))))
	check(not gallery.is_empty() and absf(hospital.to_local(gallery.position).z + 7.3) < 0.2, "a balustrade keeps you from falling off the gallery")
	var blocker := hospital.find_child("Blocker_L1", true, false) as MeshInstance3D
	check(blocker != null and not blocker.visible and blocker.find_children("*", "StaticBody3D", false, false).size() == 1,
		"the heap over stair B stops you, and only its rubble shows")
	var colours := ["Interior_DadoBlue", "Interior_DadoGreen", "Interior_DadoTeal", "Interior_DadoOchre"]
	for storey in levels.size():
		var walls := hospital.find_child("Interior_L%d" % storey, true, false) as MeshInstance3D
		var used: Array[String] = []
		for index in walls.mesh.get_surface_count():
			var material := walls.mesh.surface_get_material(index)
			if material != null:
				used.append(material.resource_name)
		var own := colours.filter(func(colour: String) -> bool: return colour in used)
		check(own == [colours[storey]], "storey %d is painted its own colour (%s)" % [storey + 1, ", ".join(own)])
	var textured := 0
	for node: Node in hospital.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for index in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(index)
			var finish := mesh.get_surface_override_material(index) as BaseMaterial3D
			if original != null and original.resource_name in ["Interior_WallUpper", "Interior_Ceiling"] and finish != null and finish.albedo_texture != null:
				textured += 1
	check(textured == 2 * levels.size(), "every storey's walls are plastered and its ceilings tiled (%d)" % textured)
	var stains := hospital.find_children("Stain*", "Decal", false, false)
	var one_storey := true
	for stain: Node in stains:
		var mask := (stain as Decal).cull_mask
		var walls := mask & 0xF000
		var furniture := mask & 0xF0
		one_storey = one_storey and walls != 0 and walls & (walls - 1) == 0 and furniture == walls >> 8 and mask == walls | furniture
	check(stains.size() == (markers.decals as Array).size() and one_storey,
		"its %d stains are on, each on its own storey only (its walls and its furniture)" % stains.size())
	var hand := hospital.find_children("Stain*_handprint", "Decal", false, false)
	check(hand.size() == 1 and (-(hand[0] as Decal).global_basis.z).dot(Vector3.UP) > 0.99 and absf((hand[0] as Decal).global_basis.y.y) < 0.01,
		"the handprint is on a wall, the right way up")
	var low := hospital.get_node_or_null("L_AtriumLow") as OmniLight3D
	var high := hospital.get_node_or_null("L_AtriumHigh") as OmniLight3D
	check(low != null and high != null and low.light_cull_mask & 0xF000 == 1 << 12 and high.light_cull_mask & 0xF000 == 1 << 13
		and hospital.to_local(low.global_position).y > float(levels[1]) + 2.0, "the atrium is lit on both its storeys, the lobby's light high in the void")

	# Navigation: from the door to the roof, and round every storey, never straight up a blocked stair.
	var navigation := map.get_node("MapNavigation") as NavigationRegion3D
	check(await wait_until(func() -> bool: return navigation.navigation_mesh != null and navigation.navigation_mesh.get_polygon_count() > 0, 240.0),
		"the town's navigation mesh is baked")
	var nav_map := navigation.get_world_3d().navigation_map
	var lift := Vector3.UP * 0.3
	# The navigation server takes the new mesh in a few frames after the bake.
	var lobby_probe: Vector3 = hospital.call("point", &"lobby") + lift
	check(await wait_until(func() -> bool: return NavigationServer3D.map_get_closest_point(nav_map, lobby_probe).distance_to(lobby_probe) < 1.0, 30.0),
		"the navigation map has taken the hospital in")
	var entrance: Vector3 = hospital.call("point", &"entrance")
	var helipad: Vector3 = hospital.call("point", &"helipad")
	var climb := NavigationServer3D.map_get_path(nav_map, entrance + lift, helipad + lift, true)
	check(climb.size() > 2 and climb[climb.size() - 1].distance_to(helipad + lift) < 1.5,
		"the navigation reaches the helipad from the door (%.0f m of walking)" % path_length(climb))
	check(path_length(climb) > 4.0 * 27.0, "the way up crosses every storey's corridor (%.0f m)" % path_length(climb))
	for pair: Array in [["landing_B1", "landing_B2", "stair B is buried on 2"], ["landing_A2", "landing_A3", "stair A is barricaded on 3"]]:
		var a: Vector3 = hospital.call("point", StringName(pair[0]))
		var b: Vector3 = hospital.call("point", StringName(pair[1]))
		var route := NavigationServer3D.map_get_path(nav_map, a + lift, b + lift, true)
		check(route.size() > 2 and path_length(route) > 40.0, "%s: the way up goes round by the other stair (%.0f m)" % [pair[2], path_length(route)])
	var lobby: Vector3 = hospital.call("point", &"lobby")
	var chained: Vector3 = hospital.call("point", &"landing_A0")
	var round := NavigationServer3D.map_get_path(nav_map, lobby + lift, chained + lift, true)
	check(path_length(round) > 40.0 or round.size() < 2 or round[round.size() - 1].distance_to(chained + lift) > 1.5,
		"stair A's chained door keeps the ground floor out of it")

	# What it holds.
	check(hospital.find_children("*", "HidingSpot", true, false).size() == (markers.hiding_spots as Array).size() and (markers.hiding_spots as Array).size() >= 30,
		"its %d hiding spots are in" % (markers.hiding_spots as Array).size())
	check(hospital.find_children("*", "BottlePickup", true, false).size() == (markers.bottles as Array).size(), "its bottles are in")
	var register := hospital.get_node_or_null("RegisterDocument")
	var notice := hospital.get_node_or_null("EvacuationDocument")
	var flight := hospital.get_node_or_null("FlightDocument")
	check(register != null and str(register.get("body")).contains("roof helipad"), "the register says the residents are flown out from the roof")
	check(notice != null and str(notice.get("body")).contains("EVACUATION BY AIR"), "the notice sends you up the stairs to the roof")
	check(flight != null and str(flight.get("body")).contains("Carrie M. on board"), "the radio log on the top floor says Carrie flew out")
	var lit := true
	for light: Node in hospital.find_children("L_*", "OmniLight3D", false, false):
		var mask := (light as OmniLight3D).light_cull_mask
		lit = lit and (mask & 0xF000) != 0 and (mask & 0xF000) & ((mask & 0xF000) - 1) == 0 and (mask & 0xF0) == (mask & 0xF000) >> 8
	check(lit, "each storey's lights light only that storey and its furniture")
	var flashlight_ok := true
	var player := map.get_node("Player") as FirstPersonPlayer
	for light: Node in player.find_children("*", "Light3D", true, false):
		flashlight_ok = flashlight_ok and ((light as Light3D).light_cull_mask & 0xF000) == 0xF000
	check(flashlight_ok, "the flashlight still lights every storey")
	var outside := 0
	var let_in: Array = []
	for node: Node in map.find_children("*", "Light3D", true, false):
		if node is DirectionalLight3D or hospital.is_ancestor_of(node) or player.is_ancestor_of(node):
			continue
		outside += 1
		var lamp := node as Light3D
		if (lamp.light_cull_mask & 0xF0F0) != 0 or (lamp.shadow_caster_mask & 0xF0F0) != 0:
			let_in.append(str(map.get_path_to(lamp)))
	check(outside > 20 and let_in.is_empty(), "the town's %d lamps outside neither light its insides nor draw them into their shadows %s" % [
		outside, let_in.slice(0, 4)])
	var flashlight_shadows := true
	for light: Node in player.find_children("*", "Light3D", true, false):
		flashlight_shadows = flashlight_shadows and ((light as Light3D).shadow_caster_mask & 0xF0F0) == 0xF0F0
	check(flashlight_shadows, "the flashlight's shadows still take in every storey and its furniture")

	# The furniture: on its storey's own layer, out of the moon's shadows (the walls and floors stay in them), and
	# inside the building drawn only on the player's storey and the ones just above and below.
	var furniture: Array = []
	var walls_ok := true
	for node: Node in hospital.get_node("Source").find_children("*", "MeshInstance3D", true, false):
		var piece := node as MeshInstance3D
		var storey := int(hospital.call("mesh_storey", str(piece.name)))
		if storey < 0:
			continue
		if str(piece.name).begins_with("Decor_"):
			furniture.append(piece)
			walls_ok = walls_ok and piece.layers == 1 << (4 + storey)
		else:
			walls_ok = walls_ok and piece.layers == 1 << (12 + storey)
	check(furniture.size() == levels.size() and walls_ok, "each storey's furniture has its own layer, its walls theirs")
	var moon := map.get_node("Moonlight") as DirectionalLight3D
	check(moon.shadow_caster_mask & 0xF0 == 0 and moon.shadow_caster_mask & 0xF000 == 0xF000 and moon.shadow_caster_mask & 1 == 1,
		"the moon leaves the furniture out of its shadows, but not the walls and floors")
	var shown_for := func(storey: int) -> Array:
		hospital.call("show_furniture_for", storey)
		var shown: Array = []
		for piece: MeshInstance3D in furniture:
			if piece.visible:
				shown.append(int(hospital.call("mesh_storey", str(piece.name))))
		shown.sort()
		return shown
	check(shown_for.call(0) == [0, 1] and shown_for.call(2) == [1, 2, 3] and shown_for.call(4) == [2, 3],
		"inside, only the furniture of your storey and the ones beside it is drawn")
	check(shown_for.call(-1) == [0, 1, 2, 3], "from outside, all of it is, through the windows")

	# The story: in at the door, up to the wards (the Clawman wakes there), up to the roof, and out.
	var story := map.get_node("OpeningStory")
	await wait_until(func() -> bool: return story.get("hospital") != null, 5.0)
	player.global_position = entrance + Vector3.UP * 0.2
	await wait_until(func() -> bool: return int(story.get("stage")) >= 3, 3.0)
	check(int(story.get("stage")) >= 3, "walking in at the new door reaches the hospital")
	var clawman := map.get_node("Clawman") as Node3D
	check(not bool(clawman.get("enabled")), "the Clawman waits until you reach the wards")
	player.global_position = hospital.call("point", &"landing_B1") + Vector3.UP * 0.2
	await wait_until(func() -> bool: return (story.get("discovered") as Dictionary).has("storey_1"), 3.0)
	check((story.get("discovered") as Dictionary).has("storey_1") and bool(clawman.get("enabled")), "reaching the wards wakes the Clawman")
	check(int(hospital.call("storey_at", clawman.global_position)) == 1, "it waits on the wards' storey (%d)" % int(hospital.call("storey_at", clawman.global_position)))
	var helicopter := hospital.get("helicopter") as Node3D
	check(helicopter != null and not bool(helicopter.get("can_board")), "the helicopter waits on the pad, not yet boarded")
	story.call("debug_start_roof")
	player.global_position = hospital.call("point", &"roof_door") + Vector3.UP * 0.2
	await wait_until(func() -> bool: return bool(helicopter.get("can_board")), 2.0)
	check(bool(helicopter.get("can_board")), "on the roof the door is open to you")
	var door := helicopter.get_node("Door") as Interactable3D
	player.global_position = door.global_position - Vector3.UP * 1.1
	door.interact(player)
	await wait_until(func() -> bool: return bool(helicopter.get("flying")), 2.0)
	check(bool(helicopter.get("flying")) and (story.get("discovered") as Dictionary).has("escaped"), "climbing in takes off")
	check(not bool(clawman.get("enabled")), "the Clawman stops hunting as you leave")
	check(map.get_node("RooftopStreet").process_mode == Node.PROCESS_MODE_DISABLED, "the flight out over the street leaves its Ridgebacks be")
	var start := helicopter.global_position
	var departed := [false]
	helicopter.connect("departed", func() -> void: departed[0] = true)
	await wait_until(func() -> bool: return departed[0], 20.0)
	check(departed[0] and helicopter.global_position.y > start.y + 20.0, "it climbs away over the town (%.0f m up)" % (helicopter.global_position.y - start.y))
	check(player.global_position.distance_to(helicopter.global_position) < 3.0, "you ride in it")
	await wait_until(func() -> bool: return story.get_node_or_null("EscapeCard") != null, 2.0)
	check(story.get_node_or_null("EscapeCard") != null, "the screen fades to the end of the chapter")
	print("DONE failures=%d" % failures)
	if FileAccess.file_exists(THROWAWAY):
		DirAccess.remove_absolute(THROWAWAY)
	quit(1 if failures else 0)
