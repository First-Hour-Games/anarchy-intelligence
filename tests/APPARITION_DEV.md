# Testing shadow sightings

Run the starting forest from the editor, finish the opening dialogue, and resume gameplay. These shortcuts require a debug build and `ForestApparitions.developer_trigger_enabled`.

| Shortcut | Action |
| --- | --- |
| Alt + 0 | Show/hide instructions, state, distance, timers, and last trigger result |
| Alt + 1 | Replace the current sighting with Hat man |
| Alt + 2 | Replace the current sighting with the dog |
| Alt + 3 | Toggle a held pose; automatic clocks stop while held |
| Alt + minus | Clear the current sighting |
| Alt + plus/equals (or numpad plus) | Alternate Hat man and dog without replacing an active sighting |

For a visual check, press Alt + 0 and Alt + 3, then Alt + 1 or Alt + 2. Hat man settles into his half-body peek and stays there; the dog settles into its crossing pose. Move or turn to inspect the figure. Press Alt + 3 again to restore normal behavior. Pause, inventory, maps, and dialogue still suppress sightings. Direct triggers preserve the alternating shortcut's sequence. Release exports ignore these controls and hold mode.

Hat man can peek from behind solid scenery: trees, full-height signs, boards, walls, building corners, props, and instanced meshes. He shows at most half his body, roughly in the outer third of the view, with actual ground and a visible head. Solid geometry must hide the concealed side from his feet through his 2.4-meter hat height. Low brick pillar surrounds, floating torso-height signs, and tall bounding boxes with inadequate geometry cannot supply cover. The sighting clears if movement or disappearing scenery exposes that concealed line. His usual minimum distance is 3 meters; full-height signs and boards can permit a 2-meter sighting. Close sightings receive a lower selection priority when another suitable location exists. A scene without suitable cover keeps one sighting pending.

Both figures use an unlit, fog-disabled, pure-black void material. Visibility comes from their outline, position, and timing. Face an open, level road for the dog. Manual triggers use the same placement checks as automatic sightings. Holding a preview does not attach it to the camera.

Tune `ForestApparitions` in the inspector: `peek_exposure` can reduce the half-body peek but cannot increase it past halfway; `screen_border_margin`/`screen_edge_width` control peripheral framing; and `dog_pass_seconds`/`dog_top_screen_y` control the dog's readability. Hat man's defaults are a 0.12-second gaze threshold, a 0.14-second retreat, and a 1.8-second maximum peek. `minimum_distance` and `small_cover_minimum_distance` can increase the spawn clearance, with hard minimums of 3 and 2 meters respectively. Hat man retreats as the player crosses the chosen cover's minimum distance and disappears immediately within 2 meters. `approach_distance` can request an earlier retreat. Developer hold permits close inspection. `cover_paths` can restrict testing to particular scenery nodes; the older `tree_paths` still isolates trees. Set `automatic_sightings_enabled` off to isolate manual trials. Test again with hold off, including sprinting and looking down.

Run the focused regression from the project root:

```powershell
& '<path-to-Godot-console.exe>' --headless --path . --script res://tests/forest_apparitions_smoke.gd
& '<path-to-Godot-console.exe>' --headless --path . --script res://tests/apparition_cover_smoke.gd
```

The tests cover framing, tree concealment, low brickwork rejection, full-height cover geometry, signs without collision, rotated/moved/hidden scenery, distance limits, delayed gaze retreat, sprint visibility, automatic timers, gameplay suppression, and developer controls. For rendered wall/sign/model previews, run the cover test without `--headless` and add `-- --preview`; `hatman-half-wall.png`, `hatman-half-sign.png`, and `hatman-reference-model.png` are saved beside the project directory. Check visibility in the running game as well; the headless renderer does not verify how the shader looks.
