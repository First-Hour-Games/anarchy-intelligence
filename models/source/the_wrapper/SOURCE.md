# The Wrapper source

- Creator: Codyanka
- Source: https://codyanka.itch.io/the-wrapped
- License stated by the creator: CC0 (commercial use, modification and
  redistribution allowed, no credit required)
- Retrieved: 2026-10-01
- Download archive: `TheWrapper V2.zip`
- Archive SHA-256: `ae8e0203e6b887dcc072521ca5a04c96858280a25e4b4559f1fc1e3669c4ca92`

All files from the archive are retained under `vendor/`:

- `MonsterPSX.fbx`
  - SHA-256: `0bc97a344a55c5849e70f957deb1f433eefb2fcd1cfff34ceb7d0b7ccc551194`
- `MonsterPSX_Diffuse.png`
  - SHA-256: `41cd6eed09e4315ea1b61eaba27bd26666e54878ba583e63424117799f8de1d8`
- `MonsterPSX.blend` (editable source, not a runtime Godot resource)
  - SHA-256: `7e117234a15a9fcbc38734eaac4498565a651a1782a53d271aa5d1842bea0f01`

The runtime model is an unmodified copy of the vendor FBX/PNG pair at:

`res://models/enemies/the_wrapper/MonsterPSX.fbx`

No Blender rebuild step has been run for this asset; it ships as retrieved.

The FBX carries a rig (`MonsterPSX_Rig`) with five baked animation clips:
`Idle_Watchful`, `Walk_Nervous`, `Run_Frantic`, `Attack_Lunge`, `Scream`, and
`WallSlam_Recover`. Nothing in the project plays these yet.
