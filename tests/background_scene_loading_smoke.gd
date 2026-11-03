extends SceneTree

var failures := 0
const INTRO := "res://scenes/chapters/intro/intro.tscn"
const TUTORIAL := "res://scenes/chapters/tutorial/tutorial.tscn"

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func run() -> void:
	var loader := root.get_node("SceneLoader")
	check(loader.prefetch("res://missing_scene.tscn") == ERR_FILE_NOT_FOUND, "missing resource rejected")
	check(loader.prefetch(TUTORIAL) == OK, "background request accepted")
	check(loader.prefetch(TUTORIAL) == OK, "duplicate request reused")
	loader.cancel_prefetch()
	var deadline := Time.get_ticks_msec() + 10000
	while not loader.get("_pending").is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(loader.get("_pending").is_empty() and not loader.is_ready(TUTORIAL), "canceled loading drained without retaining scene")
	change_scene_to_file(INTRO)
	await scene_changed
	var frames := 0
	deadline = Time.get_ticks_msec() + 10000
	while not loader.is_ready(TUTORIAL) and Time.get_ticks_msec() < deadline:
		frames += 1
		await process_frame
	check(loader.is_ready(TUTORIAL), "intro prepares tutorial before transition")
	print("Background preparation allowed ", frames, " main-loop frames")
	var transition_start := Time.get_ticks_usec()
	check(await loader.change_to(TUTORIAL) == OK, "prepared transition accepted")
	await scene_changed
	check(current_scene.scene_file_path == TUTORIAL, "prepared tutorial became current scene")
	print("Prepared transition to ready scene: ", (Time.get_ticks_usec() - transition_start) / 1000.0, " ms")
	check(loader.get("_packed") == null, "loader releases its scene reference after transition")
	check(await loader.change_to("res://missing_scene.tscn") == ERR_FILE_NOT_FOUND, "failed transition returns error")
	check(current_scene.scene_file_path == TUTORIAL, "failed transition preserves current scene")
	await create_timer(0.1).timeout
	quit(1 if failures else 0)
