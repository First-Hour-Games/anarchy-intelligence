extends SceneTree
## Gem save point: saving at the gas station gem into a file records the forest section, the
## gem's respawn point, the player's items, the forest story state and the location; the file
## screen builds its four files; and the restore helpers put taken pickups back.

const TEST_DIR := "user://save_game_smoke_test"

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Save Gem Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var save_game: Node = root.get_node_or_null("SaveGame")
	check(save_game != null, "SaveGame autoload is registered")
	if save_game == null:
		quit(1)
		return
	save_game.set("save_dir", TEST_DIR)
	save_game.call("delete_all")

	var forest: Node3D = (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate()
	forest.set("auto_start_fade", false)
	root.add_child(forest)
	await process_frame
	await physics_frame

	var gem := forest.get_node_or_null("GasStationSaveGem") as SaveGem
	check(gem != null, "GasStationSaveGem is in the starting forest")
	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(player != null, "player found")
	if gem == null or player == null:
		quit(1)
		return
	check(gem.glow is OmniLight3D and gem.glow.light_energy > 0.0, "gem has a lit OmniLight3D glow")
	var start_height := gem.model.position.y
	for i in 20:
		await process_frame
	check(gem.model.position.y > 0.5, "gem floats above the ground")
	check(not is_equal_approx(gem.model.position.y, start_height) or gem.bob_amplitude == 0.0, "gem bobs while floating")

	player.global_position = gem.get_respawn_transform().origin
	check(gem.can_interact(player), "player at the respawn point can use the gem")
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	check(bool(save_game.call("save_at", gem, player, 2, null)), "saving into file 03 works")
	check(bool(save_game.call("has_save", 2)) and not bool(save_game.call("has_save", 0)), "only file 03 is written")
	var data: Dictionary = save_game.call("read_slot", 2)
	check(str(data.get("location", "")) == "Gas Station", "file records the gem's location name")
	check(str(data.get("area", "")) == "Starting Forest", "file records the area")
	check(not str(data.get("saved_label", "")).is_empty(), "file records the save date")
	check(str(data.get("scene", "")) == forest.scene_file_path, "save records the forest scene")
	check(str(data.get("gem", "")) == "GasStationSaveGem", "save records which gem was used")
	check((data.get("respawn", []) as Array).size() == 4, "save records the respawn point")
	check((data.get("player", {}).get("items", []) as Array).has("flashlight"), "save records the flashlight in the inventory")
	check(data.get("story", {}).has("log_climbed"), "save includes the forest story state")

	# A save made after the flashlight was taken removes the pickup on restore.
	var section_state: Dictionary = data.get("section", {}).duplicate(true)
	section_state["pickups_present"] = []
	var pickup_count := forest.find_children("*", "FlashlightPickup", true, false).size()
	save_game.call("_restore_section", forest, section_state)
	await process_frame
	check(pickup_count == 0 or forest.find_children("*", "FlashlightPickup", true, false).is_empty(), "taken pickups are removed on restore")

	var screen := SaveSlotScreen.open(root, SaveSlotScreen.Mode.LOAD, func(_slot: int) -> bool: return false)
	await process_frame
	check(screen.get("_headers").size() == 4, "file screen shows four files")
	check(int(screen.get("_selected")) == 2, "load screen starts on the newest file")
	screen.close()
	await process_frame

	forest.queue_free()
	await process_frame
	save_game.call("delete_all")
	check(not bool(save_game.call("has_any_save")), "delete_all removes every file")

	print("--- Save Gem Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with " + str(failures) + " failures")
		quit(1)
