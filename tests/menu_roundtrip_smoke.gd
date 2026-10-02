extends SceneTree
var failures: int = 0
func _initialize() -> void:
	run.call_deferred()
func protect_save(node: Node) -> void:
	if node.name == &"OpeningStory":
		node.set("progress_save_path", "user://menu_roundtrip_test.json")
func run() -> void:
	node_added.connect(protect_save)
	if FileAccess.file_exists("user://menu_roundtrip_test.json"):
		DirAccess.remove_absolute("user://menu_roundtrip_test.json")
	change_scene_to_file("res://scenes/chapters/main/map.tscn")
	await create_timer(1.0).timeout
	current_scene.get_node("Player").inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	for iteration in 3:
		root.get_node("PauseMenu").set_open(true)
		root.get_node("PauseMenu").return_to_main_menu()
		await create_timer(0.5).timeout
		print("MENU ", iteration, " ", current_scene.scene_file_path)
		# Exercise Play from its GUI callback, rather than switching scenes directly.
		var menu := current_scene
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		menu.start_label.gui_input.emit(event)
		await create_timer(1.0).timeout
		var resumed := current_scene.get_node_or_null("Player") as FirstPersonPlayer
		if resumed == null or resumed.is_frozen or paused or not resumed.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM):
			failures += 1
			print("FAIL Resume ", iteration)
		else:
			print("PASS Resume ", iteration)
	if FileAccess.file_exists("user://menu_roundtrip_test.json"):
		DirAccess.remove_absolute("user://menu_roundtrip_test.json")
	quit(1 if failures else 0)
