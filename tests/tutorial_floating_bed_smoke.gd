extends SceneTree

const FloatingBed = preload("res://scenes/chapters/tutorial/floating_bed.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var tutorial_packed := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	check(tutorial_packed != null, "tutorial.tscn loaded successfully")

	var tutorial := tutorial_packed.instantiate()
	root.add_child(tutorial)
	await process_frame

	var bed := tutorial.get_node_or_null("TutorialRooms/FloatingBed")
	check(is_instance_valid(bed), "FloatingBed exists under TutorialRooms")
	check(bed is FloatingBed, "FloatingBed has FloatingBed script attached")

	var floating_bed: FloatingBed = bed as FloatingBed
	check(floating_bed.float_enabled, "float_enabled is true by default")
	check(floating_bed.is_floating(), "FloatingBed tween is active and floating")

	var base_y := floating_bed.get_base_y()
	check(is_equal_approx(base_y, 1.3257586), "Base Y matches the scene initial Y coordinate (~1.326m)")

	# Let the tween run for a bit and verify that position.y deviates smoothly within amplitude
	var moved := false
	for i in range(10):
		await create_timer(0.15).timeout
		await process_frame
		var current_y := floating_bed.position.y
		var diff := absf(current_y - base_y)
		if diff > 0.005:
			moved = true
		check(current_y <= base_y + floating_bed.float_amplitude + 0.001 and current_y >= base_y - floating_bed.float_amplitude - 0.001,
			"FloatingBed Y stays within amplitude bounds (current: %f, base: %f)" % [current_y, base_y])

	check(moved, "FloatingBed position Y changed over time (tweening up and down)")

	# Test stop_floating and reset
	floating_bed.stop_floating(true)
	check(not floating_bed.is_floating(), "stop_floating stopped the tween")
	check(is_equal_approx(floating_bed.position.y, base_y), "stop_floating(true) restored base Y position")

	# Test restart
	floating_bed.start_floating()
	check(floating_bed.is_floating(), "start_floating restarted the tween")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
