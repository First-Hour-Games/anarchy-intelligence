# Anarchy Intelligence 3D enemy contract

Use this contract for Blender generation/export and Godot integration.

## Transform and hierarchy

- Units are metres; a standing humanoid should match its gameplay capsule.
- Apply mesh scale and rotation before export.
- Place the model origin on the ground between the feet.
- Godot forward is `-Z` and up is `+Y`. Correct facing in the source/export
  pipeline instead of compensating throughout gameplay code.
- Keep one model root under the existing enemy `CharacterBody3D`.
- Keep render meshes, skeleton, attachments, collision, and gameplay logic in
  distinct nodes.

## Required clips

Use lowercase clip names:

| Clip | Mode | Expected behavior |
| --- | --- | --- |
| `idle` | loop | Neutral threatening stance |
| `walk` | loop | Slow search movement |
| `run` | loop | Pursuit movement |
| `windup` | one-shot/hold | Readable attack warning |
| `attack` | one-shot | Strike with a clear impact frame |
| `hit` | one-shot | Brief damage reaction |
| `death` | one-shot/hold | Ends on the corpse pose |

Additional clips are allowed, but the adapter must gracefully fall back when an
optional clip is absent. Locomotion clips should animate in place unless tested
root motion is explicitly requested.

## Materials and performance

- Use Godot-compatible glTF PBR materials. Avoid Blender-only procedural nodes
  unless they are baked to textures.
- Use an emissive material or material override for cybernetic lights.
- Prefer opaque or alpha-scissor materials over blended transparency.
- Keep a first gameplay prototype below roughly 60,000 rendered triangles and
  use 2K-or-smaller textures unless close-up review demonstrates a need for more.
- Enable shadows only where their visual benefit justifies the cost.

## Adapter contract

The visual adapter must expose `play(clip_name: String)`. Map gameplay names as
needed—for example, `dormant` to `idle` and `chase` to `run`. It owns animation
transitions and model-specific node paths; the enemy controller owns state,
movement, targeting, attacks, and damage.

Expose a fallback selector while replacing an existing visual. Tests should
verify every required clip resolves, one-shots do not loop unexpectedly, death
holds its final pose, and the fallback can still instantiate.
