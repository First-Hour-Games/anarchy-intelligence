extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	print("--- Running Inspection Blink Sound Smoke Test ---")
	var view_script := load("res://scenes/interaction/inspection_view.gd")
	if view_script == null:
		push_error("Failed to load inspection_view.gd")
		quit(1)
		return

	var view: InspectableView3D = InspectableView3D.new()
	var marker := Marker3D.new()
	marker.name = "CameraAnchor"
	view.add_child(marker)
	view.camera_anchor = marker
	root.add_child(view)

	# Verify default exports
	assert(view.blink_sound != null, "blink_sound should not be null by default")
	assert(view.blink_sound.resource_path == "res://sounds/player/blink.mp3", "blink_sound should be res://sounds/player/blink.mp3")
	assert(view.blink_sound_volume_db == 0.0, "blink_sound_volume_db default should be 0.0")
	assert(view.blink_sound_bus == &"Master", "blink_sound_bus default should be Master")
	print("PASS: Defaults verified. blink_sound resource path: ", view.blink_sound.resource_path)

	# Instantiate the full player scene
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as FirstPersonPlayer
	root.add_child(player)

	# Test entering inspection
	view.start_inspection(player)
	var audio_player: AudioStreamPlayer = view.get_node_or_null("BlinkAudioPlayer") as AudioStreamPlayer
	assert(audio_player != null, "BlinkAudioPlayer node should be created")
	assert(audio_player.stream == view.blink_sound, "BlinkAudioPlayer stream should match blink_sound")
	assert(audio_player.playing, "BlinkAudioPlayer should be playing on start_inspection")
	print("PASS: Blink audio played when entering inspection mode")

	# Wait for transition to finish
	while view._is_transitioning:
		await process_frame
	assert(view.is_inspecting, "Should be in inspection mode")

	# Stop player to clearly verify it plays again on exit
	audio_player.stop()
	assert(not audio_player.playing, "Audio player stopped for test")

	# Test exiting inspection
	view.exit_inspection()
	assert(audio_player.playing, "BlinkAudioPlayer should be playing on exit_inspection")
	print("PASS: Blink audio played when exiting inspection mode")

	while view._is_transitioning:
		await process_frame
	assert(not view.is_inspecting, "Should have exited inspection mode")

	print("ALL INSPECTION BLINK SOUND CHECKS PASSED!")
	view.queue_free()
	player.queue_free()
	quit(0)
