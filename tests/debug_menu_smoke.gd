extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var menu := root.get_node("DebugMenu")
	assert(menu.get("_overlay") != null)
	for entry in menu.SCENES:
		assert(ResourceLoader.exists(entry["path"], "PackedScene"))
		assert(entry["path"] != "res://scenes/chapters/main/map.tscn")
	var fixture := Node3D.new()
	fixture.name = "DebugDestination"
	var packed := PackedScene.new()
	assert(packed.pack(fixture) == OK)
	fixture.free()
	var fixture_path := "user://debug_menu_smoke_%d.tscn" % Time.get_ticks_usec()
	assert(ResourceSaver.save(packed, fixture_path) == OK)
	assert(change_scene_to_packed(packed) == OK)
	await process_frame
	await process_frame
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var previous_mouse := Input.mouse_mode
	var hotkey := InputEventKey.new()
	hotkey.keycode = KEY_QUOTELEFT
	hotkey.pressed = true
	menu.call("_input", hotkey)
	assert(menu.opened and paused)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	menu.call("_input", hotkey)
	assert(not menu.opened and not paused)
	assert(Input.mouse_mode == previous_mouse)
	hotkey.keycode = KEY_ASCIITILDE
	hotkey.shift_pressed = true
	menu.call("_input", hotkey)
	assert(menu.opened and paused)
	menu.call("_input", hotkey)
	assert(not menu.opened and not paused)
	paused = true
	menu.set_open(true)
	assert(not menu.opened and paused)
	paused = false
	menu.set_open(true)
	menu.jump_to_scene("res://missing_debug_scene.tscn")
	assert(menu.opened and menu.get("_loading_path") == "")
	menu.jump_to_scene(fixture_path)
	assert(menu.get("_loading_path") == fixture_path)
	for index in range(300):
		await process_frame
		if menu.get("_loading_path") == "":
			break
	assert(menu.get("_loading_path") == "")
	await process_frame
	await process_frame
	assert(current_scene.name == "DebugDestination")
	assert(current_scene.scene_file_path == fixture_path)
	assert(not menu.opened and not paused)
	menu.set_open(true)
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	menu.call("_input", escape)
	assert(not menu.opened and not paused)
	DirAccess.remove_absolute(fixture_path)
	current_scene.scene_file_path = menu.FOREST_PATH
	menu.set_open(true)
	menu.call("_skip_next_scene")
	assert(menu.get("_loading_path") == "")
	menu.call("_jump_to_checkpoint", "after_log")
	for index in range(180):
		await physics_frame
		if current_scene is StartingForest and current_scene.get("_has_switched_music"):
			break
	assert(current_scene is StartingForest)
	assert(current_scene.get("_has_switched_music"))
	assert(current_scene.player.has_item(&"map"))
	assert(menu.get("_pending_checkpoint") == "")
	assert(not menu.opened and not paused)
	var finished_forest := current_scene
	current_scene = null
	finished_forest.queue_free()
	await process_frame
	print("PASS: backtick/tilde/Esc, pause ownership, mouse restore, missing scene and threaded scene jump")
	quit()
