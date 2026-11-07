extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func check_coverage(bands: Array) -> void:
	var viewport_rect := root.get_visible_rect()
	var next_y := viewport_rect.position.y
	for band: ColorRect in bands:
		var rect := band.get_global_rect()
		check(is_equal_approx(rect.position.x, viewport_rect.position.x) and is_equal_approx(rect.end.x, viewport_rect.end.x),
			"band spans the full viewport width")
		check(is_equal_approx(rect.position.y, next_y), "bands meet without gaps")
		next_y = rect.end.y
	check(is_equal_approx(next_y, viewport_rect.end.y), "last band reaches the bottom of the viewport")

func run() -> void:
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await physics_frame
	var player := forest.get_node("Player") as FirstPersonPlayer
	var barrier: Variant = forest.get_node("Interactables/BarrierTree")
	check(barrier.climb_banded_fade, "forest log enables banded fade")
	barrier.trigger_post_teleport_dialogue = false
	var step: float = barrier.climb_banded_step_duration
	var hold: float = barrier.climb_black_hold_duration
	check(is_equal_approx(step * 40.0 + hold, 3.54), "log transition is 70 percent shorter at 3.54 seconds")
	check(is_equal_approx(player.sprint_speed, 5.52), "normal sprint speed is 15 percent faster")
	player.set_physics_process(false)
	barrier.climb_over_barrier(player)
	var original_position := player.global_position
	barrier._climb_tween.pause()
	var bands: Array = barrier._climb_canvas.get_node("ClimbFadeBands").get_children()
	check(bands.size() == 5, "five black bands created")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1023, 769), Vector2i(720, 1280)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		check_coverage(bands)
	barrier._climb_tween.custom_step(step * 0.96)
	check(bands[0].color.a == 0.0, "band stays clear before its first step")
	barrier._climb_tween.custom_step(step * 0.08)
	check(is_equal_approx(bands[0].color.a, 0.25) and bands[1].color.a == 0.0, "first band steps to 25% before second")
	barrier._climb_tween.custom_step(step)
	check(is_equal_approx(bands[0].color.a, 0.5), "second step reaches 50%")
	check(player.global_position.is_equal_approx(original_position), "player stays put before blackout")
	barrier._climb_tween.custom_step(step * 18.0)
	check(bands.all(func(band): return is_equal_approx(band.color.a, 1.0)), "all bands opaque before teleport")
	barrier._climb_tween.custom_step(hold * 0.4 + step * 0.04)
	check(not player.global_position.is_equal_approx(original_position), "teleport occurs during full blackout")
	barrier._climb_tween.custom_step(hold * 0.6 + step * 1.01)
	check(is_equal_approx(bands[4].color.a, 0.75) and is_equal_approx(bands[0].color.a, 1.0), "bottom band reveals first in 25% steps")
	barrier._climb_tween.custom_step(step * 20.0)
	check(not barrier._is_climbing_over and not player.is_frozen, "transition finishes and restores player control")
	await process_frame
	check(barrier._climb_canvas == null, "overlay cleaned up after transition")
	quit(1 if failures else 0)
