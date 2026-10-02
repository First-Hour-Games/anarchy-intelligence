# The Clawman source

- Creator: Codyanka
- Source: https://codyanka.itch.io/the-clawman
- License stated by the creator: CC0 (commercial use, modification and
  redistribution allowed, no credit required)
- Retrieved: 2026-10-01
- Download archive: `TheClawman.rar`
- Archive SHA-256: `8e10ee8c23c9383d6ed5cfb8540d05f50229102f861b3151fedc8b627dfb3955`

All files from the archive are retained under `vendor/`:

- `TheClawman.fbx`
  - SHA-256: `07a5dc9cbbef61add40229b2a9b96be6199768eb17a6c470ce03f35fddf08c63`
- `monster_psx_256.png` (default skin)
  - SHA-256: `4ca957ed3312fd3373a5a5a58322f979a25f79c3b24edb0cf15f7e5dca168b27`
- `textures/monster_psx_ash_256.png`
  - SHA-256: `621e191aa589a516c41e631332aa89409173544248c60b6a66774e8417626e0b`
- `textures/monster_psx_black_256.png`
  - SHA-256: `04e3776becc293348d090eba16b9786dec289ed04145f9200c8df45babaf9713`
- `textures/monster_psx_blood_256.png`
  - SHA-256: `82af30555eda94a8bb97baf3c64089ec910a4be797fc1abcef7b6733590c15ef`
- `textures/monster_psx_pale_256.png`
  - SHA-256: `e859b6835568ea7757054047939c20a13f16fab3324e41d4d3f2b298c1ea3fc2`
- `textures/monster_psx_rot_256.png`
  - SHA-256: `6c5d81514372f1c52a98b2fe055da991c3527aa556f2366d0f86feb0a01e5c17`
- `textures/monster_psx_rust_256.png`
  - SHA-256: `353ce0d921b9ac9e76cc3929f22d9635eb57912f9cc01cd690088ccc35c5c4c7`
- `textures/monster_psx_standard_256.png` (identical to `monster_psx_256.png`)
  - SHA-256: `4ca957ed3312fd3373a5a5a58322f979a25f79c3b24edb0cf15f7e5dca168b27`
- `Monster_PSX_TPose.blend` (editable source, not a runtime Godot resource)
  - SHA-256: `f0eb94ae17e76f03ac23c94ccdd9a7b517f115eac8c4f7cdcefd42bfdc5247b1`

The runtime model is at:

`res://models/enemies/the_clawman/TheClawman.glb`

It is rebuilt from the vendor FBX via `tools/blender/build_the_clawman.py`
rather than shipped as the raw FBX, for two reasons:

1. The vendor FBX bundles the store-page render booth alongside the monster:
   `CV_Floor`, `CV_WallL`/`CV_WallR`, `CV_Ceil`, `CV_Back`, `CV_Panel`,
   `CV_Crate`/`CV_Crate2`, `CV_Slab`, plus `CV_Key`/`CV_Rim`/`CV_Amb` lights
   and a `CV_Cam` camera. The build script keeps only the `Monster_PSX` mesh
   and `Monster_Rig` armature and discards the rest.
2. Godot's built-in FBX importer (`modules/fbx/fbx_document.cpp`) aborts the
   whole scene import with `Parameter "light" is null.` on a malformed light
   object embedded in the vendor file. Re-exporting through Blender as a GLB
   with no light/camera data sidesteps the bug entirely.

No mesh, rig, or animation data is altered. Rebuild with Blender 5.2:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --python tools/blender/build_the_clawman.py
```

The texture variants under `textures/` are alternate skins (ash, black,
blood, pale, rot, rust) for the same mesh; nothing selects between them yet.

The FBX carries a rig (`Monster_Rig`) with five baked animation clips:
`Idle_ClawGroom`, `Walk_Shamble`, `Chase_Run`, `Attack_Slam`, and
`Scream_Alert`. Nothing in the project plays these yet.
