extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Menu Hover Smoke Test ---")
	var menu: CanvasLayer = (load("res://scenes/mainMenu/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame

	menu.input_ready_at = 0

	# Initial state: Start Game selected (index 0)
	assert(menu.selected_index == 0, "Initial index should be 0")
	assert(menu.start_label.get_theme_font_size("font_size") == 36, "Start label should be size 36")

	# Hover Options label (index 1)
	menu.options_label.mouse_entered.emit()
	assert(menu.selected_index == 1, "Options hover should set index to 1")
	assert(menu.options_label.get_theme_font_size("font_size") == 36, "Options label should be size 36")
	assert(menu.start_label.get_theme_font_size("font_size") == 24, "Start label should shrink to 24")
	print("PASS: Main menu Options button hover updates selected_index and styling")

	# Hover Quit label (index 2)
	menu.quit_label.mouse_entered.emit()
	assert(menu.selected_index == 2, "Quit hover should set index to 2")
	assert(menu.quit_label.get_theme_font_size("font_size") == 36, "Quit label should be size 36")
	print("PASS: Main menu Quit button hover updates selected_index and styling")

	# Open Options menu
	menu._open_options()
	assert(menu.is_in_options_menu, "Should be in options menu")
	assert(menu.selected_index == 0, "Options menu should start at index 0")

	# Hover Reset Progress label (index 2 in options)
	menu.reset_label.mouse_entered.emit()
	assert(menu.selected_index == 2, "Reset label hover should set index to 2")
	assert(menu.reset_label.get_theme_font_size("font_size") == 36, "Reset label should be size 36")
	print("PASS: Options menu Reset Progress button hover works")

	# Hover Back (quit_label, index 3 in options)
	menu.quit_label.mouse_entered.emit()
	assert(menu.selected_index == 3, "Back button hover should set index to 3")
	assert(menu.quit_label.get_theme_font_size("font_size") == 36, "Back label should be size 36")
	print("PASS: Options menu Back button hover works")

	# Cursor shapes
	assert(menu.start_label.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Start label cursor shape should be pointing hand")
	assert(menu.options_label.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Options label cursor shape should be pointing hand")
	print("PASS: Pointing hand cursor shape is active")

	menu.queue_free()
	print("--- All Menu Hover Tests Passed! ---")
	quit(0)
