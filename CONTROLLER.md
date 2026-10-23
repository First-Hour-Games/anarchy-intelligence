# Controller support

The game supports keyboard/mouse and Xbox-style gamepads (Xbox, or any controller
Godot maps to the standard layout) at the same time. Whichever device you touched last
is "active", and on-screen prompts switch to match it immediately.

## Default layout

| Action | Keyboard / mouse | Gamepad |
|---|---|---|
| Move | W A S D | Left stick (analog) |
| Look | Mouse | Right stick |
| Sprint | Hold Shift | Hold L3 (press the left stick in) |
| Interact | E | X |
| Flashlight | F | RB |
| Inventory | I / Tab | B (D-pad ← → picks slots) |
| Map | M | Y |
| Journal | J | View |
| Pause | Esc | Menu (Start) |
| Confirm / continue dialogue | Enter / Space / E | A |
| Back / close menus | Esc / Tab | B |
| Jump (when enabled) | Space | A |
| Crouch (when enabled) | Hold Ctrl | R3 (toggle) |

In menus the D-pad navigates (the left stick works too, at a slower repeat rate). When a mouse cursor is on screen (inspection
view, item screens), the right stick moves the cursor and RT clicks.

## Where things live

- `scenes/input/input_manager.gd` (autoload **InputManager**, class **InputDevice**):
  device detection, prompt swapping, menu stick navigation, virtual cursor, rumble.
- **Project Settings → Input Map**: all bindings (`move_*`, `look_*`, `jump`, `sprint`,
  `crouch`, `pause`, plus gamepad buttons on the existing actions). Remap there.
- **Player → Inspector → Gamepad**: look speed, vertical scale, deadzone, response curve,
  invert Y, and whether sprint/crouch toggle on a gamepad.
- `img/controller/`: controller prompt art (stick/button icons in the game's prompt style).

## Using it in new scripts

```gdscript
# Swap a prompt automatically (text, texture, any property):
InputDevice.bind($Hint, &"text", "[ E ] OPEN", "[ X ] OPEN")

# Or react yourself:
InputDevice.on_changed(func(is_gamepad: bool) -> void: ...)
if InputDevice.using_gamepad(): ...

# Controller vibration (no-op on keyboard/mouse):
InputDevice.rumble_pad(0.3, 0.6, 0.2)
```

Read input through actions (`Input.is_action_pressed(&"sprint")`), not raw keys
(`Input.is_key_pressed(KEY_SHIFT)`), so both devices work.

## Test

```
godot --headless --path . -s tests/controller_input_smoke.gd
```
