extends SceneTree
## The phone game over: the close-up keeps the CRT, the phone rings and rattles, TRY AGAIN without
## a save respawns, LOAD PROGRESS answers and opens the load screen, BACK rings again, and MAIN
## MENU leaves for the menu. Save files go to a throwaway folder.

const SAVE_DIR := "user://test_phone_game_over_saves"
const MENU := "res://scenes/mainMenu/menu.tscn"
var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func run() -> void:
	var save_game := root.get_node("SaveGame")
	var original_dir: String = save_game.save_dir
	save_game.save_dir = SAVE_DIR
	_clear_saves()
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var health := player.get_node("CombatHealth")
	var crt := map.get_node("CRTOverlay") as CanvasLayer
	var wrapper := map.get_node("Wrapper") as Node3D

	# Caught before any save: the close-up keeps the CRT, then the phone offers TRY AGAIN.
	health.immunity = 0.0
	health.take_damage(health.max_health, wrapper)
	var scare: CanvasLayer = health.death_scare
	await process_frame
	check(crt.visible, "CRT stays on through the close-up")
	check(scare.layer < 99, "Close-up draws under the save screen and the CRT")
	await create_timer(1.8).timeout
	var game_over: CanvasLayer = health.game_over
	check(game_over != null and game_over.layer < 99, "Phone game over follows the close-up, under the save screen")
	if game_over == null:
		_finish(original_dir)
		return
	check(crt.visible and not scare.visible, "CRT stays on and the close-up is put away")
	check(not game_over.can_load and game_over._choices[0].text == "TRY AGAIN", "Without a save the first choice is TRY AGAIN")
	# A headless display has no mouse to show or capture.
	var has_mouse := DisplayServer.get_name() != "headless"
	if has_mouse:
		check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Mouse shows for the choices")
	await create_timer(1.0).timeout
	check(game_over.ring.playing and game_over.ring.stream.resource_path.ends_with("oldPhoneRinging.mp3"), "Phone rings with the tutorial's ring")
	var moved := 0.0
	var lifted := 0.0
	for i in 20:
		await process_frame
		moved = maxf(moved, game_over.phone.transform.origin.distance_to(game_over._phone_rest.origin))
		var free_end := Vector3(game_over.HANDSET_REACH, 0.0, 0.0)
		lifted = maxf(lifted, (game_over.handset.transform * free_end).y - (game_over._handset_rest * free_end).y)
	check(moved > 0.0002, "Phone rattles on the table while it rings")
	check(lifted > 0.001 and lifted <= game_over.HANDSET_LIFT + game_over.HANDSET_HOP + 0.0001,
			"Handset hops in its cradle while it rings, a few millimetres at its free end")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	check(not root.get_node("PauseMenu").opened and not paused, "Pause stays shut during the game over")
	# Read where TRY AGAIN put him before physics moves him on (CombatHealth connected first).
	var respawned := {}
	game_over.try_again.connect(func() -> void: respawned["at"] = player.global_position)
	game_over.choose(0)
	check(not game_over.ring.playing, "Answering stops the ring")
	for i in 180:
		if not health.is_dead:
			break
		await process_frame
	check(respawned.has("at") and (respawned["at"] as Vector3).distance_to(health.spawn.origin) < 0.01, "TRY AGAIN puts Thomas at his checkpoint")
	await process_frame
	check(not health.is_dead and health.game_over == null and health.death_scare == null, "TRY AGAIN respawns and clears the screens")
	if has_mouse:
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "TRY AGAIN recaptures the mouse")

	# With a save: LOAD PROGRESS answers and opens the load screen over the phone; BACK rings again.
	_write_save()
	await create_timer(1.2).timeout
	health.immunity = 0.0
	health.take_damage(health.max_health, wrapper)
	await create_timer(2.0).timeout
	game_over = health.game_over
	check(game_over != null and game_over.can_load and game_over._choices[0].text == "LOAD PROGRESS", "With a save the first choice is LOAD PROGRESS")
	if game_over == null:
		_finish(original_dir)
		return
	game_over.choose(0)
	await create_timer(0.8).timeout
	# Untyped: this script compiles before the autoloads the save screen's class refers to.
	var screen = game_over.slot_screen
	check(screen != null and screen.mode == screen.get_script().Mode.LOAD, "LOAD PROGRESS opens the load screen")
	check(screen != null and screen.layer > game_over.layer and screen.layer < crt.layer, "Load screen sits over the phone, under the CRT")
	check(health.is_dead, "Opening the load screen keeps the death in place")
	if screen != null:
		await create_timer(2.8).timeout
		screen.close()
		await create_timer(3.2).timeout
	check(game_over.slot_screen == null and game_over.ring.playing, "BACK returns to the ringing phone")

	# MAIN MENU: the ring cuts off and the menu loads.
	game_over.choose(1)
	check(not game_over.ring.playing, "MAIN MENU cuts the ring off")
	for i in 120:
		await process_frame
		if current_scene != null and current_scene.scene_file_path == MENU:
			break
	check(current_scene != null and current_scene.scene_file_path == MENU, "MAIN MENU leaves for the main menu")
	_finish(original_dir)


func _finish(original_dir: String) -> void:
	_clear_saves()
	root.get_node("SaveGame").save_dir = original_dir
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	print("Phone game over failures: ", failures)
	quit(1 if failures else 0)


func _write_save() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(SAVE_DIR + "/slot_1.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "saved_label": "26/11/03 00:12", "play_time": 60.0,
		"area": "Starting Forest", "location": "Town Entrance", "scene": "res://scenes/chapters/main/starting_forest.tscn"}))
	file.close()


func _clear_saves() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		return
	for name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR + "/" + name)
	DirAccess.remove_absolute(SAVE_DIR)
