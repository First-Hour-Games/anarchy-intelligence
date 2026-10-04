extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Log Climb Music Transition Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var forest_scene: PackedScene = load("res://scenes/chapters/main/starting_forest.tscn")
	check(forest_scene != null, "starting_forest.tscn loaded successfully")
	if forest_scene == null:
		quit(1)
		return

	var forest: StartingForest = forest_scene.instantiate() as StartingForest
	root.add_child(forest)
	await process_frame

	var visitor_bgm: AudioStreamPlayer = forest.get_node_or_null("VisitorBGM") as AudioStreamPlayer
	check(is_instance_valid(visitor_bgm), "VisitorBGM node found in starting_forest")
	check(visitor_bgm.bus == &"Music", "VisitorBGM assigned to Music bus")
	check(visitor_bgm.stream != null and visitor_bgm.stream.resource_path.ends_with("theVisitor.mp3"), "VisitorBGM stream is theVisitor.mp3")

	var hike_bgm: AudioStreamPlayer = forest.get_node_or_null("WelcomingHikeBGM") as AudioStreamPlayer
	check(is_instance_valid(hike_bgm), "WelcomingHikeBGM node found in starting_forest")
	check(hike_bgm.bus == &"Music", "WelcomingHikeBGM assigned to Music bus")
	check(hike_bgm.stream != null and hike_bgm.stream.resource_path.ends_with("welcomingHike.mp3"), "WelcomingHikeBGM stream is welcomingHike.mp3")
	check(hike_bgm.volume_db <= -70.0, "WelcomingHikeBGM starts muted/silent (-80 dB)")

	var barrier_tree: InteractableBlock3D = forest.get_node_or_null("Interactables/BarrierTree") as InteractableBlock3D
	check(is_instance_valid(barrier_tree), "BarrierTree interactable block found")

	# Start VisitorBGM as it would be during gameplay
	visitor_bgm.play()
	visitor_bgm.volume_db = -3.0
	check(visitor_bgm.playing, "VisitorBGM is playing before climb")

	# Speed up durations for test execution
	forest.music_fade_out_duration = 0.05
	forest.music_fade_in_duration = 0.05
	forest.music_fade_in_delay = 0.0

	# Test log climb trigger
	check(not forest._has_switched_music, "Music has not switched yet before climb")
	barrier_tree.climb_over_started.emit(forest.player)

	check(forest._has_switched_music, "Climb on log set _has_switched_music to true")
	check(hike_bgm.playing, "WelcomingHikeBGM began playing on climb")

	# Wait for fast fade tween to complete
	await create_timer(0.15).timeout
	await process_frame

	check(not visitor_bgm.playing, "VisitorBGM stopped playing after fade out")
	check(visitor_bgm.volume_db <= -70.0, "VisitorBGM volume faded down to -80 dB")
	check(hike_bgm.playing, "WelcomingHikeBGM is still playing")
	check(is_equal_approx(hike_bgm.volume_db, forest.welcoming_hike_volume_db), "WelcomingHikeBGM reached target volume (" + str(forest.welcoming_hike_volume_db) + " dB)")

	# Test idempotency (climbing again does not restart or error)
	barrier_tree.climb_over_started.emit(forest.player)
	check(forest._has_switched_music, "_has_switched_music remains true")
	check(hike_bgm.playing, "WelcomingHikeBGM still playing cleanly after second climb signal")

	forest.queue_free()
	await process_frame

	print("--- Log Climb Music Transition Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with " + str(failures) + " failures")
		quit(1)
