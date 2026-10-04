extends SceneTree

const StartingForestScript = preload("res://scenes/chapters/main/starting_forest.gd")

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Starting Forest Intro Fade Smoke Test ---")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "starting_forest.tscn loaded")

	var forest: Node3D = packed_forest.instantiate()
	check(forest != null and forest.get_script() == StartingForestScript, "forest is instance of StartingForest script")

	# Disable auto_start_fade so we can inspect the initial 0-volume and black screen states explicitly
	forest.auto_start_fade = false
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in starting_forest")

	var fade_canvas := forest.get_node_or_null("IntroFadeCanvas") as CanvasLayer
	check(is_instance_valid(fade_canvas), "IntroFadeCanvas exists in scene")
	check(fade_canvas.layer >= 100, "IntroFadeCanvas layer is on top of CRT overlay")

	var black_screen := fade_canvas.get_node_or_null("BlackScreen") as ColorRect
	check(is_instance_valid(black_screen), "BlackScreen ColorRect exists")
	check(is_equal_approx(black_screen.color.a, 1.0), "BlackScreen starts fully opaque (alpha = 1.0)")

	var subtitle_label := fade_canvas.get_node_or_null("SubtitleLabel") as Label
	check(is_instance_valid(subtitle_label), "SubtitleLabel exists in IntroFadeCanvas")
	check(subtitle_label.text == "five days later", "Subtitle text is 'five days later'")
	check(is_equal_approx(subtitle_label.modulate.a, 0.0), "SubtitleLabel starts hidden (alpha = 0.0)")
	check(is_equal_approx(forest.fade_duration, 3.75), "Default fade_duration is 3.75s (50% slower than 2.5s)")

	var night_ambience := forest.get_node_or_null("NightAmbience") as AudioStreamPlayer
	var engine_loop := forest.get_node_or_null("toyotaCrownModel2/EngineLoop") as AudioStreamPlayer3D
	check(is_instance_valid(night_ambience), "NightAmbience found")
	check(is_instance_valid(engine_loop), "EngineLoop found")

	check(is_equal_approx(night_ambience.volume_db, -80.0), "NightAmbience starts at 0 volume (-80 dB)")
	check(is_equal_approx(engine_loop.volume_db, -80.0), "EngineLoop starts at 0 volume (-80 dB)")
	check(night_ambience.playing, "NightAmbience is playing")
	check(engine_loop.playing, "EngineLoop is playing")

	# Start the intro fade with compressed durations for testing
	forest.initial_black_hold = 0.05
	forest.subtitle_fade_in_duration = 0.05
	forest.subtitle_hold_duration = 0.1
	forest.subtitle_fade_out_duration = 0.05
	forest.subtitle_pause_after = 0.05
	forest.fade_duration = 0.2
	forest.start_intro_fade()
	await process_frame

	check(player.is_frozen, "Player is frozen during intro fade")
	check(forest._is_fading, "Intro fade is actively running")

	# Wait for subtitle fade in + hold + fade out + pause + game fade to complete (0.5s total + margin)
	await create_timer(0.7).timeout
	await process_frame

	check(forest._has_faded, "Intro fade has completed")
	check(not forest._is_fading, "Intro fade is no longer active")
	check(not is_instance_valid(forest._fade_canvas), "IntroFadeCanvas cleaned up after fade out")

	check(is_equal_approx(night_ambience.volume_db, -4.0), "NightAmbience faded in to target volume (-4.0 dB)")
	check(is_equal_approx(engine_loop.volume_db, -10.0), "EngineLoop faded in to target volume (-10.0 dB)")

	var opening_balloon := forest.get_node_or_null("BottomDialogueBalloon") as BottomDialogueBalloon
	check(is_instance_valid(opening_balloon), "Opening dialogue balloon exists")
	check(opening_balloon.balloon.visible, "Opening dialogue balloon opened after fade out")

	# Dismiss opening dialogue
	opening_balloon._end_dialogue()
	await process_frame

	# Test skip_fade / finish_fade_immediately on a fresh instance
	var forest2: Node3D = packed_forest.instantiate()
	root.add_child(forest2)
	await process_frame
	check(forest2._is_fading, "Second instance started auto fade")
	forest2.skip_fade()
	await process_frame
	check(forest2._has_faded, "skip_fade() immediately completed the fade")
	var na2 := forest2.get_node_or_null("NightAmbience") as AudioStreamPlayer
	check(is_equal_approx(na2.volume_db, -4.0), "Audio reached target volume immediately upon skip")

	forest2.queue_free()
	forest.queue_free()

	print("--- Starting Forest Intro Fade Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)
