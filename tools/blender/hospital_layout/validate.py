"""Validate the hospital layout and its equipment: geometry, clearances, navigation, test rays,
sightlines and bottle flight, using the hospital-local game coordinates of layout.py.

python tools/blender/hospital_layout/validate.py [--files dressing_rules,dressing_west]
(exit code 1 when there are problems; --files limits which dressing_*.py files are checked)

Origin: the "horror" designer's checker (Oct 23, 2026 design panel), extended for the
hospital_dressing equipment placed by dressing_*.py.
"""
import importlib.util
import math
import sys
from collections import deque
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import layout as L  # noqa: E402

FLOOR = L.FLOOR
FX0, FX1, FZ0, FZ1 = -20.10, 17.70, -9.30, -0.30
problems = []
RULES = ("GroundFloor", "CeilingGrid", "CeilingLightFixtures", "InteriorDoorLeaves", "SkirtingAndCornerGuards", "WindowSillBoards")
CEILING_Y = 2.95  # underside of the built drop ceiling (build_hospital_interior.CEILING_Y)
notes = []


def problem(msg):
    problems.append(msg)


# ------------------------------------------------------------------ boxes
class Box:
    def __init__(self, name, x0, x1, y0, y1, z0, z1, kind, block=True):
        self.name, self.kind, self.block = name, kind, block
        self.x0, self.x1 = min(x0, x1), max(x0, x1)
        self.y0, self.y1 = min(y0, y1), max(y0, y1)
        self.z0, self.z1 = min(z0, z1), max(z0, z1)

    def overlaps(self, o, tol=0.004):
        return (self.x0 < o.x1 - tol and o.x0 < self.x1 - tol and self.y0 < o.y1 - tol and o.y0 < self.y1 - tol
                and self.z0 < o.z1 - tol and o.z0 < self.z1 - tol)

    def __repr__(self):
        return f"{self.name}[x {self.x0:.2f}..{self.x1:.2f} y {self.y0:.2f}..{self.y1:.2f} z {self.z0:.2f}..{self.z1:.2f}]"


def wall_boxes(w):
    out = []
    x1, z1, x2, z2, t, h = w["x1"], w["z1"], w["x2"], w["z2"], w["thickness"], w["height"]
    along_x = abs(z1 - z2) < 1e-6
    length = abs(x2 - x1) if along_x else abs(z2 - z1)
    sx = 1 if x2 >= x1 else -1
    sz = 1 if z2 >= z1 else -1

    def box_for(a0, a1, y0, y1, label):
        if a1 - a0 < 1e-6 or y1 - y0 < 1e-6:
            return
        if along_x:
            out.append(Box(w["id"] + label, x1 + sx * a0, x1 + sx * a1, y0, y1, z1 - t / 2, z1 + t / 2, "wall"))
        else:
            out.append(Box(w["id"] + label, x1 - t / 2, x1 + t / 2, y0, y1, z1 + sz * a0, z1 + sz * a1, "wall"))

    ops = sorted(w["openings"], key=lambda o: o["center_along"])
    cursor = 0.0
    top = FLOOR + h
    for o in ops:
        a0, a1 = o["center_along"] - o["width"] / 2, o["center_along"] + o["width"] / 2
        if a0 < cursor - 1e-6 or a1 > length + 1e-6:
            problem(f"opening out of range / overlapping in {w['id']}: {o}")
        box_for(cursor, a0, FLOOR, top, "")
        box_for(a0, a1, FLOOR, o["sill"], ":sill")
        box_for(a0, a1, o["head"], top, ":head")
        if o.get("door_state") == "locked_blocked":
            box_for(a0, a1, o["sill"], o["head"], ":closed")
        cursor = a1
    box_for(cursor, length, FLOOR, top, "")
    return out


def rotated_extent(w, d, rot):
    r = math.radians(rot)
    c, s = abs(math.cos(r)), abs(math.sin(r))
    return w * c + d * s, w * s + d * c


WALLS = [b for w in L.walls for b in wall_boxes(w)]

OBJS = []
for o in L.objects:
    w, h, d = o["size"]
    if o.get("segments"):
        for (a, b) in o["segments"]:
            OBJS.append(Box(o["name"], a, b, o["y"], o["y"] + h, o["z"] - d / 2, o["z"] + d / 2, o["kind"], o["block"]))
        continue
    if o["name"] == "EntranceDoorFrame":
        OBJS.append(Box(o["name"], -11.76, -11.68, 0.12, 2.70, -0.42, -0.30, o["kind"]))
        OBJS.append(Box(o["name"], -8.72, -8.64, 0.12, 2.70, -0.42, -0.30, o["kind"]))
        OBJS.append(Box(o["name"], -11.76, -8.64, 2.50, 2.70, -0.42, -0.30, o["kind"]))
        continue
    ex, ez = rotated_extent(w, d, o["rotation_deg"])
    OBJS.append(Box(o["name"], o["x"] - ex / 2, o["x"] + ex / 2, o["y"], o["y"] + h, o["z"] - ez / 2, o["z"] + ez / 2, o["kind"], o["block"]))

HIDE_MODEL = {  # local x extent, height, local z range (model), collision depth
    "hiding_locker": (0.624, 2.0, (-0.28, 0.33)),
    "hiding_closet": (1.16, 2.06, (-0.31, 0.36)),
    "hiding_bed": (2.08, 1.08, (-0.47, 0.47)),
}


def local_to_world(mx, mz, rot, lx, lz):
    r = math.radians(rot)
    # Godot: basis X -> (cos, 0, -sin), Z -> (sin, 0, cos)
    return mx + lx * math.cos(r) + lz * math.sin(r), mz - lx * math.sin(r) + lz * math.cos(r)


def local_box(m, lx0, lx1, lz0, lz1, y0, y1, name, kind, block=True):
    pts = [local_to_world(m["x"], m["z"], m["rotation_deg"], lx, lz) for lx in (lx0, lx1) for lz in (lz0, lz1)]
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    return Box(name, min(xs), max(xs), y0, y1, min(zs), max(zs), kind, block)


MARKS = []
SPOTS = []
for m in L.markers:
    if m["type"] in HIDE_MODEL:
        wx, hh, (z0, z1) = HIDE_MODEL[m["type"]]
        b = local_box(m, -wx / 2, wx / 2, z0, z1, m["y"], m["y"] + hh, m["name"], m["type"])
        MARKS.append(b)
        SPOTS.append((m, b))
    elif "foot" in m:
        w, h, d = m["foot"]
        b = local_box(m, -w / 2, w / 2, -d / 2, d / 2, m["y"], m["y"] + h, m["name"], m["type"], m["block"])
        MARKS.append(b)

# ------------------------------------------------------------------ equipment (hospital_dressing)
def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CATALOG = load_module(HERE.parent / "hospital_dressing" / "catalog.py", "hospital_dressing_catalog").load()
ONLY = sys.argv[sys.argv.index("--files") + 1].split(",") if "--files" in sys.argv else []
ENTRIES = []
for path in sorted(HERE.glob("dressing_*.py")):
    if ONLY and path.stem not in ONLY:
        continue
    ENTRIES += [dict(e, source=path.stem) for e in load_module(path, "hospital_" + path.stem).dressing]
DRESS = []         # (entry, spec, box)
SUPPORT = {}       # dressing name -> name of the object it rests on or inside ("on")
seen_names = set()
for e in ENTRIES:
    spec = CATALOG.get(e["prop"])
    if spec is None:
        problem(f"{e['source']}: unknown prop {e['prop']!r} for {e['name']}")
        continue
    if e["name"] in seen_names:
        problem(f"{e['source']}: duplicate dressing name {e['name']}")
    seen_names.add(e["name"])
    w, h, d = spec["size"]
    if e.get("y") is not None:
        y = e["y"]
    elif spec["mount"] == "ceiling":
        y = CEILING_Y - h
    elif spec["mount"] == "wall":
        y = spec["y"]
    else:
        y = FLOOR
    if spec["mount"] == "surface" and e.get("y") is None:
        problem(f"{e['name']}: surface props need an explicit y")
    m = {"x": e["x"], "z": e["z"], "rotation_deg": e.get("yaw", 0.0)}
    collide = spec.get("collide", True)
    b = local_box(m, -w / 2, w / 2, -d / 2, d / 2, y, y + h, e["name"], "dressing:" + e["prop"], collide)
    DRESS.append((e, spec, b))
    if e.get("on"):
        SUPPORT[e["name"]] = e["on"]
DRESS_SOLID = [b for _e, _s, b in DRESS if b.block]
DRESS_DECOR = [b for _e, _s, b in DRESS if not b.block]
OBJS += DRESS_SOLID
ALL = WALLS + OBJS + MARKS

# ------------------------------------------------------------------ checks: footprint and wall intersections
EXEMPT_WALL = {"GroundFloor", "CeilingGrid", "CeilingLightFixtures", "StairDoorChained", "InteriorDoorLeaves", "WardCurtainTracks", "SkirtingAndCornerGuards", "WindowSillBoards"}
for b in OBJS + MARKS:
    if b.name in RULES:
        continue
    if b.x0 < FX0 - 0.001 or b.x1 > FX1 + 0.001 or b.z0 < FZ0 - 0.001 or b.z1 > FZ1 + 0.001:
        problem(f"outside footprint: {b}")
    if b.name in EXEMPT_WALL:
        continue
    for wb in WALLS:
        if b.overlaps(wb):
            problem(f"intersects wall: {b} x {wb}")

# pairwise object intersections (blocking or not, excluding allowed stacks)
ALLOWED_PAIRS = {
    frozenset({"P_ExamChair", "P_SurgicalLamp"}),
    frozenset({"EntranceGlassShards", "LobbyWheelchair"}),
    frozenset({"EntranceGlassShards", "EntranceLeafEast_Fallen"}),
    frozenset({"P_WardBed3Decor", "CarrieBelongings"}),
    frozenset({"P_ProcedureBaseCabinet", "P_ProcedureHutch"}),
    frozenset({"ShelterCot_B1", "ShelterKidBelongings"}),
    frozenset({"WardCurtainTracks", "WardCubicleCurtain_Bed3"}),
    frozenset({"LinenShelving", "P_LinenWhiteJar"}),
    frozenset({"MainDoorBarricade", "VendingMachine"}),
    frozenset({"P_StoresBaseCabinet", "P_StoresHutch"}),
    frozenset({"WardCurtainTracks", "WardBunchedCurtain_Bed1"}),
}
items = [b for b in OBJS + MARKS if b.name not in RULES]
for i in range(len(items)):
    for j in range(i + 1, len(items)):
        a, c = items[i], items[j]
        if a.name == c.name:
            continue
        if frozenset({a.name, c.name}) in ALLOWED_PAIRS:
            continue
        if SUPPORT.get(a.name) == c.name or SUPPORT.get(c.name) == a.name:
            continue
        if a.overlaps(c, tol=0.002):
            problem(f"objects overlap: {a} x {c}")

# ------------------------------------------------------------------ perimeter openings vs spec
SPEC = {
    "P_Front": [(-19.33, -16.85, 0.54, 2.10), (-15.67, -13.19, 0.54, 2.10), (-12.01, -11.76, 0.54, 2.10), (-11.76, -8.64, 0.12, 2.70),
                (-8.35, -5.87, 0.54, 2.10), (-3.96, -1.56, 0.12, 1.80), (0.83, 2.38, 0.54, 1.98), (3.31, 4.85, 0.54, 1.98),
                (5.78, 7.33, 0.54, 1.98), (8.27, 9.82, 0.54, 1.98), (10.75, 12.29, 0.54, 1.98), (13.22, 14.77, 0.54, 1.98)],
    "P_Back": [(0.82, 2.36, 0.54, 1.98), (3.29, 4.83, 0.54, 1.98), (5.76, 7.30, 0.54, 1.98), (8.23, 9.77, 0.54, 1.98),
               (10.70, 12.25, 0.54, 1.98), (13.17, 14.71, 0.54, 1.98), (15.64, 17.18, 0.54, 1.98)],
    "P_East": [(-1.78, -0.56, 0.54, 1.98), (-4.48, -3.20, 0.54, 1.98), (-6.64, -5.36, 0.54, 1.98), (-8.80, -7.52, 0.54, 1.98)],
    "P_West": [],
}
for w in L.walls:
    if w["id"] not in SPEC:
        continue
    got = []
    for o in w["openings"]:
        a0, a1 = o["center_along"] - o["width"] / 2, o["center_along"] + o["width"] / 2
        if w["id"] in ("P_Front", "P_Back"):
            got.append((round(w["x1"] + a0, 3), round(w["x1"] + a1, 3), o["sill"], o["head"]))
        else:
            got.append((round(w["z1"] - a1, 3), round(w["z1"] - a0, 3), o["sill"], o["head"]))
    got.sort()
    spec = sorted(SPEC[w["id"]])
    if len(got) != len(spec) or any(max(abs(g[k] - s[k]) for k in range(4)) > 0.006 for g, s in zip(got, spec)):
        problem(f"perimeter openings mismatch {w['id']}: got {got} spec {spec}")

# door widths for Clawman
for w in L.walls:
    for o in w["openings"]:
        if o["kind"] == "door" and o["door_state"] != "locked_blocked" and o["width"] < 1.5 - 1e-6:
            notes.append(f"door narrower than 1.5 in {w['id']}: {o['width']}")

# ------------------------------------------------------------------ ray casting
def ray_hits(p, q, boxes, skip=()):
    hits = []
    d = [q[i] - p[i] for i in range(3)]
    for b in boxes:
        if b.name in skip:
            continue
        lo = (b.x0, b.y0, b.z0)
        hi = (b.x1, b.y1, b.z1)
        t0, t1 = 0.0, 1.0
        ok = True
        for i in range(3):
            if abs(d[i]) < 1e-12:
                if p[i] <= lo[i] or p[i] >= hi[i]:
                    ok = False
                    break
            else:
                a = (lo[i] - p[i]) / d[i]
                c = (hi[i] - p[i]) / d[i]
                a, c = min(a, c), max(a, c)
                t0, t1 = max(t0, a), min(t1, c)
                if t0 > t1:
                    ok = False
                    break
        if ok:
            hits.append((t0, b))
    hits.sort(key=lambda h: h[0])
    return hits


COLLIDERS = [b for b in ALL if b.name not in RULES]
entry = ray_hits((-10.2, 1.5, 2.0), (-10.2, 1.5, -3.0), COLLIDERS)
if entry:
    problem(f"entrance ray blocked by {entry[0][1]}")
else:
    notes.append("entrance ray x=-10.2 y=1.5 z +2..-3: clear")
cover = ray_hits((-5.0, 1.5, -3.0), (-5.0, 1.5, -7.0), COLLIDERS)
if not cover or cover[0][1].kind != "wall":
    problem(f"cover ray not blocked by a wall: {cover[:1]}")
else:
    notes.append(f"cover ray x=-5 hits {cover[0][1].name} at z={-3.0 - 4.0 * cover[0][0]:.2f}")
# legacy facade ray (gameplay_refinement_smoke): x=-15, y=1.7, z -2..+1 (glass is in the shell, not here)
facade = ray_hits((-15.0, 1.7, -2.0), (-15.0, 1.7, 1.0), COLLIDERS)
notes.append(f"facade ray x=-15 y=1.7 interior hits: {facade[0][1].name if facade else 'none (relies on shell glass collision)'}")

# RecordsLocker sight test (hospital_hiding_map_smoke): claw at (10.5,0.12,-6.3) eye +1.3; player camera at exit +1.65
for m, b in SPOTS:
    if m["name"].startswith("RecordsLocker"):
        ex, ez = local_to_world(m["x"], m["z"], m["rotation_deg"], 0, 0.8)
        hits = ray_hits((10.5, FLOOR + 1.3, -6.3), (ex, FLOOR + 1.65, ez), COLLIDERS)
        dist = math.dist((10.5, FLOOR, -6.3), (ex, FLOOR, ez))
        if hits or dist >= 7.0:
            problem(f"RecordsLocker sight test fails for {m['name']}: hits {hits[:1]} dist {dist:.2f}")
        else:
            notes.append(f"{m['name']}: clear sight from (10.5,-6.3), {dist:.2f} m")

# ------------------------------------------------------------------ navigation grid
RES = 0.05
GX0, GX1, GZ0, GZ1 = -20.1, 17.7, -9.3, 6.0
nx = int(round((GX1 - GX0) / RES))
nz = int(round((GZ1 - GZ0) / RES))
xs = GX0 + (np.arange(nx) + 0.5) * RES
zs = GZ0 + (np.arange(nz) + 0.5) * RES
X, Z = np.meshgrid(xs, zs, indexing="ij")
inside = (X > FX0) & (X < FX1) & (Z > FZ0) & (Z < FZ1)
outside_walk = (X > -12.6) & (X < -7.8) & (Z >= FZ1) & (Z < 6.0)  # walkway in front of the entrance
walkable = inside | outside_walk
AGENT_R = 0.45  # 0.4 m agent radius plus a margin for the 0.2 m navmesh cells
blocked = np.zeros_like(walkable)
nav_obstacles = [b for b in WALLS + OBJS + MARKS if b.block and b.y0 < FLOOR + 1.9 and b.y1 > FLOOR + 0.3]
for b in nav_obstacles:
    # signed distance from cell centre to the box footprint
    dx = np.maximum(np.maximum(b.x0 - X, X - b.x1), 0)
    dz = np.maximum(np.maximum(b.z0 - Z, Z - b.z1), 0)
    blocked |= (dx * dx + dz * dz) <= AGENT_R * AGENT_R
# the facade outside the entrance opening is solid: block the front lining strip except the opening
for b in WALLS:
    if b.name.startswith("P_"):
        pass
nav = walkable & ~blocked
# also erode near the footprint boundary (perimeter linings handle it already)


def label(grid):
    lab = np.zeros(grid.shape, dtype=np.int32)
    cur = 0
    for i in range(grid.shape[0]):
        for j in range(grid.shape[1]):
            if grid[i, j] and lab[i, j] == 0:
                cur += 1
                lab[i, j] = cur
                dq = deque([(i, j)])
                while dq:
                    a, c = dq.popleft()
                    for da, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        u, v = a + da, c + dc
                        if 0 <= u < grid.shape[0] and 0 <= v < grid.shape[1] and grid[u, v] and lab[u, v] == 0:
                            lab[u, v] = cur
                            dq.append((u, v))
    return lab


try:
    from scipy import ndimage
    LAB, _ = ndimage.label(nav)
except Exception:
    LAB = label(nav)


def snap(x, z):
    i = int((x - GX0) / RES)
    j = int((z - GZ0) / RES)
    best = None
    rad = 40
    for u in range(max(0, i - rad), min(nx, i + rad + 1)):
        for v in range(max(0, j - rad), min(nz, j + rad + 1)):
            if nav[u, v]:
                d = math.hypot(xs[u] - x, zs[v] - z)
                if best is None or d < best[0]:
                    best = (d, u, v)
    return best


spawn = next(m for m in L.markers if m["type"] == "clawman_spawn")
s = snap(spawn["x"], spawn["z"])
if s is None or s[0] > 0.05:
    problem(f"Clawman spawn not on navmesh: {s}")
SPAWN_LAB = LAB[s[1], s[2]] if s else -1


def reach(name, x, z, tol):
    r = snap(x, z)
    if r is None:
        problem(f"{name}: no navmesh nearby")
        return
    d, u, v = r
    ok = LAB[u, v] == SPAWN_LAB and d <= tol
    (notes if ok else problems).append(f"{name}: nearest nav {d:.2f} m, connected={LAB[u, v] == SPAWN_LAB}")


# HidingSpot.hunter_position(): 1.25 m beyond the exit, shrinking by 0.15 m while the point is
# off the navigation mesh, and 0.8 m at the least; hospital_hiding_map_smoke needs the
# Clawman's route to end within 0.45 m of it.
for m, b in SPOTS:
    dist = 1.1 if m["type"] == "hiding_bed" else 0.8
    for standoff in (1.25, 1.10, 0.95, 0.80):
        gx, gz = local_to_world(m["x"], m["z"], m["rotation_deg"], 0, dist + standoff)
        r = snap(gx, gz)
        on_mesh = r is not None and LAB[r[1], r[2]] == SPAWN_LAB and r[0] <= (0.45 if standoff == 0.80 else 0.15)
        if on_mesh:
            notes.append(f"hunter goal {m['name']}: {standoff:.2f} m beyond the exit ({gx:.2f},{gz:.2f}), route ends {r[0]:.2f} m away")
            break
    else:
        problem(f"hunter goal {m['name']}: no reachable point 0.8-1.25 m beyond the exit")
reach("records test point (11,-6.5)", 11.0, -6.5, 0.3)
reach("lobby test point (-10.2,-3)", -10.2, -3.0, 0.6)
reach("outside trigger (-10.2,5)", -10.2, 5.0, 0.3)
reach("opening_story pursuit point (spawn.x-9, spawn.z)", spawn["x"] - 9, spawn["z"], 0.3)
reach("throw test player (-8,-3)", -8.0, -3.0, 0.3)
reach("claw test position (10.5,-6.3)", 10.5, -6.3, 0.3)
# The cot dormitory and medical stores lie beyond the Clawman's territory (28 m from its post
# even counting lure noise), behind the 1 m aisle between cot rows that the navigation mesh
# need not cross; they are reported, not required.
for name, (x, z) in {"office": (-9.4, -6.5), "linen": (-1.6, -6.2), "ward aisle": (4.0, -6.2),
                     "procedure": (3.0, -2.2), "procedure via D1": (0.9, -1.4), "nurse": (8.0, -1.4), "day room": (13.0, -2.3), "lounge": (15.0, -6.0),
                     "shelter": (-14.0, -2.0), "records desk area": (9.0, -7.3), "stair void (must be False)": (-5.8, -7.0), "isolation void (must be False)": (-13.0, -7.0)}.items():
    if "must be False" in name:
        r = snap(x, z)
        (problems if r and LAB[r[1], r[2]] == SPAWN_LAB else notes).append(f"room {name}: connected={bool(r and LAB[r[1], r[2]] == SPAWN_LAB)}")
        continue
    reach(f"room {name}", x, z, 0.3)
for name, (x, z) in {"stores (west wing, optional)": (-17.3, -6.0), "shelter dormitory (optional)": (-17.0, -2.8)}.items():
    r = snap(x, z)
    notes.append(f"room {name}: connected={bool(r and LAB[r[1], r[2]] == SPAWN_LAB)}")

# ------------------------------------------------------------------ hiding spot clearance (1.3 m in front, full width)
for m, b in SPOTS:
    wx, hh, (z0, z1) = HIDE_MODEL[m["type"]]
    zone = local_box(m, -wx / 2, wx / 2, z1, z1 + 1.3, FLOOR, FLOOR + 1.8, m["name"] + ":clear", "zone")
    for o in WALLS + OBJS + MARKS:
        if o.kind.startswith("dressing:") and not o.block:
            continue
        if o.name == m["name"] or o.name in RULES + ("WardCurtainTracks",):
            continue
        if o.y1 <= FLOOR + 0.02:
            continue
        if zone.overlaps(o, tol=0.001):
            problem(f"hiding clearance {m['name']} blocked by {o}")

# player exit capsule (radius 0.35, y 0.12..1.92) at exit position
for m, b in SPOTS:
    dist = 1.1 if m["type"] == "hiding_bed" else 0.8
    ex, ez = local_to_world(m["x"], m["z"], m["rotation_deg"], 0, dist)
    cap = Box(m["name"] + ":exitcap", ex - 0.35, ex + 0.35, FLOOR + 0.06, FLOOR + 1.86, ez - 0.35, ez + 0.35, "cap")
    for o in WALLS + OBJS + MARKS:
        if o.name == m["name"] or o.name in RULES + ("WardCurtainTracks",):
            continue
        if cap.overlaps(o, tol=0.001):
            problem(f"exit capsule of {m['name']} hits {o}")

# ------------------------------------------------------------------ surfaces under bottles/docs/raised props
SURF = OBJS + MARKS
for m in L.markers:
    if m["type"] in ("bottle", "document") or (m["type"] == "pack_prop" and m["y"] > FLOOR + 0.01 and m["name"] != "P_SurgicalLamp"):
        y = m["y"] - (0.0225 if m["type"] == "document" else 0.0)
        found = [b for b in SURF if b.name != m["name"] and abs(b.y1 - y) < 0.006 and b.x0 <= m["x"] <= b.x1 and b.z0 <= m["z"] <= b.z1]
        shelf = [o for o in L.objects if o["kind"] in ("shelving_unit",)]
        if not found:
            # shelving units have intermediate shelves at 0.22/0.62/1.02/1.42/1.82 (island to 1.42 + cap 1.62)
            for o in L.objects:
                if o["kind"] == "shelving_unit":
                    w, h, d = o["size"]
                    ex, ez = rotated_extent(w, d, o["rotation_deg"])
                    if abs(o["x"] - m["x"]) <= ex / 2 and abs(o["z"] - m["z"]) <= ez / 2:
                        levels = [0.22, 0.62, 1.02, 1.42, 1.82] if h >= 2.0 else [0.22, 0.62, 1.02, 1.42, 1.62]
                        if any(abs(y - lv) < 0.006 for lv in levels):
                            found = [o["name"]]
        if not found:
            problem(f"no supporting surface for {m['name']} at y={y}")

# ------------------------------------------------------------------ bottle throw test
def bottle_throw(px, pz, ax, az):
    yaw_dir = np.array([ax - px, 0, az - pz], dtype=float)
    yaw_dir /= np.linalg.norm(yaw_dir)
    cam = np.array([px, FLOOR + 1.65, pz])
    pos = cam + yaw_dir * 0.45 + np.array([0, -0.1, 0])
    vel = yaw_dir * 11.0 + np.array([0, 2.5, 0])
    r = 0.06
    dt = 0.002
    for step in range(3000):
        pos = pos + vel * dt
        vel = vel + np.array([0, -9.8, 0]) * dt
        if pos[1] - r <= FLOOR:
            return pos, "floor"
        for b in COLLIDERS:
            if b.x0 - r < pos[0] < b.x1 + r and b.y0 - r < pos[1] < b.y1 + r and b.z0 - r < pos[2] < b.z1 + r:
                return pos, b.name
    return pos, "timeout"


imp, what = bottle_throw(-8.0, -3.0, 5.0, -3.0)
dist = math.hypot(imp[0] - spawn["x"], imp[2] - spawn["z"])
msg = f"throw test: impact at ({imp[0]:.2f},{imp[1]:.2f},{imp[2]:.2f}) on {what}, {dist:.2f} m from spawn"
(notes if dist < 15.5 else problems).append(msg)

# Clawman start conditions in hospital_hiding_map_smoke: player at (-8,-3) still -> not detected (dist>7 or no LOS)
d0 = math.hypot(-8 - spawn["x"], -3 - spawn["z"])
notes.append(f"throw-test player to spawn distance {d0:.2f} m")

# first sighting: from lobby (-7,-4.15) eye 1.77 to clawman chest 1.3
fs = ray_hits((-7.0, FLOOR + 1.65, -4.15), (spawn["x"], FLOOR + 1.3, spawn["z"]), COLLIDERS)
(notes if not fs else problems).append(f"first sighting line from (-7,-4.15): {'clear' if not fs else fs[0][1]}")

# visibility from spawn of key player positions (7 m sight, LOS)
for label_, (x, z) in {"ward door inside (1.5,-5.8)": (1.5, -5.8), "ward->records door (7.4,-6.2)": (7.4, -6.2),
                       "records inside door (8.75,-5.7)": (8.75, -5.7), "records desk (9.2,-8.4)": (9.2, -8.4),
                       "records lockers exit (11.51,-7.25)": (11.51, -7.25), "nurse station (8.2,-2.0)": (8.2, -2.0),
                       "day room (12.0,-2.0)": (12.0, -2.0), "lounge door inside (14.3,-5.8)": (14.3, -5.8),
                       "corridor (6.0,-4.15)": (6.0, -4.15)}.items():
    h = ray_hits((spawn["x"], FLOOR + 1.3, spawn["z"]), (x, FLOOR + 1.65, z), COLLIDERS)
    dd = math.hypot(x - spawn["x"], z - spawn["z"])
    notes.append(f"from spawn -> {label_}: dist {dd:.1f} m, {'SEEN' if (not h and dd < 7) else 'hidden' if h else 'out of range'}")

# hiding spots visible from spawn?
for m, b in SPOTS:
    dist = 1.1 if m["type"] == "hiding_bed" else 0.8
    ex, ez = local_to_world(m["x"], m["z"], m["rotation_deg"], 0, dist)
    h = ray_hits((spawn["x"], FLOOR + 1.3, spawn["z"]), (ex, FLOOR + 1.65, ez), COLLIDERS, skip=(m["name"],))
    dd = math.hypot(ex - spawn["x"], ez - spawn["z"])
    notes.append(f"spot {m['name']} exit from spawn: {dd:.1f} m, {'VISIBLE' if (not h and dd < 7) else 'safe'}; territory dist {math.hypot(m['x']-spawn['x'], m['z']-spawn['z']):.1f}")

# ------------------------------------------------------------------ counts and triangle estimate
kinds = {}
for m in L.markers:
    kinds[m["type"]] = kinds.get(m["type"], 0) + 1
notes.append(f"marker counts: {kinds}; total markers {len(L.markers)}; blender objects {len(L.objects)}; walls {len(L.walls)}")
lockers = sum(1 for m in L.markers if m["type"] == "hiding_locker")
closets = sum(1 for m in L.markers if m["type"] == "hiding_closet")
beds = sum(1 for m in L.markers if m["type"] == "hiding_bed")
bottles = sum(1 for m in L.markers if m["type"] == "bottle")
if (lockers, closets, beds, bottles) != (5, 1, 2, 5):
    problem(f"hiding/bottle counts {(lockers, closets, beds, bottles)} != (5,1,2,5)")

# room rectangles inside footprint and non-overlapping
for r in L.rooms:
    if r["x_min"] < FX0 - 1e-6 or r["x_max"] > FX1 + 1e-6 or r["z_min"] < FZ0 - 1e-6 or r["z_max"] > FZ1 + 1e-6:
        problem(f"room outside footprint {r['name']}")
area = sum((r["x_max"] - r["x_min"]) * (r["z_max"] - r["z_min"]) for r in L.rooms)
notes.append(f"room area sum {area:.2f} vs footprint {(FX1 - FX0) * (FZ1 - FZ0):.2f}")
for i in range(len(L.rooms)):
    for j in range(i + 1, len(L.rooms)):
        a, b = L.rooms[i], L.rooms[j]
        if a["x_min"] < b["x_max"] - 1e-6 and b["x_min"] < a["x_max"] - 1e-6 and a["z_min"] < b["z_max"] - 1e-6 and b["z_min"] < a["z_max"] - 1e-6:
            problem(f"rooms overlap {a['name']} / {b['name']}")

# Work surfaces inside layout objects, relative to the object's base (the builder's geometry):
# the reception counter's staff desk sits 0.75 up, behind its 1.10 m transaction ledge.
INNER_SURFACES = {"ReceptionDesk": (0.75,)}

# ------------------------------------------------------------------ equipment checks
layout_names = {o["name"] for o in L.objects} | {m["name"] for m in L.markers}
for e, spec, b in DRESS:
    if e["name"] in layout_names:
        problem(f"dressing name {e['name']} clashes with a layout object or marker")
    if b.x0 < FX0 - 0.001 or b.x1 > FX1 + 0.001 or b.z0 < FZ0 - 0.001 or b.z1 > FZ1 + 0.001:
        problem(f"outside footprint: {b}")
    for wb in WALLS:
        if b.overlaps(wb):
            problem(f"intersects wall: {b} x {wb}")
    yaw = math.radians(e.get("yaw", 0.0))
    nx_, nz_ = math.sin(yaw), math.cos(yaw)          # the prop's front direction
    w, h, d = spec["size"]
    if spec["mount"] == "wall" and not e.get("on"):
        bx, bz = local_to_world(e["x"], e["z"], e.get("yaw", 0.0), 0.0, -d / 2)
        px, pz = bx - nx_ * 0.02, bz - nz_ * 0.02     # just behind the back face
        if not any(wb.x0 - 0.01 <= px <= wb.x1 + 0.01 and wb.z0 - 0.01 <= pz <= wb.z1 + 0.01
                   and wb.y0 <= b.y0 + 0.01 and wb.y1 >= b.y1 - 0.01 for wb in WALLS):
            problem(f"wall prop {e['name']} is not against a solid wall (back centre {bx:.2f},{bz:.2f})")
    if spec["mount"] == "ceiling":
        if any(hx0 <= e["x"] <= hx1 and hz0 <= e["z"] <= hz1 for hx0, hx1, hz0, hz1 in getattr(L, "ceiling_holes", [])):
            problem(f"ceiling prop {e['name']} hangs in a ceiling hole")
    if spec["mount"] == "surface" and e.get("y") is not None:
        y = e["y"]
        tops = ["floor"] if abs(y - FLOOR) < 0.006 else []
        tops += [o for o in OBJS + MARKS if o.name != e["name"] and abs(o.y1 - y) < 0.006
                and o.x0 - 0.01 <= e["x"] <= o.x1 + 0.01 and o.z0 - 0.01 <= e["z"] <= o.z1 + 0.01]
        if not tops:
            for o in L.objects:
                if o["kind"] == "shelving_unit" and (not e.get("on") or e["on"] == o["name"]):
                    ex, ez = rotated_extent(o["size"][0], o["size"][2], o["rotation_deg"])
                    if abs(o["x"] - e["x"]) <= ex / 2 and abs(o["z"] - e["z"]) <= ez / 2:
                        levels = [0.22, 0.62, 1.02, 1.42, 1.82] if o["size"][1] >= 2.0 else [0.22, 0.62, 1.02, 1.42, 1.62]
                        if any(abs(y - lv) < 0.006 for lv in levels):
                            tops = [o["name"]]
        for o in L.objects:
            for rel in INNER_SURFACES.get(o["name"], ()):
                ex, ez = rotated_extent(o["size"][0], o["size"][2], o["rotation_deg"])
                if abs(o["y"] + rel - y) < 0.006 and abs(o["x"] - e["x"]) <= ex / 2 and abs(o["z"] - e["z"]) <= ez / 2:
                    tops = [o["name"]]
        if not tops:
            problem(f"no supporting surface for {e['name']} at y={y}")

# Pickups and notes stay visible and reachable: nothing within 0.3 m of a bottle or document
# marker at its height (the bottle prompt needs a clear line of sight from the camera).
for mk_ in L.markers:
    if mk_["type"] not in ("bottle", "document"):
        continue
    keep = Box(mk_["name"] + ":keep", mk_["x"] - 0.3, mk_["x"] + 0.3, mk_["y"] + 0.005, mk_["y"] + 0.3, mk_["z"] - 0.3, mk_["z"] + 0.3, "zone")
    for e, spec, b in DRESS:
        if keep.overlaps(b, tol=0.001):
            problem(f"{e['name']} crowds the {mk_['type']} {mk_['name']}")

# Door throats stay clear of solid equipment: the opening plus 0.9 m on both sides.
for wall_ in L.walls:
    along_x = abs(wall_["z1"] - wall_["z2"]) < 1e-6
    start = wall_["x1"] if along_x else wall_["z1"]
    sign = (1 if wall_["x2"] >= wall_["x1"] else -1) if along_x else (1 if wall_["z2"] >= wall_["z1"] else -1)
    for o in wall_["openings"]:
        if o["kind"] != "door" or o.get("door_state") == "locked_blocked":
            continue
        a = start + sign * (o["center_along"] - o["width"] / 2)
        c = start + sign * (o["center_along"] + o["width"] / 2)
        lo, hi = min(a, c) - 0.1, max(a, c) + 0.1
        reach_ = wall_["thickness"] / 2 + 0.9
        if along_x:
            zone = Box("throat", lo, hi, FLOOR, FLOOR + 2.0, wall_["z1"] - reach_, wall_["z1"] + reach_, "zone")
        else:
            zone = Box("throat", wall_["x1"] - reach_, wall_["x1"] + reach_, FLOOR, FLOOR + 2.0, lo, hi, "zone")
        for b in DRESS_SOLID:
            if zone.overlaps(b, tol=0.001):
                problem(f"{b.name} stands in the door throat of {wall_['id']} ({lo + 0.1:.2f}..{hi - 0.1:.2f})")

# The main corridor keeps at least 1.5 m clear between solid things below head height.
CORR_Z0, CORR_Z1 = -5.175, -3.125
corr_blockers = [b for b in OBJS + MARKS if b.block and b.y0 < FLOOR + 1.9 and b.y1 > FLOOR + 0.05 and b.z1 > CORR_Z0 and b.z0 < CORR_Z1]
narrowest = (9.0, None)
x = 0.4
while x < 17.6:
    spans = sorted((max(b.z0, CORR_Z0), min(b.z1, CORR_Z1)) for b in corr_blockers if b.x0 < x < b.x1)
    best, cursor = 0.0, CORR_Z0
    for z0, z1 in spans:
        best = max(best, z0 - cursor)
        cursor = max(cursor, z1)
    best = max(best, CORR_Z1 - cursor)
    if best < narrowest[0]:
        narrowest = (best, x)
    x += 0.05
(notes if narrowest[0] >= 1.5 else problems).append(f"corridor narrowest clear width {narrowest[0]:.2f} m at x={narrowest[1]:.2f} (needs 1.5)")

counts = {}
for e, spec, b in DRESS:
    counts[e["source"]] = counts.get(e["source"], 0) + 1
notes.append(f"equipment: {len(DRESS)} placements ({len(DRESS_SOLID)} solid, {len(DRESS_DECOR)} decor) from {counts or 'no dressing files'}; catalogue {len(CATALOG)} props")

print("PROBLEMS:", len(problems))
for p in problems:
    print("  !", p)
print("NOTES:")
for n in notes:
    print("  -", n)

sys.exit(1 if problems else 0)
