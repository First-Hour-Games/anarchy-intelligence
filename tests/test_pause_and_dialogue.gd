extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func run() -> void:
	print("=== Running Pause Screen and Dialogue Integration Smoke Test ===")
	await process_frame

	var pause_menu := root.get_node_or_null("PauseMenu")
	check(pause_menu != null, "PauseMenu autoload exists in root")
	check(pause_menu.layer == 250, "PauseMenu layer is 250 (always on top)")

	# 1. Verify Tutorial Scene layers and mouse filters
	print("\n--- Test 1: Tutorial Overlay and Instruction Labels Hierarchy ---")
	var packed_tutorial := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	check(packed_tutorial != null, "Tutorial scene loaded successfully")
	var tutorial_state := packed_tutorial.get_state()
	var tutorial_overlay_layer := -1
	var move_label_mouse_filter := -1
	var run_label_mouse_filter := -1
	for i in range(tutorial_state.get_node_count()):
		var node_name := tutorial_state.get_node_name(i)
		if node_name == "TutorialOverlay":
			for p in range(tutorial_state.get_node_property_count(i)):
				if tutorial_state.get_node_property_name(i, p) == "layer":
					tutorial_overlay_layer = tutorial_state.get_node_property_value(i, p)
		elif node_name == "RunLabel":
			for p in range(tutorial_state.get_node_property_count(i)):
				if tutorial_state.get_node_property_name(i, p) == "mouse_filter":
					run_label_mouse_filter = tutorial_state.get_node_property_value(i, p)
		elif node_name == "MoveLabel":
			for p in range(tutorial_state.get_node_property_count(i)):
				if tutorial_state.get_node_property_name(i, p) == "mouse_filter":
					move_label_mouse_filter = tutorial_state.get_node_property_value(i, p)

	check(tutorial_overlay_layer == 20, "TutorialOverlay layer in tutorial.tscn is 20 (got %d)" % tutorial_overlay_layer)
	check(pause_menu.layer > tutorial_overlay_layer, "PauseMenu layer (%d) is higher than TutorialOverlay layer (%d)" % [pause_menu.layer, tutorial_overlay_layer])
	check(run_label_mouse_filter == Control.MOUSE_FILTER_IGNORE, "RunLabel has mouse_filter = 2 (IGNORE) so it cannot block Quit button clicks")
	check(move_label_mouse_filter == Control.MOUSE_FILTER_IGNORE, "MoveLabel has mouse_filter = 2 (IGNORE)")

	# 2. Test pausing when player is frozen
	print("\n--- Test 2: Pause allowed when player is frozen ---")
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player: FirstPersonPlayer = player_scene.instantiate()
	root.add_child(player)
	player.is_frozen = true
	check(player.is_frozen, "Player is explicitly set to is_frozen = true")

	var esc_event := InputEventKey.new()
	esc_event.keycode = KEY_ESCAPE
	esc_event.pressed = true

	pause_menu._unhandled_input(esc_event)
	await process_frame
	check(pause_menu.opened, "Pause menu opened via Escape key despite player.is_frozen == true")
	check(paused, "Game tree is paused")
	check(pause_menu.overlay.visible, "PauseMenu overlay is visible")

	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout

	# Close pause menu (wait for distortion tween to complete)
	pause_menu.set_open(false)
	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout
	check(not pause_menu.opened, "Pause menu closed cleanly")
	check(not paused, "Game tree is unpaused")

	# 3. Test that BottomDialogueBalloon does not prevent pausing
	print("\n--- Test 3: Dialogue does not prevent pausing ---")
	var balloon_scene := load("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn") as PackedScene
	var balloon: BottomDialogueBalloon = balloon_scene.instantiate()
	root.add_child(balloon)
	balloon.show()
	balloon.balloon.show()

	# Simulate Escape event on balloon - verify it returns early without handling
	var handled_before: bool = root.is_input_handled()
	balloon._unhandled_input(esc_event)
	var handled_after: bool = root.is_input_handled()
	check(handled_before == handled_after, "BottomDialogueBalloon did not consume or block Escape input")

	# Escape then reaches pause menu
	pause_menu._unhandled_input(esc_event)
	await process_frame
	check(pause_menu.opened, "PauseMenu opened while dialogue is active")
	check(paused, "Game paused successfully during dialogue")
	check(pause_menu.layer > balloon.layer, "PauseMenu layer (%d) is on top of BottomDialogueBalloon layer (%d)" % [pause_menu.layer, balloon.layer])

	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout

	# Resume from pause menu during dialogue
	pause_menu.set_open(false)
	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout
	check(not pause_menu.opened, "PauseMenu closed successfully")
	check(balloon.is_inside_tree(), "Dialogue balloon remains inside tree and intact after resume")

	# 4. Test CustomDialogueBalloon (used by old phone) also does not swallow Escape
	print("\n--- Test 4: CustomDialogueBalloon does not prevent pausing ---")
	var custom_balloon_scene := load("res://scenes/ui/balloon/balloon.tscn") as PackedScene
	var custom_balloon: CustomDialogueBalloon = custom_balloon_scene.instantiate()
	root.add_child(custom_balloon)
	custom_balloon.show()
	custom_balloon.balloon.show()

	var cb_handled_before: bool = root.is_input_handled()
	custom_balloon._unhandled_input(esc_event)
	var cb_handled_after: bool = root.is_input_handled()
	check(cb_handled_before == cb_handled_after, "CustomDialogueBalloon did not consume or block Escape input")

	pause_menu._unhandled_input(esc_event)
	await process_frame
	check(pause_menu.opened, "PauseMenu opened while CustomDialogueBalloon is active")
	check(paused, "Game paused while CustomDialogueBalloon is active")

	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout

	pause_menu.set_open(false)
	while pause_menu._is_transitioning:
		await create_timer(0.05).timeout

	# Cleanup
	custom_balloon.queue_free()
	balloon.queue_free()
	player.queue_free()
	await process_frame

	print("\n=== Result: %d failure(s) ===" % failures)
	if failures == 0:
		print("ALL PAUSE SCREEN AND DIALOGUE CHECKS PASSED!")
	quit(failures)
