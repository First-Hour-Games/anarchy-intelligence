"""Carrie's house, a 1920s American foursquare: grey-box layout in house-local game metres.

x runs along the front (+x to the right when facing the house), y is up, and +z points
out of the front door toward the porch. Exterior wall centre lines are x -5..5, z -10..0.
Read by tools/blender/build_carrie_house.py. Design: four rooms per floor around a
ground-floor loop, a main stair up from the hall and a back stair down to the kitchen, a
cellar with a bulkhead out to the yard, and an attic. For the opening chapter the cellar,
attic, parents' room, bathroom and sewing room are shut; the open route is the hall, living
room, both stairs, the landing, Carrie's room and the kitchen with its back door.

Everything on the open route is sized for the game's bodies, not a real house: doors at least
1.0 m wide (monsters are 0.8 m across), 1.2 m of clear floor at both ends of each stair, and no
furniture in front of a door or a stair. carrie_house/validate.py checks this.
"""

GRADE = 0.0     # yard
GROUND = 0.6    # ground-floor finished floor
UPPER = 3.65    # upstairs finished floor (ground ceiling at 3.40)
ATTIC = 6.4     # attic floor (upstairs ceiling at 6.25)
CELLAR = -1.9   # cellar floor
EXT_T = 0.2
INT_T = 0.12
GROUND_TOP = UPPER - 0.25
UPPER_TOP = ATTIC - 0.15


def opening(a, b, y0, y1, kind="opening"):
    """A gap in a wall from a to b along it, between heights y0 and y1."""
    return {"a": a, "b": b, "y0": y0, "y1": y1, "kind": kind}


def window(a, b, floor, sill=0.75, head=2.25):
    return opening(a, b, floor + sill, floor + head, "window")


def door(a, b, floor, kind="door", head=2.15):
    return opening(a, b, floor, floor + head, kind)


walls = []


def wall(id, axis, fixed, start, end, y0, y1, t=INT_T, openings=(), slope=None):
    """axis "x": runs along x at z = fixed; axis "z": runs along z at x = fixed. slope = (y_at_start,
    y_at_end) makes the top follow a stair instead of y1."""
    walls.append({"id": id, "axis": axis, "fixed": fixed, "start": min(start, end), "end": max(start, end),
                  "y0": y0, "y1": y1, "t": t, "openings": list(openings), "slope": slope})


# --- Exterior walls (cellar floor to the attic plate) --------------------------------
wall("ExtFront", "x", 0.0, -5.1, 5.1, CELLAR - 0.2, ATTIC, EXT_T, [
    door(1.6, 2.8, GROUND),                                        # front door
    window(-4.1, -3.1, GROUND), window(-2.1, -1.1, GROUND),        # living room
    window(-4.1, -3.1, UPPER, 0.8, 2.2), window(-2.1, -1.1, UPPER, 0.8, 2.2),  # Carrie's room
    window(1.7, 2.7, UPPER, 0.8, 2.2),                             # parents' room
])
wall("ExtBack", "x", -10.0, -5.1, 5.1, CELLAR - 0.2, ATTIC, EXT_T, [
    door(1.75, 2.75, GROUND),                                      # back door
    window(0.85, 1.55, GROUND, 1.0, 2.0),                          # over the sink
    window(-3.4, -2.4, GROUND),                                    # dining room
    window(3.9, 4.6, GROUND, 1.5, 2.4),                            # back stair
    window(-3.4, -2.4, UPPER, 0.8, 2.2),                           # sewing room
    window(1.4, 2.1, UPPER, 1.3, 2.2),                             # bathroom
    door(-3.5, -2.5, CELLAR, "door", 2.0),                         # cellar door to the bulkhead
])
wall("ExtLeft", "z", -5.0, -10.1, 0.1, CELLAR - 0.2, ATTIC, EXT_T, [
    window(-2.2, -1.2, GROUND),                                    # living room
    window(-7.4, -6.4, GROUND), window(-9.2, -8.2, GROUND),        # dining room
    window(-3.6, -2.6, UPPER, 0.8, 2.2),                           # Carrie's room
    window(-5.4, -4.6, UPPER, 1.0, 2.2),                           # landing
    window(-8.0, -7.0, UPPER, 0.8, 2.2),                           # sewing room
])
wall("ExtRight", "z", 5.0, -10.1, 0.1, CELLAR - 0.2, ATTIC, EXT_T, [
    window(-2.8, -2.0, GROUND, 1.0, 2.2),                          # hall, beside the stair
    window(-8.4, -7.6, GROUND, 1.1, 2.1),                          # kitchen, over the stairs
    window(-2.6, -1.6, UPPER, 1.0, 2.2),                           # main stairwell
    window(-7.8, -7.0, UPPER, 1.0, 2.2),                           # back stairwell
])

# --- Ground floor ----------------------------------------------------------------------
wall("G_FrontBack", "x", -5.0, -4.9, 3.6, GROUND, GROUND_TOP, INT_T, [
    opening(-3.6, -2.0, GROUND, GROUND + 2.25),                    # living <-> dining, wide cased opening
    opening(1.2, 2.6, GROUND, GROUND + 2.15),                      # hall <-> kitchen
])
wall("G_CellarLanding", "x", -5.0, 3.6, 4.9, GROUND, GROUND_TOP)
wall("G_LeftRight", "z", 0.6, -9.9, -0.1, GROUND, GROUND_TOP, INT_T, [
    opening(-3.8, -1.0, GROUND, GROUND + 2.25),                    # living <-> hall, wide cased opening
    opening(-8.4, -7.0, GROUND, GROUND + 2.15),                    # dining <-> kitchen
])
wall("G_StairEnclosure", "z", 3.6, -9.9, -5.0, GROUND, GROUND_TOP, INT_T, [
    door(-6.0, -5.2, GROUND, "door"),                              # cellar door (shut)
    door(-9.85, -8.65, GROUND, "door"),                            # back stair foot
])
# Stringer wall of the main stair, with the coat closet underneath its upper half. It ends at
# the stair's first riser, leaving the 1.2 m in front of the stair open to the hall.
wall("G_StairSide", "z", 3.65, -5.0, -1.3, GROUND, GROUND_TOP, 0.08,
     [door(-4.6, -3.8, GROUND, "closet", 1.95)], slope=(GROUND + 3.05, GROUND))
wall("G_ClosetFront", "x", -3.6, 3.7, 4.9, GROUND, GROUND + 1.85, 0.08)    # meets the stair's underside

# --- Upstairs --------------------------------------------------------------------------
# The landing hall is 1.8 m wide: room for two people to pass, and for enemies to follow.
wall("U_FrontRoomsBack", "x", -4.2, -4.9, 3.6, UPPER, UPPER_TOP, INT_T, [
    door(-2.5, -1.3, UPPER), door(1.6, 2.6, UPPER),               # Carrie's room, parents' room
])
wall("U_BackRoomsFront", "x", -6.0, -4.9, 3.5, UPPER, UPPER_TOP, INT_T, [
    door(-2.4, -1.4, UPPER, "boarded"), door(1.6, 2.5, UPPER),     # sewing room (boarded), bathroom
])
wall("U_FrontSplit", "z", 0.3, -4.2, -0.1, UPPER, UPPER_TOP, INT_T, [door(-3.6, -2.8, UPPER, "closet")])
wall("U_ClosetEast", "z", 1.3, -4.2, -2.2, UPPER, UPPER_TOP, INT_T, [door(-3.6, -2.8, UPPER, "closet")])
wall("U_ClosetFront", "x", -2.2, 0.3, 1.3, UPPER, UPPER_TOP)
wall("U_BackSplit", "z", 0.3, -9.9, -6.0, UPPER, UPPER_TOP)
wall("U_BathEast", "z", 3.5, -9.9, -6.0, UPPER, UPPER_TOP)
wall("U_ParentsEast", "z", 3.6, -4.2, -0.1, UPPER, UPPER_TOP)

# --- Floors: (id, y_top, thickness, rectangle (x0, x1, z0, z1), holes) ---------------------
floors = [
    ("CellarFloor", CELLAR, 0.2, (-4.9, 4.9, -9.9, -0.1), []),
    ("GroundFloor", GROUND, 0.25, (-4.9, 4.9, -9.9, -0.1), []),
    ("UpperFloor", UPPER, 0.25, (-4.9, 4.9, -9.9, -0.1), [(3.6, 4.9, -4.55, -0.1), (3.6, 4.9, -9.5, -5.8)]),
    ("AtticFloor", ATTIC, 0.15, (-4.9, 4.9, -9.9, -0.1), []),
    ("PorchDeck", GROUND - 0.05, GROUND - 0.05, (-5.4, 5.4, 0.1, 2.7), []),
    ("BackStoop", GROUND - 0.05, GROUND - 0.05, (1.5, 3.0, -11.1, -10.1), []),
]

# --- Stairs: x range, z where it starts and ends, heights, riser count ------------------
stairs = [
    # 8-inch risers on 8.5-inch treads. The foot leaves 1.2 m of hall in front of the first riser
    # and the top lands 1.25 m from the back stair's, so both ends have room to step off.
    {"id": "MainStair", "x": (3.7, 4.9), "z": (-1.3, -4.55), "y": (GROUND, UPPER), "risers": 15},
    # A steep servants' stair: 1.3 m of floor at its foot by the kitchen door.
    {"id": "BackStair", "x": (3.65, 4.9), "z": (-8.6, -5.8), "y": (GROUND, UPPER), "risers": 14},
    {"id": "PorchSteps", "x": (1.5, 2.9), "z": (2.7, 3.6), "y": (GROUND - 0.05, GRADE), "risers": 3},
    {"id": "BackSteps", "x": (1.5, 3.0), "z": (-11.1, -11.85), "y": (GROUND - 0.05, GRADE), "risers": 3},
    {"id": "BulkheadSteps", "x": (-3.6, -2.4), "z": (-10.1, -12.6), "y": (CELLAR, GRADE), "risers": 10},
    # The cellar stair and the attic ladder are left out while the cellar and attic are shut.
]

# --- Rooms (labels and later checks): name, floor y, x0, x1, z0, z1 ------------------------
rooms = [
    ("LIVING ROOM", GROUND, -4.9, 0.6, -5.0, -0.1), ("HALL", GROUND, 0.6, 3.6, -5.0, -0.1),
    ("DINING ROOM", GROUND, -4.9, 0.6, -9.9, -5.0), ("KITCHEN", GROUND, 0.6, 3.6, -9.9, -5.0),
    ("CARRIE'S ROOM", UPPER, -4.9, 0.3, -4.2, -0.1), ("PARENTS' ROOM", UPPER, 0.3, 3.6, -4.2, -0.1),
    ("LANDING", UPPER, -4.9, 4.9, -6.0, -4.2), ("SEWING ROOM", UPPER, -4.9, 0.3, -9.9, -6.0),
    ("BATH", UPPER, 0.3, 3.5, -9.9, -6.0), ("CELLAR", CELLAR, -4.9, 4.9, -9.9, -0.1),
    ("ATTIC", ATTIC, -3.5, 3.5, -8.5, -1.5),
]

# --- Grey-box objects: name, role, floor y, x0, x1, z0, z1, height ------------------------
# Roles colour the blocks: hide (hiding spot), interact (distraction or puzzle), story,
# furniture, blocked.
objects = [
    # Living room
    # Against the back wall beside the dining-room opening, under the landscape.
    ("Sofa", "furniture", GROUND, -1.9, 0.1, -4.94, -4.14, 0.85),
    # Facing the TV, seen side-on through the opening from the hall: the Wrapper sits here.
    ("Armchair", "furniture", GROUND, -3.05, -2.15, -2.85, -1.95, 0.9),
    ("TV", "interact", GROUND, -2.95, -2.25, -0.6, -0.12, 1.05),
    ("ChimneyBreast", "furniture", GROUND, -4.9, -4.45, -4.4, -3.0, GROUND_TOP - GROUND),
    ("Hearth", "furniture", GROUND, -4.45, -3.85, -4.4, -3.0, 0.06),
    # Hall
    ("CoatRack", "furniture", GROUND, 0.75, 1.1, -0.6, -0.25, 1.8),
    ("HallTable", "furniture", GROUND, 2.9, 3.55, -2.65, -2.15, 0.8),
    ("CoatCloset", "hide", GROUND, 3.72, 4.88, -4.95, -3.65, 0.05),
    # Dining room
    ("DiningTable", "furniture", GROUND, -3.4, -1.6, -8.3, -6.9, 0.76),
    ("ChinaCabinet", "furniture", GROUND, 0.0, 0.54, -9.8, -8.6, 1.9),
    # Kitchen
    ("Counter", "furniture", GROUND, 0.66, 1.55, -9.9, -9.3, 0.92),
    ("Stove", "furniture", GROUND, 0.66, 1.31, -9.25, -8.5, 0.95),
    ("Icebox", "furniture", GROUND, 0.66, 1.36, -6.9, -6.2, 1.7),
    # Against the stair wall, so the kitchen stays open for the back stair and back door.
    ("KitchenTable", "furniture", GROUND, 2.94, 3.54, -7.8, -7.0, 0.76),
    ("Radio", "interact", GROUND + 0.92, 0.8, 1.15, -9.75, -9.5, 0.3),
    # Carrie's room
    ("CarrieBed", "hide", UPPER, -4.6, -3.6, -2.15, -0.15, 0.6),
    ("CarrieWardrobe", "hide", UPPER, -4.8, -3.8, -4.14, -3.6, 2.0),
    # Far enough back from the desk to stand at it and read the notebook.
    ("DollhouseTable", "furniture", UPPER, -2.6, -1.4, -3.0, -1.95, 0.6),
    # This house at 1:16 on its base, front to the windows and open back to the door.
    ("Dollhouse", "story", UPPER + 0.6, -2.38, -1.62, -2.94, -2.01, 0.65),
    ("CarrieDesk", "furniture", UPPER, -2.2, -1.0, -0.7, -0.15, 0.75),
    # Parents' room
    ("ParentsBed", "furniture", UPPER, 1.5, 3.1, -2.3, -0.25, 0.6),
    ("Dresser", "furniture", UPPER, 3.05, 3.55, -4.1, -2.9, 1.0),
    ("WalkInCloset", "hide", UPPER, 0.36, 1.24, -4.14, -2.26, 0.05),
    # Sewing room (boarded)
    ("SewingTable", "furniture", UPPER, -2.4, -1.0, -9.6, -8.8, 0.75),
    ("SewingBoards", "blocked", UPPER, -2.45, -1.35, -5.94, -5.84, 2.1),
    # Bathroom
    ("Bathtub", "furniture", UPPER, 0.4, 2.0, -9.85, -9.1, 0.55),
    ("Basin", "furniture", UPPER, 2.4, 2.9, -9.85, -9.45, 0.85),
    # Attic
    ("AtticTrunk", "furniture", ATTIC, -2.6, -1.4, -6.9, -6.3, 0.6),
    ("AtticBoxes", "furniture", ATTIC, 1.0, 2.4, -7.0, -5.8, 0.8),
    # Cellar
    ("Furnace", "furniture", CELLAR, -1.0, 0.6, -5.8, -4.4, 1.6),
    ("CellarShelves", "furniture", CELLAR, -4.9, -4.4, -4.0, -1.0, 2.0),
    ("WashingMachine", "interact", CELLAR, 2.2, 2.9, -9.8, -9.2, 1.0),
    ("LaundryTub", "furniture", CELLAR, 1.3, 2.0, -9.8, -9.3, 0.9),
    ("CoalBin", "furniture", CELLAR, -4.8, -3.8, -9.8, -8.6, 1.0),
    # Outside: the bulkhead doors over the cellar steps, chained shut
    ("BulkheadDoors", "blocked", GRADE + 0.05, -3.7, -2.3, -12.7, -10.1, 0.75),
]

# --- Doors: which stand open ------------------------------------------------------------------
# Interior door leaves by (wall, opening start): name, hinge jamb, side it swings to across the
# wall (+1 or -1), degrees open. A door at 0 is shut and solid; an open one has no collision and
# is walked through, so it stands back against the wall on its hinge side.
door_leaves = {
    ("G_StairEnclosure", -6.0): ("CellarDoor", "b", -1.0, 0.0),
    ("G_StairEnclosure", -9.85): ("BackStairDoor", "a", 1.0, 90.0),
    ("G_StairSide", -4.6): ("CoatClosetDoor", "a", -1.0, 0.0),
    ("U_FrontRoomsBack", -2.5): ("CarrieDoor", "a", 1.0, 95.0),
    ("U_FrontRoomsBack", 1.6): ("ParentsDoor", "b", 1.0, 0.0),
    ("U_BackRoomsFront", 1.6): ("BathDoor", "a", -1.0, 0.0),
    ("U_FrontSplit", -3.6): ("WalkInClosetDoorWest", "a", -1.0, 0.0),
    ("U_ClosetEast", -3.6): ("WalkInClosetDoorEast", "a", 1.0, 0.0),
}
# The ground-floor doors in the outside walls, by wall, in the same form. The front door folds
# back flat against the front wall, clear of the view into the living room and the way to the stair.
exterior_doors = {
    "ExtFront": ("FrontDoorLeaf", "b", -1.0, 175.0),
    "ExtBack": ("BackDoorLeaf", "a", 1.0, 90.0),
}
