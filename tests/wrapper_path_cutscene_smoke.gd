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
	var forest: StartingForest = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	root.add_child(forest)
	current_scene = forest
	forest.get_node("IntroFadeCanvas").hide()
	var player := forest.player
	player.set_physics_process(false)
	player.unfreeze()
	var cutscene := forest.get_node("WrapperCutscene")
	var wrapper := forest.get_node("Wrapper") as CharacterBody3D
	var zone := cutscene.get_node("ActivationZone") as Area3D
	var start := cutscene.get_node("Start") as Marker3D
	var end := cutscene.get_node("End") as Marker3D
	var view_target := cutscene.get_node("ViewTarget") as Marker3D
	var inside := Vector3(zone.global_position.x, 0.6, zone.global_position.z)
	var outside := inside + Vector3(0, 0, 3)
	player.global_position = outside
	await frames()
	check(not wrapper.visible and not wrapper.is_physics_processing(), "Wrapper starts hidden with its AI disabled")
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
	player.head.rotation.x = atan2(view_target.global_position.y - player.camera.global_position.y, Vector2(view_target.global_position.x - player.camera.global_position.x, view_target.global_position.z - player.camera.global_position.z).length())
	player.reset_physics_interpolation()
	await frames()
	check(cutscene.has_played and cutscene.is_playing and wrapper.visible, "turning toward the front windows inside the zone reveals the Wrapper")
	check(not player.is_frozen and not paused, "the appearance keeps player control active")
	var animation_player := wrapper.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	check(animation_player.current_animation == "cutscene/walk" and animation_player.is_playing(), "the real nervous-walk animation is playing")
	check(is_equal_approx(wrapper.global_basis.get_scale().x, 1.3), "following the markers preserves the authored model scale")
	var deadline := Time.get_ticks_msec() + 10000
	var on_line := true
	var captured := false
	var previous := start.global_position
	while cutscene.is_playing and Time.get_ticks_msec() < deadline:
		await physics_frame
		var position := wrapper.global_position
		on_line = on_line and is_equal_approx(position.z, start.global_position.z) and is_equal_approx(position.y, start.global_position.y)
		on_line = on_line and position.x <= previous.x + 0.001
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
	player.global_position = outside
	await frames()
	player.global_position = inside
	await frames()
	check(not wrapper.visible and not cutscene.is_playing, "re-entering cannot replay the one-shot appearance")
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
