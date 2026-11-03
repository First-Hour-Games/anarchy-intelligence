extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var start := Time.get_ticks_usec()
	var scene := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	var loaded := Time.get_ticks_usec()
	var instance := scene.instantiate()
	var instantiated := Time.get_ticks_usec()
	root.add_child(instance)
	current_scene = instance
	var ready_time := Time.get_ticks_usec()
	await process_frame
	var frame_time := Time.get_ticks_usec()
	print("TUTORIAL PROFILE ", JSON.stringify({
		"load_ms": (loaded - start) / 1000.0,
		"instantiate_ms": (instantiated - loaded) / 1000.0,
		"ready_ms": (ready_time - instantiated) / 1000.0,
		"next_frame_ms": (frame_time - ready_time) / 1000.0,
		"node_count": instance.find_children("*", "", true, false).size() + 1,
		"black_hold_seconds": instance.get("intro_black_hold_seconds"),
		"fade_seconds": instance.get("intro_fade_duration"),
		"door_fade_seconds": instance.get("door_color_fade_duration"),
	}))
	await create_timer(8.0).timeout
	quit()
