# Hospital ground-floor layout data

`layout.py` (walls, rooms, Blender-modelled objects) and `markers.py` (Godot-spawned
hiding spots, bottles, documents, lights, props and the Clawman spawn) describe the
hospital interior in hospital-local game metres (x east, y up, z = 0 at the front
facade and negative inward). `tools/blender/build_hospital_interior.py` reads them.

Origin: draft layout by the "horror" designer of the Oct 23, 2026 design panel,
validated by its own checker (door widths, navigation reachability, hiding-spot
clearance, existing test rays). Replace these files with the final merged layout
when it is approved; keep the same data shapes.

## Equipment placements

`dressing_*.py` files place the props from `tools/blender/hospital_dressing/` (see its
README for the entry format).

- `dressing_rules.py` derives door plaques, sanitizers and ceiling fixtures from the walls
  and rooms.
- `dressing_west.py`, `dressing_core.py` and `dressing_east.py` place the room equipment by
  hand with the helpers in `placing.py`.

Run `python validate.py` (optionally `--files dressing_rules,dressing_east`) before rebuilding.
It must report 0 problems. It checks:

- door throats;
- the 1.5 m corridor width;
- hiding-spot clearance and exits;
- navigation to every room and hunter goal;
- the clearance around bottles and notes;
- wall contact and surface support.

`../hospital_dressing/render_zone.py` renders plans and eye-level shots of the built
interior headlessly.
