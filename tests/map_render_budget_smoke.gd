extends SceneTree
## The town maps' render budget, in the main map and the alt route's copy: what lies flat on the ground (the
## ground, roads, curbs, road markings, the generated sidewalks and drives, the cul-de-sacs, the downtown's paving)
## casts no shadows, while what stands up still does; LightDistanceFade (light_distance_fade.gd) fades the
## town's lamps with distance, leaving the player's flashlight as it is; and FogDrawDistance (fog_draw_distance.gd)
## stops drawing small, low things past the camera fog, but not tall or big ones, nor the player's, and not while
## the world map shows the town from above. Nothing is saved: the story's save points at a throwaway file.

const MAPS := ["res://scenes/chapters/main/map.tscn", "res://scenes/chapters/alt_route/map_alt.tscn"]
const THROWAWAY := "user://test_map_render_budget_story.json"
const OFF := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func run() -> void:
	for path: String in MAPS:
		await check_map(path)
	quit(1 if failures else 0)


func shadowless(nodes: Array) -> bool:
	return not nodes.is_empty() and nodes.all(func(n: Node) -> bool: return (n as GeometryInstance3D).cast_shadow == OFF)


## The geometry under `root` named one of `names`, however Godot numbered the repeats (Sidewalk2, @Sidewalk@3).
func named(root: Node, names: Array) -> Array:
	return root.find_children("*", "GeometryInstance3D", true, false).filter(
		func(n: Node) -> bool: return str(n.name).replace("@", "").rstrip("0123456789") in names)


func check_map(path: String) -> void:
	var title := path.get_file().get_basename()
	var map := (load(path) as PackedScene).instantiate() as Node3D
	for node in map.find_children("*", "", true, false):
		if "persist_progress" in node:
			node.set("persist_progress", false)
		if "progress_save_path" in node:
			node.set("progress_save_path", THROWAWAY)
		if "cache_navigation" in node:
			node.set("cache_navigation", false)
	root.add_child(map)
	current_scene = map
	for i in 8:
		await process_frame

	# Flat on the ground: no shadows.
	check((map.get_node("GroundPlane") as GeometryInstance3D).cast_shadow == OFF, "%s: the ground casts no shadow" % title)
	var laid: Array = []
	for group in ["Roads", "Curbs", "RoadMarkings"]:
		laid.append_array(map.get_node(group).find_children("*", "GeometryInstance3D", true, false))
	check(shadowless(laid), "%s: its %d roads, curbs and road markings cast none" % [title, laid.size()])
	var streets := map.get_node("ConnectedUpperStreet")
	var paving := named(streets, ["Sidewalk", "Driveway", "DrivewayApron", "DrivewayCrossing", "ParkingPad", "FrontWalk", "Curb", "GardenTerrace"])
	check(shadowless(paving), "%s: nor do the upper street's %d sidewalks, drives and curbs" % [title, paving.size()])
	var standing := named(streets, ["CarportRoof", "FenceRail", "MailboxPost"])
	check(not standing.is_empty() and standing.all(func(n: Node) -> bool: return (n as GeometryInstance3D).cast_shadow != OFF),
		"%s: while its carports, fences and mailboxes still do" % title)
	var connections := map.get_node("RemainingStreetConnections").find_children("*", "MeshInstance3D", true, false)
	check(shadowless(connections), "%s: the other streets' %d drives and sidewalks cast none" % [title, connections.size()])
	var turnarounds := named(map.get_node("CulDeSacs"), ["RoadSurface", "Curb", "Sidewalk"])
	check(shadowless(turnarounds), "%s: nor the cul-de-sacs (%d)" % [title, turnarounds.size()])
	var downtown_paving := map.get_node("Buildings/Downtown").find_children("Paving", "MeshInstance3D", true, false)
	check(shadowless(downtown_paving), "%s: nor the downtown's paving" % title)

	# Lamps fade with distance; the player's flashlight keeps its own fade.
	var fader := map.get_node_or_null("LightDistanceFade")
	check(fader != null, "%s: has its LightDistanceFade" % title)
	var player := map.get_node("Player") as Node3D
	var lamps := 0
	var faded := true
	for node: Node in map.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or player.is_ancestor_of(light) or light.has_meta(&"keep_far"):
			continue
		lamps += 1
		faded = faded and light.distance_fade_enabled and light.distance_fade_begin + light.distance_fade_length <= 200.0
	check(lamps > 50 and faded, "%s: all its %d lamps fade out in the distance" % [title, lamps])
	var flashlight := player.find_children("*", "SpotLight3D", true, false).filter(func(n: Node) -> bool: return (n as SpotLight3D).spot_range > 20.0)
	check(not flashlight.is_empty() and is_equal_approx((flashlight[0] as Light3D).distance_fade_begin, 27.0),
		"%s: the flashlight keeps its own fade" % title)
	var late := OmniLight3D.new()
	map.get_node("Buildings").add_child(late)
	await process_frame
	await process_frame
	check(late.distance_fade_enabled, "%s: a lamp added later fades too" % title)

	# Small, low things stop drawing where the camera fog hides them.
	var drawer := map.get_node_or_null("FogDrawDistance")
	check(drawer != null, "%s: has its FogDrawDistance" % title)
	var distance: float = drawer.get("draw_distance") if drawer else 0.0
	var ranged: Array = []
	var wrong: Array = []
	for node: Node in map.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_in_group(&"fog_draw_distance_ranged"):
			continue
		ranged.append(geometry)
		var box := geometry.global_transform * geometry.get_aabb()
		if box.end.y > 4.01 or box.size[box.get_longest_axis_index()] >= 40.0 or player.is_ancestor_of(geometry) \
				or not is_equal_approx(geometry.visibility_range_end, distance):
			wrong.append(str(map.get_path_to(geometry)))
	check(distance > 70.0 and ranged.size() > 500 and wrong.is_empty(),
		"%s: %d small, low things stop drawing past %.0f m, none of them tall, big or the player's %s" % [title, ranged.size(), distance, wrong.slice(0, 3)])
	var tall_ranged := 0
	for node: Node in map.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if (geometry.global_transform * geometry.get_aabb()).end.y > 6.0 and geometry.is_in_group(&"fog_draw_distance_ranged"):
			tall_ranged += 1
	check(tall_ranged == 0 and (map.get_node("GroundPlane") as GeometryInstance3D).visibility_range_end == 0.0,
		"%s: the ground and everything tall keep drawing at any distance" % title)
	var crate := MeshInstance3D.new()
	crate.mesh = BoxMesh.new()
	map.get_node("Buildings").add_child(crate)
	crate.global_position = Vector3(10.0, 0.5, 10.0)
	var mast := MeshInstance3D.new()
	var mast_box := BoxMesh.new()
	mast_box.size = Vector3(0.4, 8.0, 0.4)
	mast.mesh = mast_box
	map.get_node("Buildings").add_child(mast)
	mast.global_position = Vector3(12.0, 4.0, 10.0)
	await process_frame
	await process_frame
	check(is_equal_approx(crate.visibility_range_end, distance) and mast.visibility_range_end == 0.0,
		"%s: a small thing added later stops drawing far off too, a tall one does not" % title)
	# The world map draws the town from high above: all of it, until it closes.
	var world_map: Node = null
	for node: Node in [map.get_node("WorldMap")] + map.get_node("WorldMap").find_children("*", "", true, false):
		var script := node.get_script() as Script
		if script != null and script.resource_path.ends_with("world_map.gd"):
			world_map = node
	check(world_map != null, "%s: has its world map" % title)
	if world_map != null:
		world_map.call("_set_overhead_rendering", true)
		var all_drawn := ranged.all(func(n: Node) -> bool: return not is_instance_valid(n) or (n as GeometryInstance3D).visibility_range_end == 0.0)
		world_map.call("_set_overhead_rendering", false)
		var limited_again := ranged.all(func(n: Node) -> bool: return not is_instance_valid(n) or is_equal_approx((n as GeometryInstance3D).visibility_range_end, distance))
		check(all_drawn and limited_again, "%s: the world map's overhead view draws them all, and they stop again once it closes" % title)

	map.queue_free()
	current_scene = null
	for i in 4:
		await process_frame
