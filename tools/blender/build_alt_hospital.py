"""Build and export the alt route's hospital (the plan is in tools/blender/alt_hospital/).

blender --background --factory-startup --disable-autoexec --python tools/blender/build_alt_hospital.py

Builds the whole building in memory from alt_hospital/plan.py (walls with their doors and windows, floors,
stairs, ceilings, the facade, and the roof with its helipad) and alt_hospital/dressing.py (equipment from
tools/blender/hospital_dressing and the old interior builder's furniture kits, which this runs as a library).
It merges everything into a few meshes per storey and writes, without saving any .blend:
  models/buildings/alt_hospital/alt_hospital.glb
  models/buildings/alt_hospital/alt_hospital_markers.json  (rooms, hiding spots, bottles, documents, lights
                                                            and the story's points, for alt_hospital.gd)
Mesh names say what Godot does with them (scenes/environment/alt_hospital.gd):
  GroundFloor_L<n>  storey n's floors, landings and stairs (collision, tile footsteps);
  Interior_L<n>     its walls, doors and furniture (collision);
  Decor_L<n>        its ceiling, fittings, glass, signs and small equipment (no collision);
  Exterior          the outside walls, bands, canopy, parapet and stair house (collision);
  RoofFloor         the roof deck, helipad and roof plant (collision, concrete footsteps);
  Blocker_L<n>      invisible blocks that make sure a blocked stair stays blocked (collision, hidden).
"""

import json
import math
import runpy
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix

ROOT = Path(__file__).resolve().parents[2]
PLAN_DIR = Path(__file__).resolve().parent / "alt_hospital"
OUT_DIR = ROOT / "models" / "buildings" / "alt_hospital"
GLB = OUT_DIR / "alt_hospital.glb"
MARKERS = OUT_DIR / "alt_hospital_markers.json"

sys.path.insert(0, str(PLAN_DIR))
for _module in ("plan", "dressing"):
    sys.modules.pop(_module, None)
import plan  # noqa: E402
import dressing  # noqa: E402

# The old interior builder as a library: its palette, furniture kits and the equipment catalogue, here at
# 1:1 (the old hospital's model was at 0.6) and with this building's ceiling height.
# runpy hands back a copy of the module's globals; its functions read the real ones, so settings are changed
# there.
LIB = runpy.run_path(str(ROOT / "tools" / "blender" / "build_hospital_interior.py"), run_name="alt_hospital_library")
LIB = LIB["box"].__globals__
LIB["GODOT_SCALE"] = 1.0
LIB["COLLECTION"] = "AltHospital"
LIB["ROOT_NAME"] = "AltHospitalRoot"
LIB["CEILING_Y"] = plan.FLOOR0 + plan.CEILING
LIB["PALETTE"].update({
    "ExteriorRender": ((0.80, 0.80, 0.77), 0.0, 0.85),
    "ExteriorBand": ((0.30, 0.36, 0.42), 0.1, 0.6),
    "RoofDeck": ((0.24, 0.24, 0.23), 0.0, 0.95),
    "HelipadAsphalt": ((0.08, 0.085, 0.09), 0.0, 0.9),
    "HelipadPaint": ((0.86, 0.84, 0.76), 0.0, 0.7),
    "PadLight": ((0.95, 0.85, 0.25), 0.0, 0.4),
    "BeaconRed": ((1.0, 0.08, 0.05), 0.0, 0.4),
    "SignLitRed": ((0.95, 0.12, 0.08), 0.0, 0.5),
    "SignLitGreen": ((0.10, 0.85, 0.30), 0.0, 0.5),
    "Concrete": ((0.48, 0.47, 0.45), 0.0, 0.9),
    "Rubble": ((0.40, 0.39, 0.36), 0.0, 0.95),
    "Rebar": ((0.22, 0.16, 0.12), 0.6, 0.6),
    "StairNosing": ((0.75, 0.62, 0.12), 0.0, 0.6),
    "Chain": ((0.30, 0.30, 0.30), 0.9, 0.4),
    # Each floor's colour, along the bottom of its walls and on its doors.
    "DadoBlue": ((0.17, 0.29, 0.44), 0.0, 0.7),
    "DadoGreen": ((0.29, 0.42, 0.33), 0.0, 0.7),
    "DadoTeal": ((0.15, 0.38, 0.39), 0.0, 0.7),
    "DadoOchre": ((0.52, 0.38, 0.15), 0.0, 0.7),
    "ExitBox": ((0.06, 0.55, 0.22), 0.0, 0.4),
    "BodyBag": ((0.05, 0.05, 0.055), 0.2, 0.35),
    "CeilingTile": ((0.78, 0.77, 0.72), 0.0, 0.95),
})
LIB["EMISSION"].update({"PadLight": 3.0, "BeaconRed": 4.0, "SignLitRed": 1.6, "SignLitGreen": 1.6, "ExitBox": 2.2})

KIT_DECOR = {"ceiling_panel", "notice_board", "privacy_curtain"}
DADO = 1.0
# Kits placed on the roof are built for the top storey and lifted with it; this base puts them on the roof.
ROOF_BASE = plan.ROOF_Y - (plan.floor_y(plan.LEVELS - 1) - plan.FLOOR0)


# ---- Making and tagging objects --------------------------------------------------------------------------
def tag(obj, group: str, level: int):
    obj["group"] = group
    obj["level"] = level
    return obj


def solid(name: str, low: tuple, high: tuple, mat: str, group: str, level: int):
    if high[0] - low[0] < 1e-4 or high[1] - low[1] < 1e-4 or high[2] - low[2] < 1e-4:
        return None
    return tag(LIB["box"](name, low, high, mat), group, level)


def lifted(group: str, level: int, build, *args, **kwargs) -> list:
    """Run a builder that places things for the ground floor, then lift what it made to `level`."""
    before = set(bpy.data.objects)
    build(*args, **kwargs)
    made = [obj for obj in bpy.data.objects if obj not in before]
    dy = plan.floor_y(level) - plan.FLOOR0
    for obj in made:
        if abs(dy) > 1e-6:
            if obj.type == "MESH":
                obj.data.transform(Matrix.Translation((0.0, dy, 0.0)))
            else:
                obj.location.y += dy
        decor = group == "Decor" or obj.name.startswith("Decor_") or obj.type == "FONT"
        tag(obj, "Decor" if decor else group, level)
    return made


def kit(name: str):
    return LIB["Kit"](name)


# ---- Walls ---------------------------------------------------------------------------------------------
def floor_colour(level: int) -> str:
    return plan.FLOOR_COLOURS[level] if 0 <= level < plan.LEVELS else "WallLower"


def painted(name: str, low: tuple, high: tuple, floor: float, level: int, group: str = "Interior") -> None:
    """A wall block painted like the rooms: the floor's colour below DADO, the pale paint above."""
    split = floor + DADO
    dado = floor_colour(level)
    if low[1] < split < high[1]:
        solid(name + "_dado", low, (high[0], split, high[2]), dado, group, level)
        solid(name, (low[0], split, low[2]), high, "WallUpper", group, level)
    elif high[1] <= split:
        solid(name + "_dado", low, high, dado, group, level)
    else:
        solid(name, low, high, "WallUpper", group, level)


def wall_frame(wall: dict) -> dict:
    along_x = abs(wall["z2"] - wall["z1"]) < 1e-6
    a = wall["x1"] if along_x else wall["z1"]
    b = wall["x2"] if along_x else wall["z2"]
    return dict(along_x=along_x, a=a, sign=1.0 if b >= a else -1.0, length=abs(b - a),
                fixed=wall["z1"] if along_x else wall["x1"])


def block(f: dict, s0: float, s1: float, near: float, far: float, h0: float, h1: float) -> tuple:
    """Box (low, high) of the stretch s0..s1 along a wall, from `near` to `far` across it, h0..h1 up."""
    p0, p1 = f["a"] + f["sign"] * s0, f["a"] + f["sign"] * s1
    lo, hi = min(p0, p1), max(p0, p1)
    c0, c1 = min(near, far), max(near, far)
    if f["along_x"]:
        return (lo, h0, c0), (hi, h1, c1)
    return (c0, h0, lo), (c1, h1, hi)


def build_rail(wall: dict) -> None:
    """A balustrade (glass panels between steel posts under a handrail) or a glass screen between bed bays.
    The glass is solid: nobody walks or falls through it."""
    f = wall_frame(wall)
    level = wall["level"]
    y0, y1 = wall["y0"], wall["y1"]
    mid = f["fixed"]
    posts = max(2, int(f["length"] / 1.5) + 1)
    for k in range(posts):
        at = min(max(k * f["length"] / (posts - 1), 0.03), f["length"] - 0.03)
        low, high = block(f, at - 0.03, at + 0.03, mid - 0.03, mid + 0.03, y0, y1)
        solid(f"{wall['id']}_post{k}", low, high, "Chrome", "Interior", level)
    if wall["style"] == "balustrade":
        low, high = block(f, 0.0, f["length"], mid - 0.035, mid + 0.035, y1 - 0.05, y1)
        solid(f"{wall['id']}_rail", low, high, "Chrome", "Interior", level)
        low, high = block(f, 0.03, f["length"] - 0.03, mid - 0.01, mid + 0.01, y0 + 0.08, y1 - 0.08)
    else:
        low, high = block(f, 0.0, f["length"], mid - 0.03, mid + 0.03, y1 - 0.04, y1)
        solid(f"{wall['id']}_head", low, high, "Chrome", "Interior", level)
        low, high = block(f, 0.03, f["length"] - 0.03, mid - 0.01, mid + 0.01, y0 + 0.12, y1 - 0.04)
    solid(f"{wall['id']}_glass", low, high, "DoorGlass", "Interior", level)


def door_leaves(wall: dict, f: dict, o: dict, floor: float, name: str, level: int) -> None:
    """The doors of a doorway, standing open (each at its own angle) to the side `swing` names: a stair's
    folded right back against the stairwell's wall, clear of its landing; a room's about square to the wall.
    Drawn only (no collision), so an open door never shuts anyone in or out."""
    import random
    rng = random.Random(name)
    count = 1 if o["width"] <= 1.1 else 2
    width = o["width"] / count - 0.02
    height = min(o["head"] - o["sill"], plan.DOOR_H) - 0.04
    along = (1.0, 0.0) if f["along_x"] else (0.0, 1.0)
    along = (along[0] * f["sign"], along[1] * f["sign"])
    # The wall's left, seen looking along it, in game x, z (the side plan.door's swing +1 names).
    left = (-along[1], along[0])
    side = (left[0] * o["swing"], left[1] * o["swing"])
    s0, s1 = o["center"] - o["width"] / 2.0, o["center"] + o["width"] / 2.0
    hinges = [(s0, 1.0), (s1, -1.0)][:count] if count == 2 else [(s0, 1.0)]
    for index, (at, toward) in enumerate(hinges):
        angle = math.radians(rng.uniform(162.0, 172.0) if "Core" in wall["id"] else rng.uniform(78.0, 100.0))
        # The leaf runs from its hinge toward the doorway's middle, turned open toward `side`.
        dx = along[0] * toward * math.cos(angle) + side[0] * math.sin(angle)
        dz = along[1] * toward * math.cos(angle) + side[1] * math.sin(angle)
        point = f["a"] + f["sign"] * at
        hx, hz = (point, f["fixed"]) if f["along_x"] else (f["fixed"], point)
        # Hinged at the wall's face on the side it opens to.
        hx += side[0] * wall["t"] / 2.0
        hz += side[1] * wall["t"] / 2.0
        yaw = math.degrees(math.atan2(-dz, dx))
        leaf = kit(f"{name}_leaf{index}")
        leaf.box((0.0, 0.01, -0.022), (width, height, 0.022), floor_colour(level))
        leaf.box((width * 0.3, 1.25, -0.024), (width * 0.7, 1.75, 0.024), "DoorGlass")
        leaf.box((width - 0.12, 0.98, -0.05), (width - 0.06, 1.02, 0.05), "Chrome")
        lifted("Decor", level, leaf.build, hx, hz, yaw, plan.FLOOR0 + (floor - plan.floor_y(level)))


def exit_sign(wall: dict, f: dict, o: dict, floor: float, name: str, level: int) -> None:
    """A lit EXIT box over a stair door, on the corridor side."""
    toward_corridor = 1.0 if f["fixed"] < 0 else -1.0
    face = f["fixed"] + toward_corridor * (wall["t"] / 2.0 + 0.04)
    y = floor + o["head"] + 0.12
    low, high = block(f, o["center"] - 0.24, o["center"] + 0.24, face - 0.035, face + 0.035, y, y + 0.2)
    solid(name + "_exit", low, high, "ExitBox", "Decor", level)
    point = f["a"] + f["sign"] * o["center"]
    sx, sz = (point, face + toward_corridor * 0.04) if f["along_x"] else (face + toward_corridor * 0.04, point)
    yaw = 90.0 if (not f["along_x"] and toward_corridor > 0) else (-90.0 if not f["along_x"] else 0.0)
    tag(LIB["text_label"](name + "_exitText", "EXIT", sx, y + 0.1, sz, yaw, size=0.12, mat="SignWhite"), "Decor", level)


def build_wall(wall: dict) -> None:
    if wall.get("style", "wall") != "wall":
        build_rail(wall)
        return
    f = wall_frame(wall)
    t = wall["t"]
    level = wall["level"]
    floor = plan.floor_y(level) if level >= 0 else plan.FLOOR0
    y0, y1 = wall["y0"], wall["y1"]
    # Exterior walls are an outside skin (render) and an inside lining (paint); the parapet and the stair house
    # are all outside.
    if wall["outside"] and level < plan.LEVELS:
        # Which side is outdoors: the front (+z) or back (-z) for walls along x, the ends for walls along z.
        if f["along_x"]:
            outward = 1.0 if f["fixed"] > -9.0 else -1.0
        else:
            outward = 1.0 if f["fixed"] > 0 else -1.0
        outer_face = f["fixed"] + outward * t / 2
        layers = [("skin", outer_face, outer_face - outward * 0.1, "Exterior"),
                  ("lining", outer_face - outward * 0.1, f["fixed"] - outward * t / 2, "Interior")]
    else:
        layers = [("all", f["fixed"] - t / 2, f["fixed"] + t / 2, "Exterior" if wall["outside"] else "Interior")]
    cuts = []
    last = 0.0
    for o in wall["openings"]:
        lo, hi = o["center"] - o["width"] / 2.0, o["center"] + o["width"] / 2.0
        cuts.append((last, lo, None))
        cuts.append((lo, hi, o))
        last = hi
    cuts.append((last, f["length"], None))
    for label, near, far, group in layers:
        tag_level = level if group != "Exterior" else -1
        for index, (s0, s1, o) in enumerate(cuts):
            name = f"{wall['id']}_{label}{index}"
            spans = [(y0, y1)] if o is None else [(y0, floor + o["sill"]), (floor + o["head"], y1)]
            for h0, h1 in spans:
                if h1 - h0 < 1e-3:
                    continue
                low, high = block(f, s0, s1, near, far, h0, h1)
                if group == "Interior":
                    painted(name, low, high, floor, tag_level)
                else:
                    solid(name, low, high, "ExteriorRender", group, tag_level)
    for index, (s0, s1, o) in enumerate(cuts):
        if o is not None:
            fill_opening(wall, f, o, floor, f"{wall['id']}_o{index}")


def fill_opening(wall: dict, f: dict, o: dict, floor: float, name: str) -> None:
    t = wall["t"]
    level = max(wall["level"], 0) if wall["level"] < plan.LEVELS else plan.LEVELS - 1
    s0, s1 = o["center"] - o["width"] / 2.0, o["center"] + o["width"] / 2.0
    h0, h1 = floor + o["sill"], floor + o["head"]
    mid = f["fixed"]
    if o["kind"] in ("window", "glass"):
        low, high = block(f, s0, s1, mid - 0.01, mid + 0.01, h0, h1)
        solid(name + "_glass", low, high, "DoorGlass", "Decor", level)
        low, high = block(f, s0 - 0.03, s1 + 0.03, mid - t / 2 - 0.02, mid + t / 2 + 0.02, h0 - 0.04, h0)
        solid(name + "_sill", low, high, "SillStone", "Decor", level)
        return
    if o["kind"] == "pass":
        # A counter ledge along the opening's sill.
        low, high = block(f, s0, s1, mid - t / 2 - 0.18, mid + t / 2 + 0.18, h0 - 0.04, h0 + 0.02)
        solid(name + "_ledge", low, high, "Countertop", "Interior", level)
        return
    # Doorways: a steel frame round the opening on both faces.
    for jamb0, jamb1 in ((s0 - 0.06, s0), (s1, s1 + 0.06)):
        low, high = block(f, jamb0, jamb1, mid - t / 2 - 0.02, mid + t / 2 + 0.02, h0, h1 + 0.06)
        solid(name + "_jamb", low, high, "DoorFrame", "Decor", level)
    low, high = block(f, s0, s1, mid - t / 2 - 0.02, mid + t / 2 + 0.02, h1, h1 + 0.06)
    solid(name + "_head", low, high, "DoorFrame", "Decor", level)
    if o["kind"] == "chained":
        # A closed steel door with a chain through its push bar, and a sign.
        low, high = block(f, s0, s1, mid - 0.03, mid + 0.03, h0, h1)
        solid(name + "_leaf", low, high, "DoorPaint", "Interior", level)
        for side in (-1.0, 1.0):
            low, high = block(f, s0 + 0.1, s1 - 0.1, mid + side * 0.04, mid + side * 0.07, h0 + 0.95, h0 + 1.0)
            solid(name + "_bar", low, high, "Chrome", "Decor", level)
            for k in range(7):
                c = s0 + 0.2 + k * (o["width"] - 0.4) / 6.0
                low, high = block(f, c - 0.03, c + 0.03, mid + side * 0.075, mid + side * 0.1, h0 + 0.9 + 0.05 * (k % 2), h0 + 1.05 + 0.05 * (k % 2))
                solid(name + f"_chain{k}", low, high, "Chain", "Decor", level)
        low, high = block(f, o["center"] - 0.45, o["center"] + 0.45, mid + 0.031, mid + 0.04, h0 + 1.5, h0 + 1.75)
        solid(name + "_sign", low, high, "SprayPaint", "Decor", level)
        exit_sign(wall, f, o, floor, name, level)
    elif o["kind"] == "door" and o.get("swing", 0.0):
        door_leaves(wall, f, o, floor, name, level)
        if "Core" in wall["id"]:
            exit_sign(wall, f, o, floor, name, level)
    elif o["kind"] == "lift":
        for k, (a0, a1) in enumerate(((s0, o["center"] - 0.005), (o["center"] + 0.005, s1))):
            low, high = block(f, a0, a1, mid - 0.025, mid + 0.025, h0, h1)
            solid(name + f"_door{k}", low, high, "Chrome", "Interior", level)
    elif o["kind"] == "entrance":
        # The glass doors jammed open to the sides, against the inside of the facade.
        for k, (a0, a1) in enumerate(((s0 - 1.45, s0 - 0.05), (s1 + 0.05, s1 + 1.45))):
            inside = f["fixed"] - 0.22
            low, high = block(f, a0, a1, inside - 0.02, inside + 0.02, h0 + 0.02, h0 + 2.5)
            solid(name + f"_leaf{k}", low, high, "DoorGlass", "Decor", level)


# ---- Floors, stairs and ceilings -------------------------------------------------------------------------
def build_floors() -> None:
    for level in range(plan.LEVELS):
        top = plan.floor_y(level)
        bottom = 0.0 if level == 0 else top - plan.SLAB
        for x0, x1, z0, z1, finish, name in plan.floor_zones(level):
            safe = "".join(ch for ch in name if ch.isalnum())
            solid(f"L{level}_Floor_{safe}", (x0, bottom, z0), (x1, top, z1), finish, "Floor", level)
    for x0, x1, z0, z1, finish, name in plan.roof_zones():
        safe = "".join(ch for ch in name if ch.isalnum())
        solid(f"Roof_{safe}", (x0, plan.ROOF_Y - plan.SLAB, z0), (x1, plan.ROOF_Y, z1), finish, "Roof", plan.LEVELS - 1)


def build_ceilings() -> None:
    for level in range(plan.LEVELS):
        y = plan.floor_y(level) + plan.CEILING
        for x0, x1, z0, z1, name in plan.ceiling_zones(level):
            safe = "".join(ch for ch in name if ch.isalnum())
            solid(f"L{level}_Ceiling_{safe}", (x0, y, z0), (x1, y + 0.04, z1), "Ceiling", "Decor", level)


def build_stairs() -> None:
    corridor_mid = (plan.CORRIDOR[0] + plan.CORRIDOR[1]) / 2.0
    zf = (corridor_mid, plan.CORE_Z[1] - plan.CORE_WALL / 2)   # flight 1 (the front half)
    zb = (plan.CORE_Z[0] + plan.CORE_WALL / 2, corridor_mid)    # flight 2 (the back half)
    for core in ("A", "B"):
        c = plan.core_x(core)
        s = c["s"]
        for level in range(plan.LEVELS):
            if plan.UP[core][level] is None:
                continue
            base = plan.floor_y(level)
            mid_y = base + plan.STOREY / 2.0
            # The wall between the two flights.
            lo, hi = sorted((c["landing_end"], c["flight_end"]))
            painted(f"Core{core}{level}_Divider", (lo, base, corridor_mid - 0.05), (hi, plan.floor_y(level + 1), corridor_mid + 0.05), base, level)
            for k in range(1, plan.RISERS):
                # Flight 1: from the floor landing out toward the end wall.
                x0 = c["landing_end"] + s * plan.TREAD * (k - 1)
                x1 = c["landing_end"] + s * plan.TREAD * k
                top = base + plan.RISE * k
                solid(f"Core{core}{level}_F1_{k}", (min(x0, x1), top - 0.4, zf[0] + 0.05), (max(x0, x1), top, zf[1]), "FloorConcrete", "Floor", level)
                # A yellow nosing on the front edge of each tread.
                edge = x0
                solid(f"Core{core}{level}_F1n_{k}", (min(edge, edge + s * 0.05), top, zf[0] + 0.05), (max(edge, edge + s * 0.05), top + 0.006, zf[1]), "StairNosing", "Decor", level)
                # Flight 2: from the mid landing back in to the next floor.
                x0 = c["flight_end"] - s * plan.TREAD * (k - 1)
                x1 = c["flight_end"] - s * plan.TREAD * k
                top = mid_y + plan.RISE * k
                solid(f"Core{core}{level}_F2_{k}", (min(x0, x1), top - 0.4, zb[0]), (max(x0, x1), top, zb[1] - 0.05), "FloorConcrete", "Floor", level)
                edge = x0
                solid(f"Core{core}{level}_F2n_{k}", (min(edge, edge - s * 0.05), top, zb[0]), (max(edge, edge - s * 0.05), top + 0.006, zb[1] - 0.05), "StairNosing", "Decor", level)
            lo, hi = sorted((c["flight_end"], c["outer"]))
            solid(f"Core{core}{level}_Mid", (lo, mid_y - 0.25, plan.CORE_Z[0] + plan.CORE_WALL / 2), (hi, mid_y, plan.CORE_Z[1] - plan.CORE_WALL / 2), "FloorConcrete", "Floor", level)
            # Where the stair goes, on the wall beside the mid landing.
            name = plan.LEVEL_NAMES[level + 1] if level + 1 < plan.LEVELS else "ROOF"
            sign = LIB["text_label"](f"Core{core}{level}_UpSign", f"UP: {name}", (c["flight_end"] + c["outer"]) / 2.0,
                                     mid_y + 1.5, plan.CORE_Z[1] - plan.CORE_WALL / 2 - 0.012, 180.0, size=0.22, mat="SignWhite")
            tag(sign, "Decor", level)
        # Where a core stops, its top landing looks down the well: a solid balustrade closes it off.
        tops = [level for level in range(plan.LEVELS + 1)
                if level >= 1 and (level == plan.LEVELS or plan.UP[core][level] is None)
                and (level < plan.LEVELS or plan.STAIR_HOUSE[0] == core) and plan.UP[core][level - 1] is not None]
        for level in tops:
            floor = plan.floor_y(level)
            x = c["landing_end"]
            painted(f"Core{core}{level}_Balustrade", (min(x, x + s * 0.12), floor, zf[0] - 0.05),
                    (max(x, x + s * 0.12), floor + 1.1, zf[1]), floor, min(level, plan.LEVELS - 1))
            solid(f"Core{core}{level}_Handrail", (min(x, x + s * 0.12) - 0.03, floor + 1.1, zf[0] - 0.05),
                  (max(x, x + s * 0.12) + 0.03, floor + 1.16, zf[1]), "Chrome", "Decor", min(level, plan.LEVELS - 1))
        # The floor's number on each landing, facing the corridor.
        for level in range(plan.LEVELS):
            words = f"STAIR {core}  -  {plan.LEVEL_NAMES[level]}"
            y = plan.floor_y(level) + 2.2
            sign_z = plan.CORE_Z[1] - plan.CORE_WALL / 2 - 0.012
            obj = LIB["text_label"](f"Core{core}{level}_FloorSign", words, (c["inner"] + c["landing_end"]) / 2.0, y, sign_z, 180.0, size=0.16, mat="SignWhite")
            tag(obj, "Decor", level)


def build_blockages() -> None:
    corridor_mid = (plan.CORRIDOR[0] + plan.CORRIDOR[1]) / 2.0
    for (core, level), how in plan.BLOCKAGE.items():
        c = plan.core_x(core)
        s = c["s"]
        base = plan.floor_y(level)
        foot = c["landing_end"]
        zf0, zf1 = corridor_mid + 0.05, plan.CORE_Z[1] - plan.CORE_WALL / 2
        if how == "collapse":
            # The stair above has come down onto this one: slabs leaning across it, a heap of broken concrete over
            # its first steps, bent rebar, ceiling tiles, and an invisible block so nobody climbs the heap.
            import random
            rng = random.Random(f"{core}{level}")
            mid_z = (zf0 + zf1) / 2.0
            for k, (dx, dy, dz, w, h, d, yaw, pitch, roll) in enumerate((
                    (1.0, 0.2, 0.0, 2.1, 0.22, 1.5, 4.0, -38.0, 6.0), (1.9, 0.9, 0.2, 1.6, 0.22, 1.2, -12.0, -22.0, -9.0),
                    (0.4, 0.0, -0.3, 1.2, 0.2, 0.9, 30.0, 14.0, 20.0))):
                slab = kit(f"Core{core}{level}_Slab{k}")
                slab.box((-w / 2, 0.0, -d / 2), (w / 2, h, d / 2), "Concrete")
                slab.box((-w / 2, h, -d / 2 + 0.05), (w / 2 - 0.3, h + 0.012, d / 2 - 0.05), "FloorConcrete")
                lifted("Interior", level, slab.build, foot + s * dx, mid_z + dz, yaw, plan.FLOOR0 + dy, pitch=pitch, roll=roll)
            for k in range(30):
                size = rng.uniform(0.18, 0.75)
                chunk = kit(f"Core{core}{level}_Chunk{k}")
                chunk.box((-size / 2, 0.0, -size * 0.4), (size / 2, size * rng.uniform(0.45, 0.9), size * 0.4),
                          "Rubble" if k % 3 else "Concrete")
                reach = rng.uniform(-0.3, 1.9)
                lift = max(0.0, (reach - 0.1) / plan.TREAD * plan.RISE) * 0.8 + rng.uniform(0.0, 0.5)
                lifted("Interior", level, chunk.build, foot + s * reach, rng.uniform(zf0 + 0.15, zf1 - 0.15),
                       rng.uniform(0.0, 360.0), plan.FLOOR0 + lift, pitch=rng.uniform(-35.0, 35.0), roll=rng.uniform(-35.0, 35.0))
            for k in range(6):
                tile = kit(f"Core{core}{level}_Tile{k}")
                tile.box((-0.3, 0.0, -0.6), (0.3, 0.02, 0.6), "CeilingTile")
                lifted("Decor", level, tile.build, foot - s * rng.uniform(0.2, 1.4), rng.uniform(zf0, zf1 - 0.2),
                       rng.uniform(0.0, 360.0), plan.FLOOR0 + 0.01 + 0.03 * k, pitch=rng.uniform(-8.0, 8.0))
            for k in range(7):
                bar = kit(f"Core{core}{level}_Rebar{k}")
                bar.cylinder((0.0, 0.8, 0.0), 0.012, 1.6, "Rebar", axis="y", segments=6)
                lifted("Decor", level, bar.build, foot + s * (0.4 + 0.3 * k), zf0 + 0.3 + 0.45 * (k % 3), 23.0 * k,
                       plan.FLOOR0 + 0.5 + 0.1 * k, pitch=30.0 + 8 * k, roll=-15.0 + 9 * k)
            lo, hi = sorted((foot - s * 0.05, foot + s * 2.1))
            solid(f"Core{core}{level}_Blocker", (lo, base, zf0), (hi, base + 2.6, zf1), "Rubble", "Blocker", level)
        elif how == "barricade":
            # Plywood screwed across the foot of the flight, with beds and cabinets piled against it.
            x = foot + s * 0.05
            solid(f"Core{core}{level}_Plywood", (min(x, x + s * 0.05), base, zf0), (max(x, x + s * 0.05), base + 2.3, zf1), "Plywood", "Interior", level)
            lifted("Interior", level, LIB["gurney"], f"Core{core}{level}_BarricadeGurney", foot - s * 0.45, (zf0 + zf1) / 2.0, 90.0)
            # Piled in the flight's lane, clear of the landing you come up onto and of the door out.
            lifted("Interior", level, LIB["filing_cabinet"], f"Core{core}{level}_BarricadeCabinet", foot - s * 0.3, zf1 - 0.3, 90.0 * s)
            chair = kit(f"Core{core}{level}_BarricadeChair")
            chair.box((-0.25, 0.0, -0.25), (0.25, 0.45, 0.25), "Vinyl").box((-0.25, 0.45, -0.25), (0.25, 0.9, -0.2), "Vinyl")
            lifted("Interior", level, chair.build, foot - s * 0.95, zf0 + 0.75, 30.0, plan.FLOOR0 + 0.86, roll=70.0)
            words = LIB["text_label"](f"Core{core}{level}_Warning", "DON'T GO UP", foot + s * 0.04, base + 1.6,
                                      (zf0 + zf1) / 2.0, -90.0 * s, size=0.2, mat="SprayPaint")
            tag(words, "Decor", level)
            # More of the ward piled against it: a second trolley on its side, a mattress, a wheelchair.
            made = lifted("Interior", level, LIB["gurney"], f"Core{core}{level}_BarricadeGurney2", foot - s * 0.55,
                          zf1 - 0.5, 75.0)
            tilt_objects(made, (foot - s * 0.55, base, zf1 - 0.5), 75.0, 0.0, 88.0, base)
            mattress = kit(f"Core{core}{level}_BarricadeMattress")
            mattress.box((-0.95, 0.0, -0.45), (0.95, 0.16, 0.45), "Mattress")
            lifted("Interior", level, mattress.build, foot - s * 0.25, (zf0 + zf1) / 2.0, 90.0, plan.FLOOR0 + 0.9,
                   pitch=-62.0)
            made = lifted("Interior", level, LIB["wheelchair"], f"Core{core}{level}_BarricadeChair2", foot - s * 1.1,
                          zf1 - 0.45, 140.0)
            tilt_objects(made, (foot - s * 1.1, base, zf1 - 0.45), 140.0, 70.0, 0.0, base)


# ---- The outside ---------------------------------------------------------------------------------------
def build_exterior_details() -> None:
    # A band at every floor line, standing a little proud of the walls.
    for level in range(1, plan.LEVELS + 1):
        y = plan.floor_y(level) - plan.SLAB
        for (low, high) in (((plan.X0 - 0.06, y - 0.05, plan.Z1 - 0.01), (plan.X1 + 0.06, y + 0.32, plan.Z1 + 0.06)),
                            ((plan.X0 - 0.06, y - 0.05, plan.Z0 - 0.06), (plan.X1 + 0.06, y + 0.32, plan.Z0 + 0.01)),
                            ((plan.X0 - 0.06, y - 0.05, plan.Z0 - 0.06), (plan.X0 + 0.01, y + 0.32, plan.Z1 + 0.06)),
                            ((plan.X1 - 0.01, y - 0.05, plan.Z0 - 0.06), (plan.X1 + 0.06, y + 0.32, plan.Z1 + 0.06))):
            solid(f"Band{level}", low, high, "ExteriorBand", "Exterior", -1)
    # The entrance canopy on two columns, and its sign.
    solid("Canopy", (-4.2, 3.05, 0.0), (4.2, 3.3, 3.4), "ExteriorBand", "Exterior", -1)
    for x in (-3.7, 3.7):
        solid("CanopyColumn", (x - 0.14, 0.0, 2.9), (x + 0.14, 3.05, 3.18), "ExteriorRender", "Exterior", -1)
    tag(LIB["text_label"]("CanopySign", "MAIN ENTRANCE  -  EMERGENCY", 0.0, 3.18, 3.42, 0.0, size=0.2, mat="SignWhite"), "Exterior", -1)
    # The name over the door, lit red, and a green cross on the stair house.
    tag(LIB["text_label"]("HospitalSign", "HOSPITAL", 0.0, plan.ROOF_Y + 0.35, plan.Z1 + 0.04, 0.0, size=1.25, mat="SignLitRed"), "Exterior", -1)
    house = plan.core_x(plan.STAIR_HOUSE[0])
    cx = (house["inner"] + house["outer"]) / 2.0
    cy = plan.ROOF_Y + plan.STAIR_HOUSE[1] * 0.55
    face = plan.CORE_Z[1] + plan.CORE_WALL / 2 + 0.02
    solid("CrossV", (cx - 0.25, cy - 0.85, face), (cx + 0.25, cy + 0.85, face + 0.06), "SignLitGreen", "Exterior", -1)
    solid("CrossH", (cx - 0.85, cy - 0.25, face), (cx + 0.85, cy + 0.25, face + 0.06), "SignLitGreen", "Exterior", -1)
    # The path from the door to the sidewalk.
    solid("EntranceWalk", (-2.6, 0.0, 0.0), (2.6, 0.1, 19.6), "Concrete", "Walk", -1)
    # The stair house's roof.
    lo, hi = sorted((house["inner"] - house["s"] * 0.1, plan.X0 if house["s"] < 0 else plan.X1))
    solid("StairHouseRoof", (lo, plan.ROOF_Y + plan.STAIR_HOUSE[1], plan.CORE_Z[0] - 0.1),
          (hi, plan.ROOF_Y + plan.STAIR_HOUSE[1] + 0.25, plan.CORE_Z[1] + 0.1), "ExteriorBand", "Exterior", -1)


def build_roof() -> None:
    hx, hz, r = plan.HELIPAD
    y = plan.ROOF_Y
    pad = kit("Helipad")
    pad.cylinder((0.0, 0.02, 0.0), r, 0.04, "HelipadAsphalt", axis="y", segments=40)
    lifted("Roof", plan.LEVELS - 1, pad.build, hx, hz, 0.0, ROOF_BASE)
    ring = kit("HelipadRing")
    for k in range(40):
        angle = 2 * math.pi * k / 40
        ca, sa = math.cos(angle), math.sin(angle)
        # Short tangent dashes round the circle.
        ring.box((r * 0.82 * ca - 0.22, 0.045, r * 0.82 * sa - 0.22), (r * 0.82 * ca + 0.22, 0.06, r * 0.82 * sa + 0.22), "HelipadPaint")
    for low, high in (((-1.6, 0.045, -2.0), (-1.0, 0.06, 2.0)), ((1.0, 0.045, -2.0), (1.6, 0.06, 2.0)), ((-1.0, 0.045, -0.3), (1.0, 0.06, 0.3))):
        ring.box(low, high, "HelipadPaint")
    lifted("Decor", plan.LEVELS - 1, ring.build, hx, hz, 0.0, ROOF_BASE)
    lights = kit("HelipadLights")
    for k in range(12):
        angle = 2 * math.pi * k / 12
        x, z = r * 1.02 * math.cos(angle), r * 1.02 * math.sin(angle)
        lights.box((x - 0.09, 0.0, z - 0.09), (x + 0.09, 0.14, z + 0.09), "PadLight")
    lifted("Decor", plan.LEVELS - 1, lights.build, hx, hz, 0.0, ROOF_BASE)
    for k, (x, z, w, h, d) in enumerate(plan.ROOF_PLANT):
        unit = kit(f"RoofPlant{k}")
        unit.box((-w / 2, 0.0, -d / 2), (w / 2, h, d / 2), "ShelfSteel")
        unit.box((-w / 2 + 0.1, h, -d / 2 + 0.1), (w / 2 - 0.1, h + 0.08, d / 2 - 0.1), "Rubber")
        lifted("Roof", plan.LEVELS - 1, unit.build, x, z, 0.0, ROOF_BASE)
    mast = kit("RadioMast")
    mast.box((-0.12, 0.0, -0.12), (0.12, 8.0, 0.12), "ShelfSteel")
    mast.box((-0.3, 8.0, -0.3), (0.3, 8.5, 0.3), "BeaconRed")
    lifted("Roof", plan.LEVELS - 1, mast.build, 17.6, -16.6, 0.0, ROOF_BASE)


# ---- Dressing --------------------------------------------------------------------------------------------
def tilt_objects(objects: list, pivot: tuple, yaw: float, pitch: float, roll: float, floor: float) -> None:
    """Knocks things over: turns their meshes about pivot (pitch about their own x, roll about their own z, after
    their yaw), then sets the lowest point back on the floor."""
    from mathutils import Vector
    turn = (Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(yaw), 4, "Y")
            @ Matrix.Rotation(math.radians(pitch), 4, "X") @ Matrix.Rotation(math.radians(roll), 4, "Z")
            @ Matrix.Rotation(math.radians(-yaw), 4, "Y") @ Matrix.Translation(-Vector(pivot)))
    meshes = [obj for obj in objects if obj.type == "MESH"]
    for obj in meshes:
        obj.data.transform(turn)
    low = min((v.co.y for obj in meshes for v in obj.data.vertices), default=floor)
    if low < floor:
        for obj in meshes:
            obj.data.transform(Matrix.Translation((0.0, floor - low + 0.004, 0.0)))


def build_words(e: dict) -> None:
    words = LIB["text_label"](e["name"], e["text"], e["x"], plan.floor_y(e["level"]) + e["y"], e["z"], e["yaw"],
                              size=e["size"], mat=e["mat"])
    tag(words, "Decor", e["level"])


def build_sign(e: dict) -> None:
    """A blue plate with its lines in white; hanging ones hang from the ceiling on two rods and read both ways."""
    lines, back = e["sign"], e.get("back")
    size = 0.13 if e["hanging"] else 0.068
    rows = max(len(lines), len(back) if back else 0)
    height = rows * size * 1.45 + 0.1
    width = e["width"]
    plate = kit(e["name"] + "Plate")
    plate.box((-width / 2, 0.0, -0.015), (width / 2, height, 0.015), "SignBlue")
    if e["hanging"]:
        rods = plan.CEILING - e["y"] - height
        for x in (-width / 2 + 0.12, width / 2 - 0.12):
            plate.box((x - 0.01, height, -0.01), (x + 0.01, height + rods, 0.01), "Chrome")
    base = plan.FLOOR0 + e["y"]
    lifted("Decor", e["level"], plate.build, e["x"], e["z"], e["yaw"], base)
    for words, lz, turn in ((lines, 0.017, 0.0), (back, -0.017, 180.0)):
        if not words:
            continue
        lifted("Decor", e["level"], LIB["kit_text"], e["name"] + ("Back" if turn else "Front"), "\n".join(words),
               e["x"], e["z"], e["yaw"], base, (0.0, height / 2.0, lz), size=size, turn=turn)


def build_papers(e: dict) -> None:
    import random
    rng = random.Random(e["seed"])
    for k in range(e["papers"]):
        sheet = kit(f"{e['name']}_{k}")
        sheet.box((-0.105, 0.0, -0.15), (0.105, 0.002, 0.15), "Paper")
        r = e["radius"] * math.sqrt(rng.random())
        a = rng.uniform(0.0, math.tau)
        lifted("Decor", e["level"], sheet.build, e["x"] + r * math.cos(a), e["z"] + r * math.sin(a),
               rng.uniform(0.0, 360.0), plan.FLOOR0 + 0.002 + 0.001 * k)


def build_fixture(e: dict) -> None:
    if e["fixture"] == "panel":
        lifted("Decor", e["level"], LIB["ceiling_panel"], e["name"], e["x"], e["z"], 90.0, lit=True)
        return
    lamp = kit(e["name"])
    lamp.box((-0.2, 0.0, -0.08), (0.2, 0.1, 0.08), "ExitHousing")
    lamp.box((-0.16, -0.012, -0.06), (0.16, 0.0, 0.06), "ExitGlow")
    lifted("Decor", e["level"], lamp.build, e["x"], e["z"], 90.0, plan.FLOOR0 + plan.CEILING - 0.1)


def build_bodybag(e: dict) -> None:
    lifted("Interior", e["level"], LIB["gurney"], e["name"] + "Gurney", e["x"], e["z"], e["yaw"])
    bag = kit(e["name"])
    bag.box((-0.92, 0.86, -0.25), (0.92, 1.08, 0.25), "BodyBag")
    bag.box((-0.8, 1.08, -0.2), (0.75, 1.16, 0.2), "BodyBag")
    bag.box((0.55, 1.08, -0.16), (0.88, 1.2, 0.16), "BodyBag")
    bag.box((-0.85, 1.161, -0.012), (0.85, 1.168, 0.012), "Chrome")
    lifted("Interior", e["level"], bag.build, e["x"], e["z"], e["yaw"])


def build_dressing(furnishing) -> None:
    catalog = LIB["load_dressing_catalog"]()
    api = LIB["dressing_api"]()
    special = {"text": build_words, "sign": build_sign, "papers": build_papers, "fixture": build_fixture,
               "bodybag": build_bodybag}
    for entry in furnishing.placements:
        level = entry["level"]
        kind = next((k for k in special if k in entry), None)
        if kind is not None:
            special[kind](entry)
            continue
        if "prop" in entry:
            if entry["prop"] not in catalog:
                print("alt hospital: unknown prop", entry["prop"])
                continue
            placed = dict(entry)
            if entry.get("y") is not None:
                placed["y"] = plan.FLOOR0 + entry["y"]
            made = lifted("Interior", level, LIB["place_dressing"], catalog, api, placed)
        else:
            group = "Decor" if entry["kit"] in KIT_DECOR else "Interior"
            made = lifted(group, level, LIB[entry["kit"]], entry["name"], entry["x"], entry["z"], entry["yaw"], **entry["opts"])
        if entry.get("tilt"):
            pitch, roll = entry["tilt"]
            floor = plan.floor_y(level)
            tilt_objects(made, (entry["x"], floor, entry["z"]), entry["yaw"], pitch, roll, floor)


# ---- Markers -------------------------------------------------------------------------------------------
def write_markers(furnishing) -> None:
    lights = []
    for name, level, x, z, color, energy, reach, mode, *height in plan.LIGHTS:
        over = height[0] if height else plan.CEILING - 0.12
        lights.append(dict(name="L_" + name, level=level, mode=mode, position=[x, round(plan.floor_y(level) + over, 3), z],
                           color=list(color), energy=energy, range=reach))
    rooms = [dict(level=r[0], kind=r[1], name=r[2], rect=[r[3], r[4], r[5], r[6]]) for r in plan.ROOMS]
    data = dict(
        levels=[plan.floor_y(level) for level in range(plan.LEVELS)], roof_y=plan.ROOF_Y, storey=plan.STOREY,
        ceiling=plan.CEILING, footprint=[plan.X0, plan.X1, plan.Z0, plan.Z1],
        rooms=rooms, hiding_spots=furnishing.hiding, bottles=furnishing.bottles, documents=furnishing.documents,
        decals=furnishing.decals,
        lights=lights, points={k: list(v) for k, v in plan.POINTS.items()},
        clawman_posts={str(k): list(v) for k, v in plan.CLAWMAN_POSTS.items()},
        helicopter=dict(position=[plan.HELICOPTER[0], plan.ROOF_Y, plan.HELICOPTER[1]], yaw=plan.HELICOPTER[2]),
        up=plan.UP, core_doors=plan.CORE_DOOR, blocked=[[core, level, how] for (core, level), how in plan.BLOCKAGE.items()],
        cores={core: dict(z=list(plan.CORE_Z), **plan.core_x(core)) for core in ("A", "B")},
    )
    MARKERS.parent.mkdir(parents=True, exist_ok=True)
    MARKERS.write_text(json.dumps(data, indent=1), encoding="utf-8", newline="\n")


# ---- Merge and export ----------------------------------------------------------------------------------
def merge_and_export() -> dict:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups: dict = {}
    for obj in list(bpy.data.objects):
        if obj.type not in ("MESH", "FONT") or "group" not in obj:
            continue
        group, level = obj["group"], int(obj["level"])
        if group == "Floor":
            key = f"GroundFloor_L{level}"
        elif group in ("Interior", "Decor"):
            key = f"{group}_L{max(level, 0)}"
        elif group == "Roof":
            key = "RoofFloor"
        elif group == "Walk":
            key = "EntranceWalk"
        elif group == "Blocker":
            key = f"Blocker_L{max(level, 0)}"
        else:
            key = "Exterior"
        groups.setdefault(key, []).append(obj)
    made = {}
    meshes = {}
    for key, members in sorted(groups.items()):
        merged = bmesh.new()
        materials: list = []
        for obj in members:
            data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
            data.transform(obj.matrix_world)
            remap = []
            for material in data.materials:
                if material not in materials:
                    materials.append(material)
                remap.append(materials.index(material))
            for polygon in data.polygons:
                polygon.material_index = remap[polygon.material_index] if remap else 0
            merged.from_mesh(data)
            bpy.data.meshes.remove(data)
        mesh = bpy.data.meshes.new("merged_" + key)
        merged.to_mesh(mesh)
        merged.free()
        for material in materials:
            mesh.materials.append(material)
        meshes[key] = mesh
        made[key] = (len(members), len(mesh.polygons))
    # Every source object goes before the merged ones take their names (a source could be named like one).
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for key, mesh in meshes.items():
        mesh.name = key
        target = bpy.data.objects.new(key, mesh)
        bpy.context.scene.collection.objects.link(target)
        assert target.name == key, target.name
    for obj in bpy.data.objects:
        obj.select_set(True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", export_apply=True, use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_animations=False,
                              export_cameras=False, export_lights=False)
    return made


def build(export: bool = True) -> dict:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    problems = plan.check()
    if problems:
        raise SystemExit("alt hospital plan problems:\n" + "\n".join(problems))
    furnishing = dressing.build()
    for wall in plan.all_walls():
        if wall["level"] != -1:
            build_wall(wall)
            continue
        # A full-height core wall, built a storey at a time so each storey's lights reach only its part. The
        # part above the roof (core A's stair house) is outside on one face: it is built as a stair house wall.
        for level in range(plan.LEVELS + 1):
            y0 = wall["y0"] if level == 0 else plan.floor_y(level)
            y1 = plan.floor_y(level + 1) if level < plan.LEVELS else wall["y1"]
            y1 = min(y1, wall["y1"])
            if y1 - y0 <= 1e-3:
                continue
            part = dict(wall, id=f"{wall['id']}_{level}", y0=y0, y1=y1)
            if level < plan.LEVELS:
                part.update(level=level, outside=False)
            else:
                part.update(level=plan.LEVELS - 1, outside=True)
            build_wall(part)
    build_floors()
    build_ceilings()
    build_stairs()
    build_blockages()
    build_exterior_details()
    build_roof()
    build_dressing(furnishing)
    write_markers(furnishing)
    return merge_and_export() if export else {}


if __name__ == "__main__":
    summary = build()
    for key, (count, faces) in summary.items():
        print("MESH %-16s %5d objects -> %6d faces" % (key, count, faces))
    print("GLB", GLB)
    print("MARKERS", MARKERS)
