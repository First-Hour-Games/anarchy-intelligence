extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var menu := root.get_node("PauseMenu")
	menu.set_open(true)
	check(paused and menu.overlay.visible, "Escape menu pauses gameplay")
	var footstep_slider: HSlider = menu.sliders["Footsteps"]
	var original_volume := footstep_slider.value
	footstep_slider.value = 0.25
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Footsteps")), linear_to_db(0.25)), "Footstep slider applies reduced volume")
	footstep_slider.value = 0.0
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Footsteps")), "Footstep slider can mute footsteps")
	footstep_slider.value = original_volume
	menu.set_open(false)
	check(not paused and not menu.overlay.visible, "Resume closes menu and restores gameplay")
	player._play_surface_footstep()
	check(player.footstep_players[0].stream in player.WOOD_FOOTSTEPS, "Original recorded footsteps restored")
	check(player.footstep_players[0].bus == &"Footsteps", "Footsteps routed to dedicated slider")
	check(player.footstep_players[1].bus == &"Footsteps", "Alternating footsteps use the same volume control")
	check(AudioServer.get_bus_send(AudioServer.get_bus_index("Footsteps")) == &"Reverb", "Footsteps retain their original reverb")
	check(is_equal_approx(map.get_node("Clawman/Visual/Model").rotation.y, PI), "Clawman model forward corrected")
	check(is_equal_approx(map.get_node("THE_RIDGEBACK/Visual/Model").rotation.y, PI), "Ridgeback model forward corrected")
	player.freeze()
	var wrapper := map.get_node("Wrapper") as CharacterBody3D
	wrapper.enabled = true
	player.global_position = wrapper.global_position + Vector3(0, 0.2, 35)
	player.camera.look_at(player.camera.global_position + Vector3.FORWARD)
	# Turn away from the pursuer regardless of the camera's prior rotation.
	player.camera.look_at(player.camera.global_position + (player.global_position - wrapper.global_position).normalized())
	var before := wrapper.global_position
	for i in 100:
		await physics_frame
	check(Vector2(wrapper.global_position.x - before.x, wrapper.global_position.z - before.z).length() > 0.2, "Wrapper follows beyond its old territory")
	check(map.get_node("THE_RIDGEBACK").watch_distance > 500 and not map.get_node("THE_RIDGEBACK").watch_requires_line_of_sight, "Ridgeback can navigate after player rounds a corner")
	print("Pause and roaming failures: ", failures)
	quit(1 if failures else 0)
