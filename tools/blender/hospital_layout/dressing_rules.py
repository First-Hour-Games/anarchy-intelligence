"""Rule-placed hospital equipment, derived from layout.py so it follows layout changes:
- every door off a public space gets a room plaque and (when open) a hand-sanitizer dispenser
  on the public side;
- every room's ceiling gets a smoke detector, sprinklers on a ~3 m grid and, in public spaces,
  paging speakers, all kept clear of the light troffers and ceiling holes.
Entries use the dressing format of README.md in tools/blender/hospital_dressing.
"""

import math

import layout as L

CEILING_Y = 2.95
CASING = 0.06                     # door architrave width on each wall face
PUBLIC = ("Main Corridor", "Lobby", "Tower Hall", "Shelter Hall")
# Plaque (number, label) by the start of the room name behind the door.
PLAQUES = {
    "Procedure Room 1": ("101", "PROCEDURE 1"), "Nurse Station": ("103", "NURSES' STATION"),
    "Day Room": ("105", "DAY ROOM"), "Medical Stores": ("102", "CENTRAL SUPPLY"),
    "Isolation 104": ("104", "ISOLATION"), "Shelter Office": ("106", "ADMITTING"),
    "Stair 1": ("S1", "STAIR"), "Linen & Changing": ("108", "LINEN / STAFF"),
    "Treatment Ward": ("110", "WARD B"), "Staff Records": ("112", "STAFF RECORDS"),
    "Staff Lounge": ("114", "STAFF LOUNGE"),
}
SPRINKLER_SPACING = 3.0

dressing = []


def room_at(x: float, z: float):
    for room in L.rooms:
        if room["x_min"] <= x <= room["x_max"] and room["z_min"] <= z <= room["z_max"]:
            return room
    return None


def is_public(room) -> bool:
    return room is not None and room["name"].startswith(PUBLIC)


def short(name: str) -> str:
    return "".join(part for part in name.split("(")[0].title() if part.isalnum())


def footprint(o: dict) -> tuple:
    """(x0, x1, y0, y1, z0, z1) of a layout object or marker footprint."""
    w, h, d = o.get("size") or o.get("foot") or (0.0, 0.0, 0.0)
    r = math.radians(o.get("rotation_deg", 0.0))
    ex = abs(w * math.cos(r)) + abs(d * math.sin(r))
    ez = abs(w * math.sin(r)) + abs(d * math.cos(r))
    return (o["x"] - ex / 2, o["x"] + ex / 2, o["y"], o["y"] + h, o["z"] - ez / 2, o["z"] + ez / 2)


TAKEN = [footprint(o) for o in L.objects if o["kind"] not in ("floor_slab", "drop_ceiling", "light_fixture_set", "trim_set", "door_frame_set")]
TAKEN += [footprint(m) for m in L.markers if "foot" in m]


def free(box: tuple) -> bool:
    x0, x1, y0, y1, z0, z1 = box
    for a in TAKEN:
        if x0 < a[1] - 0.005 and a[0] < x1 - 0.005 and y0 < a[3] - 0.005 and a[2] < y1 - 0.005 and z0 < a[5] - 0.005 and a[4] < z1 - 0.005:
            return False
    return True


def add(prop: str, name: str, x: float, z: float, yaw: float, y: float | None = None, **opts) -> None:
    taken = {e["name"] for e in dressing}
    unique, count = name, 1
    while unique in taken:
        count += 1
        unique = f"{name}_{count}"
    entry = {"prop": prop, "name": unique, "x": round(x, 3), "z": round(z, 3), "yaw": yaw, "opts": opts}
    if y is not None:
        entry["y"] = y
    dressing.append(entry)


# ------------------------------------------------------------------ doors: plaques and sanitizers
WALL_ITEMS = {"room_plaque": (0.26, 0.18, 0.012, 1.45), "sanitizer_dispenser": (0.12, 0.28, 0.11, 1.00)}


def wall_item(wall: dict, spans: list, prop: str, along: float, side: float, name: str, **opts) -> bool:
    """Place a wall prop centred at `along` on the wall face toward `side` (+1/-1 across the wall)
    if the wall is there, clear of openings and of other things. Returns whether it was placed."""
    w, h, d, y = WALL_ITEMS[prop]
    along_x = abs(wall["z1"] - wall["z2"]) < 1e-6
    lo_run = min(wall["x1"], wall["x2"]) if along_x else min(wall["z1"], wall["z2"])
    hi_run = max(wall["x1"], wall["x2"]) if along_x else max(wall["z1"], wall["z2"])
    a, b = along - w / 2, along + w / 2
    if a < lo_run + 0.1 or b > hi_run - 0.1:
        return False
    if any(a < s1 + CASING + 0.04 and s0 - CASING - 0.04 < b for s0, s1 in spans):
        return False
    fixed = wall["z1"] if along_x else wall["x1"]
    face = fixed + side * wall["thickness"] / 2
    if along_x:
        box = (a, b, y, y + h, min(face, face + side * d), max(face, face + side * d))
        x, z, yaw = along, face + side * d / 2, 0.0 if side > 0 else 180.0
    else:
        box = (min(face, face + side * d), max(face, face + side * d), y, y + h, a, b)
        x, z, yaw = face + side * d / 2, along, 90.0 if side > 0 else -90.0
    if not free(box):
        return False
    TAKEN.append(box)
    add(prop, name, x, z, yaw, **opts)
    return True


for wall in L.walls:
    if wall["id"].startswith("P_"):
        continue
    along_x = abs(wall["z1"] - wall["z2"]) < 1e-6
    start = wall["x1"] if along_x else wall["z1"]
    sign = (1 if wall["x2"] >= wall["x1"] else -1) if along_x else (1 if wall["z2"] >= wall["z1"] else -1)
    spans = []
    for o in wall["openings"]:
        c = start + sign * o["center_along"]
        spans.append((c - o["width"] / 2, c + o["width"] / 2))
    for o, (s0, s1) in zip(wall["openings"], spans):
        if o["kind"] != "door":
            continue
        mid = (s0 + s1) / 2
        fixed = wall["z1"] if along_x else wall["x1"]
        sides = {}
        for side in (1.0, -1.0):
            probe = fixed + side * 0.4
            sides[side] = room_at(mid, probe) if along_x else room_at(probe, mid)
        public = [s for s, r in sides.items() if is_public(r)]
        if len(public) != 1:
            continue
        side = public[0]
        target = sides[-side]
        if target is None:
            continue
        key = next((k for k in PLAQUES if target["name"].startswith(k)), None)
        label = short(target["name"])
        plaque_at = [s1 + CASING + 0.17, s0 - CASING - 0.17]
        sanitizer_at = [s0 - CASING - 0.14, s1 + CASING + 0.14]
        placed_plaque = None
        if key is not None:
            number, words = PLAQUES[key]
            for index, along in enumerate(plaque_at):
                if wall_item(wall, spans, "room_plaque", along, side, f"Rule_Plaque_{label}", number=number, label=words):
                    placed_plaque = index
                    break
        if o.get("door_state") == "open":
            order = sanitizer_at if placed_plaque != 1 else sanitizer_at[::-1]
            for along in order:
                if wall_item(wall, spans, "sanitizer_dispenser", along, side, f"Rule_Sanitizer_{label}"):
                    break

# ------------------------------------------------------------------ ceilings
TROFFERS = []                      # (x0, x1, z0, z1) of the builder's light troffers
for fx in getattr(L, "corridor_fixtures_x", []):
    fz = getattr(L, "corridor_fixtures_z", -4.15)
    TROFFERS.append((fx - 0.3, fx + 0.3, fz - 0.6, fz + 0.6))
for room in L.rooms:
    if "Corridor" in room["name"] or "void" in room["floor_finish"]:
        continue
    nx = max(1, round((room["x_max"] - room["x_min"]) / 2.4))
    nz = max(1, round((room["z_max"] - room["z_min"]) / 2.4))
    for i in range(nx):
        for j in range(nz):
            cx = room["x_min"] + (i + 0.5) * (room["x_max"] - room["x_min"]) / nx
            cz = room["z_min"] + (j + 0.5) * (room["z_max"] - room["z_min"]) / nz
            TROFFERS.append((cx - 0.3, cx + 0.3, cz - 0.6, cz + 0.6))
HOLES = [(x0 - 0.15, x1 + 0.15, z0 - 0.15, z1 + 0.15) for x0, x1, z0, z1 in getattr(L, "ceiling_holes", [])]
CEILING_TAKEN = []                 # (x, z, radius) of placed ceiling items


def ceiling_free(x: float, z: float, radius: float, room) -> bool:
    if not (room["x_min"] + 0.4 <= x <= room["x_max"] - 0.4 and room["z_min"] + 0.4 <= z <= room["z_max"] - 0.4):
        return False
    for x0, x1, z0, z1 in TROFFERS + HOLES:
        dx = max(x0 - x, 0.0, x - x1)
        dz = max(z0 - z, 0.0, z - z1)
        if math.hypot(dx, dz) < radius + 0.12:
            return False
    # Ceiling-height things in the layout (hanging signs, curtain tracks, the surgical lamp).
    for a in TAKEN:
        if a[3] > CEILING_Y - 0.4 and a[0] - radius < x < a[1] + radius and a[4] - radius < z < a[5] + radius:
            return False
    return all(math.hypot(x - cx, z - cz) >= radius + r + 0.2 for cx, cz, r in CEILING_TAKEN)


def ceiling_item(prop: str, name: str, room, x: float, z: float, radius: float, search: float = 1.2) -> bool:
    """Place at (x, z) or the nearest free spot within `search` metres (0.15 m steps)."""
    steps = int(search / 0.15)
    spots = sorted(((x + i * 0.15, z + j * 0.15) for i in range(-steps, steps + 1) for j in range(-steps, steps + 1)),
                   key=lambda p: math.hypot(p[0] - x, p[1] - z))
    for px, pz in spots:
        if ceiling_free(px, pz, radius, room):
            CEILING_TAKEN.append((px, pz, radius))
            add(prop, name, px, pz, 0.0)
            return True
    return False


for room in L.rooms:
    if "void" in room["floor_finish"]:
        continue
    label = short(room["name"])
    w = room["x_max"] - room["x_min"]
    d = room["z_max"] - room["z_min"]
    cx, cz = (room["x_min"] + room["x_max"]) / 2, (room["z_min"] + room["z_max"]) / 2
    if "Corridor" in room["name"]:
        for index, x in enumerate((4.3, 11.3, 16.8)):
            ceiling_item("smoke_detector", f"Rule_Smoke_{label}_{index}", room, x, cz, 0.07)
        for index, x in enumerate((1.5, 8.0, 14.5)):
            ceiling_item("ceiling_speaker", f"Rule_Speaker_{label}_{index}", room, x, cz, 0.16)
    else:
        ceiling_item("smoke_detector", f"Rule_Smoke_{label}", room, cx + 0.45, cz + 0.45, 0.07, search=2.0)
        if is_public(room):
            ceiling_item("ceiling_speaker", f"Rule_Speaker_{label}", room, cx - 0.9, cz - 0.6, 0.16, search=2.0)
    nx = max(1, math.ceil(w / SPRINKLER_SPACING))
    nz = max(1, math.ceil(d / SPRINKLER_SPACING))
    index = 0
    for i in range(nx):
        for j in range(nz):
            sx = room["x_min"] + (i + 0.5) * w / nx
            sz = room["z_min"] + (j + 0.5) * d / nz
            if ceiling_item("sprinkler_head", f"Rule_Sprinkler_{label}_{index}", room, sx, sz, 0.04, search=0.9):
                index += 1
