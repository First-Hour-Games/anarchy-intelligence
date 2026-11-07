extends SceneTree
## Measures the worm mass demo's real frame rate at each strand count. Run WITHOUT --headless:
##   Godot_console.exe --path . --script res://tools/worm_mass_bench.gd
## It loads the demo (vsync is off in the project), lets each density settle, averages the frame
## rate over a timed window, prints one line per density, and quits.

const DEMO := "res://scenes/chapters/playground/worm_mass_demo.tscn"
const DENSITIES := [300, 600, 900, 1200]
const SETTLE_FRAMES := 45
const MEASURE_FRAMES := 120


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("BENCH FAILED: run without --headless; nothing renders otherwise")
		quit(1)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var demo := (load(DEMO) as PackedScene).instantiate()
	root.add_child(demo)
	current_scene = demo
	var worm := demo.get_node("WormMass")
	var camera := demo.get_node("DemoCamera") as Camera3D
	camera.global_position = Vector3(2.2, 1.8, 2.4)
	camera.look_at(Vector3(0.0, 1.3, 0.0))
	print("BENCH window %s driver %s" % [DisplayServer.window_get_size(), RenderingServer.get_video_adapter_name()])
	for density: int in DENSITIES:
		worm.call("set_density", density)
		for frame in SETTLE_FRAMES:
			await process_frame
		var started := Time.get_ticks_usec()
		for frame in MEASURE_FRAMES:
			await process_frame
		var seconds := float(Time.get_ticks_usec() - started) / 1_000_000.0
		var fps := MEASURE_FRAMES / maxf(seconds, 0.0001)
		print("BENCH %4d strands (%4d shown): %6.1f FPS  %5.2f ms" % [density, int(worm.call("strands_shown")), fps, 1000.0 / fps])
	quit(0)
