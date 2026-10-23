class_name InputDevice extends Node

## Autoload: InputManager (this script). Other scripts use the static helpers below —
## `InputDevice.using_gamepad()`, `InputDevice.bind(...)`, `InputDevice.on_changed(...)`,
## `InputDevice.rumble_pad(...)` — which are null-safe, so scenes still work in tests or
## tools where the autoload isn't running.
##
## - Auto-detects whether the player is using keyboard/mouse or an Xbox-style gamepad,
##   based on whichever device produced the most recent real input, and emits
##   `device_changed` when that switches.
## - Swaps on-screen prompts (label text, prompt textures) via `bind_property()`.
## - Gamepad menu support: left stick navigates menus with proper repeat (instead of
##   firing ui_up/ui_down on every tiny stick movement), and while the mouse cursor is
##   visible the right stick drives it and RT clicks, so mouse-only UI (inspection
##   hotspots, click-to-continue screens) works on a controller.
## - `rumble()` helper that only vibrates when the player is actually on a gamepad.
##
## Bindings live in Project Settings > Input Map (move_*, look_*, jump, sprint, crouch,
## pause, interact, ...), so they can be remapped in the editor like any other action.

signal device_changed(is_gamepad: bool)

enum Device { KEYBOARD_MOUSE, GAMEPAD }

## Events this script generates are tagged with this device id so they never count as
## "real" input for device detection.
const SYNTHETIC_DEVICE_ID := 7331

## Prompt glyphs per action. Keep these short; they are shown inside [ ] brackets.
const KEYBOARD_GLYPHS := {
	&"interact": "E",
	&"jump": "SPACE",
	&"sprint": "SHIFT",
	&"crouch": "CTRL",
	&"pause": "ESC",
	&"ui_accept": "ENTER",
	&"ui_cancel": "ESC",
	&"map_toggle": "M",
	&"inventory_toggle": "TAB",
	&"flashlight_toggle": "F",
	&"story_journal": "J",
}
const GAMEPAD_GLYPHS := {
	&"interact": "X",
	&"jump": "A",
	&"sprint": "L3",
	&"crouch": "R3",
	&"pause": "MENU",
	&"ui_accept": "A",
	&"ui_cancel": "B",
	&"map_toggle": "Y",
	&"inventory_toggle": "B",
	&"flashlight_toggle": "RB",
	&"story_journal": "VIEW",
}

const NAV_ACTIONS := [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]
const NAV_DPAD_BUTTONS := {
	&"ui_up": JOY_BUTTON_DPAD_UP,
	&"ui_down": JOY_BUTTON_DPAD_DOWN,
	&"ui_left": JOY_BUTTON_DPAD_LEFT,
	&"ui_right": JOY_BUTTON_DPAD_RIGHT,
}

## How far a stick/trigger must move before it counts as "the player switched to gamepad".
var gamepad_switch_threshold: float = 0.45
## Mouse movement (pixels) needed to switch back to keyboard/mouse; filters desk bumps.
var mouse_switch_threshold: float = 4.0

## Left-stick menu navigation.
var nav_press_threshold: float = 0.7
var nav_release_threshold: float = 0.4
## Seconds before a held stick starts repeating, then seconds between repeats.
var nav_initial_delay: float = 0.5
var nav_repeat_interval: float = 0.22

## Right-stick virtual cursor (only while the mouse cursor is visible).
var cursor_enabled: bool = true
var cursor_deadzone: float = 0.2
## Fraction of the screen height travelled per second at full stick deflection.
var cursor_speed: float = 1.1

var rumble_enabled: bool = true

var device: Device = Device.KEYBOARD_MOUSE
var active_joypad: int = 0

var _bindings: Array[Dictionary] = []
var _ignore_mouse_motion_until_msec: int = 0
var _nav_direction: StringName = &""
var _nav_timer: float = 0.0
var _cursor_click_held: bool = false


# ---------------------------------------------------------------- static helpers

## The running InputManager autoload, or null (e.g. in a tool script or bare test).
static func manager() -> InputDevice:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"InputManager") as InputDevice


## True when the most recent input came from a gamepad.
static func using_gamepad() -> bool:
	var m := manager()
	return m != null and m.is_gamepad()


## Null-safe `bind_property()`; without the autoload the keyboard value is applied.
static func bind(target: Object, property: StringName, keyboard_value: Variant, gamepad_value: Variant) -> void:
	var m := manager()
	if m != null:
		m.bind_property(target, property, keyboard_value, gamepad_value)
	elif target != null:
		target.set(property, keyboard_value)


## Calls `callback(is_gamepad: bool)` whenever the device switches.
static func on_changed(callback: Callable) -> void:
	var m := manager()
	if m != null and not m.device_changed.is_connected(callback):
		m.device_changed.connect(callback)


static func rumble_pad(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	var m := manager()
	if m != null:
		m.rumble(weak_magnitude, strong_magnitude, duration)


# ---------------------------------------------------------------- instance API

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_remove_left_stick_from_ui_navigation()
	_ensure_dpad_ui_navigation()
	# window_input fires for every event before any node sees it, so detection works
	# even when a script marks the event as handled.
	get_tree().root.window_input.connect(_on_window_input)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	var pads := Input.get_connected_joypads()
	if not pads.is_empty():
		active_joypad = pads[0]


func is_gamepad() -> bool:
	return device == Device.GAMEPAD


## Short prompt label for an action on the current device, e.g. "E" / "X".
func glyph(action: StringName) -> String:
	var table: Dictionary = GAMEPAD_GLYPHS if is_gamepad() else KEYBOARD_GLYPHS
	return String(table.get(action, String(action).to_upper()))


## Keeps `target.property` set to `keyboard_value` or `gamepad_value` depending on the
## active device. Safe to call from _ready(); the binding is dropped once target is freed.
func bind_property(target: Object, property: StringName, keyboard_value: Variant, gamepad_value: Variant) -> void:
	if target == null:
		return
	for binding in _bindings:
		var existing: Object = (binding.target as WeakRef).get_ref()
		if existing == target and binding.property == property:
			binding.keyboard = keyboard_value
			binding.gamepad = gamepad_value
			_apply_binding(binding)
			return
	var entry := {
		"target": weakref(target),
		"property": property,
		"keyboard": keyboard_value,
		"gamepad": gamepad_value,
	}
	_bindings.append(entry)
	_apply_binding(entry)


## Vibrates the active controller. No-op on keyboard/mouse or when rumble is disabled.
func rumble(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if not rumble_enabled or not is_gamepad():
		return
	Input.start_joy_vibration(active_joypad, clampf(weak_magnitude, 0.0, 1.0), clampf(strong_magnitude, 0.0, 1.0), duration)


func _process(delta: float) -> void:
	if not is_gamepad():
		_nav_direction = &""
		return
	_update_stick_navigation(delta)
	_update_virtual_cursor(delta)


# ---------------------------------------------------------------- device detection

func _on_window_input(event: InputEvent) -> void:
	if event.device == SYNTHETIC_DEVICE_ID:
		return
	if event is InputEventJoypadButton:
		if event.pressed:
			active_joypad = event.device
			_set_device(Device.GAMEPAD)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) >= gamepad_switch_threshold:
			active_joypad = event.device
			_set_device(Device.GAMEPAD)
	elif event is InputEventKey:
		if event.pressed:
			_set_device(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseButton:
		if event.pressed:
			_set_device(Device.KEYBOARD_MOUSE)
	elif event is InputEventMouseMotion:
		if Time.get_ticks_msec() >= _ignore_mouse_motion_until_msec and event.relative.length() >= mouse_switch_threshold:
			_set_device(Device.KEYBOARD_MOUSE)


func _on_joy_connection_changed(joypad: int, connected: bool) -> void:
	if connected:
		active_joypad = joypad
		return
	if joypad == active_joypad:
		var pads := Input.get_connected_joypads()
		if pads.is_empty():
			_set_device(Device.KEYBOARD_MOUSE)
		else:
			active_joypad = pads[0]


func _set_device(new_device: Device) -> void:
	if device == new_device:
		return
	device = new_device
	_nav_direction = &""
	_release_cursor_click()
	for binding in _bindings.duplicate():
		_apply_binding(binding)
	device_changed.emit(is_gamepad())


func _apply_binding(binding: Dictionary) -> void:
	var target: Object = (binding.target as WeakRef).get_ref()
	if target == null:
		_bindings.erase(binding)
		return
	target.set(binding.property, binding.gamepad if is_gamepad() else binding.keyboard)


# ---------------------------------------------------------------- menu navigation

## Godot's default ui_* actions include the left stick, which fires a "pressed" event for
## every small stick movement and makes the custom menus scroll uncontrollably. The stick
## is removed here and re-implemented below with a proper initial delay + repeat.
## D-pad navigation is untouched.
func _remove_left_stick_from_ui_navigation() -> void:
	for action: StringName in NAV_ACTIONS:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)


## The D-pad is the main way to move through menus; make sure it is always bound.
func _ensure_dpad_ui_navigation() -> void:
	for action: StringName in NAV_DPAD_BUTTONS:
		if not InputMap.has_action(action):
			continue
		var has_dpad := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and event.button_index == NAV_DPAD_BUTTONS[action]:
				has_dpad = true
		if not has_dpad:
			var dpad := InputEventJoypadButton.new()
			dpad.device = -1
			dpad.button_index = NAV_DPAD_BUTTONS[action]
			InputMap.action_add_event(action, dpad)


func _update_stick_navigation(delta: float) -> void:
	# Only navigate when some UI owns the cursor (menus, inventory, dialogue choices),
	# never while the player is walking around with the stick.
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_nav_direction = &""
		return

	var stick := Vector2(
		Input.get_joy_axis(active_joypad, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(active_joypad, JOY_AXIS_LEFT_Y)
	)
	var direction: StringName = &""
	var threshold := nav_release_threshold if _nav_direction != &"" else nav_press_threshold
	if stick.length() >= threshold:
		if absf(stick.x) > absf(stick.y):
			direction = &"ui_right" if stick.x > 0.0 else &"ui_left"
		else:
			direction = &"ui_down" if stick.y > 0.0 else &"ui_up"

	if direction == &"":
		_nav_direction = &""
		return
	if direction != _nav_direction:
		_nav_direction = direction
		_nav_timer = nav_initial_delay
		_emit_action_tap(direction)
		return
	_nav_timer -= delta
	if _nav_timer <= 0.0:
		_nav_timer = nav_repeat_interval
		_emit_action_tap(direction)


func _emit_action_tap(action: StringName) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	press.strength = 1.0
	press.device = SYNTHETIC_DEVICE_ID
	Input.parse_input_event(press)
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	release.device = SYNTHETIC_DEVICE_ID
	Input.parse_input_event(release)


# ---------------------------------------------------------------- virtual cursor

func _update_virtual_cursor(delta: float) -> void:
	if not cursor_enabled or Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		_release_cursor_click()
		return
	var viewport := get_viewport()
	if viewport == null:
		return

	var stick := Vector2(
		Input.get_joy_axis(active_joypad, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(active_joypad, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > cursor_deadzone:
		var strength := inverse_lerp(cursor_deadzone, 1.0, minf(stick.length(), 1.0))
		var velocity := stick.normalized() * strength * strength * cursor_speed * viewport.get_visible_rect().size.y
		var rect := viewport.get_visible_rect()
		var target := (viewport.get_mouse_position() + velocity * delta).clamp(rect.position, rect.end - Vector2.ONE)
		# Warping produces mouse-motion events; don't let them flip us back to keyboard/mouse.
		_ignore_mouse_motion_until_msec = Time.get_ticks_msec() + 200
		viewport.warp_mouse(target)

	var trigger_down := Input.is_action_pressed(&"gamepad_cursor_click")
	if trigger_down and not _cursor_click_held:
		_cursor_click_held = true
		_emit_mouse_button(true)
	elif not trigger_down and _cursor_click_held:
		_release_cursor_click()


func _release_cursor_click() -> void:
	if _cursor_click_held:
		_cursor_click_held = false
		_emit_mouse_button(false)


func _emit_mouse_button(pressed: bool) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var click := InputEventMouseButton.new()
	click.device = SYNTHETIC_DEVICE_ID
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	# parse_input_event() expects window coordinates; convert from the (possibly stretched) viewport.
	click.position = viewport.get_final_transform() * viewport.get_mouse_position()
	click.global_position = click.position
	Input.parse_input_event(click)
