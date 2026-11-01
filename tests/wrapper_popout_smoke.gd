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
	var capture := "--capture" in OS.get_cmdline_user_args()
	if capture:
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
	player.unfreeze()
	player.set_physics_process(false)
	var zone: Variant = forest.get_node("WrapperPopoutZone")
	var marker: Marker3D = forest.get_node("WrapperPopout")
	var wrapper: CharacterBody3D = forest.get_node("Wrapper")
	var walk: Variant = forest.get_node("WrapperCutscene")
	var shape: CollisionShape3D = zone.get_node("CollisionShape3D")
	var center := shape.global_position
	check(is_equal_approx(center.x + (shape.shape as BoxShape3D).size.x * 0.5, 151.0), "ambush trigger reaches two meters earlier along the approach")
	# Approach along the inside of the fence, rather than placing the player across it.
	var inside := Vector3(center.x, 0.2, center.z + 0.6)
	var outside := inside + Vector3(3, 0, 0)
	player.global_position = outside
	await frames()
	player.global_position = inside
	await frames()
	check(zone.overlaps_body(player), "real player enters the authored generator trigger")
	check(not zone.has_played and not wrapper.visible, "no key means no enemy activation")
	var appearance_audio := wrapper.get_node("AppearanceAudio") as AudioStreamPlayer
	check(not appearance_audio.playing, "appearance cue stays silent before activation")
	player.inventory.add_item(PlayerInventory.FENCE_KEY_ITEM)
	player.is_frozen = true
	await frames()
	check(not zone.has_played, "key inspection cannot activate the enemy while player is frozen")
	player.unfreeze()
	player.set_physics_process(false)
	var focus := marker.global_position + Vector3.UP * 1.4
	player.look_at(Vector3(focus.x, player.global_position.y, focus.z), Vector3.UP)
	player.head.look_at(focus, Vector3.UP)
	player.reset_physics_interpolation()
	player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
	player.flashlight.set_enabled(true)
	zone._try_activate()
	check(wrapper.visible and wrapper.enabled, "qualifying zone activation reveals the Wrapper immediately")
	await frames()
	check(zone.has_played and wrapper.visible and wrapper.enabled, "key arms the zone and enables the existing enemy")
	await process_frame
	check(wrapper.get_node("HuntAudio").playing, "generator ambush starts the nearby Wrapper hunt loop")
	check(appearance_audio.playing and appearance_audio.stream.resource_path.ends_with("scaryMoment.ogg"), "ambush layers the new Ogg appearance cue over the hunt loop")
	check(not (appearance_audio.stream as AudioStreamOggVorbis).loop and appearance_audio.volume_db > wrapper.get_node("HuntAudio").hunt_volume_db, "appearance cue plays once at a higher volume than the hunt loop")
	check(wrapper.is_physics_processing() and wrapper.collision_layer != 0, "enemy physics and collision are restored")
	check(not wrapper.freeze_when_watched, "this ambush approaches even while watched")
	check(is_equal_approx(wrapper.movement_speed, 1.4) and is_equal_approx(wrapper.movement_speed, zone.ambush_movement_speed), "ambush movement is 50 percent slower than the previous 2.8 speed")
	check(walk.has_played and not walk.is_playing, "window controller cannot reclaim the attacking enemy")
	check(wrapper.spawn.origin.is_equal_approx(marker.global_position), "enemy starts at the authored WrapperPopout marker")
	var health: Node = player.get_node("CombatHealth")
	var initial_health: float = health.health
	var start_position := wrapper.global_position
	var deadline := Time.get_ticks_msec() + 14000
	var moved := false
	while health.health >= initial_health and Time.get_ticks_msec() < deadline:
		player.look_at(Vector3(wrapper.global_position.x, player.global_position.y, wrapper.global_position.z), Vector3.UP)
		player.head.look_at(wrapper.global_position + Vector3.UP * 1.4, Vector3.UP)
		await physics_frame
		moved = moved or wrapper.global_position.distance_to(start_position) > 0.2
	check(moved, "Wrapper walks out from the marker using navigation")
	check(health.health < initial_health, "existing attack system damages the real player")
	check(wrapper.is_watched_by_player(), "enemy reaches attack range while the player is watching it")
	check(wrapper.get_node("Visual").clip == "attack", "existing combat AI plays the Wrapper lunge animation")
	check(wrapper.visible and wrapper.enabled, "enemy remains active instead of disappearing after 1.25 seconds")
	if capture:
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/wrapper_popout.png")
	print("ENEMY FINAL ", wrapper.global_position, " PLAYER ", player.global_position, " HEALTH ", health.health)
	wrapper.suspended = true
	var post: Transform3D = wrapper.spawn
	zone._on_body_entered(player)
	await frames()
	check(wrapper.spawn.is_equal_approx(post), "re-entering cannot teleport or restart the active enemy")
	var state: Dictionary = root.get_node("SaveGame")._capture_section(forest)
	check(state.one_shot_cutscenes.get("WrapperPopoutZone", false), "save records the activated encounter")
	appearance_audio.stop()
	zone._activated = false
	wrapper.enabled = false
	wrapper.hide()
	root.get_node("SaveGame")._restore_section(forest, state)
	await frames()
	check(wrapper.enabled and wrapper.visible, "save restoration resumes the enemy rather than hiding it permanently")
	check(not appearance_audio.playing, "save restoration does not replay the appearance cue")
	var streaming := root.get_node("WorldStreaming")
	streaming._save_state(forest)
	zone._activated = false
	wrapper.enabled = false
	wrapper.hide()
	streaming._restore_state(forest)
	await frames()
	check(wrapper.enabled and wrapper.visible, "streaming restoration resumes the activated enemy")
	check(not appearance_audio.playing, "streaming restoration does not replay the appearance cue")
	zone.has_played = false
	zone._activated = false
	wrapper.enabled = false
	player.inventory.remove_one(PlayerInventory.FENCE_KEY_ITEM)
	forest.get_node("GasStation/MetalFenceGate").is_locked = false
	zone._on_body_entered(player)
	await frames()
	check(zone.has_played and wrapper.enabled, "key already used on the gate still qualifies for the ambush")
	var ordinary: Node = load("res://scenes/monsters/the_wrapper.tscn").instantiate()
	check(ordinary.freeze_when_watched, "ordinary Wrapper instances retain their watcher behavior")
	check(is_equal_approx(ordinary.movement_speed, 1.05), "ordinary Wrapper instances retain their original movement speed")
	ordinary.free()
	current_scene = null
	scene_changed.emit()
	forest.queue_free()
	await process_frame
	print("Wrapper popout: %d failures" % failures)
	quit(1 if failures else 0)
