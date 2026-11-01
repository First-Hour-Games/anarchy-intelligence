extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func collect(player: FirstPersonPlayer, item_id: StringName) -> void:
	var pickup := InventoryPickup.new()
	pickup.item_id = item_id
	pickup.visual_target_path = NodePath(".")
	root.add_child(pickup)
	pickup.global_position = player.global_position + Vector3(0, 0, -1)
	pickup.interact(player)
	var screen: Variant = root.get_node("ItemPickupScreen")
	check(player.inventory.has_item(item_id) and player.is_frozen, "new %s opens pickup with player frozen" % item_id)
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "pickup temporarily releases the cursor")
	await screen.opened
	var key := InputEventAction.new()
	key.action = &"interact"
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await screen.closed
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP item_pickup_cursor_smoke requires real mouse capture")
		quit(0)
		return
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await process_frame
	for item: StringName in [&"fence_key", &"bottle", &"metal_pipe"]:
		await collect(player, item)
		check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.is_frozen, "closing %s recaptures the cursor without clicking the window" % item)
		var original_yaw := player.rotation.y
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(20, 0)
		player._unhandled_input(motion)
		check(not is_equal_approx(player.rotation.y, original_yaw), "camera look works immediately after pickup")
	var inspection := InspectableView3D.new()
	var marker := Marker3D.new()
	inspection.add_child(marker)
	inspection.camera_anchor = marker
	inspection.blink_close_duration = 0.01
	inspection.blink_hold_duration = 0.01
	inspection.blink_open_duration = 0.01
	root.add_child(inspection)
	inspection.start_inspection(player)
	while inspection._is_transitioning:
		await process_frame
	await collect(player, &"map")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and player.is_frozen and player.camera.top_level, "inspection pickup preserves the inspection cursor and frozen player")
	inspection.exit_inspection()
	await inspection.inspection_ended
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not player.is_frozen, "leaving inspection still returns the captured gameplay cursor")
	inspection.queue_free()
	player.queue_free()
	await process_frame
	print("item_pickup_cursor_smoke: %d failures" % failures)
	quit(1 if failures else 0)
