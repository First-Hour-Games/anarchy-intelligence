# Watching Yeti

The existing Corrupted Friend scene now presents the animated Yeti from
Quaternius's Ultimate Monsters pack. The scene path remains unchanged so map
and story references continue to work.

The bear is a passive stalker by default:

- It notices a living player within 20 metres.
- It turns and slowly follows a visible player at 0.85 metres per second.
- It stops 3.25 metres away and watches instead of closing into attack range.
- Walls block its gaze.
- It never enters an attack state or deals damage.
- Its idle, walk, run, punch, hit, and death motion comes from the bundled
  rigged asset instead of procedural whole-model bobbing.

Open `enemy_test.tscn` and press F6 to inspect this behavior. Move around the
bear and behind the wall in the test arena.

## Asset source and rebuild

The runtime model is:

`res://models/enemies/watching_yeti/watching_yeti.glb`

It is normalized to 1.9 metres and contains seven focused lowercase animation
clips. The pinned raw GLB, attribution, checksums, editable Blender source, and
preview are under:

`res://models/source/watching_yeti/`

The source page states CC0. Rebuild the cleaned `.blend`, preview, and GLB with
Blender 5.2:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --python tools/blender/build_watching_yeti.py
```

Set `Visual.use_previous_bear` to restore the prior PSX bear while evaluating
the replacement. `Visual.set_use_3d_model(false)` still enables the sprite
fallback.

## Behavior settings

- `watch_only = true` is the safe default used by the map.
- `watch_distance` controls how far away the player can be noticed.
- `watch_requires_line_of_sight` controls whether walls interrupt tracking.
- `watch_turn_speed` controls the body rotation speed.
- `watch_follow_speed` controls its passive stalking pace.
- `watch_stop_distance` controls how far away it stops to stare.
- `activation_enabled = false` temporarily disables watching; `activate()`
  enables it again.

The old navigation/combat controller remains available for future enemy
variants only by explicitly setting `watch_only = false`. The previous sprite
atlas also remains available through `Visual.set_use_3d_model(false)`.

Run validation with:

```powershell
godot --headless --path . --script res://tests/corrupted_friend_smoke.gd
godot --headless --path . --script res://tests/friend_map_chase.gd
```
