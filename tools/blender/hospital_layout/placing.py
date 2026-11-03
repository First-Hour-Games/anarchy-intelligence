"""Helpers for the dressing_*.py files: catalogue sizes and placement against wall faces.

Partition walls are 0.15 thick, so their faces sit 0.075 either side of the wall line in
layout.py; the perimeter linings' inner faces are z -0.30 (front), z -9.30 (back),
x -20.10 (west) and x 17.70 (east).
"""

import importlib.util
from pathlib import Path

_spec = importlib.util.spec_from_file_location(
    "hospital_dressing_catalog", Path(__file__).resolve().parents[1] / "hospital_dressing" / "catalog.py")
_catalog = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_catalog)
SIZES = {key: spec["size"] for key, spec in _catalog.load().items()}
FACING_YAW = {"+z": 0.0, "-z": 180.0, "+x": 90.0, "-x": -90.0}


def entry(prop: str, name: str, x: float, z: float, yaw: float = 0.0, y: float | None = None,
          on: str | None = None, **opts) -> dict:
    placed = {"prop": prop, "name": name, "x": round(x, 3), "z": round(z, 3), "yaw": yaw, "opts": opts}
    if y is not None:
        placed["y"] = y
    if on:
        placed["on"] = on
    return placed


def wall(prop: str, name: str, face: float, facing: str, along: float, y: float | None = None,
         gap: float = 0.0, **opts) -> dict:
    """A prop with its back on the wall face at coordinate `face`, its front toward `facing`
    ("+z", "-z", "+x" or "-x"), centred at `along` on the wall's running axis. Floor props
    standing against a wall pass a small `gap` (clear of skirting and handrails)."""
    depth = SIZES[prop][2]
    sign = 1.0 if facing[0] == "+" else -1.0
    offset = face + sign * (gap + depth / 2.0)
    x, z = (along, offset) if facing[1] == "z" else (offset, along)
    return entry(prop, name, x, z, FACING_YAW[facing], y, **opts)
