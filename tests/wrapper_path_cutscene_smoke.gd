extends SceneTree

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1


func frames(count: int = 4) -> void:
	for index in count:
		await physics_frame


func run() -> void:
	if "--capture" in OS.get_cmdline_user_args():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(960, 720))
		root.size = Vector2i(960, 720)
	var forest: Variant = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	root.add_child(forest)
	current_scene = forest
	forest.get_node("IntroFadeCanvas").hide()
	var player: FirstPersonPlayer = forest.player
	player.set_physics_process(false)
	player.unfreeze()
	var cutscene: Variant = forest.get_node("WrapperCutscene")
	var wrapper := forest.get_node("Wrapper") as CharacterBody3D
	var authored_scale := wrapper.global_basis.get_scale()
	var zone := cutscene.get_node("ActivationZone") as Area3D
	var start := cutscene.get_node("Start") as Marker3D
	var end := cutscene.get_node("End") as Marker3D
	var view_target := cutscene.get_node("ViewTarget") as Marker3D
	var inside := Vector3(zone.global_position.x, 0.6, zone.global_position.z)
	var zone_shape := zone.get_node("CollisionShape3D") as CollisionShape3D
	var outside := inside + Vector3(0, 0, (zone_shape.shape as BoxShape3D).size.z * zone.global_basis.get_scale().z + 3.0)
	player.global_position = outside
	await frames()
	check(not wrapper.visible and not wrapper.is_physics_processing(), "Wrapper starts hidden with its AI disabled")
	check(cutscene._buildup_player == null, "buildup stays silent until the window appearance triggers")
	var appearance_audio := wrapper.get_node("AppearanceAudio") as AudioStreamPlayer
	check(not appearance_audio.playing, "scary moment stays silent until the Wrapper appears")
	check(is_equal_approx(cutscene.walk_speed, 1.5 * 1.15), "window walk moves 15 percent faster")
	check(wrapper.collision_layer == 0 and wrapper.collision_mask == 0, "cutscene Wrapper cannot block or attack the player")
	player.global_position = inside
	await frames()
	check(zone.overlaps_body(player), "player physically enters the authored activation volume")
	check(not cutscene.has_played and not wrapper.visible, "entering without the flashlight does not trigger or consume the cutscene")
	# Exercise the real pickup, skipping only its separately tested dialogue.
	var pickup := forest.get_node("FlashlightItem/Pickup") as FlashlightPickup
	pickup.pickup_dialogue_resource = null
	pickup.interact(player)
	await create_timer(0.4).timeout
	var screen := root.get_node("ItemPickupScreen")
	screen.close()
	await create_timer(0.4).timeout
	player.set_physics_process(false)
	check(player.has_item(PlayerInventory.FLASHLIGHT_ITEM) and not player.is_frozen, "real flashlight pickup finishes and returns control")
	check(not cutscene.has_played, "collecting the flashlight while already inside does not count as entering after pickup")
	player.global_position = outside
	await frames()
	player.look_at(player.global_position + Vector3.BACK, Vector3.UP)
	player.head.rotation = Vector3.ZERO
	player.global_position = inside
	await frames()
	check(not cutscene.has_played and not wrapper.visible, "entering with the flashlight while looking away does not consume the appearance")
	await frames()
	check(not cutscene.is_playing, "the Wrapper stays hidden while the player faces away inside the zone")
	player.global_position = outside
	await frames()
	player.look_at(Vector3(view_target.global_position.x, player.global_position.y, view_target.global_position.z), Vector3.UP)
	await frames()
	check(not cutscene.has_played, "looking toward the windows after leaving the zone does not trigger the appearance")
	player.look_at(player.global_position + Vector3.BACK, Vector3.UP)
	player.global_position = inside
	await frames()
	player.look_at(Vector3(view_target.global_position.x, player.global_position.y, view_target.global_position.z), Vector3.UP)
	player.head.rotation.x = 1.2
	await frames()
	check(not cutscene.has_played, "looking at the ceiling does not count as the reference window view")
	check(absf(db_to_linear(forest.near_town_volume_db) / db_to_linear(-20.0) - 1.5) < 0.0001, "nearTown target volume is 50 percent louder")
	forest.finish_near_town_immediately()
	var near_town: AudioStreamPlayer = forest.near_town_bgm
	var near_town_start_db := near_town.volume_db
	check(near_town.playing, "nearTown is playing before the buildup takes over")
	player.head.rotation.x = 0.0
	player.camera.look_at(view_target.global_position, Vector3.UP)
	player.reset_physics_interpolation()
	await frames()
	check(cutscene.has_played and cutscene.is_playing and wrapper.visible, "turning toward the front windows inside the zone reveals the Wrapper")
	var music := cutscene._buildup_player as AudioStreamPlayer
	check(music != null and music.playing, "buildup starts with the window appearance")
	check(appearance_audio.playing and appearance_audio.stream.resource_path.ends_with("scaryMoment.ogg"), "window reveal overlaps scary moment with the existing buildup")
	check(appearance_audio.volume_db > music.volume_db, "scary moment has volume priority over the buildup")
	if music == null:
		quit(1)
		return
	check(cutscene.buildup_music.resource_path.ends_with("/buildUp.ogg"), "appearance uses the new buildup track")
	check(music.bus == &"Music" and is_equal_approx(music.volume_db, -6.0), "buildup uses requested gain and follows Music volume")
	check(music.stream.loop and absf(music.stream.loop_offset - 62.136) < 0.001, "buildup loops back to 1:02.136")
	check(music.get_playback_position() < 1.0, "buildup initially starts from zero")
	check(near_town.playing and near_town.volume_db < near_town_start_db, "nearTown starts fading as buildup begins")
	check(not player.is_frozen and not paused, "the appearance keeps player control active")
	var animation_player := wrapper.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	check(animation_player.current_animation == "cutscene/walk" and animation_player.is_playing(), "the real nervous-walk animation is playing")
	check(is_equal_approx(animation_player.get_playing_speed(), 1.15), "walk animation also runs 15 percent faster")
	check(wrapper.global_basis.get_scale().is_equal_approx(authored_scale), "following the markers preserves the authored model scale")
	var deadline := Time.get_ticks_msec() + 10000
	var on_line := true
	var captured := false
	var previous := start.global_position
	var route_direction := start.global_position.direction_to(end.global_position)
	while cutscene.is_playing and Time.get_ticks_msec() < deadline:
		await physics_frame
		var position := wrapper.global_position
		var along_route := (position - start.global_position).dot(route_direction)
		on_line = on_line and position.distance_to(start.global_position + route_direction * along_route) < 0.001
		on_line = on_line and (position - previous).dot(route_direction) >= -0.001
		previous = position
		if not captured and "--capture" in OS.get_cmdline_user_args() and position.x < start.global_position.x - 2.0 and position.x > end.global_position.x + 2.0:
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/wrapper_cutscene_walk.png")
			captured = true
	check(on_line, "Wrapper walks monotonically along the authored Start-to-End line")
	check(not cutscene.is_playing and not wrapper.visible, "Wrapper disappears on the same physics step that reaches the end")
	check(wrapper.global_position.is_equal_approx(end.global_position), "the final position is exactly the authored End marker")
	check(music.playing, "full buildup track continues after the short window crossing")
	if forest._near_town_tween != null and forest._near_town_tween.is_running():
		await forest._near_town_tween.finished
	check(not near_town.playing and near_town.volume_db <= -79.0, "nearTown fades fully out and stops")
	forest._check_near_town_trigger()
	check(not near_town.playing and music.playing, "proximity cannot restart nearTown over the buildup")
	player.global_position = outside
	await frames()
	player.global_position = inside
	await frames()
	var popout: Node = forest.get_node("WrapperPopoutZone")
	check(not cutscene.is_playing and (not wrapper.visible or popout.get("is_playing")), "re-entering cannot replay the window walk while allowing the separate generator scare")
	check(cutscene._buildup_player == music, "re-entering does not create another music player")
	music.seek(music.stream.get_length() - 0.15)
	await create_timer(0.5).timeout
	check(music.playing and music.get_playback_position() >= 62.136 and music.get_playback_position() < 63.136, "playback crosses the end and resumes at the requested loop point")
	var save_gem := forest.get_node("GasStationSaveGem") as Node3D
	var fade_zone := save_gem.get_node("BuildupFadeZone") as Area3D
	var before_fade := music.volume_db
	player.global_position = save_gem.global_position + Vector3(6, 0.2, 0)
	await frames()
	check(not fade_zone.overlaps_body(player) and music.playing, "buildup continues outside the save-point zone")
	player.global_position = save_gem.global_position + Vector3(0, 0.2, 0)
	await frames()
	check(fade_zone.overlaps_body(player), "player physically enters the authored save-point fade zone")
	check(cutscene._buildup_fade != null and music.playing and music.volume_db < before_fade, "save zone gradually fades buildup instead of cutting it")
	if cutscene._buildup_fade != null and cutscene._buildup_fade.is_running():
		await cutscene._buildup_fade.finished
	check(not music.playing and music.volume_linear <= 0.0001, "buildup stops at silence after the save-zone fade")
	player.global_position += Vector3(6, 0, 0)
	await frames()
	player.global_position = save_gem.global_position + Vector3(0, 0.2, 0)
	await frames()
	check(not music.playing, "leaving and re-entering the save zone cannot restart buildup")
	var stream := root.get_node("WorldStreaming")
	stream._save_state(forest)
	var restored: Node3D = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	stream._restore_state(restored)
	check(restored.get_node("WrapperCutscene").has_played, "streaming restores the consumed state before the forest re-enters the tree")
	check(not restored.get_node("Wrapper").visible, "restored forest keeps the Wrapper hidden")
	restored.free()
	var sections: Array = stream._sections.values().duplicate()
	current_scene = null
	scene_changed.emit()
	for section: Node in sections:
		if is_instance_valid(section) and not section.is_queued_for_deletion():
			section.queue_free()
	await process_frame
	print("Wrapper path cutscene: %d failures" % failures)
	quit(1 if failures else 0)
