extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var forest: Node = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("BottomDialogueBalloon").auto_start = false
	root.add_child(forest)
	current_scene = forest
	await process_frame
	var streaming := root.get_node("WorldStreaming")
	streaming.set_process(false)
	var mixer := root.get_node("AmbienceMixer")
	mixer.set_process(false)
	var baseline: AudioStreamPlayer = streaming.shared_nodes.get("NightAmbience")
	check(is_instance_valid(baseline), "Shared outdoor ambience is adopted by WorldStreaming")
	if not is_instance_valid(baseline):
		quit(1)
		return
	check(baseline.playing and baseline.volume_db == -80.0, "Outdoor ambience retains the intro's silent starting level")
	check(forest.get("_target_volumes").has(baseline), "Intro fade still owns the shared ambience player's target volume")
	forest.start_intro_fade()
	forest.finish_fade_immediately()
	check(is_equal_approx(baseline.volume_db, -4.0), "Finishing intro restores authored outdoor volume")
	check(baseline.bus == &"OutdoorAmbience", "Only the outdoor bed uses the muffling bus")
	var bgm: AudioStreamPlayer = streaming.shared_nodes.get("VisitorBGM")
	var bgm_volume := bgm.volume_db
	var player: Node3D = forest.player
	player.set_physics_process(false)
	for boundary in get_nodes_in_group("map_boundary_zones"):
		boundary.is_enabled = false
	var zone: Node3D = forest.get_node("GasStation/InteriorAmbienceZone")
	player.global_position = zone.global_position
	var playback_before := baseline.get_playback_position()
	for i in range(180):
		mixer.call("_process", 1.0 / 30.0)
	await create_timer(0.15).timeout
	var audio: AudioStreamPlayer = mixer.get("_zones")[zone].audio
	check(audio.playing and audio.stream is AudioStreamMP3, "Actual gas station starts the factory ambience")
	check(baseline.playing and baseline.get_playback_position() >= playback_before, "Outdoor track keeps playing through interior transition")
	check(is_equal_approx(baseline.volume_db, -4.0), "Zone mixing composes with the intro without overwriting its volume")
	check(bgm.volume_db == bgm_volume and bgm.bus == &"Music", "Zone does not change music")
	player.global_position = zone.to_global(Vector3(0, 0, zone.size.z * 0.5 + 10))
	for i in range(300):
		mixer.call("_process", 1.0 / 30.0)
	check(not audio.playing, "Leaving actual station releases the factory ambience")
	check(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("OutdoorAmbience"))) < 0.01, "Outdoor bed returns at full authored level")
	print("Forest ambience integration: %d failures" % failures)
	quit(1 if failures else 0)
