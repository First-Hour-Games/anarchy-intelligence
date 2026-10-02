# The Ridgeback source

- Creator: Codyanka
- Source: https://codyanka.itch.io/the-ridgeback
- License stated by the creator: CC0 (commercial use, modification and
  redistribution allowed, no credit required)
- Retrieved: 2026-10-01
- Download archive: `THE RIDGEBACK.zip`
- Archive SHA-256: `4babd109f30ba488f571d51bc812c3b3148364f8a74e1118cac9c109efd2e143`

All files from the archive are retained under `vendor/`:

- `THE_RIDGEBACK.fbx`
  - SHA-256: `07b5087eec6697e7e51535ebc8120e1bea2eeadf5e91c906d1b0ecff241eee9a`
- `textures/ManThing_blood.png`
  - SHA-256: `96600fb55ccff23d899698220bb839235c9de0e2962e13f3f38e29ae801b43a3`
- `textures/ManThing_burnt.png`
  - SHA-256: `2bc6d09f98f4098e3b46e7c524dd72b6cae1af5bac1468b0e16669dbaf31f49d`
- `textures/ManThing_dirt.png`
  - SHA-256: `c6103119dccc874ddeb3571f9a07ff5bd509ca9a1cba092271dc493399c668ac`
- `textures/ManThing_flesh.png`
  - SHA-256: `4d2b56908e6f5157cb2f5cd5f6af576ed7cd078aaedfc09fd87eae0ef53dcafe`
- `textures/ManThing_frost.png`
  - SHA-256: `c5f3a6bf8fa758db4cb4bbd68950021f3f6bfd35e1877712e10e197cc5c1dfad`
- `textures/ManThing_pale.png`
  - SHA-256: `683d2ca546c3b49b8179afb584646f7b435086fbde3c0e3f0df5e5dbcd1833f5`
- `textures/ManThing_rot.png`
  - SHA-256: `24fd6e533ec1dbe608f14643f0884009b4592f96f2280fa9920c55383cd850f8`
- `textures/ManThing_tar.png`
  - SHA-256: `25259c8e15122065af3d887226f385ebaa2639966aee09c7eb74ff17d4e926c5`
- `THE_RIDGEBACK.blend` (editable source, not a runtime Godot resource)
  - SHA-256: `d1387770bd61e9a07ae14f6ff8b4fb42ff46ef564958a19da2eabb2dcf47d89f`

The runtime model is at:

`res://models/enemies/the_ridgeback/THE_RIDGEBACK.glb`

It is rebuilt from the vendor FBX via `tools/blender/build_the_ridgeback.py`
rather than shipped as the raw FBX, because the vendor FBX's "PSX_ManThing"
material ships with no texture wired up (the artist provides eight
interchangeable skins as loose PNGs instead of baking one in). The build
script imports the FBX in Blender, wires the `flesh` skin onto the
material's base color, and re-exports as a GLB. No mesh, rig, or animation
data is altered. Rebuild with Blender 5.2:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --python tools/blender/build_the_ridgeback.py
```

The texture variants under `textures/` are alternate skins (blood, burnt,
dirt, flesh, frost, pale, rot, tar) for the same mesh; only `flesh` is
wired up by default. Swap it for one of the others by editing
`DEFAULT_SKIN` in the build script and rebuilding, or by replacing the
material's texture directly in Godot.

The FBX carries a rig (`PSX_Rig`) with five baked animation clips:
`ManThing_IDLE`, `ManThing_WALK`, `ManThing_CHASE`, `ManThing_NOTICE`, and
`ManThing_ATTACK`. Nothing in the project plays these yet.
