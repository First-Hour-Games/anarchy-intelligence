extends SceneTree
## The alt route's way to the hospital (scenes/chapters/alt_route/rooftop_street.gd in map_alt.tscn): the
## downtown street between the alt downtown's tall rows, jammed with cars in rows that each leave one way
## through, and a line of fourteen Ridgebacks along both rows' roof edges. They are up there once Carrie's
## notebook has been read; walking in among the first cars sets the whole line shrieking, then they throw
## themselves off ahead of the player one at a time, onto the road or a car's roof (whose alarm goes off).
## The first lives and the survivors lose their legs, leave them where they hit and drag themselves after
## the player to claw at the ankles, which hurts and holds the player back. Shot in the air they land dead;
## shot on the roof they jump at once, or fall dead; a crawler takes two shots. Past the finale line the rest
## come down together, and at the hospital it is over. A death puts the street back before the shriek, with
## the Wrapper kept out and the checkpoint at the corner. The main storyline's map and downtown are unchanged.
## Nothing is saved: the story's save points at a throwaway file and is never written.

const MAP_ALT := "res://scenes/chapters/alt_route/map_alt.tscn"
const MAP := "res://scenes/chapters/main/map.tscn"
const THROWAWAY := "user://test_alt_rooftop_street_story.json"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


## Waits until `ready` holds or `seconds` of game time pass; whether it held.
func wait_until(ready: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if ready.call():
			return true
		await physics_frame
		left -= 1.0 / Engine.physics_ticks_per_second * Engine.time_scale
	return bool(ready.call())


func place(player: FirstPersonPlayer, at: Vector3, look: Vector3) -> void:
	player.global_position = at
	var camera := player.get_node("Head/Camera3D") as Camera3D
	var to := look - camera.global_position
	player.rotation.y = atan2(-to.x, -to.z)
	player.head.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())


## How many separate ways through the row of cars at `x` a player-sized capsule finds, across the street.
func openings(space: PhysicsDirectSpaceState3D, x: float, ignore: Array[RID]) -> int:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = ignore
	var count := 0
	var was_free := false
	var z := RooftopStreet.NORTH_WALL
	while z <= RooftopStreet.SOUTH_WALL:
		var free := true
		for dx: float in [-0.9, 0.0, 0.9]:
			query.transform = Transform3D(Basis.IDENTITY, Vector3(x + dx, 0.95, z))
			if not space.intersect_shape(query, 1).is_empty():
				free = false
		if free and not was_free:
			count += 1
		was_free = free
		z += 0.1
	return count


func run() -> void:
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	if FileAccess.file_exists(THROWAWAY):
		DirAccess.remove_absolute(THROWAWAY)

	# The main storyline's map and downtown stay as they were.
	var base_map := FileAccess.get_file_as_string(MAP)
	check(not base_map.contains("rooftop_street") and base_map.contains("res://scenes/environment/downtown.tscn"),
		"The main map has no rooftop street and keeps the main downtown")
	var finishing: GDScript = load("res://scenes/environment/civic_finishing.gd")
	check(finishing.get_script_constant_map()["MARKERS"] == "res://models/buildings/downtown/downtown_markers.json",
		"The main downtown's furniture still reads the main downtown's markers")

	var map: Node3D = (load(MAP_ALT) as PackedScene).instantiate()
	for node in map.find_children("*", "", true, false):
		if "persist_progress" in node:
			node.set("persist_progress", false)
		if "progress_save_path" in node:
			node.set("progress_save_path", THROWAWAY)
		if "cache_navigation" in node:
			node.set("cache_navigation", false)
	root.add_child(map)
	current_scene = map
	var player := map.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	place(player, Vector3(101.0, 0.2, 225.0), Vector3(140.0, 12.0, 225.0))
	for i in 8:
		await physics_frame
	var story := map.get_node("OpeningStory")
	var street := map.get_node("RooftopStreet") as RooftopStreet
	var health := player.get_node("CombatHealth")
	var wrapper := map.get_node("Wrapper")
	var space := street.get_world_3d().direct_space_state
	check(map.get_node("Buildings/Downtown").scene_file_path == "res://scenes/environment/downtown_alt.tscn",
		"The alt map stands the alt downtown on the street")
	check(story.get("progress_save_path") == THROWAWAY and not bool(story.get("persist_progress")),
		"The test's story never saves")

	# The line, before the story has sent Thomas to the hospital: there, but not shown.
	var fallers := street.fallers
	check(fallers.size() == 14, "Fourteen Ridgebacks stand on the roofs")
	var on_edges := true
	var facing := true
	for faller in fallers:
		var p := faller.global_position
		on_edges = on_edges and p.y >= 14.0 and (absf(p.z - 216.28) < 0.05 or absf(p.z - 234.22) < 0.05)
		var forward := -faller.global_basis.z
		facing = facing and forward.dot(Vector3(0, 0, signf(225.0 - p.z))) > 0.95
	check(on_edges, "Each one stands on the front edge of a roof, 14 m up or more")
	check(facing, "Each one faces the street")
	var north := fallers.filter(func(f: RidgebackFaller) -> bool: return f.global_position.z < 225.0).size()
	check(north == 7, "Seven stand along each row")
	var kinds := {}
	for faller in fallers:
		kinds[faller.visual.walker] = true
	check(kinds.size() == 1 and kinds.has(&""), "The line is the original Ridgeback")
	check(street.phase == RooftopStreet.Phase.ASLEEP and fallers.all(func(f: RidgebackFaller) -> bool: return not f.visible),
		"Before Carrie's notebook they are not up there")

	# The jam: rows of cars that each leave one way through, and the street still open end to end.
	var bodies: Array[RID] = [player.get_rid()]
	for faller in fallers:
		bodies.append(faller.get_rid())
	check(street.cars.size() >= 35, "The evacuation left a jam of cars in the street (%d)" % street.cars.size())
	var sealed := true
	for row: Array in RooftopStreet.ROWS:
		var ways := openings(space, float(row[0]), bodies)
		if ways != 1:
			sealed = false
			print("  row at x %.1f: %d ways through" % [float(row[0]), ways])
	check(sealed, "Every row of cars leaves exactly one way through")
	var reach := {}
	var start := street._cell(Vector3(104.0, 0.0, 225.0))
	var queue: Array[Vector2i] = [start]
	reach[start] = true
	var far := 0.0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		far = maxf(far, street._point(cell, 0.0).x)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if not reach.has(next) and street.grid.is_in_boundsv(next) and not street.grid.is_point_solid(next):
				reach[next] = true
				queue.append(next)
	check(far >= 240.0, "A crawler can find its way from the corner to the hospital (%.1f)" % far)
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	var fenced := true
	for mouth: Vector3 in [Vector3(139.0, 0.95, 234.3), Vector3(169.0, 0.95, 234.3), Vector3(201.0, 0.95, 234.3),
			Vector3(172.75, 0.95, 216.2), Vector3(222.5, 0.95, 216.2), Vector3(120.0, 0.95, 216.2)]:
		query.transform = Transform3D(Basis.IDENTITY, mouth)
		fenced = fenced and not space.intersect_shape(query, 1).is_empty()
	check(fenced, "Fences close the alleys and the corner lot")
	check(street.get_node_or_null("CrashedPoliceCar") != null and street.get_node_or_null("Shells1") != null,
		"The police car crashed at the corner has shells by it")
	# Its lamps on a budget: only headlights, tail lights and the floodlights cast shadows, the cars' lamps only
	# near the camera, and every lamp but the floodlights fades out in the distance.
	var shadowed := 0
	var floods := 0
	var budget_kept := true
	for node: Node in street.find_children("*", "Light3D", true, false):
		var lamp := node as Light3D
		if lamp is DirectionalLight3D:
			continue
		if lamp.has_meta(&"keep_far"):
			floods += 1
			budget_kept = budget_kept and lamp.shadow_enabled and not lamp.distance_fade_enabled
			continue
		if lamp.shadow_enabled:
			shadowed += 1
			var headlight := lamp is SpotLight3D and lamp.light_energy >= RooftopStreet.HEADLIGHT_ENERGY
			var tail_light := lamp is OmniLight3D and (lamp as OmniLight3D).omni_range >= RooftopStreet.TAIL_LIGHT_REACH \
				and (lamp as OmniLight3D).omni_range <= RooftopStreet.TAIL_LIGHT_RANGE \
				and (lamp as OmniLight3D).omni_shadow_mode == OmniLight3D.SHADOW_DUAL_PARABOLOID
			budget_kept = budget_kept and (headlight or tail_light)
		budget_kept = budget_kept and lamp.distance_fade_enabled and lamp.distance_fade_shadow <= RooftopStreet.HEADLIGHT_SHADOW_REACH
	check(budget_kept and floods == 2 and shadowed > 0 and shadowed <= 20,
		"Only the headlights and tail lights (%d, tail lights reaching %.0f m) and the two floodlights cast shadows; the cars' lamps fade out far off" % [
			shadowed, RooftopStreet.TAIL_LIGHT_RANGE])

	# The notebook read (the debug menu's start): they are up there now.
	story.call("debug_start_street")
	place(player, Vector3(101.0, 0.2, 225.0), Vector3(140.0, 12.0, 225.0))
	check(int(story.get("stage")) == 2 and player.has_item(&"shotgun") and player.has_item(PlayerInventory.FLASHLIGHT_ITEM),
		"The street's start has the story at the hospital stage, with the shotgun and the flashlight")
	check(await wait_until(func() -> bool: return street.phase == RooftopStreet.Phase.WATCHING, 1.0)
		and fallers.all(func(f: RidgebackFaller) -> bool: return f.visible and f.is_perched()),
		"Once Thomas is bound for the hospital they stand on the roofs, waiting")
	var spare := street.get_node_or_null("Shotgun")
	check(spare == null or spare.is_queued_for_deletion(), "The police car's shotgun goes once Thomas has one")

	# Into the cars: the whole line shrieks, then they start to come down.
	place(player, Vector3(117.0, 0.2, 225.0), Vector3(140.0, 12.0, 225.0))
	await create_timer(0.5).timeout
	check(street.phase == RooftopStreet.Phase.WATCHING, "Short of the cars, the line only watches")
	place(player, Vector3(122.0, 0.2, 225.0), Vector3(140.0, 14.0, 225.0))
	var shrieking := func() -> bool:
		return fallers.all(func(f: RidgebackFaller) -> bool: return f.state == RidgebackFaller.State.SHRIEKING)
	var all_shriek := await wait_until(shrieking, 1.2)
	check(all_shriek, "Among the first cars, every one of them shrieks")
	check(not bool(wrapper.get("enabled")), "The Wrapper keeps out of the street while it has Thomas")
	var spawn: Transform3D = health.get("spawn")
	check(spawn.origin.distance_to(Vector3(103.0, 0.35, 225.0)) < 0.5, "A death in the street starts Thomas at the corner")
	var found: Array[RidgebackFaller] = []
	var someone_falls := func() -> bool:
		for f in fallers:
			if f.is_falling() and not f.dead:
				found.append(f)
				return true
		return false
	check(await wait_until(someone_falls, 4.0), "Then they throw themselves off")
	var first: RidgebackFaller = found[0] if not found.is_empty() else null
	if first == null:
		_finish(map)
		return
	var lead := first.global_position.x - player.global_position.x
	check(lead > 0.0, "The first one goes from in front of the player (%.1f m ahead)" % lead)
	check(first.survives and is_instance_valid(first.landing_car), "The first one lives and is heading for a car's roof")
	var car := first.landing_car
	check(await wait_until(func() -> bool: return first.state >= RidgebackFaller.State.SPLATTED, 4.0), "It hits")
	var landed_at := first.global_position
	check(Vector2(landed_at.x - first.home.origin.x, landed_at.z - first.home.origin.z).length() <= street.leap_reach + 0.1,
		"It lands within one leap of its roof")
	check(landed_at.y > 1.0, "On the car's roof")
	var alarm := car.get_node_or_null("CarAlarm") as CarAlarm
	check(alarm != null and alarm.is_sounding(), "The car's alarm goes off")
	check(street.get_node("Gore").get_children().any(func(n: Node) -> bool: return n is Decal), "It leaves blood where it hit")
	check(await wait_until(func() -> bool: return first.visual.is_crawler, 2.0) and first.visual.legs.visible
		and first.visual.legs.top_level and first.visual.legs.global_position.distance_to(landed_at) < 0.6,
		"It lives without its legs, and leaves them where it hit")

	# It drags itself after the player, round the cars, and claws at the ankles.
	var stand := Vector3.ZERO
	for offset: Vector3 in [Vector3(0, 0, 3.5), Vector3(0, 0, -3.5), Vector3(3.5, 0, 0), Vector3(-3.5, 0, 0),
			Vector3(0, 0, 5.0), Vector3(0, 0, -5.0)]:
		var spot := Vector3(landed_at.x, 0.0, landed_at.z) + offset
		if street._walkable(spot):
			stand = spot + Vector3.UP * 0.2
			break
	check(stand != Vector3.ZERO, "There is room to stand near where it came down")
	place(player, stand, landed_at)
	var path_left := func() -> float:
		var path := street.grid.get_point_path(street._nearest_open(street._cell(first.global_position)),
			street._nearest_open(street._cell(stand)), true)
		var length := 0.0
		for index in range(1, path.size()):
			length += path[index].distance_to(path[index - 1]) * RooftopStreet.GRID_CELL
		return length
	var start_gap: float = path_left.call()
	await create_timer(3.0).timeout
	var gap: float = path_left.call()
	check(first.is_crawling() and gap < start_gap, "It crawls toward the player, round the cars (%.1f m to %.1f m)" % [start_gap, gap])
	var before := float(health.get("health"))
	var walk := player.walk_speed
	var clawed: Array[bool] = [false]
	var hurt := func() -> bool:
		clawed[0] = clawed[0] or first.state == RidgebackFaller.State.GRABBING
		return float(health.get("health")) < before
	var grabbed := await wait_until(hurt, 20.0)
	check(grabbed and clawed[0], "It claws at the ankles, and it hurts")
	check(grabbed and player.walk_speed < walk * 0.5, "and holds the player back a moment")
	check(await wait_until(func() -> bool: return is_equal_approx(player.walk_speed, walk), 2.0), "then lets go")

	# The shotgun: a crawler takes two shots.
	first.take_shot(18.0, player.global_position + Vector3.UP * 1.6)
	check(first.state == RidgebackFaller.State.HURT and not first.dead, "A crawler hit once squeals and keeps coming")
	first.take_shot(40.0, player.global_position + Vector3.UP * 1.6)
	check(first.dead and first.state == RidgebackFaller.State.DEAD, "A second shot kills it")
	check(first.visual.is_crawler, "It dies where it crawled")

	# Shot in the air, one lands dead.
	place(player, Vector3(150.0, 0.2, 225.0), Vector3(170.0, 14.0, 225.0))
	found.clear()
	check(await wait_until(someone_falls, 12.0), "Another comes down")
	var flying: RidgebackFaller = found[0] if not found.is_empty() else null
	if flying != null:
		flying.take_shot(20.0, player.global_position)
		check(flying.dead, "Shot in the air, it is dead before it lands")
		check(await wait_until(func() -> bool: return flying.state == RidgebackFaller.State.DEAD, 4.0)
			and not flying.visual.is_crawler, "and lands dead, legs and all")

	# Shot on the roof: a wound sends it off at once; a killing shot tips it off dead.
	var perched := fallers.filter(func(f: RidgebackFaller) -> bool: return f.is_perched())
	if perched.size() >= 2:
		var wounded: RidgebackFaller = perched[0]
		wounded.take_shot(10.0, player.global_position)
		check(wounded.state == RidgebackFaller.State.LEAPING, "Wounded on its roof, it jumps at once")
		var killed: RidgebackFaller = perched[1]
		killed.take_shot(200.0, player.global_position)
		check(killed.dead and killed.state == RidgebackFaller.State.FALLING, "Killed on its roof, it goes over the edge")
		check(await wait_until(func() -> bool: return killed.state == RidgebackFaller.State.DEAD, 4.0)
			and killed.global_position.y < 3.0, "and lies in the street below")

	# A death: the street goes back to before the shriek, with the player at the corner.
	place(player, Vector3(103.0, 0.35, 225.0), Vector3(140.0, 12.0, 225.0))
	call_group(&"corrupted_friend", "reset_enemy")
	await physics_frame
	check(street.phase == RooftopStreet.Phase.WATCHING, "After a death the street waits for the player again")
	var home_whole := func(f: RidgebackFaller) -> bool:
		return f.is_perched() and not f.dead and not f.visual.is_crawler and f.global_position.distance_to(f.home.origin) < 0.01
	check(fallers.all(home_whole), "and every one of them is back on its roof, whole")
	await physics_frame
	check(street.get_node("Gore").get_children().all(func(n: Node) -> bool: return n.is_queued_for_deletion()),
		"The blood is gone")
	check(not alarm.is_sounding(), "The alarms are quiet")

	# Back in: the shriek again, then the finale, then the hospital.
	place(player, Vector3(122.0, 0.2, 225.0), Vector3(140.0, 14.0, 225.0))
	check(await wait_until(func() -> bool: return street.phase == RooftopStreet.Phase.RAINING, 4.0), "Walking back in starts it again")
	place(player, Vector3(212.0, 0.2, 225.0), Vector3(230.0, 14.0, 225.0))
	check(await wait_until(func() -> bool: return street.phase == RooftopStreet.Phase.FINALE, 1.0), "Near the far end comes the finale")
	check(await wait_until(func() -> bool: return fallers.all(func(f: RidgebackFaller) -> bool: return not f.is_perched()), 12.0),
		"in which every one still up there comes down")
	place(player, Vector3(241.0, 0.2, 232.0), Vector3(255.0, 1.5, 247.0))
	check(await wait_until(func() -> bool: return street.phase == RooftopStreet.Phase.DONE, 1.0), "At the hospital it is over")
	check(await wait_until(func() -> bool: return bool(wrapper.get("enabled")), 1.0), "and the Wrapper is free to follow again")
	var lying := fallers.filter(func(f: RidgebackFaller) -> bool: return f.dead).map(func(f: RidgebackFaller) -> Vector3: return f.global_position)
	call_group(&"corrupted_friend", "reset_enemy")
	await physics_frame
	var still := true
	for f in fallers:
		if f.dead and not lying.has(f.global_position):
			still = false
	check(street.phase == RooftopStreet.Phase.DONE and still, "A death after it leaves the street as it was")

	check(fallers[0].scare_kind in (load("res://scenes/ui/death_scare.gd") as GDScript).get_script_constant_map()["SOUNDS"],
		"A Ridgeback that kills plays its own death scream")
	check(not FileAccess.file_exists(THROWAWAY), "Nothing was saved")
	_finish(map)


func _finish(map: Node) -> void:
	map.queue_free()
	await process_frame
	print("FAILURES %d" % failures)
	quit(1 if failures else 0)
