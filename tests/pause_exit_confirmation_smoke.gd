extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	await process_frame
	var menu = root.get_node("PauseMenu")
	menu.set_open(true)
	await create_timer(0.5).timeout
	menu.selected_index = 2
	menu._trigger_current_option()
	assert(menu.is_confirming_exit and not menu.changing_scene)
	assert(paused and menu.opened)
	assert(menu.selected_index == 0 and menu._active_menu_count() == 2)
	assert(menu._exit_warning_label.visible)
	assert(menu._exit_warning_label.text.contains("Any unsaved changes will be lost."))
	menu._trigger_current_option()
	assert(not menu.is_confirming_exit and menu.selected_index == 2)
	assert(paused and menu.opened and not menu._exit_warning_label.visible)
	menu._trigger_current_option()
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu._unhandled_input(escape)
	assert(not menu.is_confirming_exit and paused and menu.opened)
	menu._trigger_current_option()
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	menu._unhandled_input(down)
	assert(menu.selected_index == 1)
	menu._unhandled_input(down)
	assert(menu.selected_index == 0)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	menu._on_label_gui_input(click, 1)
	assert(menu.changing_scene)
	await create_timer(0.5).timeout
	assert(current_scene.scene_file_path == "res://scenes/mainMenu/menu.tscn")
	assert(not paused and not menu.opened and not menu.is_confirming_exit)
	print("PASS: Pause exit confirmation, Cancel, Escape, navigation, and confirmed return")
	quit(0)
