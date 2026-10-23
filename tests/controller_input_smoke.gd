extends SceneTree

## Run: godot --headless --path . -s tests/controller_input_smoke.gd
## Checks gamepad bindings, keyboard/gamepad auto-detection, prompt swapping and stick movement.

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func _has_joy_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false


func _has_key_event(action: StringName) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return true
	return false


func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func _joy_button(index: JoyButton, pressed: bool = true) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index
	e.pressed = pressed
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	return e


func _key(code: Key, pressed: bool = true) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = pressed
	return e


func run() -> void:
	var manager := root.get_node_or_null(^"InputManager")
	check(manager != null, "InputManager autoload is registered")
	if manager == null:
		quit(1)
		return

	# --- Input map
	for action: StringName in [&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"crouch", &"pause"]:
		check(_has_key_event(action) and _has_joy_event(action), "%s has keyboard + gamepad bindings" % action)
	for action: StringName in [&"look_up", &"look_down", &"look_left", &"look_right", &"gamepad_cursor_click"]:
		check(_has_joy_event(action), "%s has gamepad binding" % action)
	for action: StringName in [&"interact", &"flashlight_toggle", &"map_toggle", &"inventory_toggle", &"story_journal"]:
		check(_has_key_event(action) and _has_joy_event(action), "%s keeps its key and gains a gamepad button" % action)
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var has_stick := false
		var has_dpad := false
		for event in InputMap.action_get_events(action):
			has_stick = has_stick or event is InputEventJoypadMotion
			has_dpad = has_dpad or event is InputEventJoypadButton
		check(not has_stick and has_dpad, "%s uses D-pad directly; stick nav is repeat-limited" % action)

	# --- Requested layout: X interact, Y map, B inventory, L3 sprint, D-pad menus
	var expect := {&"interact": JOY_BUTTON_X, &"map_toggle": JOY_BUTTON_Y, &"inventory_toggle": JOY_BUTTON_B, &"sprint": JOY_BUTTON_LEFT_STICK, &"pause": JOY_BUTTON_START}
	for action: StringName in expect:
		var found := false
		for event in InputMap.action_get_events(action):
			found = found or (event is InputEventJoypadButton and event.button_index == expect[action])
		check(found, "%s is on gamepad button %d" % [action, expect[action]])

	# --- Device auto-detection
	var switches: Array[bool] = []
	manager.device_changed.connect(func(is_pad: bool) -> void: switches.append(is_pad))
	check(not manager.is_gamepad(), "starts on keyboard/mouse")

	var label := Label.new()
	root.add_child(label)
	manager.bind_property(label, &"text", "[ E ]", "[ X ]")
	check(label.text == "[ E ]", "bound prompt shows keyboard text initially")

	_send(_joy_axis(JOY_AXIS_LEFT_X, 0.1))
	await process_frame
	check(not manager.is_gamepad(), "tiny stick drift does not switch to gamepad")

	_send(_joy_button(JOY_BUTTON_A))
	_send(_joy_button(JOY_BUTTON_A, false))
	await process_frame
	check(manager.is_gamepad(), "pressing A switches to gamepad")
	check(label.text == "[ X ]", "bound prompt swapped to gamepad text")
	check(manager.glyph(&"interact") == "X" and manager.glyph(&"pause") == "MENU", "gamepad glyphs")

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(1, 0)
	_send(motion)
	await process_frame
	check(manager.is_gamepad(), "1px mouse jitter does not switch back")

	_send(_key(KEY_W))
	_send(_key(KEY_W, false))
	await process_frame
	check(not manager.is_gamepad(), "pressing a key switches back to keyboard")
	check(label.text == "[ E ]", "bound prompt swapped back to keyboard text")
	check(manager.glyph(&"interact") == "E", "keyboard glyphs")
	check(switches == [true, false], "device_changed fired once per switch")

	label.queue_free()
	await process_frame
	_send(_joy_button(JOY_BUTTON_B))
	_send(_joy_button(JOY_BUTTON_B, false))
	await process_frame
	check(manager.is_gamepad(), "freed bound node doesn't break switching")

	# --- Left stick navigates menus with a delay + repeat (only while the cursor is free)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var nav_events: Array[StringName] = []
	var on_nav := func(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed:
			nav_events.append(event.action)
	root.window_input.connect(on_nav)
	_send(_joy_axis(JOY_AXIS_LEFT_Y, 1.0))
	await create_timer(0.2).timeout
	check(nav_events == [&"ui_down"], "holding stick down gives one ui_down at first (%s)" % [nav_events])
	await create_timer(1.0).timeout
	check(nav_events.size() >= 3 and nav_events.size() <= 6 and nav_events.all(func(a): return a == &"ui_down"), "then repeats at a readable rate (%d events in 1.2s)" % nav_events.size())
	_send(_joy_axis(JOY_AXIS_LEFT_Y, 0.0))
	await process_frame
	var count_after_release := nav_events.size()
	await create_timer(0.3).timeout
	check(nav_events.size() == count_after_release, "releasing the stick stops navigation")
	check(manager.is_gamepad(), "synthetic nav events don't flip the device")
	root.window_input.disconnect(on_nav)

	# --- Stick movement reaches the player's movement vector
	_send(_joy_axis(JOY_AXIS_LEFT_Y, -1.0))
	await process_frame
	var move := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	check(move.y < -0.9, "left stick up = walk forward (%s)" % move)
	_send(_joy_axis(JOY_AXIS_LEFT_Y, 0.0))
	_send(_joy_axis(JOY_AXIS_RIGHT_X, 1.0))
	await process_frame
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	check(look.x > 0.9, "right stick right = look right (%s)" % look)
	_send(_joy_axis(JOY_AXIS_RIGHT_X, 0.0))

	# --- Player scene loads with the new controller code and turns with the right stick
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	check(player_scene != null, "player scene loads")
	if player_scene != null:
		var floor_body := StaticBody3D.new()
		var floor_shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(40, 1, 40)
		floor_shape.shape = box
		floor_body.add_child(floor_shape)
		floor_body.position.y = -0.5
		root.add_child(floor_body)
		var player := player_scene.instantiate()
		root.add_child(player)
		await physics_frame
		await physics_frame
		# Headless can't capture the mouse (player._process only turns while captured),
		# so exercise the same look path the stick uses directly.
		var yaw_before: float = player.rotation.y
		var pitch_before: float = player.head.rotation.x
		player._apply_look_rotation(Vector2(0.2, 0.1), Vector2.ZERO)
		check(player.rotation.y < yaw_before - 0.19, "stick look turns the body right (yaw %.3f -> %.3f)" % [yaw_before, player.rotation.y])
		check(player.head.rotation.x < pitch_before - 0.09, "stick look pitches the head down")
		player._apply_look_rotation(Vector2(0.0, -10.0), Vector2.ZERO)
		check(player.head.rotation.x <= deg_to_rad(player.vertical_look_limit_degrees) + 0.001, "pitch stays clamped")
		player.rotation.y = 0.0
		player.head.rotation.x = 0.0

		_send(_joy_axis(JOY_AXIS_LEFT_Y, -1.0))
		for i in 20:
			await physics_frame
		var speed := Vector2(player.velocity.x, player.velocity.z).length()
		check(speed > 1.0, "left stick walks the player (speed %.2f)" % speed)

		# Holding L3 sprints (like holding Shift); letting go stops
		_send(_joy_button(JOY_BUTTON_LEFT_STICK))
		for i in 10:
			await physics_frame
		check(player.is_sprinting, "holding L3 sprints")
		_send(_joy_button(JOY_BUTTON_LEFT_STICK, false))
		for i in 5:
			await physics_frame
		check(not player.is_sprinting, "releasing L3 stops sprinting")
		_send(_joy_axis(JOY_AXIS_LEFT_Y, 0.0))
		player.queue_free()
		floor_body.queue_free()

	await process_frame
	print("controller_input_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures > 0 else 0)
