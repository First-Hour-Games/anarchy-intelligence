extends SceneTree

const Alignment := preload("res://scenes/environment/surface_alignment.gd")
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func protect_save(node: Node) -> void:
	if node.name == &"OpeningStory":
		node.set("persist_progress", false)

func run() -> void:
	node_added.connect(protect_save)
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var house := map.get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	var nav := house.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav)
	var outside := house.to_global(Vector3(11.75, 0.25, 16))
	var inside := house.to_global(Vector3(11.75, 0.25, 7.5))
	var route := NavigationServer3D.map_get_path(nav, outside, inside, true)
	var reached := not route.is_empty() and Vector2(route[-1].x - inside.x, route[-1].z - inside.z).length() < 0.25
	check(reached, "Corner house interior connects to exterior navigation")
	player.freeze()
	player.global_position = inside
	player.camera.look_at(inside + Vector3.UP * 1.5 + Vector3.LEFT * 5)
	var wrapper := map.get_node("Wrapper") as CharacterBody3D
	wrapper.global_position = outside
	wrapper.enabled = true
	for i in 850:
		await physics_frame
	var local := house.to_local(wrapper.global_position)
	print("Wrapper house position ", local)
	check(local.z < 9.25, "Wrapper physically walks through the corner house door")
	var civic := map.get_node("Buildings/CivicFinishing")
	var supported: int = 0
	var total: int = 0
	for child: Node in civic.get_children():
		if child is Node3D and child.is_in_group("grounded_urban_prop"):
			total += 1
			var bounds := Alignment.world_bounds(child)
			var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
			var ray := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.02, foot - Vector3.UP * 0.05)
			if not child.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				supported += 1
			else:
				print("UNSUPPORTED ", child.name, " ", foot)
	check(total > 10 and supported == total, "Every civic ground prop rests on a supporting surface")
	var hospital := map.get_node("Buildings/NeighborhoodHospital") as Node3D
	for name: String in ["ReceptionDesk", "RecordsDesk", "PrivacyScreen", "SupplyShelfUpright"]:
		var box := hospital.get_node(name) as CSGBox3D
		check(is_equal_approx(box.position.y - box.size.y * 0.5, 0.12), name + " rests on hospital floor")
	var aligned_medical: int = 0
	var medical_total: int = 0
	for child: Node in hospital.get_children():
		if child is Node3D and child.has_meta("target_height"):
			medical_total += 1
			var bottom := Alignment.world_bounds(child).position.y
			var height := float(child.get_meta("target_height"))
			var correct := is_equal_approx(bottom, 0.12)
			if is_equal_approx(height, 0.65):
				correct = is_equal_approx(bottom, 1.02)
			elif is_equal_approx(height, 0.22):
				correct = is_equal_approx(bottom, 0.59) or is_equal_approx(bottom, 1.19) or is_equal_approx(bottom, 1.79)
			if correct:
				aligned_medical += 1
	check(medical_total >= 20 and aligned_medical == medical_total, "All hospital furniture and bottles sit on floor, cabinet or shelves")
	player.unfreeze()
	var pause_menu := root.get_node("PauseMenu")
	pause_menu.set_open(true)
	pause_menu.return_to_main_menu()
	for i in 12:
		await process_frame
	check(current_scene.scene_file_path == "res://scenes/mainMenu/menu.tscn" and not paused, "Escape Main Menu reaches the menu without pausing it")
	check(current_scene.can_continue, "Returning player receives Continue Game")
	current_scene._start_game()
	for i in 20:
		await physics_frame
	check(current_scene.scene_file_path == "res://scenes/chapters/main/map.tscn", "Continue resumes chapter without replaying intro")
	check(current_scene.get_node("MapNavigation").cache_reused, "Unchanged map reuses baked navigation cache")
	var resumed := current_scene.get_node("Player") as FirstPersonPlayer
	check(not paused and not resumed.is_frozen and resumed.is_physics_processing(), "Resumed player is active")
	var before := resumed.global_position
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	for i in 30:
		await physics_frame
	key.pressed = false
	Input.parse_input_event(key)
	check(resumed.global_position.distance_to(before) > 0.2, "Movement works after returning from menu")
	print("Menu, entry and alignment failures: ", failures)
	current_scene.queue_free()
	current_scene = null
	for i in 3:
		await process_frame
		await physics_frame
	quit(1 if failures else 0)
