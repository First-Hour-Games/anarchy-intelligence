extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, words: String) -> void:
	print(("PASS " if value else "FAIL ") + words)
	if not value:
		failures += 1

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var inventory := player.inventory
	check(player.max_stamina == 200, "Sprint capacity is doubled")
	check(player.get_node("HandViewmodel/AspectRatioContainer/Content/StaminaHUD/StaminaLabel").text == "", "Stamina bar has no word label")
	check(not inventory.get_node("InventoryBar").visible, "Mini inventory is removed from gameplay")
	check(inventory.has_item(PlayerInventory.MAP_ITEM), "Inventory carries the welcome-center map")
	inventory.set_open(true)
	check(inventory.is_open and paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "E inventory safely pauses the world")
	inventory.set_open(false)
	check(not inventory.is_open and not paused, "Closing inventory resumes the world")
	inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	inventory.select_slot(0)
	var event := InputEventAction.new()
	event.action = &"flashlight_toggle"
	event.pressed = true
	player._unhandled_input(event)
	check(player.flashlight.is_enabled(), "F works with flashlight owned while the map is selected")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	player._unhandled_input(wheel)
	check(inventory.selected_slot_index == 0, "Mouse wheel no longer switches items")
	var hospital := map.get_node("Buildings/NeighborhoodHospital") as Node3D
	player.global_position = hospital.to_global(Vector3(-10.2, 0.3, -3))
	await physics_frame
	check(player.get_footstep_surface() == &"tile", "Hospital floor selects tile footsteps")
	player.global_position = Vector3(100, 0.3, 100)
	await physics_frame
	check(player.get_footstep_surface() == &"gravel", "Town road selects gravel footsteps")
	var bottles: Array[Node] = []
	for child: Node in hospital.get_children():
		if child.has_meta("target_height") and is_equal_approx(float(child.get_meta("target_height")), 0.22):
			bottles.append(child)
	check(bottles.size() == 9, "Medical bottles are normalized to 22 cm")
	var ray := PhysicsRayQueryParameters3D.create(hospital.to_global(Vector3(-15, 1.7, -2)), hospital.to_global(Vector3(-15, 1.7, 1)))
	check(not hospital.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Hospital front shell closes facade gaps away from the door")
	var visual := map.get_node("Clawman/Visual")
	check(visual.animation_player != null and visual.animation_player.is_playing(), "Clawman plays its idle animation instead of its rest pose")
	for clip: String in ["idle", "walk", "run", "windup", "attack"]:
		check(visual.resolve_clip(clip) != &"", "Clawman resolves " + clip)
	player.freeze()
	var ridge := map.get_node("THE_RIDGEBACK")
	ridge.global_position = Vector3(300, 0.2, 100)
	player.global_position = Vector3(300, 0.2, 108)
	player.camera.look_at(ridge.global_position + Vector3.UP * 1.2)
	player.flashlight.set_enabled(true)
	await physics_frame
	check(ridge._flashlight_hits_me(), "Ridgeback detects a flashlight beam with clear sight")
	var before: float = ridge.global_position.distance_to(player.global_position)
	for i in 30:
		await physics_frame
	check(ridge.light_fear > 0 and ridge.global_position.distance_to(player.global_position) > before + 0.3, "Flashlight makes Ridgeback retreat farther")
	player.flashlight.set_enabled(false)
	var lamp := OmniLight3D.new()
	lamp.light_energy = 3.0
	lamp.omni_range = 10
	lamp.add_to_group("ridgeback_repellent")
	map.add_child(lamp)
	lamp.global_position = player.global_position + Vector3.UP * 2
	check(ridge._world_light_at(player.global_position + Vector3.UP) > 0.12, "Stationary light protects the player")
	print("Gameplay refinement failures: ", failures)
	map.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
