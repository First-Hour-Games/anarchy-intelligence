extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func axis(which: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = which
	event.axis_value = value
	send(event)

func button(which: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = which
	event.pressed = true
	send(event)
	event = event.duplicate()
	event.pressed = false
	send(event)

func point_at(position: Vector2) -> void:
	root.warp_mouse(position)
	var motion := InputEventMouseMotion.new()
	motion.device = InputDevice.SYNTHETIC_DEVICE_ID
	motion.position = position
	root.push_input(motion, true)

func run() -> void:
	var manager := InputDevice.manager()
	var view := InspectableView3D.new()
	root.add_child(view)
	view.is_inspecting = true
	view._dots_canvas.visible = true
	manager.set_inspection_cursor_owner(view)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var hotspot := InspectionHotspot3D.new()
	view.add_child(hotspot)
	view._refresh_hotspots()
	var eye: InspectionDotButton = view._hotspot_map[hotspot]
	var clicks: Array[int] = [0]
	eye.clicked.connect(func() -> void: clicks[0] += 1)
	eye.position = Vector2(300, 200)
	await process_frame
	manager._ignore_mouse_motion_until_msec = Time.get_ticks_msec() + 2000
	root.warp_mouse(Vector2(200, 220))
	await create_timer(0.1).timeout
	var start := root.get_mouse_position()
	var nav_events: Array[StringName] = []
	var on_input := func(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed:
			nav_events.append(event.action)
	root.window_input.connect(on_input)
	axis(JOY_AXIS_LEFT_X, 1.0)
	await create_timer(0.15).timeout
	axis(JOY_AXIS_LEFT_X, 0.0)
	check(root.get_mouse_position().x > start.x + 20, "left stick moves inspection cursor")
	check(nav_events.is_empty(), "inspection stick does not emit menu navigation")
	start = root.get_mouse_position()
	axis(JOY_AXIS_RIGHT_Y, 1.0)
	await create_timer(0.1).timeout
	axis(JOY_AXIS_RIGHT_Y, 0.0)
	check(root.get_mouse_position().distance_to(start) < 2, "right stick does not move inspection cursor")
	point_at(eye.position + eye.size * 0.5)
	await create_timer(0.1).timeout
	button(JOY_BUTTON_A)
	await process_frame
	check(clicks[0] == 1, "controller confirmation activates hovered eye exactly once")
	var click := InputEventMouseButton.new()
	click.position = eye.position + eye.size * 0.5
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	root.push_input(click, true)
	check(clicks[0] == 2, "mouse click activates eye exactly once")
	click = click.duplicate()
	click.pressed = false
	root.push_input(click, true)
	point_at(Vector2(100, 100))
	await create_timer(0.1).timeout
	button(JOY_BUTTON_A)
	check(clicks[0] == 2, "confirmation away from eyes does not activate them")
	view._is_transitioning = true
	point_at(eye.position + eye.size * 0.5)
	await create_timer(0.1).timeout
	button(JOY_BUTTON_A)
	check(clicks[0] == 2, "transition blocks eye confirmation")
	view._is_transitioning = false
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	check(back.is_action_pressed(&"ui_cancel"), "B is bound to ui_cancel")
	button(JOY_BUTTON_B)
	check(view._is_transitioning, "B starts inspection exit instead of confirming eye")
	await create_timer(0.7).timeout
	check(not view.is_inspecting and not view._is_transitioning, "B completes inspection exit")
	check(clicks[0] == 2, "B exits without activating hovered eye")
	# Exercise the full entry/exit with the real player and inspection camera.
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	var anchor := Marker3D.new()
	view.add_child(anchor)
	view.camera_anchor = anchor
	view.blink_close_duration = 0.01
	view.blink_hold_duration = 0.01
	view.blink_open_duration = 0.01
	view.start_inspection(player)
	await create_timer(0.2).timeout
	check(view.is_inspecting and player.is_frozen and player.camera.top_level, "real inspection freezes player and takes camera")
	button(JOY_BUTTON_B)
	await create_timer(0.2).timeout
	check(not view.is_inspecting and not player.is_frozen and not player.camera.top_level, "B restores real player movement and camera")
	player.queue_free()
	# A menu frees the cursor again after returning to captured gameplay.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	axis(JOY_AXIS_LEFT_Y, 1.0)
	await create_timer(0.1).timeout
	axis(JOY_AXIS_LEFT_Y, 0.0)
	check(nav_events.has(&"ui_down"), "left stick returns to menu navigation after inspection")
	view.queue_free()
	await process_frame
	check(not manager._inspection_cursor_active(), "freed inspection releases cursor ownership")
	root.window_input.disconnect(on_input)
	print("inspection_controller_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures > 0 else 0)
