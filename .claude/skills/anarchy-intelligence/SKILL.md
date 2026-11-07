---
name: anarchy-intelligence
description: Develop, debug, review, and plan the Anarchy Intelligence Godot 4.7 horror game — gameplay, scenes, GDScript, UI, dialogue, audio, shaders, physics, imports, and project configuration. Use for any implementation or investigation work in this repository.
---

# Anarchy Intelligence

Work from the repository root containing `project.godot`. Tool paths and the
test command live in `CLAUDE.md`.

## Project baseline

- Target Godot 4.7 and typed GDScript unless the user explicitly chooses otherwise.
- Desktop builds render with Forward+ on the Direct3D 12 driver; only the
  mobile override uses GL Compatibility (`project.godot` still lists a stale
  "GL Compatibility" feature tag). Volumetric fog and `FogVolume` depend on
  Forward+. Preserve these renderer settings and Jolt Physics unless the task
  specifically changes them.
- The startup scene is `scenes/mainMenu/startup.tscn`, which leads to the main
  menu `scenes/mainMenu/menu.tscn`. Chapter content lives under
  `scenes/chapters/` (`intro`, `tutorial`, `main`, `playground`).
- Autoloads: `GraphicsSettings`, `DialogueManager`, `PauseMenu`,
  `ItemPickupScreen`, `DebugMenu`, `SceneLoader`. Check `project.godot` before
  adding another.
- Dialogue Manager is a third-party add-on. Keep project integration and
  `.dialogue` resources outside `addons/dialogue_manager/` unless the requested
  fix is inside the add-on itself.
- Treat `scenes/`, `shaders/`, `tests/`, `tools/`, `sounds/`, `music/`, `img/`,
  and `models/` as first-party content. Do not edit `.godot/`, imported binary
  assets, or generated `.import` metadata unless an import problem is the task.

## Implementation conventions

- Preserve typed exports and member variables, return annotations, `snake_case`
  functions and variables, and `PascalCase` `class_name` declarations.
- Use `res://` resource paths. Preserve Godot UIDs and existing
  `ext_resource`/`sub_resource` relationships.
- When changing a `.tscn`, keep its scripts, node paths, signals, exported
  properties, and referenced resources synchronized; validate them together.
- Use Input Map actions for new remappable controls instead of hard-coded keys.
- Expose designer-tunable gameplay values as typed `@export` properties; keep
  implementation details private.
- Keep serialized scene diffs focused; avoid unrelated reformatting or resource churn.
- Prefer small, reversible changes that preserve player-facing behavior unless
  the request explicitly changes it.

## Workflow

1. Check `git status` before editing and preserve unrelated user changes.
2. Identify the affected scene, script, resources, and existing smoke tests
   (`tests/*_smoke.gd`, named after the feature) before implementing.
3. Add or update a focused smoke test when behavior can be checked headlessly.
   Follow the existing pattern: `extends SceneTree`, a `check(value, label)`
   helper printing `PASS`/`FAIL`, and `quit(1 if failures else 0)` so the
   exit code reflects the result.
4. Run the affected tests with `tools/run_smoke_tests.ps1 -Filter <name>`, then
   the full suite before handoff when the change touches shared systems
   (player, autoloads, UI, scene loading).
5. For lighting, fog, shader, material, or framing changes, use the
   `visual-check` skill. Headless runs do not render.
6. Before handoff, review the diff and report remaining uncommitted changes
   separately from the task's changes.

## Validation reporting

- If Godot is unavailable, say runtime validation was not possible and list the
  static checks completed.
- Distinguish newly introduced warnings or errors from pre-existing ones. Leaked
  RID/ObjectDB warnings at exit are pre-existing noise in the test harness.
