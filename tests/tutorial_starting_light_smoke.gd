extends SceneTree

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
	# Configure fast durations for deterministic automated testing
	tutorial.set("intro_black_hold_seconds", 0.05)
	tutorial.set("intro_fade_duration", 0.4)
	tutorial.set("door_color_fade_duration", 0.4)
	tutorial.set("intro_light_start_y", 1.278)
	tutorial.set("intro_light_end_y", 2.094)

	root.add_child(tutorial)
	await process_frame

	var starting_omni := tutorial.get_node_or_null("Lights/StartingOmni") as OmniLight3D
	check(is_instance_valid(starting_omni), "StartingOmni light node exists under Lights")
	if is_instance_valid(starting_omni):
		check(is_equal_approx(starting_omni.position.y, 1.278), "StartingOmni initial position Y is 1.278m")

	# Wait for black hold to finish and intro fade to start (0.05s)
	await create_timer(0.08).timeout
	await process_frame

	var position_tween: Tween = tutorial.get("_intro_light_position_tween")
	check(position_tween != null and position_tween.is_valid(), "Position tween was created and is active")

	# Sample midway through fade (tween is 0.4 + 0.4 = 0.8s)
	await create_timer(0.3).timeout
	await process_frame
	if is_instance_valid(starting_omni):
		check(starting_omni.position.y > 1.278 and starting_omni.position.y < 2.094, "StartingOmni is tweening up between 1.278m and 2.094m")

	# Wait until door color fade completes (0.05 + 0.8 = 0.85s total)
	await create_timer(0.6).timeout
	await process_frame
	if is_instance_valid(starting_omni):
		check(is_equal_approx(starting_omni.position.y, 2.094), "StartingOmni reached 2.094m as door color finished fading in")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
