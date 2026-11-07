extends SceneTree
## The alternate route is a copy of the storyline's forest and residence: each copy streams with the
## other copy, never with the base storyline's sections.

const FOREST := "res://scenes/chapters/main/starting_forest.tscn"
const RESIDENCE := "res://scenes/chapters/main/residence_area.tscn"
const ALT_FOREST := "res://scenes/chapters/alt_route/starting_forest_alt.tscn"
const ALT_RESIDENCE := "res://scenes/chapters/alt_route/residence_area_alt.tscn"
var stream: Node
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func run() -> void:
	stream = root.get_node("WorldStreaming")
	root.get_node("PauseMenu").set_process_unhandled_input(false)
	root.get_node("DebugMenu").set_process_input(false)
	var forest: Node3D = load(ALT_FOREST).instantiate()
	check(forest.get_script() == load("res://scenes/chapters/main/starting_forest.gd"), "the alternate forest runs the storyline's forest script")
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await process_frame
	check(stream.active_section == forest, "the alternate forest registers with the streaming manager")
	check(stream.forest_path == ALT_FOREST and stream.residence_path == ALT_RESIDENCE, "the alternate forest pairs with the alternate residence")
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	player.position = Vector3(127, 0.15, 30)
	check(await wait_for(func(): return stream._sections.has(ALT_RESIDENCE)), "the alternate residence streams in near the crossing")
	check(not stream._sections.has(RESIDENCE) and not stream._sections.has(FOREST), "the base storyline's sections never load on the alternate route")
	if not stream._sections.has(ALT_RESIDENCE):
		quit(1)
		return
	var residence: Node3D = stream._sections[ALT_RESIDENCE]
	var forest_id := forest.get_instance_id()
	player.position.z = 75
	check(await wait_for(func(): return current_scene == residence), "walking across makes the alternate residence the active section")
	player.position.z = stream.seam_position.z + maxf(stream.unload_distance, stream.preload_distance + stream.crossing_hysteresis) + 10.0
	check(await wait_for(func(): return not is_instance_id_valid(forest_id)), "the alternate forest unloads once far behind")
	player.position.z = 110
	check(await wait_for(func(): return stream._sections.has(ALT_FOREST)), "heading back streams the alternate forest, not the base one")
	check(not stream._sections.has(FOREST), "the base forest stays unloaded on the way back")
	print("alt_route_streaming_smoke: %d failures" % failures)
	quit(1 if failures else 0)
