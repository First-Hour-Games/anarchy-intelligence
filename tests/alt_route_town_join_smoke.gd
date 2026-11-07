extends SceneTree
## The alt route plays on from the Ridgeback road into its copy of the town map: past the road, Thomas's lines
## in the residence area lead to map_alt.tscn instead of the school (the main storyline still goes to the
## school), and he takes the shotgun, the shells in it and in his pocket, and the flashlight with him. The map
## starts the chapter afresh at the head of Carrie's road, at the stage of finding her notebook, with all of
## it. The two halves are checked on their own, without changing scenes; the map's story saves to a throwaway
## file only.

const RESIDENCE_ALT := "res://scenes/chapters/alt_route/residence_area_alt.tscn"
const MAP_ALT := "res://scenes/chapters/alt_route/map_alt.tscn"
const THROWAWAY := "user://test_alt_town_join_story.json"

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1


func run() -> void:
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	if FileAccess.file_exists(THROWAWAY):
		DirAccess.remove_absolute(THROWAWAY)
	var base: GDScript = load("res://scenes/chapters/main/residence_area.gd")
	var plain := Node3D.new()
	plain.set_script(base)
	check(plain.get("next_scene_path") == "res://scenes/flashbacks/school.tscn", "The main storyline still goes on to the school")
	plain.free()

	# Leaving the residence area with the shotgun.
	var section: Node3D = (load(RESIDENCE_ALT) as PackedScene).instantiate()
	for node in section.find_children("*", "", true, false):
		if "persist_progress" in node:
			node.set("persist_progress", false)
	root.add_child(section)
	current_scene = section
	for i in 4:
		await physics_frame
	check(section.get("next_scene_path") == MAP_ALT, "In the alt route, Thomas's lines past the road lead on into the town map")
	var player := section.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.inventory.add_item(&"shotgun")
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	var shotgun := player.get_node("Head/Camera3D/ShotgunWeapon")
	shotgun.call("restore_shells", 1, 9)
	section.call("_leaving", player)
	section.queue_free()
	await process_frame
	await process_frame

	# Coming into the town map with it.
	var map: Node3D = (load(MAP_ALT) as PackedScene).instantiate()
	var story := map.get_node("OpeningStory")
	story.set("progress_save_path", THROWAWAY)
	for node in map.find_children("*", "", true, false):
		if "cache_navigation" in node:
			node.set("cache_navigation", false)
	root.add_child(map)
	current_scene = map
	for i in 4:
		await physics_frame
	var arrived := map.get_node("Player") as FirstPersonPlayer
	var arrival: Vector3 = story.get_script().get_script_constant_map()["ARRIVAL"]
	check(arrived.global_position.distance_to(arrival) < 0.6, "He comes in at the head of Carrie's road")
	check(int(story.get("stage")) == 1, "at the stage of finding her notebook")
	check(arrived.has_item(PlayerInventory.FLASHLIGHT_ITEM), "with the flashlight")
	var carried := arrived.get_node("Head/Camera3D/ShotgunWeapon")
	check(arrived.has_item(&"shotgun") and int(carried.get("loaded")) == 1 and int(carried.get("reserve")) == 9,
		"and the shotgun, with the one shell in it and the nine in his pocket")
	var queued: Array = story.get("subtitle_queue")
	var showing := String((story.get("subtitle") as Label).text)
	check(queued.any(func(line: String) -> bool: return line.contains("Carrie's house is at the end of this road"))
		or showing.contains("Carrie's house is at the end of this road"), "He says where he is going")
	check(not queued.any(func(line: String) -> bool: return line.contains("visitor center")), "and not the chapter's opening lines")
	check(FileAccess.file_exists(THROWAWAY), "The arrival is saved, to the test's own file")
	check(AltRouteCarry.take().is_empty(), "What he carried is taken once")
	map.queue_free()
	await process_frame
	if FileAccess.file_exists(THROWAWAY):
		DirAccess.remove_absolute(THROWAWAY)
	print("FAILURES %d" % failures)
	quit(1 if failures else 0)
