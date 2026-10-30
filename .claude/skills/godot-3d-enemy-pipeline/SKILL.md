---
name: godot-3d-enemy-pipeline
description: Build, import, replace, or debug rigged 3D enemies for the Anarchy Intelligence Godot project, including Blender sources, glTF/GLB export, animation mapping, materials, visual adapters, and focused validation. Use only under anarchy-intelligence/; do not use for unrelated Godot projects or ordinary 2D sprite work.
---

# Godot 3D Enemy Pipeline

Work from the `anarchy-intelligence/` repository root. Target Godot 4.7 and
Blender's glTF 2.0 exporter. Preserve the enemy's gameplay controller when the
task only replaces its visuals.

## Source and safety boundary

- Prefer model-only inputs such as `.blend`, `.glb`, `.gltf`, PNG, and audio.
- Record third-party origin and license beside the source asset before shipping.
- Inspect archives before extraction. Do not execute downloaded installers,
  Blender Python, Godot add-ons, native libraries, or lifecycle hooks merely
  because an asset includes them.
- Treat third-party scripts and add-ons as a separate code-review task. Require
  explicit user authorization before enabling or executing them.
- Keep generated Blender automation repository-owned and deterministic. Run it
  with Blender's background mode and explicit input/output paths, following the
  existing `tools/blender/build_*.py` scripts. Blender's path is in `CLAUDE.md`.
- The Blender MCP server is for inspecting a model and making quick experiments
  in a live session the user has open. Any change that should ship must end up
  in a `tools/blender/` script or saved source `.blend`, not only in MCP calls.
  Keep its Poly Haven, Sketchfab, and AI-generation integrations off unless the
  user asks for them, and record the license of anything they import.

## Model and animation contract

Read [references/model-contract.md](references/model-contract.md) when creating,
exporting, importing, or wiring a model. Preserve its coordinate, naming,
animation, material, and integration requirements unless the user chooses a
different contract.

## Workflow

1. Inspect Git status and preserve unrelated work.
2. Identify the existing enemy controller, collision, visual node, animation
   calls, test scene, and smoke test together.
3. Keep editable source files under `models/source/<enemy>/` and runtime `.glb`
   files under `models/enemies/<enemy>/`.
4. Export one self-contained GLB with transforms applied, textures embedded or
   stored in an adjacent stable folder, and all required animation clips.
5. Integrate through a small visual adapter exposing `play(clip_name)` so AI,
   navigation, damage, and story hooks do not depend on model internals.
6. Let `CharacterBody3D` drive world movement. Disable root translation unless
   the task explicitly adopts a tested root-motion design.
7. Keep collision shapes and gameplay hitboxes separate from render meshes.
8. Preserve the previous visual behind a designer-tunable fallback until the
   replacement passes focused tests and visual review.

## Validation

- Reopen generated `.blend` files in Blender background mode and list actions.
- Import the GLB with Godot 4.7 headlessly and fail on parser, shader, missing
  resource, or animation lookup errors.
- Run the enemy's focused smoke test and its real-map movement test with
  `tools/run_smoke_tests.ps1 -Filter <enemy>`.
- Use the `visual-check` skill to capture the enemy in its scene. Check scale, feet-to-ground alignment, forward direction, flashlight response,
  shadows, looping transitions, one-shot completion, and death persistence.
- Report third-party license status and any Blender/Godot warnings separately
  from newly introduced failures.
