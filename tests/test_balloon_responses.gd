extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, msg: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + msg)
	if not condition:
		failures += 1

func run() -> void:
	print("=== Running Comprehensive BottomDialogueBalloon Responses Test ===")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node("Player") as FirstPersonPlayer
	player.inventory.add_item(&"map")
	var barrier := forest.get_node("Interactables/BarrierTree") as InteractableBlock3D
	var teleport := forest.get_node("ClimbOverTeleport") as Node3D

	# Speed up fade intervals for fast test
	barrier.climb_fade_out_duration = 0.05
	barrier.climb_black_hold_duration = 0.05
	barrier.climb_fade_in_duration = 0.05

	# --- SUBTEST 1: Click 'No' button with mouse ---
	print("--- SUBTEST 1: Click 'No' with mouse ---")
	barrier.cooldown = 0.0
	barrier._is_cooling_down = false
	barrier.interact(player)
	await process_frame

	var balloon := forest.find_child("BottomDialogueBalloon", true, false) as BottomDialogueBalloon
	check(is_instance_valid(balloon), "Balloon spawned")
	var responses_menu := balloon.get_node("%ResponsesMenu") as DialogueResponsesMenu
	check(responses_menu.response_selected.get_connections().size() > 0, "response_selected signal is connected")

	# Skip text to choices line
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	check(responses_menu.visible, "Responses menu is visible on line 3")
	var items: Array = responses_menu.get_menu_items()
	check(items.size() == 2, "2 response items displayed")
	check(items[0].text == "Yes", "Item 0 is 'Yes'")
	check(items[1].text == "No", "Item 1 is 'No'")

	# Click 'No'
	var mb_no := InputEventMouseButton.new()
	mb_no.button_index = MOUSE_BUTTON_LEFT
	mb_no.pressed = true
	items[1].gui_input.emit(mb_no)
	await process_frame
	await process_frame

	check(not balloon.balloon.visible, "Dialogue closed after clicking 'No'")
	check(not barrier._is_climbing_over, "Did not climb over after clicking 'No'")
	check(player.global_position.distance_to(teleport.global_position) > 5.0, "Player did not teleport")
	check(not player.is_frozen, "Player is unfrozen after selecting 'No'")

	# Clean up any leftover balloon
	if is_instance_valid(balloon):
		balloon.queue_free()
	await process_frame

	# --- SUBTEST 2: Navigate with 'S' and select 'No' with 'E' key ---
	print("--- SUBTEST 2: S navigation + 'E' selection ---")
	barrier.cooldown = 0.0
	barrier._is_cooling_down = false
	barrier.interact(player)
	await process_frame

	balloon = forest.find_child("BottomDialogueBalloon", true, false) as BottomDialogueBalloon
	responses_menu = balloon.get_node("%ResponsesMenu") as DialogueResponsesMenu

	# Skip to choices line
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	items = responses_menu.get_menu_items()
	check(root.gui_get_focus_owner() == items[0], "First item ('Yes') auto-focused")

	# Press 'S' key -> should focus 'No'
	var s_event := InputEventKey.new()
	s_event.keycode = KEY_S
	s_event.pressed = true
	balloon._unhandled_input(s_event)
	await process_frame

	check(root.gui_get_focus_owner() == items[1], "'S' key navigated focus to 'No'")

	# Press 'E' key -> should confirm 'No'
	var e_event := InputEventKey.new()
	e_event.keycode = KEY_E
	e_event.pressed = true
	balloon._unhandled_input(e_event)
	await process_frame
	await process_frame

	check(not balloon.balloon.visible, "Dialogue closed after pressing 'E' on 'No'")
	check(not barrier._is_climbing_over, "Did not climb over")

	if is_instance_valid(balloon):
		balloon.queue_free()
	await process_frame

	# --- SUBTEST 3: Select 'Yes' with 'E' key to proceed ---
	print("--- SUBTEST 3: Confirm 'Yes' with 'E' key ---")
	barrier.cooldown = 0.0
	barrier._is_cooling_down = false
	barrier.interact(player)
	await process_frame

	balloon = forest.find_child("BottomDialogueBalloon", true, false) as BottomDialogueBalloon
	responses_menu = balloon.get_node("%ResponsesMenu") as DialogueResponsesMenu

	# Skip to choices line
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	items = responses_menu.get_menu_items()
	check(root.gui_get_focus_owner() == items[0], "'Yes' is focused")

	# Press 'E' on 'Yes'
	balloon._unhandled_input(e_event)
	await process_frame
	await process_frame

	check(barrier._is_climbing_over, "BarrierTree initiated climb-over after 'E' on 'Yes'")
	check(player.is_frozen, "Player frozen during climb-over transition")

	# Wait for climb-over fade and teleport to finish
	await create_timer(0.25).timeout
	await process_frame

	check(not barrier._is_climbing_over, "Climb-over finished")
	check(player.global_position.distance_to(teleport.global_position) < 1.0, "Player teleported successfully across barrier")
	check(not player.is_frozen, "Player unfrozen after climbing over")

	print("\nTest completed with ", failures, " failure(s).")
	if failures == 0:
		print("ALL CHECKS PASSED SUCCESSFULLY!")
	quit(failures)
