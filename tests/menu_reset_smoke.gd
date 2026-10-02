extends SceneTree
var failures: int = 0
const TEST_SAVE := "user://menu_reset_test.json"
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
func run() -> void:
	var file := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	file.store_string('{"stage":2,"flashlight":true}')
	file.close()
	var original_session: bool = root.get_node("PauseMenu").has_started_chapter
	var settings_before := FileAccess.get_file_as_bytes("user://audio_settings.cfg")
	var menu := (load("res://scenes/mainMenu/menu.tscn") as PackedScene).instantiate()
	menu.progress_save_path = TEST_SAVE
	root.add_child(menu)
	current_scene = menu
	await process_frame
	check(menu.can_continue and menu.reset_label.visible, "Saved game exposes reset option")
	menu._ask_reset_progress()
	check(menu.reset_warning.visible and FileAccess.file_exists(TEST_SAVE), "Reset displays warning before touching save")
	menu._start_game()
	check(not menu.is_starting, "Play cannot run behind reset warning")
	menu.reset_warning.canceled.emit()
	menu.reset_warning.hide()
	check(FileAccess.file_exists(TEST_SAVE) and menu.can_continue, "Cancel preserves progress")
	menu._ask_reset_progress()
	menu.reset_warning.confirmed.emit()
	check(not FileAccess.file_exists(TEST_SAVE) and not menu.can_continue and not root.get_node("PauseMenu").has_started_chapter, "Confirmed reset clears saved and session progress")
	check(menu.start_label.text == "Start Game", "Reset returns Play to a new game")
	check(settings_before == FileAccess.get_file_as_bytes("user://audio_settings.cfg"), "Reset preserves sound settings")
	menu._open_options()
	menu.input_ready_at = 0
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu.quit_label.gui_input.emit(click)
	check(not menu.is_in_options_menu and menu.main_options.size() == 4, "Options Back uses correct action after adding reset row")
	root.get_node("PauseMenu").has_started_chapter = original_session
	menu.queue_free()
	current_scene = null
	for i in 3:
		await process_frame
		await physics_frame
	quit(1 if failures else 0)
