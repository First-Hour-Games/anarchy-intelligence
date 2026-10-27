extends SceneTree

const FOREST := "res://scenes/chapters/main/starting_forest.tscn"
const RESIDENCE := "res://scenes/chapters/main/residence_area.tscn"
var stream: Node
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func road_layout(road: Node3D) -> Dictionary:
	var layout := {}
	for shape in road.find_children("*", "CSGBox3D", true, false):
		layout[road.get_path_to(shape)] = [shape.transform, shape.size, shape.use_collision]
	return {"transform": road.transform, "shapes": layout}

func building_layout(section: Node3D) -> Dictionary:
	var layout := {}
	for node in section.find_children("*", "Node3D", true, false):
		if not node.scene_file_path.begins_with("res://models/buildings/neighborhood_lots/") and not node.scene_file_path.ends_with("hood.Final.glb"):
			continue
		var parts: Array[Node] = [node]
		parts.append_array(node.find_children("*", "Node3D", true, false))
		for part: Node3D in parts:
			# Works before entering the tree, so the saved scene is the reference.
			var world := part.transform
			var ancestor := part.get_parent()
			while ancestor is Node3D:
				world = ancestor.transform * world
				ancestor = ancestor.get_parent()
			layout[section.get_path_to(part)] = world
	return layout

func check_building_layout(section: Node3D, expected: Dictionary, stage: String) -> void:
	var actual := building_layout(section)
	var matches := actual.size() == expected.size()
	for path: NodePath in expected:
		if not actual.has(path) or not expected[path].is_equal_approx(actual[path]):
			matches = false
			print("Building placement mismatch at ", stage, ": ", path, " saved=", expected[path], " runtime=", actual.get(path))
	check(matches, "saved house, yard, garage and light transforms survive " + stage)

func check_junction_open(road: Node3D) -> void:
	# The west edge of the connecting road must leave the residential mouth open.
	# Check the actual road marking footprints rather than requiring named segments.
	for z in [132.5, 135.65405, 138.8]:
		var point := Vector3(124.22005, 0.105, z)
		var blocked := false
		for marking in road.find_children("*", "CSGBox3D", true, false):
			if not String(marking.name).contains("EdgeLine"):
				continue
			var bounds := AABB(-marking.size * 0.5, marking.size)
			if bounds.has_point(marking.to_local(point)):
				blocked = true
		check(not blocked, "residential junction has no edge stripe across its mouth at z=%s" % z)

func audit_foliage() -> void:
	var mesh_intrusions := 0
	var tree_overlaps := 0
	var batches := 0
	var grass_batches := 0
	var tree_bounds: Array[Dictionary] = []
	for section: Node3D in stream._sections.values():
		for node in section.get_node("Foliage").find_children("*", "MultiMeshInstance3D", true, false):
			if node.multimesh == null:
				continue
			batches += 1
			var is_tree: bool = node.name.to_lower().contains("tree")
			if not is_tree:
				grass_batches += 1
			for i in node.multimesh.instance_count:
				var bounds: AABB = (node.global_transform * node.multimesh.get_instance_transform(i)) * node.multimesh.mesh.get_aabb()
				var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
				for road: AABB in stream._road_bounds:
					if footprint.intersects(Rect2(Vector2(road.position.x, road.position.z), Vector2(road.size.x, road.size.z))):
						mesh_intrusions += 1
				for obstacle: AABB in stream._obstacle_bounds:
					if bounds.intersects(obstacle):
						mesh_intrusions += 1
				if is_tree:
					for previous in tree_bounds:
						if stream.preserve_authored_tree_spacing and previous.section == section:
							continue
						if bounds.intersects(previous.bounds):
							tree_overlaps += 1
					tree_bounds.append({"bounds": bounds, "section": section})
	check(batches >= 26 and grass_batches >= 2 and mesh_intrusions == 0, "every tree and nested grass mesh clears roads and obstacle geometry")
	check(tree_bounds.size() > 0 and tree_overlaps == 0, "tree canopies have no new cross-section conflicts while preserving authored spacing")

func run() -> void:
	stream = root.get_node("WorldStreaming")
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	# Use real scene assets and physics, skipping only the opening cinematic.
	var forest: Node3D = load(FOREST).instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	var residence_template: Node3D = load(RESIDENCE).instantiate()
	check(road_layout(forest.get_node("Streets2")) == road_layout(residence_template.get_node("Streets2")), "both entry scenes author the same connecting road and intersection markings")
	var saved_buildings := building_layout(residence_template)
	residence_template.free()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await process_frame
	check(stream.active_section == forest, "forest registers with streaming manager")
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	player.inventory.add_item(&"map")
	player.inventory.add_item(&"flashlight")
	player.inventory.select_slot(1)
	player.flashlight.set_enabled(true)
	player.stamina = 37.0
	player.head.rotation.x = -0.2
	player.velocity = Vector3(0, 0, 4)
	var original_player := player.get_instance_id()
	var forest_id := forest.get_instance_id()
	var original_ui: Node = forest.get_node("WorldMap")
	var original_ground: Node = forest.get_node("GroundPlane")
	var original_environment: Node = forest.get_node("WorldEnvironment")
	var original_road: Node = forest.get_node("Streets2")
	var door := forest.get_node("Interactables/VisitorCenterLockedDoor") as InteractableBlock3D
	door.is_enabled = false
	forest.set("_has_switched_music", true)
	var pickups := forest.find_children("*", "FlashlightPickup", true, false)
	var removed_pickup := NodePath()
	if not pickups.is_empty():
		removed_pickup = forest.get_path_to(pickups[0])
		pickups[0].free()
	# Start outside the preload radius, then approach the crossing on the existing road.
	player.position = Vector3(-150, 0.15, 10)
	await process_frame
	check(stream._sections.size() == 1 and stream._pending.is_empty(), "distant residence stays unloaded")
	player.position = Vector3(127, 0.15, 30)
	check(await wait_for(func(): return stream._sections.has(RESIDENCE)), "residence loads before crossing")
	if not stream._sections.has(RESIDENCE):
		quit(1)
		return
	var residence: Node3D = stream._sections[RESIDENCE]
	print("Foliage reconciliation: ", stream._foliage_filter.last_stats)
	var residence_id := residence.get_instance_id()
	check(current_scene == forest and not paused, "preloading leaves gameplay and active scene running")
	check(not residence.has_node("Player") and not residence.has_node("GroundPlane") and not residence.has_node("Streets2"), "preloaded section has no duplicate player, terrain or road")
	check(residence.get_node("ResidenceBoundary").is_point_inside(Vector3(127, 0.15, 75)), "residence boundary covers forest exit")
	check_building_layout(residence, saved_buildings, "preloading from forest")
	var road_intrusions := 0
	var tree_count := 0
	for section: Node3D in stream._sections.values():
		for trees in section.get_node("Foliage").get_children():
			if not trees is MultiMeshInstance3D or not trees.name.to_lower().contains("tree"):
				continue
			for i in trees.multimesh.instance_count:
				tree_count += 1
				var point: Vector3 = trees.global_transform * trees.multimesh.get_instance_transform(i).origin
				for bounds: AABB in stream._road_bounds:
					if Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).has_point(Vector2(point.x, point.z)):
						road_intrusions += 1
	check(tree_count > 0 and road_intrusions == 0, "both sections' tree trunks clear every streamed road and turnaround")
	audit_foliage()
	var grass_generator := forest.get_node("Foliage/ProceduralGrass") as ProceduralGrassGenerator
	grass_generator.clear_grass()
	await process_frame
	check(grass_generator.get_low_grass_node().multimesh.instance_count == 0, "cleared grass is not restored from the streaming cache")
	grass_generator.low_grass_count = 100
	grass_generator.tall_grass_count = 30
	grass_generator.generate_grass()
	await process_frame
	await process_frame
	audit_foliage()
	player.position.z = 75
	var departure := player.global_transform
	check(await wait_for(func(): return current_scene == residence), "walking across activates residence")
	if current_scene != residence:
		print("Crossing state: paused=", paused, " frozen=", player.is_frozen, " position=", player.global_position, " ready=", stream._ready_frames, " physics=", Engine.get_physics_frames())
		quit(1)
		return
	check(residence.get_node("Player").get_instance_id() == original_player, "same player survives crossing")
	check(player.global_transform.is_equal_approx(departure) and player.velocity == Vector3(0, 0, 4), "crossing preserves position, orientation and velocity")
	check(player.stamina == 37.0 and player.inventory.selected_slot_index == 1 and player.flashlight.is_enabled(), "stamina, inventory selection and flashlight persist")
	check(is_equal_approx(player.head.rotation.x, -0.2) and player.camera.is_current(), "look direction and active camera persist")
	check(residence.get_node("WorldMap") == original_ui and residence.get_node("WorldEnvironment") == original_environment, "same map UI and lighting survive")
	check(residence.get_node("GroundPlane") == original_ground and residence.get_node("Streets2") == original_road, "same ground and connecting road survive")
	check_building_layout(residence, saved_buildings, "activation from forest")
	check_junction_open(residence.get_node("Streets2"))
	check(is_instance_valid(forest), "forest remains loaded around crossing")
	player.position.z = 68
	await process_frame
	check(current_scene == residence, "small seam movements do not oscillate scenes")
	player.position.z = stream.seam_position.z + stream.unload_distance + 10.0
	check(await wait_for(func(): return not is_instance_id_valid(forest_id)), "forest unloads after leaving overlap")
	check(not paused and not player.is_frozen, "streaming never pauses or freezes the player")
	check_building_layout(residence, saved_buildings, "forest unloading")
	check_junction_open(residence.get_node("Streets2"))
	# Open the carried map after its old parent was freed.
	var map_display := original_ui.get_node("Display") as WorldMapOverlay
	map_display.set_map_open(true, false)
	check(map_display.is_map_open() and paused, "persistent map opens after forest unload")
	map_display.set_map_open(false, false)
	check(not paused, "persistent map closes and resumes gameplay")
	player.position.z = 110
	check(await wait_for(func(): return stream._sections.has(FOREST)), "return approach reloads forest")
	var returned_forest: StartingForest = stream._sections.get(FOREST)
	if returned_forest == null:
		quit(1)
		return
	check(not returned_forest.has_node("IntroFadeCanvas") and not returned_forest.has_node("BottomDialogueBalloon"), "forest return does not replay intro or opening dialogue")
	check(not returned_forest.get_node("Interactables/VisitorCenterLockedDoor").is_enabled, "one-shot interaction state survives unloading")
	check(returned_forest.get("_has_switched_music"), "forest music progression survives unloading")
	if not removed_pickup.is_empty():
		check(not returned_forest.has_node(removed_pickup), "collected flashlight stays removed")
	player.position.z = 60
	check(await wait_for(func(): return current_scene == returned_forest), "walking back activates forest")
	check(returned_forest.player == player and player.get_instance_id() == original_player, "returning forest binds the original player")
	player.position = Vector3(-100, 0.15, 10)
	check(await wait_for(func(): return not is_instance_id_valid(residence_id)), "residence unloads when returning deep into forest")
	# Leaving this world must also release preloaded neighbors and shared references.
	player.position = Vector3(127, 0.15, 30)
	check(await wait_for(func(): return stream._sections.has(RESIDENCE)), "second approach can stream residence again")
	var neighbor: Node = stream._sections.get(RESIDENCE)
	check_building_layout(neighbor, saved_buildings, "residence unloading and reloading")
	var elsewhere := Node3D.new()
	root.add_child(elsewhere)
	current_scene = elsewhere
	returned_forest.queue_free()
	scene_changed.emit()
	await process_frame
	await process_frame
	check(not is_instance_valid(neighbor) and stream.shared_nodes.is_empty(), "external scene change cleans up streamed neighbors")
	elsewhere.queue_free()
	current_scene = null
	await process_frame
	# Running the residence scene directly must also stream a playable forest.
	var direct: Node3D = load(RESIDENCE).instantiate()
	root.add_child(direct)
	current_scene = direct
	await process_frame
	await process_frame
	var direct_player := direct.get_node("Player") as FirstPersonPlayer
	direct_player.set_physics_process(false)
	direct_player.unfreeze()
	direct_player.position = Vector3(127, 0.15, 85)
	check(await wait_for(func(): return stream._sections.has(FOREST)), "direct residence entry preloads forest")
	var direct_forest: Node3D = stream._sections.get(FOREST)
	check(stream.shared_nodes.has("NightAmbience") and stream.shared_nodes.has("WelcomingHikeBGM"), "direct entry adopts forest audio once")
	direct_player.position.z = 60
	check(await wait_for(func(): return current_scene == direct_forest), "direct residence entry can walk back to forest")
	# Exercise actual CharacterBody movement over the seam, including collider reparenting.
	var supported := true
	for frame in 220:
		await physics_frame
		direct_player.velocity = Vector3(0, -1, 4)
		direct_player.move_and_slide()
		if direct_player.position.y < -0.1 or direct_player.position.y > 0.4:
			supported = false
	check(supported and direct_player.position.z > 72, "physical walking across seam keeps continuous ground support")
	check(current_scene == direct and not paused, "physical crossing activates residence without a pause")
	check_building_layout(direct, saved_buildings, "direct residence entry and return crossing")
	check_junction_open(direct.get_node("Streets2"))
	var playing: AudioStreamPlayer = stream.shared_nodes.get("NightAmbience")
	check(playing != null and playing.playing and playing.get_parent() == stream, "ambience stays on persistent parent across crossing")
	if "--capture" in OS.get_cmdline_user_args():
		direct_player.rotation.y = PI
		direct_player.flashlight.set_enabled(true)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/streaming_crossing.png")
	current_scene = null
	scene_changed.emit()
	await process_frame
	await process_frame
	print("World streaming smoke: %d failures" % failures)
	quit(1 if failures else 0)
