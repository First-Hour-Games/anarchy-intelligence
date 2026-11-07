extends SceneTree

const TEST_DIR := "user://debug_save_screen_smoke"
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var saves := root.get_node("SaveGame")
	saves.save_dir = TEST_DIR
	saves.delete_all()
	var section := Node3D.new()
	section.scene_file_path = "res://scenes/chapters/main/starting_forest.tscn"
	root.add_child(section)
	current_scene = section
	var player := load("res://scenes/player/player.tscn").instantiate() as FirstPersonPlayer
	player.name = "Player"
	section.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(12, 0, -7)
	player.rotation.y = 0.6
	check(saves.save_here(player, 1), "Saving where the player stands works without a gem")
	var data: Dictionary = saves.read_slot(1)
	var respawn: Array = data.get("respawn", [])
	check(respawn.size() == 4 and Vector3(respawn[0], respawn[1], respawn[2]).is_equal_approx(Vector3(12, 0, -7)) and absf(float(respawn[3]) - 0.6) < 0.01, "The file respawns the player where and facing how they stood")
	check(data.get("scene") == section.scene_file_path and data.get("location") == "Debug save", "The file names the current scene and marks itself as a debug save")
	var menu := root.get_node("DebugMenu")
	menu.set_open(true)
	var buttons: Array = menu.get("_buttons")
	check(buttons[0].text.begins_with("Open save") and buttons[1].text.begins_with("Open load"), "Save and Load are the first two buttons")
	buttons[0].pressed.emit()
	for i in 6:
		await process_frame
	var screen: Variant = get_first_node_in_group("save_slot_screen")
	check(not menu.opened and screen != null and screen.mode == screen.Mode.SAVE and player.is_frozen, "The debug button closes the menu and opens the save screen")
	if screen != null:
		await screen._transition_tween.finished
		screen.close()
		await screen.closed
	check(not player.is_frozen, "Closing the save screen gives control back")

	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var previous_mouse := Input.mouse_mode
	menu.set_open(true)
	buttons[1].pressed.emit()
	screen = section.get_child(-1)
	check(not menu.opened and paused and screen.is_in_group("save_slot_screen") and screen.mode == screen.Mode.LOAD, "Load opens the slot picker and pauses gameplay")
	if screen.is_in_group("save_slot_screen"):
		await screen._transition_tween.finished
		screen.close()
		await screen.closed
	check(not paused and Input.mouse_mode == previous_mouse, "Canceling Load restores pause and mouse state")

	var destination := Node3D.new()
	destination.name = "DebugLoadDestination"
	var packed := PackedScene.new()
	check(packed.pack(destination) == OK, "The load destination can be packed")
	destination.free()
	var destination_path := TEST_DIR + "/destination.tscn"
	check(ResourceSaver.save(packed, destination_path) == OK, "The load destination is saved to disk")
	section.scene_file_path = destination_path
	check(saves.save_here(player, 1), "A slot points to the load destination")
	menu.set_open(true)
	buttons[1].pressed.emit()
	screen = section.get_child(-1)
	await screen._transition_tween.finished
	screen._select(1)
	screen._activate()
	for i in 300:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == destination_path and not paused:
			break
	check(current_scene != null and current_scene.name == "DebugLoadDestination" and not paused, "Selecting a slot changes scenes and resumes gameplay")
	saves.delete_all()
	DirAccess.remove_absolute(destination_path)
	if current_scene != null:
		current_scene.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
