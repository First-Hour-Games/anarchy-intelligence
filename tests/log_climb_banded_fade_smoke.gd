extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func run() -> void:
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await physics_frame
	var player := forest.get_node("Player") as FirstPersonPlayer
	var barrier := forest.get_node("Interactables/BarrierTree") as InteractableBlock3D
	check(barrier.climb_banded_fade, "forest log enables banded fade")
	barrier.trigger_post_teleport_dialogue = false
	barrier.climb_fade_out_duration = 1.0
	barrier.climb_black_hold_duration = 1.0
	barrier.climb_fade_in_duration = 1.0
	var original_position := player.global_position
	barrier.climb_over_barrier(player)
	barrier._climb_tween.pause()
	var bands := barrier._climb_canvas.get_node("ClimbFadeBands").get_children()
	check(bands.size() == 5, "five black bands created")
	for index in range(5):
		check(is_equal_approx(bands[index].anchor_top, index / 5.0) and is_equal_approx(bands[index].anchor_bottom, (index + 1) / 5.0), "band %d covers equal fifth of viewport" % (index + 1))
	barrier._climb_tween.custom_step(0.24)
	check(bands[0].color.a == 0.0, "band stays clear before quarter-second step")
	barrier._climb_tween.custom_step(0.02)
	check(is_equal_approx(bands[0].color.a, 0.25) and bands[1].color.a == 0.0, "first band steps to 25% before second")
	barrier._climb_tween.custom_step(0.25)
	check(is_equal_approx(bands[0].color.a, 0.5), "second quarter-second step reaches 50%")
	check(player.global_position.is_equal_approx(original_position), "player stays put before blackout")
	barrier._climb_tween.custom_step(4.5)
	check(bands.all(func(band): return is_equal_approx(band.color.a, 1.0)), "all bands opaque before teleport")
	barrier._climb_tween.custom_step(0.5)
	check(not player.global_position.is_equal_approx(original_position), "teleport occurs during full blackout")
	barrier._climb_tween.custom_step(0.75)
	check(is_equal_approx(bands[4].color.a, 0.75) and is_equal_approx(bands[0].color.a, 1.0), "bottom band reveals first in 25% steps")
	barrier._climb_tween.custom_step(5.0)
	check(not barrier._is_climbing_over and not player.is_frozen, "transition finishes and restores player control")
	await process_frame
	check(barrier._climb_canvas == null, "overlay cleaned up after transition")
	quit(1 if failures else 0)
