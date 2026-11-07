"""The alt route's hospital: four storeys and a helipad, replacing the old hospital in map_alt.tscn.

Building-local game metres: x along the front (+x is on your right as you face the entrance from the
forecourt), y up, z = 0 at the front face of the facade and negative into the building. The node in the map
turns this to face the street (see scenes/environment/alt_hospital.tscn).

Each floor has its own shape: the lobby is open two storeys high, with floor 2's corridor running along a glass
balustrade over it past the ward hub (an open nurse station and day room); floor 3's theatres have viewing glass
along the corridor, behind the theatre suite's doors; floor 4 is mostly one open intensive care unit of glass bed
bays.

The way up zig-zags, so every floor is crossed end to end. There are two stair cores, A at the -x end and B at
the +x end; each is a switchback (two flights a storey round a mid landing). Each floor blocks one core's way
up:
  G  in at the front door, up core B (core A's door is chained);
  2  up core A (core B's flight up is buried under the collapsed ceiling);
  3  up core B (core A's flight up is barricaded);
  4  up core A to the roof (core B ends here), and the helicopter on the pad.

tools/blender/build_alt_hospital.py builds it from this module and exports the model and its markers.
Nothing here imports bpy, so the plan can be checked in plain Python (python plan.py).
"""

# ---- Storeys -------------------------------------------------------------------------------------------
LEVELS = 4
LEVEL_NAMES = ["G", "2", "3", "4"]
FLOOR0 = 0.12          # the ground floor's finished floor, one step up from the forecourt
STOREY = 3.8           # floor to floor
SLAB = 0.25            # an upper floor's slab
CEILING = 3.2          # drop ceiling above each floor
DOOR_H = 2.6           # doorways, tall enough for the alt Clawman
PARAPET = 1.1


def floor_y(level: int) -> float:
    return round(FLOOR0 + STOREY * level, 3)


ROOF_Y = floor_y(LEVELS)   # 15.32

# ---- Footprint -----------------------------------------------------------------------------------------
X0, X1, Z0, Z1 = -20.0, 20.0, -18.0, 0.0      # outer faces of the exterior walls
EXT = 0.3                                     # exterior wall
IX0, IX1, IZ0, IZ1 = X0 + EXT, X1 - EXT, Z0 + EXT, Z1 - EXT
PT = 0.15                                     # partitions
CORE_WALL = 0.2
CORRIDOR = (-10.1, -7.3)                      # z of its south and north walls
BAY_X = (-13.6, -6.8, 0.0, 6.8, 13.6)
# Stair cores: inner wall at x = +-13.6 (the corridor's ends), out to the exterior wall. From the inside out:
# the floor landing (part of each floor), the flights, the mid landing against the exterior wall.
CORE_Z = (-10.7, -6.7)
LANDING = 1.8
RISERS = 10            # per flight
TREAD = 0.3
FLIGHT = TREAD * (RISERS - 1)   # 2.7 m run
MID = round(IX1 - BAY_X[-1] - LANDING - FLIGHT, 3)  # 1.6 m mid landing
RISE = STOREY / (2 * RISERS)    # 0.19 m


def core_x(core: str) -> dict:
    """x of a core's walls and parts; s is +1 for core B (+x end), -1 for core A."""
    s = -1.0 if core == "A" else 1.0
    inner = s * BAY_X[-1]
    return dict(s=s, inner=inner, landing_end=inner + s * LANDING, flight_end=inner + s * (LANDING + FLIGHT),
                outer=s * IX1)


# Which flights go up from each level: "open", "blocked" (built, but buried or barricaded at the foot), or
# None (the core stops at that level). Which corridor doors into the cores are open: "open" or "chained".
UP = {"A": ["open", "open", "blocked", "open"], "B": ["open", "blocked", "open", None]}
CORE_DOOR = {"A": ["chained", "open", "open", "open"], "B": ["open", "open", "open", "open"]}
# How each blocked flight is blocked.
BLOCKAGE = {("B", 1): "collapse", ("A", 2): "barricade"}
# Core A rises through the roof into a stair house with a door out onto the roof.
STAIR_HOUSE = ("A", 2.9)        # core, height above the roof

# The lifts: two dead cars behind the middle of the corridor's south side.
LIFTS = (-2.6, 2.6, -12.6)      # x0, x1, back wall z

# ---- Rooms ---------------------------------------------------------------------------------------------
# Each room: (level, kind, name, x0, x1, z0, z1, doors). A number is a 1.8 m doorway in the corridor wall at that
# x; ("x", z_center, x) is a door in the side partition at x; ("pass", x_center, width) is a counter opening in
# the corridor wall (sill at counter height); ("wide", x_center, width) is a wide doorway with no doors.
# A front room's corridor wall is the north corridor wall (z = -7.3); a back room's is the south one (z = -10.1).
# A "void" room has no floor: it is the upper half of a two-storey space below it.
FRONT = (-7.3, -0.3)
BACK = (-17.7, -10.1)
END_FRONT = (-6.7, -0.3)
END_BACK = (-17.7, -10.7)
SHAFTS_BACK = LIFTS[2]

ROOMS = [
    # Ground floor: admissions and emergency. The lobby runs across the middle two front bays, open to the
    # corridor.
    (0, "lobby", "Admissions Lobby", -6.8, 6.8, *FRONT, []),
    (0, "er", "Emergency Treatment", -13.6, -6.8, *FRONT, [-11.4, ("x", -3.0, -6.8)]),
    (0, "shelter", "Shelter Ward", 6.8, 13.6, *FRONT, [11.2, ("x", -3.0, 6.8)]),
    (0, "ambulance", "Ambulance Bay", -19.7, -13.6, *END_FRONT, [("x", -3.6, -13.6)]),
    (0, "security", "Security", 13.6, 19.7, *END_FRONT, [("x", -3.6, 13.6)]),
    (0, "radiology", "Radiology", -13.6, -6.8, *BACK, [-10.2]),
    (0, "pharmacy", "Pharmacy", -6.8, -2.6, *BACK, [-4.7]),
    (0, "staff", "Staff Room", 2.6, 6.8, *BACK, [4.7]),
    (0, "records", "Medical Records", 6.8, 13.6, *BACK, [10.2]),
    (0, "storage", "Stores", -19.7, -13.6, *END_BACK, [("x", -14.2, -13.6)]),
    (0, "linen", "Linen", 13.6, 19.7, *END_BACK, [("x", -14.2, 13.6)]),
    (0, "plant", "Lift Machinery", -2.6, 2.6, -17.7, SHAFTS_BACK, [("x", -15.2, -2.6)]),
    # 2: the wards.
    (1, "ward", "Ward 2A", -13.6, -6.8, *FRONT, [-8.6]),
    (1, "void", "Atrium", -6.8, 6.8, *FRONT, []),
    (1, "ward", "Ward 2D", 6.8, 13.6, *FRONT, [8.6]),
    (1, "children", "Children's Ward", -13.6, -6.8, *BACK, [-8.6]),
    (1, "nurse", "Nurse Station", -6.8, -2.6, *BACK, [-5.85, ("pass", -3.825, 2.05)]),
    (1, "dayroom", "Day Room", 2.6, 6.8, *BACK, [("wide", 4.7, 2.6)]),
    (1, "ward", "Ward 2E", 6.8, 13.6, *BACK, [8.6]),
    (1, "isolation", "Isolation", -19.7, -13.6, *END_FRONT, [("x", -3.6, -13.6)]),
    (1, "sluice", "Sluice Room", 13.6, 19.7, *END_FRONT, [("x", -3.6, 13.6)]),
    (1, "storage", "Ward Stores", -19.7, -13.6, *END_BACK, [("x", -14.2, -13.6)]),
    (1, "linen", "Linen", 13.6, 19.7, *END_BACK, [("x", -14.2, 13.6)]),
    (1, "plant", "Lift Machinery", -2.6, 2.6, -17.7, SHAFTS_BACK, [("x", -15.2, -2.6)]),
    # 3: surgery.
    (2, "theatre", "Theatre 1", -13.6, -6.8, *FRONT, [-8.6]),
    (2, "scrub", "Scrub Room", -6.8, 0.0, *FRONT, [-3.4, ("x", -3.0, -6.8)]),
    (2, "theatre", "Theatre 2", 0.0, 6.8, *FRONT, [4.6, ("x", -3.0, 0.0)]),
    (2, "recovery", "Recovery", 6.8, 13.6, *FRONT, [8.6]),
    (2, "sterile", "Sterile Supply", -13.6, -6.8, *BACK, [-10.2]),
    (2, "anaesthetics", "Anaesthetics", -6.8, -2.6, *BACK, [-4.7]),
    (2, "staff", "Surgeons' Lounge", 2.6, 6.8, *BACK, [4.7]),
    (2, "ward", "Surgical Ward", 6.8, 13.6, *BACK, [8.6]),
    (2, "waiting", "Surgical Waiting", -19.7, -13.6, *END_FRONT, [("x", -3.6, -13.6)]),
    (2, "changing", "Changing", 13.6, 19.7, *END_FRONT, [("x", -3.6, 13.6)]),
    (2, "storage", "Equipment Store", -19.7, -13.6, *END_BACK, [("x", -14.2, -13.6)]),
    (2, "linen", "Linen", 13.6, 19.7, *END_BACK, [("x", -14.2, 13.6)]),
    (2, "plant", "Lift Machinery", -2.6, 2.6, -17.7, SHAFTS_BACK, [("x", -15.2, -2.6)]),
    # 4: intensive care and the offices.
    (3, "icu", "Intensive Care", -13.6, 0.0, *FRONT, [-6.8]),
    (3, "office", "Director", 0.0, 6.8, *FRONT, [1.8]),
    (3, "radio", "Communications", 6.8, 13.6, *FRONT, [8.6]),
    (3, "oncall", "On-Call Rooms", -13.6, -6.8, *BACK, [-8.6]),
    (3, "records", "Administration", -6.8, -2.6, *BACK, [-4.7]),
    (3, "conference", "Conference Room", 2.6, 6.8, *BACK, [4.7]),
    (3, "office", "Medical Director", 6.8, 13.6, *BACK, [8.6]),
    (3, "waiting", "Roof Access", -19.7, -13.6, *END_FRONT, [("x", -3.6, -13.6)]),
    (3, "waiting", "Visitors", 13.6, 19.7, *END_FRONT, [("x", -3.6, 13.6)]),
    (3, "storage", "Stores", -19.7, -13.6, *END_BACK, [("x", -14.2, -13.6)]),
    (3, "linen", "Linen", 13.6, 19.7, *END_BACK, [("x", -14.2, 13.6)]),
    (3, "plant", "Lift Machinery", -2.6, 2.6, -17.7, SHAFTS_BACK, [("x", -15.2, -2.6)]),
]
# Intensive care and the theatres have glass along the corridor, either side of their doors.
GLAZED = {"icu", "theatre"}
# Floors with no slab of their own over these rooms: the lobby rises through floor 2 (its "void").
ATRIUM_KINDS = {"lobby"}
# The theatre suite's doors across floor 3's corridor (x), and the open intensive care unit's glass bed screens
# on floor 4 (x of each screen; they run in from the facade this far).
SUITE_DOORS = (2, 7.0)
ICU_SCREENS = (3, (-11.0, -8.3, -5.5, -2.7), -3.0)
# Each floor's colour: the dado along its walls and its doors.
FLOOR_COLOURS = ["DadoBlue", "DadoGreen", "DadoTeal", "DadoOchre"]

# Floor finish by room kind; the corridor and the cores have their own.
FLOOR_FINISH = {
    "lobby": "FloorTerrazzo", "er": "FloorLightGrey", "shelter": "FloorBeige", "ambulance": "FloorConcrete",
    "security": "FloorCarpet", "radiology": "FloorLightGrey", "pharmacy": "FloorLightGrey", "staff": "FloorWood",
    "records": "FloorCarpet", "storage": "FloorConcrete", "linen": "FloorSafety", "plant": "FloorConcrete",
    "ward": "FloorGreen", "children": "FloorBeige", "nurse": "FloorGreen", "dayroom": "FloorWood",
    "isolation": "FloorLightGrey", "sluice": "FloorSafety", "theatre": "FloorLightGrey", "scrub": "FloorSafety",
    "recovery": "FloorGreen", "sterile": "FloorLightGrey", "anaesthetics": "FloorLightGrey", "waiting": "FloorBeige",
    "changing": "FloorSafety", "icu": "FloorLightGrey", "office": "FloorCarpet", "radio": "FloorCarpet",
    "oncall": "FloorCarpet", "conference": "FloorCarpet", "void": "FloorTerrazzo",
}
CORRIDOR_FINISH = "FloorGreen"
CORE_FINISH = "FloorConcrete"

# ---- Walls ----------------------------------------------------------------------------------------------
# A wall runs from (x1, z1) to (x2, z2) along x or along z; openings are measured along it from its first
# end. kind: door (open doorway), chained (a closed leaf with a chain), lift (closed lift doors), window,
# glass (interior glazing), entrance (the glass front doors, open).


def opening(kind: str, center: float, width: float, sill: float, head: float, swing: float = 0.0) -> dict:
    return dict(kind=kind, center=round(center, 3), width=round(width, 3), sill=round(sill, 3), head=round(head, 3),
                swing=swing)


def door(center: float, width: float = 1.8, kind: str = "door", swing: float = 0.0) -> dict:
    """A doorway; swing +1 or -1 hangs leaves opening to the wall's left or right (seen along the wall), 0 none."""
    return opening(kind, center, width, 0.0, DOOR_H, swing)


def window(center: float, width: float = 1.5) -> dict:
    return opening("window", center, width, 0.9, 2.4)


def _wall(walls: list, wid: str, level: int, x1: float, z1: float, x2: float, z2: float, t: float, y0: float,
          y1: float, openings: list, outside: bool = False, style: str = "wall") -> None:
    """style: wall, balustrade (a glass rail at a drop) or screen (a glass partition)."""
    walls.append(dict(id=wid, level=level, x1=x1, z1=z1, x2=x2, z2=z2, t=t, y0=round(y0, 3), y1=round(y1, 3),
                      openings=sorted(openings, key=lambda o: o["center"]), outside=outside, style=style))


def wall_top(level: int) -> float:
    """Interior walls rise from the floor to the underside of the slab above."""
    return floor_y(level + 1) - SLAB


def rooms_at(level: int) -> list:
    return [dict(level=r[0], kind=r[1], name=r[2], x0=r[3], x1=r[4], z0=r[5], z1=r[6], doors=r[7])
            for r in ROOMS if r[0] == level]


def exterior_walls(level: int) -> list:
    """The four exterior walls for one storey, from the bottom of its slab to the bottom of the next."""
    walls: list = []
    y0 = 0.0 if level == 0 else floor_y(level) - SLAB
    y1 = floor_y(level + 1) - SLAB
    front, back, left, right = [], [], [], []
    # Front and back: two windows in each middle bay, one in each end bay.
    for a, b in zip(BAY_X, BAY_X[1:]):
        middle = (a + b) / 2.0
        for offset in (-1.6, 1.6):
            x = middle + offset
            if level in (0, 1) and -6.8 < x < 6.8:
                continue
            front.append(window(x - X0))
        for offset in (-1.6, 1.6):
            x = middle + offset
            if LIFTS[0] - 0.8 < x < LIFTS[1] + 0.8:
                continue
            back.append(window(x - X0))
    for x in (-16.65, 16.65):
        front.append(window(x - X0))
        back.append(window(x - X0))
    if level == 0:
        # The entrance and the lobby's tall windows either side of it.
        front.append(opening("entrance", 0.0 - X0, 3.2, 0.0, 2.8))
        for x in (-4.6, 4.6):
            front.append(opening("window", x - X0, 3.0, 0.5, 2.8))
    if level == 1:
        # The atrium's upper windows, tall, over the lobby's.
        for x in (-4.6, 0.0, 4.6):
            front.append(opening("window", x - X0, 3.0 if x else 2.6, 0.3, 3.0))
    # The ends: a window in each end bay, and a tall one lighting the stair's mid landing.
    for z in (-3.5, -14.2):
        left.append(window(-z))
        right.append(window(-z))
    stair_mid = -((CORE_Z[0] + CORE_Z[1]) / 2.0)
    for walls_list in (left, right):
        walls_list.append(opening("window", stair_mid, 1.2, 0.9 + STOREY / 2.0 - 0.7, min(STOREY - SLAB - 0.15, 0.9 + STOREY / 2.0 + 1.1)))
    _wall(walls, f"L{level}_Front", level, X0, Z1 - EXT / 2, X1, Z1 - EXT / 2, EXT, y0, y1, front, outside=True)
    _wall(walls, f"L{level}_Back", level, X0, Z0 + EXT / 2, X1, Z0 + EXT / 2, EXT, y0, y1, back, outside=True)
    # End walls run from the front (z = 0) back (along -z); openings are measured from the front.
    _wall(walls, f"L{level}_EndA", level, X0 + EXT / 2, Z1, X0 + EXT / 2, Z0, EXT, y0, y1, left, outside=True)
    _wall(walls, f"L{level}_EndB", level, X1 - EXT / 2, Z1, X1 - EXT / 2, Z0, EXT, y0, y1, right, outside=True)
    return walls


def _open_room(room: dict) -> bool:
    """Rooms with no wall onto the corridor: the lobby and the atrium over it."""
    return room["kind"] in ("lobby", "void")


def interior_walls(level: int) -> list:
    walls: list = []
    y0, y1 = floor_y(level), wall_top(level)
    rooms = rooms_at(level)
    corridor_n, corridor_s = [], []
    side_doors: dict = {}
    for room in rooms:
        front = room["z1"] > CORRIDOR[1]
        for d in room["doors"]:
            if isinstance(d, tuple) and d[0] == "x":
                side_doors.setdefault(("x", d[2]), []).append(d[1])
                continue
            # Doors onto the corridor open into the room: to +z for front rooms, -z for back rooms.
            if isinstance(d, tuple):
                kind, x, width = d
                o = opening("pass", x, width, 1.05, 2.4) if kind == "pass" else opening("door", x, width, 0.0, DOOR_H)
            else:
                o = opening("door", d, 1.8, 0.0, DOOR_H, 1.0 if front else -1.0)
            (corridor_n if front else corridor_s).append(o)
        if room["kind"] in GLAZED:
            # Glass along the corridor, wherever it is clear of the room's door.
            door_xs = [d for d in room["doors"] if not isinstance(d, tuple)]
            x = room["x0"] + 1.2
            while x < room["x1"] - 1.1:
                if all(abs(x - dx) > 2.0 for dx in door_xs):
                    (corridor_n if front else corridor_s).append(opening("glass", x, 1.8, 0.9, 2.3))
                    x += 2.3
                else:
                    x += 0.5
    # The corridor's north wall, along the front rooms; open where the lobby or the atrium meets it.
    opens = sorted((r["x0"], r["x1"]) for r in rooms if _open_room(r) and r["z1"] > CORRIDOR[1])
    spans_n, a = [], BAY_X[0]
    for x0, x1 in opens:
        spans_n.append((a, x0))
        a = x1
    spans_n.append((a, BAY_X[-1]))
    for index, (a, b) in enumerate(spans_n):
        openings = [dict(o, center=round(o["center"] - a, 3)) for o in corridor_n if a < o["center"] < b]
        _wall(walls, f"L{level}_CorridorN{index}", level, a, CORRIDOR[1], b, CORRIDOR[1], PT, y0, y1, openings)
    # Over the atrium the corridor runs along a glass balustrade.
    for r in rooms:
        if r["kind"] == "void":
            _wall(walls, f"L{level}_Balustrade", level, r["x0"], CORRIDOR[1], r["x1"], CORRIDOR[1], 0.1, y0, y0 + 1.1,
                  [], style="balustrade")
    # The corridor's south wall, with the lift doors.
    south = [dict(o, center=round(o["center"] - BAY_X[0], 3)) for o in corridor_s]
    for x in (LIFTS[0] + 1.3, LIFTS[1] - 1.3):
        south.append(opening("lift", x - BAY_X[0], 1.1, 0.0, 2.2))
    _wall(walls, f"L{level}_CorridorS", level, BAY_X[0], CORRIDOR[0], BAY_X[-1], CORRIDOR[0], PT, y0, y1, south)
    # Partitions between the middle bays, front and back, except where a room spans the line.
    for x in BAY_X[1:-1]:
        if not any(r["x0"] < x < r["x1"] and r["z1"] > CORRIDOR[1] for r in rooms):
            openings = [door(-c + FRONT[1], 1.6, swing=1.0) for c in side_doors.get(("x", x), []) if c > CORRIDOR[1]]
            _wall(walls, f"L{level}_FrontPart{x:+.1f}", level, x, FRONT[1], x, FRONT[0], PT, y0, y1, openings)
    for x in (-6.8, LIFTS[0], LIFTS[1], 6.8):
        openings = [door(-c + BACK[1], 1.6, swing=1.0) for c in side_doors.get(("x", x), []) if c < CORRIDOR[0]]
        _wall(walls, f"L{level}_BackPart{x:+.1f}", level, x, BACK[1], x, BACK[0], PT, y0, y1, openings)
    # The lift shafts: their back wall and the wall between them.
    _wall(walls, f"L{level}_LiftBack", level, LIFTS[0], LIFTS[2], LIFTS[1], LIFTS[2], PT, y0, y1, [])
    _wall(walls, f"L{level}_LiftMiddle", level, 0.0, CORRIDOR[0], 0.0, LIFTS[2], PT, y0, y1, [])
    # The walls at x = +-13.6 between the end bays and the middle bays, and the cores' inner walls with their
    # doors onto the corridor (which open into the stairwell).
    for core, x in (("A", BAY_X[0]), ("B", BAY_X[-1])):
        front_doors = [door(-c + FRONT[1], 1.6, swing=1.0) for c in side_doors.get(("x", x), []) if c > CORE_Z[1]]
        back_doors = [door(-c + CORE_Z[0], 1.6, swing=1.0) for c in side_doors.get(("x", x), []) if c < CORE_Z[0]]
        _wall(walls, f"L{level}_End{core}Front", level, x, FRONT[1], x, CORE_Z[1], PT, y0, y1, front_doors)
        corridor_mid = (CORRIDOR[0] + CORRIDOR[1]) / 2.0
        kind = "chained" if CORE_DOOR[core][level] == "chained" else "door"
        swing = 0.0 if kind == "chained" else (1.0 if core == "B" else -1.0)
        _wall(walls, f"L{level}_Core{core}Door", level, x, CORE_Z[1], x, CORE_Z[0], CORE_WALL, y0, y1,
              [door(-corridor_mid + CORE_Z[1], 1.8, kind, swing)])
        _wall(walls, f"L{level}_End{core}Back", level, x, CORE_Z[0], x, BACK[0], PT, y0, y1, back_doors)
    # Floor 3: the theatre suite's double doors across the corridor, propped open.
    if level == SUITE_DOORS[0]:
        x = SUITE_DOORS[1]
        _wall(walls, f"L{level}_SuiteDoors", level, x, CORRIDOR[1], x, CORRIDOR[0], PT, y0, y1,
              [door((CORRIDOR[1] - CORRIDOR[0]) / 2.0, 2.0, swing=1.0)])
    # Floor 4: the glass screens between the intensive care bays.
    if level == ICU_SCREENS[0]:
        for x in ICU_SCREENS[1]:
            _wall(walls, f"L{level}_Screen{x:+.1f}", level, x, FRONT[1], x, ICU_SCREENS[2], 0.08, y0, y0 + 2.3, [],
                  style="screen")
    return walls


def core_walls() -> list:
    """The cores' long walls, full height (with the stair house on core A)."""
    walls: list = []
    for core in ("A", "B"):
        c = core_x(core)
        top = ROOF_Y + (STAIR_HOUSE[1] if STAIR_HOUSE[0] == core else 0.0) - (SLAB if STAIR_HOUSE[0] != core else 0.0)
        for z in CORE_Z:
            _wall(walls, f"Core{core}_Side{z:+.1f}", -1, c["inner"], z, c["outer"], z, CORE_WALL, FLOOR0, top, [])
    return walls


def stair_house_walls() -> list:
    """Core A above the roof: its inner wall with the door onto the roof."""
    walls: list = []
    core = STAIR_HOUSE[0]
    c = core_x(core)
    y0, y1 = ROOF_Y, ROOF_Y + STAIR_HOUSE[1]
    corridor_mid = (CORRIDOR[0] + CORRIDOR[1]) / 2.0
    _wall(walls, "StairHouse_Inner", LEVELS, c["inner"], CORE_Z[1], c["inner"], CORE_Z[0], CORE_WALL, y0, y1,
          [door(-corridor_mid + CORE_Z[1], 1.8)], outside=True)
    end_x = X0 + EXT / 2 if c["s"] < 0 else X1 - EXT / 2
    _wall(walls, "StairHouse_Outer", LEVELS, end_x, CORE_Z[1], end_x, CORE_Z[0], EXT, y0, y1, [], outside=True)
    return walls


def parapet_walls() -> list:
    walls: list = []
    y0, y1 = ROOF_Y - SLAB, ROOF_Y + PARAPET
    _wall(walls, "Parapet_Front", LEVELS, X0, Z1 - EXT / 2, X1, Z1 - EXT / 2, EXT, y0, y1, [], outside=True)
    _wall(walls, "Parapet_Back", LEVELS, X0, Z0 + EXT / 2, X1, Z0 + EXT / 2, EXT, y0, y1, [], outside=True)
    _wall(walls, "Parapet_EndA", LEVELS, X0 + EXT / 2, Z1, X0 + EXT / 2, Z0, EXT, y0, y1, [], outside=True)
    _wall(walls, "Parapet_EndB", LEVELS, X1 - EXT / 2, Z1, X1 - EXT / 2, Z0, EXT, y0, y1, [], outside=True)
    return walls


def all_walls() -> list:
    walls = []
    for level in range(LEVELS):
        walls += exterior_walls(level) + interior_walls(level)
    return walls + core_walls() + stair_house_walls() + parapet_walls()


# ---- Floors ---------------------------------------------------------------------------------------------
def floor_zones(level: int) -> list:
    """Rectangles (x0, x1, z0, z1, finish, name) tiling one floor; core flight wells are left open above G, and
    so is the atrium."""
    zones = []
    for r in rooms_at(level):
        if r["kind"] == "void":
            continue
        zones.append((r["x0"], r["x1"], r["z0"], r["z1"], FLOOR_FINISH[r["kind"]], r["name"]))
    zones.append((BAY_X[0], BAY_X[-1], CORRIDOR[0], CORRIDOR[1], CORRIDOR_FINISH, "Corridor"))
    zones.append((LIFTS[0], LIFTS[1], LIFTS[2], CORRIDOR[0], "FloorConcrete", "Lift shafts"))
    for core in ("A", "B"):
        c = core_x(core)
        lo, hi = sorted((c["inner"], c["landing_end"]))
        zones.append((lo, hi, CORE_Z[0], CORE_Z[1], CORE_FINISH, f"Core {core} landing"))
        if level == 0:
            lo, hi = sorted((c["landing_end"], c["outer"]))
            zones.append((lo, hi, CORE_Z[0], CORE_Z[1], CORE_FINISH, f"Core {core} well"))
    return zones


def ceiling_zones(level: int) -> list:
    """Rectangles (x0, x1, z0, z1, name) of a storey's drop ceiling: its rooms and corridor, with the atrium's
    ceiling high over the lobby (the lobby itself has none); none in the stair cores or the lift shafts."""
    zones = []
    for r in rooms_at(level):
        if r["kind"] in ATRIUM_KINDS and any(v["kind"] == "void" for v in rooms_at(level + 1)):
            continue
        zones.append((r["x0"], r["x1"], r["z0"], r["z1"], r["name"]))
    zones.append((BAY_X[0], BAY_X[-1], CORRIDOR[0], CORRIDOR[1], "Corridor"))
    return zones


def roof_zones() -> list:
    """The roof slab: everything but core A's well under the stair house's flights."""
    c = core_x(STAIR_HOUSE[0])
    zones = [(IX0, IX1, IZ0, CORE_Z[0], "RoofDeck", "Roof"), (IX0, IX1, CORE_Z[1], IZ1, "RoofDeck", "Roof"),
             (BAY_X[0], BAY_X[-1], CORE_Z[0], CORE_Z[1], "RoofDeck", "Roof")]
    lo, hi = sorted((c["inner"], c["landing_end"]))
    zones.append((lo, hi, CORE_Z[0], CORE_Z[1], CORE_FINISH, "Stair house landing"))
    other = core_x("B" if STAIR_HOUSE[0] == "A" else "A")
    lo, hi = sorted((other["inner"], other["outer"]))
    zones.append((lo, hi, CORE_Z[0], CORE_Z[1], "RoofDeck", "Roof"))
    return zones


# ---- The helipad and the roof ---------------------------------------------------------------------------
HELIPAD = (4.0, -9.0, 6.2)     # centre x, z and radius of the pad's circle
HELICOPTER = (4.0, -9.0, 180.0)  # where it sits and its yaw: nose to the street (+z), open door (its right) toward the stair house
ROOF_PLANT = [(-6.5, -15.2, 3.0, 1.6, 2.2), (-9.8, -15.2, 2.2, 1.4, 2.0), (13.0, -2.6, 3.4, 1.8, 2.0),
              (16.5, -15.5, 2.4, 2.4, 2.6)]  # x, z, w, h, d of roof units

# ---- Lights ----------------------------------------------------------------------------------------------
# Godot lights each storey (scenes/environment/alt_hospital.gd): name, level, x, z, colour, energy, range,
# mode (steady, flicker, strobe, dying, noise, pulse), and optionally its height over the floor (by default
# just under the ceiling). A light lights only its own storey, so the atrium has one for each: the lobby's
# hangs high in the void, just under the gallery's, whose fitting is on the atrium's ceiling.
EMERGENCY = (1.0, 0.14, 0.08)
TUBE = (0.86, 0.92, 0.88)
WARM = (1.0, 0.78, 0.5)
LIGHTS = [
    ("AtriumLow", 0, 1.0, -4.0, TUBE, 2.6, 11.0, "steady", 6.75),
    ("AtriumHigh", 1, 1.0, -4.0, TUBE, 1.6, 8.0, "steady"),
    ("LobbyExitA", 0, -6.0, -7.9, EMERGENCY, 1.2, 4.0, "steady"),
    ("CorridorG1", 0, -10.0, -8.7, TUBE, 0.9, 4.5, "flicker"),
    ("CorridorG2", 0, 10.5, -8.7, EMERGENCY, 1.2, 4.0, "pulse"),
    ("RecordsLamp", 0, 9.4, -16.4, WARM, 1.1, 3.4, "steady"),
    ("ShelterLantern", 0, 9.0, -3.2, WARM, 1.0, 4.2, "noise"),
    ("StairBG", 0, 15.0, -8.7, EMERGENCY, 1.0, 3.6, "steady"),
    ("Corridor2a", 1, 11.0, -8.7, EMERGENCY, 1.2, 4.0, "steady"),
    ("Corridor2b", 1, -0.5, -8.7, TUBE, 0.9, 4.5, "strobe"),
    ("Corridor2c", 1, -11.0, -8.7, EMERGENCY, 1.1, 4.0, "pulse"),
    ("NurseLamp", 1, -4.7, -11.6, WARM, 1.2, 3.6, "flicker"),
    ("ChildrenNight", 1, -10.2, -14.5, (0.55, 0.62, 1.0), 0.8, 3.6, "steady"),
    ("Corridor3a", 2, -11.0, -8.7, EMERGENCY, 1.1, 4.0, "steady"),
    ("Corridor3b", 2, 2.0, -8.7, TUBE, 0.8, 4.5, "dying"),
    ("Theatre1Lamp", 2, -10.2, -3.8, (0.9, 0.95, 1.0), 1.6, 3.8, "flicker"),
    ("Corridor3c", 2, 11.5, -8.7, EMERGENCY, 1.1, 4.0, "pulse"),
    ("Corridor4a", 3, 11.0, -8.7, EMERGENCY, 1.1, 4.0, "steady"),
    ("Corridor4b", 3, 0.0, -8.7, TUBE, 0.8, 4.5, "flicker"),
    ("ICUMonitors", 3, -4.0, -3.4, (0.35, 1.0, 0.55), 0.7, 3.4, "noise"),
    ("RadioDesk", 3, 10.5, -1.6, WARM, 1.2, 3.4, "steady"),
    ("Corridor4c", 3, -11.0, -8.7, EMERGENCY, 1.3, 4.0, "strobe"),
]

# ---- Story points (building-local) ---------------------------------------------------------------------
def landing_point(core: str, level: int) -> tuple:
    c = core_x(core)
    return (round((c["inner"] + c["landing_end"]) / 2.0, 3), floor_y(level), -8.7)


POINTS = {
    "entrance": (0.0, FLOOR0, 2.0),
    "lobby": (0.0, FLOOR0, -4.0),
    "roof_door": (core_x(STAIR_HOUSE[0])["inner"] + 1.6, ROOF_Y, -8.7),
    "helipad": (HELIPAD[0], ROOF_Y, HELIPAD[1]),
}
for _core in ("A", "B"):
    for _level in range(LEVELS):
        POINTS[f"landing_{_core}{_level}"] = landing_point(_core, _level)
# Where the Clawman waits on each storey (building-local): the far end of the corridor from where you come in.
CLAWMAN_POSTS = {1: (-11.6, floor_y(1), -8.7), 2: (11.6, floor_y(2), -8.7), 3: (-11.6, floor_y(3), -8.7)}


def check() -> list:
    """Problems in the plan that would break the building."""
    problems = []
    for wall in all_walls():
        length = abs(wall["x2"] - wall["x1"]) + abs(wall["z2"] - wall["z1"])
        if wall.get("style", "wall") != "wall":
            continue
        last = 0.0
        for o in wall["openings"]:
            lo, hi = o["center"] - o["width"] / 2.0, o["center"] + o["width"] / 2.0
            if lo < 0.1 or hi > length - 0.1:
                problems.append(f"{wall['id']}: opening at {o['center']} runs off the wall ({length:.2f} m)")
            if lo < last - 1e-6:
                problems.append(f"{wall['id']}: openings overlap at {o['center']}")
            last = hi
            if o["kind"] in ("door", "chained") and o["width"] < 1.6:
                problems.append(f"{wall['id']}: doorway {o['width']} m is narrower than 1.6 m")
    for level in range(LEVELS):
        area = sum((z[1] - z[0]) * (z[3] - z[2]) for z in floor_zones(level))
        if area <= 0:
            problems.append(f"level {level}: no floor")
    return problems


if __name__ == "__main__":
    found = check()
    print("\n".join(found) if found else "plan OK: %d walls, %d rooms" % (len(all_walls()), len(ROOMS)))
