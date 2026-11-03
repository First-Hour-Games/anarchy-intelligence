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
	menu._open_save_screen()
	for i in 6:
		await process_frame
	var screen: Variant = get_first_node_in_group("save_slot_screen")
	check(not menu.opened and screen != null and screen.mode == SaveSlotScreen.Mode.SAVE and player.is_frozen, "The debug button closes the menu and opens the save screen")
	if screen != null:
		await screen._transition_tween.finished
		screen.close()
		await screen.closed
	check(not player.is_frozen, "Closing the save screen gives control back")
	saves.delete_all()
	section.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
