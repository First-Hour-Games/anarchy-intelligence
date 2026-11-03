extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1
func run() -> void:
	var menu: CanvasLayer = (load("res://scenes/mainMenu/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	current_scene = menu
	await process_frame
	menu.input_ready_at = 0
	var labels: Array = menu.main_options.map(func(option: Dictionary) -> Label: return option.label)
	check(labels.has(menu.credits_label) and labels.find(menu.credits_label) == labels.find(menu.quit_label) - 1, "Credits sits just above Quit in the main menu")
	check(menu.credits_label.visible and menu.credits_label.text == "Credits", "Credits entry is shown")
	menu.selected_index = labels.find(menu.credits_label)
	menu._trigger_option_action()
	await process_frame
	var screen: CanvasLayer = null
	for child in menu.get_children():
		if child.has_signal("closed") and child.get_script() == preload("res://scenes/mainMenu/credits_screen.gd"):
			screen = child
	check(screen != null and menu.credits_open, "Choosing Credits opens the credits screen")
	var texts := ""
	var largest_body := 0
	for label: Label in screen.find_children("*", "Label", true, false):
		texts += label.text + "\n"
		if label.text != "CREDITS" and not label.text.to_upper() == label.text:
			largest_body = maxi(largest_body, label.get_theme_font_size("font_size"))
	for member in ["Duc Nguyen", "Henry Nguyen", "Irvin Soto", "Narciso Gonzales"]:
		check(member in texts, "Team member listed: " + member)
	check("Codyanka" in texts and "Danylo Tyupa" in texts and "CC BY 4.0" in texts, "3D model credits and licences are listed")
	check(largest_body > 0 and largest_body < menu.UNSELECTED_FONT_SIZE, "Credit lines use smaller text than the menu (%d)" % largest_body)
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	var before: int = menu.selected_index
	menu._input(down)
	check(menu.selected_index == before, "The menu ignores keys while the credits are open")
	await create_timer(0.25).timeout
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen._input(escape)
	await process_frame
	check(not is_instance_valid(screen) or screen.is_queued_for_deletion(), "Esc closes the credits")
	check(not menu.credits_open, "Closing returns to the menu")
	menu.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
