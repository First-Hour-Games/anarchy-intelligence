extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Tab Inventory & Inspection View Smoke Test ---")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "Loaded starting_forest.tscn")

	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in scene")

	var inventory: PlayerInventory = player.inventory
	check(is_instance_valid(inventory), "Player inventory found")

	# Ensure starting forest intro fade and opening dialogue are finished so player is unfrozen
	if forest is StartingForest:
		if forest.has_method(&"finish_fade_immediately"):
			forest.finish_fade_immediately()
			await process_frame
		if is_instance_valid(forest.opening_balloon):
			forest.opening_balloon._end_dialogue()
			await process_frame
	player.unfreeze()
	await process_frame

	check(not player.is_frozen, "Player is unfrozen and ready for input")
	check(not inventory.is_open, "Inventory is initially closed")

	# Test 1: Open inventory with Tab key
	var tab_event := InputEventKey.new()
	tab_event.pressed = true
	tab_event.keycode = KEY_TAB
	inventory._input(tab_event)
	await process_frame

	check(inventory.is_open, "Pressing Tab opens inventory")

	# Test 2: Close inventory with Tab key
	inventory._input(tab_event)
	await process_frame

	check(not inventory.is_open, "Pressing Tab again closes inventory")

	# Test 3: Open inventory with Tab and close with Esc
	inventory._input(tab_event)
	await process_frame
	check(inventory.is_open, "Inventory reopened with Tab")

	var esc_event := InputEventKey.new()
	esc_event.pressed = true
	esc_event.keycode = KEY_ESCAPE
	inventory._input(esc_event)
	await process_frame

	check(not inventory.is_open, "Pressing Esc closes inventory")

	# Test 4: Check InspectableView3D prompt label font and styling
	var inspect_view := forest.get_node_or_null("Interactables/MapInspect/InspectableView") as InspectableView3D
	check(is_instance_valid(inspect_view), "InspectableView3D found")

	var prompt_label: Label = inspect_view.get("_exit_prompt_label")
	check(is_instance_valid(prompt_label), "Exit prompt label exists")
	if is_instance_valid(prompt_label):
		check("TAB" in prompt_label.text and "ESC" in prompt_label.text, "Prompt label displays Tab and Esc: '%s'" % prompt_label.text)
		var font: Font = prompt_label.get_theme_font("font")
		check(is_instance_valid(font), "Prompt label has font override")
		if is_instance_valid(font):
			check(font.resource_path.ends_with("EuropeanTeletextNuevo.ttf"), "Prompt label uses EuropeanTeletextNuevo.ttf: %s" % font.resource_path)
		var font_size: int = prompt_label.get_theme_font_size("font_size")
		check(font_size == 14, "Prompt label font size is 14 (got %d)" % font_size)

	# Test 5: Tab key exits inspection view and does not open inventory
	inspect_view.start_inspection(player)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame

	check(inspect_view.is_inspecting, "Inspection mode is active")
	check(player.is_frozen, "Player is frozen while inspecting")

	# Send Tab input: inventory should NOT open, inspection should exit
	inventory._input(tab_event)
	check(not inventory.is_open, "Inventory does NOT open from Tab while inspecting")

	inspect_view._unhandled_input(tab_event)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame

	check(not inspect_view.is_inspecting, "Pressing Tab exits inspection view")
	check(not player.is_frozen, "Player is unfrozen after exiting inspection")

	# Test 6: Esc key exits inspection view
	inspect_view.start_inspection(player)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame
	check(inspect_view.is_inspecting, "Inspection mode active again")

	inspect_view._unhandled_input(esc_event)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame

	check(not inspect_view.is_inspecting, "Pressing Esc exits inspection view")

	# Test 7: Backspace key exits inspection view (backwards compatibility)
	inspect_view.start_inspection(player)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame
	check(inspect_view.is_inspecting, "Inspection mode active third time")

	var backspace_event := InputEventKey.new()
	backspace_event.pressed = true
	backspace_event.keycode = KEY_BACKSPACE
	inspect_view._unhandled_input(backspace_event)
	while inspect_view._is_transitioning:
		await process_frame
	await process_frame

	check(not inspect_view.is_inspecting, "Pressing Backspace exits inspection view")

	forest.queue_free()

	print("--- Tab Inventory & Inspection View Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
