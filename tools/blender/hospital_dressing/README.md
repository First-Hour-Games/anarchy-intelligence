# Hospital equipment (dressing)

Procedural hospital equipment for the hospital interior in `Hospital_V2.blend`. Each prop
module in this folder defines `PROPS`. `catalog.py` merges every module's props.
`build_hospital_interior.py` (stage `dressing`) builds the placements listed in
`../hospital_layout/dressing_*.py`, and `../hospital_layout/validate.py` checks them.

## Preview a module (headless; never touches Hospital_V2.blend)

```
"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" --background --factory-startup ^
  --python tools/blender/hospital_dressing/preview.py -- --module <module> --out <dir> [--props a,b]
```

This builds each prop and each preview variant against a sample wall with a wainscot, chair
rail and skirting, plus the floor. Surface props get a counter and ceiling props a ceiling strip.

- It prints declared and measured sizes, the base height, triangles and contract flags.
- It renders `overview.png` and `<instance>.png` (two angles side by side) into `<dir>`.

## Module contract

```python
"""Bedside wall equipment for the hospital interior (see README.md)."""

PALETTE = {"HeadwallBeige": ((0.80, 0.77, 0.68), 0.0, 0.5)}   # optional extra materials, module-prefixed names
EMISSION = {}                                                  # optional: name -> strength
ALPHA = {}                                                     # optional: name -> alpha


def sharps_container(B, name: str, x: float, z: float, yaw: float = 0.0, y: float = 1.25, full: bool = False):
    kit = B.Kit(name)
    kit.box((-0.14, 0.0, -0.08), (0.14, 0.30, 0.06), "MedicalRed")          # body
    ...
    obj = kit.build(x, z, yaw, y=y)
    B.kit_text(name + "Label", "SHARPS", x, z, yaw, y, (0.0, 0.2, 0.062), size=0.03)
    return obj


PROPS = {
    "sharps_container": {
        "build": sharps_container,
        "size": (0.28, 0.34, 0.16),   # w (local X), h (Y), d (local Z) before yaw
        "mount": "wall",              # floor | wall | surface | ceiling
        "y": 1.25,                    # wall props only: default base height (game metres)
        "collide": False,             # False = decoration: no collision, never blocks navigation
        "variants": [{}, {"full": True}],
        "desc": "Red wall-bracket sharps container",
    },
}
```

### Coordinates and units

- All coordinates are game metres. +Y is up and the floor top is `B.FLOOR_Y` (0.12). The ceiling
  underside is `B.CEILING_Y` (2.95).
- The local origin is the footprint centre at the prop's base. The front faces local +Z.
- `yaw` follows Godot: +90 turns the front toward +X.
- A wall prop's back face sits exactly on local z = -d/2, against the wall. A ceiling prop's top
  is at local y = h and touches the ceiling.
- The declared `size` must match the measured bounds: no axis more than 2 cm over or 5 cm under.
  The validator uses it for collision and navigation.

### Builder signature

`build(B, name, x, z, yaw=0.0, y=<default base>, **options)` returns the main object.

- The default for `y` is `B.FLOOR_Y` for floor props, and the declared `y` for wall props.
- Every object the builder creates must have a name starting with `name`.

### Tools on `B`

- `B.Kit(name)`: `.box(low, high, mat)` adds an axis-aligned box. `.cylinder(center, radius,
  length, mat, axis="y"|"x"|"z", segments=12)` adds a capped cylinder; `segments=3` makes a
  triangular prism (arrows) and 6 to 16 is normal. `.build(x, z, yaw, y=..., pitch=0, roll=0)`
  places the kit as one object. It applies roll about local Z, then pitch about local X, then yaw.
- Angled parts (a raised backrest, a tilted monitor) are a second kit built with pitch or roll.
  Place it with `B.local_point(x, z, yaw, lx, lz)`, which returns the game (x, z) of a local
  offset.
- `B.kit_text(name, words, x, z, yaw, y, (lx, ly, lz), size=0.05, mat="SignWhite", turn=0.0)`
  places flat text at a kit-local point, facing the prop's +Z. Use `turn=90` for its +X side.
  Text is expensive, about 40 triangles per glyph. Use it only for iconic labels at least 2.5 cm
  tall, and keep it under about 30 glyphs per prop.

### Materials

These are shared palette names; reuse them before adding new ones:
WallUpper, WallLower, Baseboard, Ceiling, Trim, DoorFrame, DoorGlass, Plywood, Laminate,
Countertop, Vinyl, Chrome, Canvas, Curtain, Linen, Blanket, Rubber, Cork, Paper, SignBlue,
SignWhite, FilingGrey, ShelfSteel, Wood, Cardboard, DoorPaint, Appliance, Mattress, BookRed,
BookBlue, BookGreen, LampGlow (emissive), PanelLit (emissive), CartRed, CartBlue, PlasticWhite,
PlasticBeige, PlasticGrey, ScreenDark, ScreenGreen (emissive), OxygenGreen, AirYellow,
MedicalRed, SafetyYellow, SignGreen, ScrubTeal, GloveBlue, GlovePurple, FilmLit (emissive),
FilmDark, Brass, VinylTeal, VinylMauve, MattressBlue, AlarmRed (emissive).

### Rules

- Real-world proportions for a 1990s small-town US community hospital, worn but intact.
- Labels and decals sit at least 2 mm proud of the face they are on. Coplanar faces z-fight in
  Godot.
- No red-cross emblems: the emblem is legally protected. Also no Star of Life, no real brand
  names and no logos. Use plain text such as "AED", "SHARPS" or "OXYGEN".
- Never put a loose small bottle on an open surface: the player reads those as bottle pickups.
- Triangle budgets: floor 1500 (3000 when the footprint is over 1 m²), wall and surface 700,
  ceiling 300.
- Code style follows `build_hospital_interior.py`: short typed functions and one-line part
  comments.
