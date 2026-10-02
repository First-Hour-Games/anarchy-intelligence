# Watching Yeti source

- Creator: Quaternius
- Original pack: https://quaternius.com/packs/ultimatemonsters.html
- Individual model mirror: https://poly.pizza/m/ceRHrn8HHE
- License: CC0 1.0 Universal
- Retrieved: 2026-09-28
- Source model: `vendor/Yeti.glb`
- Source model SHA-256: `789FCDD3D32A1BF6CEAA0E30F9AC5D8D2C52D15FA0181D4D1D980A1B2A2AC869`
- Source preview SHA-256: `AF14ACF9A4E581FD6FDED062A31A3ADF434C9CC759D0F069621C191CF968AD48`

The source download is a model-only GLB. No installer, plug-in, script, native
library, or add-on from the asset was executed. The raw file contains a rigged
Yeti plus preview camera, light, cube, and backdrop objects.

`tools/blender/build_watching_yeti.py` keeps only the rigged character, removes
the preview objects, normalizes its height and facing, gives its materials a
darker brown nighttime palette, lowers the source rig's horizontal base arms
across each retained action, and exports these lowercase gameplay clips:

- `idle`
- `walk`
- `run`
- `windup`
- `attack`
- `hit`
- `death`

The original source model also contains Duck, Jump, Jump Idle, Jump Land, No,
Wave, Weapon, and Yes clips. They are omitted from the focused runtime GLB.
