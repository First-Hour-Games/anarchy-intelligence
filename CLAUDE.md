# Anarchy Intelligence

First-person 3D horror game built with Godot 4.7.2 and typed GDScript. Desktop
renders with Forward+ on Direct3D 12; physics uses Jolt. The `anarchy-intelligence`
skill holds the conventions; `godot-3d-enemy-pipeline` covers rigged enemies;
`visual-check` covers screenshots.

## Tools on this machine

- Godot console: `%LOCALAPPDATA%\Programs\Godot\4.7.2\Godot_v4.7.2-stable_win64_console.exe`
  (`/c/Users/<user>/AppData/Local/Programs/Godot/4.7.2/...` from Git Bash). It is
  not on PATH. Scripts honor a `GODOT_CONSOLE` environment variable override.
- Blender 5.2: `C:\Program Files\Blender Foundation\Blender 5.2\blender.exe`.
  Model build scripts live in `tools/blender/build_*.py` and resolve their own
  output paths. Run them with `blender.exe --background --python <script>`.
- MCP servers (local to this machine, not committed): `godot` (launch the
  editor, run the project, read debug output) and `blender` (inspect and edit a
  live Blender session after the user starts the add-on's server from the N panel).

## Tests

```powershell
powershell -ExecutionPolicy Bypass -File tools/run_smoke_tests.ps1                    # full suite
powershell -ExecutionPolicy Bypass -File tools/run_smoke_tests.ps1 -Filter fog,menu   # name substrings
```

Each `tests/*.gd` script is a headless `SceneTree` test that prints `PASS`/`FAIL`
lines. The runner fails a test on a non-zero exit, any `FAIL ` line, a script
error, or a timeout. Leaked RID/ObjectDB messages at exit are normal noise.

If tests suddenly report `referenced non-existent resource` for files that exist,
the import cache is stale (common after a pull that moves assets). Rebuild it:
`<godot console> --headless --path . --import`. Run the same command after adding
a new `class_name` script or a new model: `--script` runs do not register new
global classes, so dependent scripts fail with "Identifier not declared".

Known pre-existing failures (25 tests, measured Oct 22, 2026, before the hiding and
bottle feature): barrier_tree_dialogue_smoke, civic_block_smoke,
forest_apparitions_smoke, forest_intro_fade_smoke, friend_map_chase,
gameplay_refinement_smoke, inspection_brochure_pickup_smoke,
inspection_eye_button_smoke, map_post_decal_smoke, menu_entry_alignment_smoke
(Continue check only), moving_gradient_noise_fog_smoke, opening_story_smoke (two
Clawman alert checks: the test freezes the player, which zeroes the velocity it
fakes), pause_and_roaming_smoke, player_flashlight_smoke, player_inventory_smoke,
starting_forest_fog_log_smoke, test_balloon_responses, test_climb_teleport_ground,
test_gas_station_platform_smoke, test_multimesh_exclusion,
test_procedural_tree_generator_smoke, test_tree_variation, town_map_waypoint_smoke,
tutorial_door_smoke, tutorial_flicker_smoke. Compare individual FAIL lines, not only
test names: a failing test can gain a new failing check.

## Screenshots

Headless runs do not render. To see a scene, run `tools/capture_scene.gd` without
`--headless`; it writes PNGs to `../captures/`. See the `visual-check` skill.

## Notes

- The project lives in a OneDrive-synced folder. If files show as missing or
  Godot stalls on first access, OneDrive may still be downloading cloud-only files.
- `scratch/` is tracked; put throwaway output in `../scratch/` or `../captures/`
  instead.
