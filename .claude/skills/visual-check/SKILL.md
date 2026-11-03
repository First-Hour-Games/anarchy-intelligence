---
name: visual-check
description: Render Anarchy Intelligence scenes to PNG and inspect them — use after changing lighting, fog, shaders, materials, post-processing, model placement, UI layout, or anything whose correctness is visual, and for before/after comparisons. Headless smoke tests cannot verify how things look.
---

# Visual check

`tools/capture_scene.gd` instantiates a scene in a real rendering window, waits
for it to settle, and saves a PNG beside the repository in `../captures/`
(outside git). Read the PNG with the Read tool to look at it.

## Capture

Run from the repository root **without** `--headless` (a window opens briefly):

```bash
"$GODOT_CONSOLE" --path . --script res://tools/capture_scene.gd -- \
  --scene res://scenes/chapters/main/starting_forest.tscn --tag after --hide-ui
```

`$GODOT_CONSOLE` is the console executable listed in `CLAUDE.md`. Useful options:

| Option | Use |
| --- | --- |
| `--tag before` / `--tag after` | Name paired captures for comparison |
| `--pos x,y,z --look x,y,z` | Spawn a camera at a chosen viewpoint |
| `--camera Path/To/Camera3D` | Use a camera already in the scene |
| `--frames 180` | Wait longer for fades, dialogue openers, or fog to settle |
| `--quality 0`/`1`/`2` | Force the Low/Medium/High graphics preset |
| `--hide-ui` | Hide every CanvasLayer (HUD, dialogue, menus) |
| `--inspect` | Fog off and bright ambient light to review layout in dark scenes like `map.tscn` (not the in-game look) |
| `--flashlight` | Attach a spotlight to the camera, approximating the player's flashlight |
| `--size 1920x1080` | Change resolution |

Without `--camera` or `--pos`, the scene's own current camera (usually the
player's) is used. The script prints the active camera's position and facing;
reuse those numbers to reproduce a viewpoint exactly.

## Workflow

1. Before editing, capture the affected view with `--tag before`. Pick a
   viewpoint that shows the change, using positions from the scene file or the
   printed camera line.
2. Make the change, then capture the same view with `--tag after`.
3. Read both images and compare them. Describe what changed, and check for
   regressions: blown-out or black areas, missing meshes (magenta/absent
   textures), z-fighting, fog banding, light leaks, wrong scale or floating props.
4. For anything affected by graphics presets (shadows, fog, light ranges),
   capture at `--quality 0` as well as the default High.
5. Report what the captures show, and say explicitly that the user should still
   check it in motion in the running game; a still frame does not show
   flicker, animation, or timing.

## Placing cameras in map.tscn

An instanced scene's transform in its parent replaces the root's own transform.
The hospital (`Buildings/NeighborhoodHospital`) sits at (245, 0, 251) rotated 180°,
so its local point (x, y, z) is at world (245 - x, y, 251 - z). Check a node's
parent transform this way before computing a world-space camera position.

## Limits

- Scenes that start with a black fade or an intro sequence may need a larger
  `--frames` value, or a spawned camera with `--hide-ui`.
- Gameplay state (pickups, triggered scares, dialogue progress) is not
  simulated. For a specific moment, write a focused script that drives the
  scene into that state and then saves `root.get_texture().get_image()`, as
  `tests/apparition_cover_smoke.gd` does with `--preview`.
- Once the Godot MCP server is connected, its `run_project` and
  `get_debug_output` tools are better for runtime errors during real play;
  this skill stays the way to obtain images.
