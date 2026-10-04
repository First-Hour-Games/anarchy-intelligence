extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Pause Sound Randomization Smoke Test ---")
	await process_frame
	var pause_menu := root.get_node_or_null("PauseMenu")
	assert(pause_menu != null, "PauseMenu autoload must exist")

	# 1. Verify PAUSE_SOUNDS array
	assert(pause_menu.PAUSE_SOUNDS.size() == 2, "PAUSE_SOUNDS should contain 2 streams")
	var path0: String = pause_menu.PAUSE_SOUNDS[0].resource_path
	var path1: String = pause_menu.PAUSE_SOUNDS[1].resource_path
	assert(path0.contains("pause1.mp3") or path0.contains("pause2.mp3"), "Should contain pause1 or pause2")
	assert(path1.contains("pause1.mp3") or path1.contains("pause2.mp3"), "Should contain pause1 or pause2")
	assert(path0 != path1, "PAUSE_SOUNDS should have two distinct sounds")
	print("PASS: PAUSE_SOUNDS contains pause1.mp3 and pause2.mp3")

	# 2. Verify _pause_sfx_player
	var player: AudioStreamPlayer = pause_menu._pause_sfx_player
	assert(player != null, "PauseSfxPlayer must exist")
	assert(player.bus == &"Master", "PauseSfxPlayer bus should be Master")
	assert(player.process_mode == Node.PROCESS_MODE_ALWAYS, "PauseSfxPlayer must be PROCESS_MODE_ALWAYS")
	print("PASS: PauseSfxPlayer properly initialized")

	# 3. Test sound randomization on pause
	pause_menu.set_open(true)
	assert(player.stream != null, "Player stream should be set on pause")
	assert(player.stream == pause_menu.PAUSE_SOUNDS[0] or player.stream == pause_menu.PAUSE_SOUNDS[1], "Stream should be from PAUSE_SOUNDS")
	assert(player.pitch_scale >= 0.93 and player.pitch_scale <= 1.07, "Pitch scale should be randomized within ~0.94-1.06, got %f" % player.pitch_scale)
	print("PASS: Sound played on pause with randomized pitch: %f" % player.pitch_scale)

	# 4. Test sound randomization on unpause
	pause_menu.set_open(false)
	assert(player.stream != null, "Player stream should be set on unpause")
	assert(player.pitch_scale >= 0.93 and player.pitch_scale <= 1.07, "Pitch scale should be randomized within ~0.94-1.06, got %f" % player.pitch_scale)
	print("PASS: Sound played on unpause with randomized pitch: %f" % player.pitch_scale)

	# 5. Statistical distribution test (calling _play_random_pause_sound 20 times)
	var seen_streams := {}
	var pitches: Array[float] = []
	for i in range(20):
		pause_menu._play_random_pause_sound()
		seen_streams[player.stream] = true
		pitches.append(player.pitch_scale)

	assert(seen_streams.size() == 2, "Both pause1 and pause2 should be selected across 20 trials")
	var min_pitch: float = pitches.min()
	var max_pitch: float = pitches.max()
	assert(min_pitch != max_pitch, "Pitch variation should produce different pitch values")
	print("PASS: Both sounds selected, pitch range observed: [%.4f, %.4f]" % [min_pitch, max_pitch])

	# 6. Verify pressing Resume only plays cassette sound, not UI click sound
	pause_menu._click_sfx_player.stop()
	pause_menu._pause_sfx_player.stop()
	pause_menu.opened = true
	pause_menu._is_transitioning = false
	pause_menu.is_in_options = false
	pause_menu.selected_index = 0
	pause_menu._trigger_current_option()
	assert(not pause_menu._click_sfx_player.playing, "Click SFX player must NOT play when resuming")
	assert(pause_menu._pause_sfx_player.playing, "Pause cassette SFX player must play when resuming")
	print("PASS: Resume triggers cassette sound only, without UI click sound")

	# 7. Verify other options DO play UI click sound
	pause_menu._click_sfx_player.stop()
	pause_menu.opened = true
	pause_menu._is_transitioning = false
	pause_menu.selected_index = 1
	pause_menu._trigger_current_option()
	assert(pause_menu._click_sfx_player.playing, "Click SFX player should play for Options menu item")
	print("PASS: Non-resume menu item plays UI click sound")

	print("--- All Pause Sound Randomization Checks Passed! ---")
	quit(0)
