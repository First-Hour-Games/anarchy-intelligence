extends SceneTree

# The map's editor start (OpeningStory.editor_start): an editor play run set to start at Carrie's
# house lands on its porch at the notebook step, with the Wrapper waiting in its chair, and never
# saves. Runs without the editor's debugger, like this test's own, ignore the setting.

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func run() -> void:
	var plain := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	plain.get_node("OpeningStory").set("persist_progress", false)
	plain.get_node("OpeningStory").set("editor_start", 2)
	root.add_child(plain)
	for i in 6:
		await process_frame
	var start := (plain.get_node("Player") as Node3D).global_position
	check(plain.get_node("OpeningStory").stage == 0 and start.distance_to(Vector3(69.4, 0, -2.17)) < 2, "A run without the editor's debugger ignores the editor start")
	plain.queue_free()
	await process_frame
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	var story := map.get_node("OpeningStory")
	story.set("persist_progress", false)
	story.set("editor_start", 2)
	# As if started with the editor's play button.
	story.set("_editor_play", true)
	root.add_child(map)
	current_scene = map
	for i in 6:
		await process_frame
	var house := map.get_node("Buildings/ResidentialLots/CarrieHouse") as Node3D
	var player := map.get_node("Player") as Node3D
	var wrapper := map.get_node("Wrapper") as Node3D
	check(not story.persist_progress and not story.get("_restored"), "An editor start ignores the save and never writes it")
	check(story.stage == 1 and player.global_position.distance_to(house.call("point", &"porch")) < 0.5, "Starting at Carrie's house puts Thomas on its porch at the notebook step")
	check(wrapper.get("seated") and not wrapper.get("enabled"), "The Wrapper waits in its chair")
	var notes := story.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return (label as Label).text.begins_with("EDITOR START"))
	check(notes.size() == 1, "A corner note says the run starts away from the save")
	map.queue_free()
	await process_frame
	quit(1 if failures else 0)
