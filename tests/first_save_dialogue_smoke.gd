extends SceneTree

const TEST_DIR := "user://first_save_dialogue_smoke"
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
	saves.start_new_game()
	var section := Node3D.new()
	section.scene_file_path = "res://scenes/chapters/main/starting_forest.tscn"
	root.add_child(section)
	current_scene = section
	var player := load("res://scenes/player/player.tscn").instantiate() as FirstPersonPlayer
	player.name = "Player"
	section.add_child(player)
	player.set_physics_process(false)
	var gem: Variant = load("res://scenes/interaction/save_gem.tscn").instantiate()
	section.add_child(gem)
	gem.first_save_dialogue = "A custom first line.\nA second line."
	check(not gem.should_show_first_save_dialogue(), "Other save points skip the introduction")
	gem.introduce_first_save = true
	check(gem.should_show_first_save_dialogue(), "New playthrough qualifies for the introduction")
	var resource: DialogueResource = gem._first_save_dialogue_resource()
	var line := await resource.get_next_dialogue_line("start")
	check(line.text == "A custom first line." and line.character == "Thomas", "Editable text and speaker become dialogue")
	line = await resource.get_next_dialogue_line(line.next_id)
	check(line.text == "A second line.", "Multiline text advances through separate lines")
	gem.interact(player)
	await process_frame
	var balloon: BottomDialogueBalloon
	for child in gem.get_children():
		if child is BottomDialogueBalloon:
			balloon = child
	check(balloon != null and player.is_frozen, "First interaction shows dialogue and freezes player")
	check(get_first_node_in_group("save_slot_screen") == null, "Save menu waits for dialogue")
	gem.interact(player)
	var balloon_count := 0
	for child in gem.get_children():
		if child is BottomDialogueBalloon:
			balloon_count += 1
	check(balloon_count == 1, "Repeated interaction cannot duplicate the introduction")
	balloon._end_dialogue(false)
	await process_frame
	var screen: Variant = get_first_node_in_group("save_slot_screen")
	check(screen != null and player.is_frozen, "Dialogue hands off to the save menu without unfreezing")
	check(saves.first_save_dialogue_seen and not gem.should_show_first_save_dialogue(), "Introduction is consumed once per playthrough")
	check(saves.save_at(gem, player, 0), "Saving after introduction works")
	var data: Dictionary = saves.read_slot(0)
	check(data.get("first_save_dialogue_seen", false), "Save records the completed introduction")
	await screen._transition_tween.finished
	screen.close()
	await screen.closed
	check(not player.is_frozen and not gem._screen_open, "Closing save menu restores interaction and movement")
	await screen.tree_exited
	saves.start_new_game()
	check(gem.should_show_first_save_dialogue(), "Starting a new game resets the introduction")
	await saves._restore(section, data)
	check(not gem.should_show_first_save_dialogue(), "Loading a save suppresses the introduction")
	saves.start_new_game()
	data.erase("first_save_dialogue_seen")
	await saves._restore(section, data)
	check(saves.first_save_dialogue_seen, "Older saves skip the introduction")
	saves.start_new_game()
	gem.first_save_dialogue = "   "
	check(not gem.should_show_first_save_dialogue(), "Blank author text skips dialogue")
	saves.delete_all()
	section.queue_free()
	await process_frame
	quit(1 if failures else 0)
