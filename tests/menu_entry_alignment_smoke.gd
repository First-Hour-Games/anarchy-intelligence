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
	var house := map.get_node("Buildings/ResidentialLots/CarrieHouse") as Node3D
	var nav := house.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav)
	var outside: Vector3 = house.call("point", &"yard_front") + Vector3.UP * 0.25
	# Deep enough in the hall that the Wrapper, stopping at arm's length, is still past the door.
	var inside: Vector3 = house.call("point", &"hall") - house.global_basis.z * 1.6 + Vector3.UP * 0.25
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
	check(local.z < -0.2, "Wrapper physically walks through the corner house door")
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
	# The furnished interior is part of the exported model; its floors sit at the hospital floor height.
	for area: String in ["West", "Lobby", "Core", "EastA", "EastB"]:
		var floor_mesh := hospital.get_node_or_null("Source/GroundFloor_" + area) as MeshInstance3D
		check(floor_mesh != null and absf(Alignment.world_bounds(floor_mesh).end.y - 0.12) < 0.002, "GroundFloor_" + area + " is level with the hospital floor")
	var aligned_medical: int = 0
	var medical_total: int = 0
	for child: Node in hospital.get_children():
		if child is Node3D and child.has_meta("target_height") and child.has_meta("support_y"):
			medical_total += 1
			var bottom := Alignment.world_bounds(child).position.y
			if absf(bottom - float(child.get_meta("support_y"))) < 0.01:
				aligned_medical += 1
			else:
				print("MISALIGNED ", child.name, " bottom ", bottom, " support ", child.get_meta("support_y"))
	check(medical_total >= 20 and aligned_medical == medical_total, "All hospital pack props sit on their floor, counter, cabinet or shelf")
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
