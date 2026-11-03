"""Furniture and fittings for Carrie's house, modelled from boxes, rods and prisms.

Each model fills one piece's footprint in a frame of its own: x across its width W, y up from its
floor, z from its back (0) to its front (D). H is the height the layout gives. build_carrie_house.py
supplies the piece `p`, which maps that frame into the house and offers:
    p.box(x0, x1, y0, y1, z0, z1, mat)
    p.stick(a, b, r, mat, r2=None, normal=None)       rod from point a to b; with normal, a flat board
    p.tube(a, b, r, mat, sides=10)                     round pipe from point a to b
    p.cyl(centre, r, a, b, mat, axis="y", sides=8, r2=None)
    p.tray(x0, x1, y0, y1, z0, z1, wall, mat)           open-topped box
Materials are names from the builder's FINISHES and TEXTURES.
"""

from math import cos, sin

# Layout objects: name -> (model, the direction its front faces).
PIECES = {
    "Sofa": ("sofa", "+z"), "Armchair": ("armchair", "+z"), "TV": ("console_tv", "-z"),
    "ChimneyBreast": ("fireplace", "+x"), "Hearth": ("hearth", "+x"),
    "CoatRack": ("hall_tree", "+x"), "HallTable": ("hall_table", "-x"),
    "DiningTable": ("dining_table", "+z"), "ChinaCabinet": ("china_cabinet", "-x"),
    "Counter": ("sink_counter", "+z"), "Stove": ("range_stove", "+x"), "Icebox": ("icebox", "+x"),
    "KitchenTable": ("kitchen_table", "+z"), "Radio": ("radio", "+z"),
    "CarrieBed": ("child_bed", "-z"), "CarrieWardrobe": ("wardrobe", "+z"), "DollhouseTable": ("play_table", "-z"),
    "CarrieDesk": ("desk", "-z"), "ParentsBed": ("double_bed", "-z"), "Dresser": ("dresser", "-x"),
    "SewingTable": ("sewing_machine", "+z"), "SewingBoards": ("nailed_boards", "+z"),
    "Bathtub": ("clawfoot_tub", "+z"), "Basin": ("pedestal_sink", "+z"),
    "AtticTrunk": ("trunk", "+z"), "AtticBoxes": ("box_stack", "+z"),
    "Furnace": ("furnace", "+z"), "CellarShelves": ("shelves", "+x"), "WashingMachine": ("wringer_washer", "+z"),
    "LaundryTub": ("laundry_tub", "+z"), "CoalBin": ("coal_bin", "+x"),
}

# Furniture that doesn't stop the player: rugs, small things on tables, the doll on the bed.
PASSABLE = {"LivingRug", "HallRunner", "CarrieRug", "ParentsRug", "Hearth", "Radio", "CarrieDoll", "FloorLamp"}

# Extra dressing: name, model, storey ("CELLAR", "GROUND", "UPPER", "ATTIC"), lift above that floor,
# x0, x1, z0, z1, height, facing.
DRESSING = [
    ("DiningChair1", "dining_chair", "GROUND", 0.0, -3.25, -2.8, -8.8, -8.35, 0.95, "+z"),
    ("DiningChair2", "dining_chair", "GROUND", 0.0, -2.2, -1.75, -8.8, -8.35, 0.95, "+z"),
    ("DiningChair3", "dining_chair", "GROUND", 0.0, -3.25, -2.8, -6.85, -6.4, 0.95, "-z"),
    ("DiningChair4", "dining_chair", "GROUND", 0.0, -2.2, -1.75, -6.85, -6.4, 0.95, "-z"),
    ("LivingRug", "rug", "GROUND", 0.0, -3.9, -0.9, -3.3, -1.1, 0.01, "+z"),
    ("FloorLamp", "floor_lamp", "GROUND", 0.0, 0.15, 0.45, -4.9, -4.6, 1.6, "+z"),
    ("HallRunner", "runner", "GROUND", 0.0, 1.45, 2.35, -4.6, -0.75, 0.01, "+x"),
    ("CarrieDeskChair", "desk_chair", "UPPER", 0.0, -1.85, -1.45, -1.12, -0.72, 0.8, "+z"),
    ("CarrieRug", "rag_rug", "UPPER", 0.0, -3.5, -0.9, -3.6, -2.65, 0.01, "+z"),
    ("CarrieDoll", "doll", "UPPER", 0.54, -4.22, -3.97, -0.86, -0.66, 0.34, "-z"),
    ("ParentsRug", "rug", "UPPER", 0.0, 1.5, 3.1, -3.4, -2.45, 0.01, "+z"),
    ("Nightstand", "nightstand", "UPPER", 0.0, 3.15, 3.5, -0.75, -0.3, 0.6, "-x"),
    ("DressForm", "dress_form", "UPPER", 0.0, -4.25, -3.75, -7.15, -6.65, 1.5, "+x"),
    ("Toilet", "toilet", "UPPER", 0.0, 2.95, 3.4, -9.85, -9.2, 0.4, "+z"),
]

# Framed pictures: name, wall, side of it (+1 or -1 across), along, centre height above that storey's
# floor, width, height, image material.
PICTURES = [
    ("HallPortrait", "G_LeftRight", 1.0, -4.4, 1.6, 0.42, 0.55, "Photo"),
    ("LivingLandscape", "G_FrontBack", 1.0, -1.0, 1.75, 0.75, 0.5, "Painting"),
    ("LandingPicture", "U_FrontRoomsBack", -1.0, -3.7, 1.6, 0.5, 0.4, "Painting"),
    ("CarrieDrawing", "U_FrontSplit", -1.0, -1.4, 1.25, 0.3, 0.22, "Paper"),
    ("WeddingPortrait", "U_FrontRoomsBack", 1.0, 2.95, 1.7, 0.36, 0.48, "Photo"),
]
# Rooms whose windows get curtains, and the curtain material.
CURTAINS = {"LIVING ROOM": "Curtain", "DINING ROOM": "Curtain", "CARRIE'S ROOM": "Quilt",
            "PARENTS' ROOM": "Curtain", "SEWING ROOM": "Fabric"}


def scatter(seed: int, count: int) -> list:
    """Repeatable pseudo-random numbers in 0..1."""
    values, state = [], seed * 2654435761 % 4294967296
    for _ in range(count):
        state = (1103515245 * state + 12345) % 2147483648
        values.append(state / 2147483648.0)
    return values


def legs(p, height, size, mat, inset=0.03, x0=0.0, x1=None, z0=0.0, z1=None):
    """Four square legs inset from the corners of a rectangle."""
    x1 = p.W if x1 is None else x1
    z1 = p.D if z1 is None else z1
    for x in (x0 + inset, x1 - inset - size):
        for z in (z0 + inset, z1 - inset - size):
            p.box(x, x + size, 0.0, height, z, z + size, mat)


def framed(p, x0, x1, y0, y1, z0, z1, border, frame_mat, inner_mat, inset=0.012):
    """A frame of four bars round an inner panel set back from the frame's front."""
    p.box(x0, x1, y0, y0 + border, z0, z1, frame_mat)
    p.box(x0, x1, y1 - border, y1, z0, z1, frame_mat)
    p.box(x0, x0 + border, y0, y1, z0, z1, frame_mat)
    p.box(x1 - border, x1, y0, y1, z0, z1, frame_mat)
    p.box(x0 + border, x1 - border, y0 + border, y1 - border, z0, z1 - inset, inner_mat)


def panel_door(p, x0, x1, y0, y1, z, mat, knob_x=None, inner=None):
    """A flat door or drawer front on the piece's front at depth z, with a raised frame and a knob."""
    p.box(x0, x1, y0, y1, z, z + 0.015, mat)
    border = min(0.06, (x1 - x0) / 5.0, (y1 - y0) / 5.0)
    framed(p, x0, x1, y0, y1, z + 0.015, z + 0.025, border, mat, inner or mat, 0.006)
    if knob_x is not None:
        y = (y0 + y1) / 2.0 if y1 - y0 < 0.4 else y0 + (y1 - y0) * 0.45
        p.box(knob_x - 0.015, knob_x + 0.015, y - 0.015, y + 0.015, z + 0.025, z + 0.05, "Brass")


def picture(p, image):
    """A picture on a wire, or a sheet of paper pinned up when image is "Paper"."""
    W, H = p.W, p.H
    if image == "Paper":
        p.box(0.0, W, 0.0, H, 0.0, 0.002, "Paper")
        p.box(W / 2.0 - 0.006, W / 2.0 + 0.006, H - 0.03, H - 0.018, 0.002, 0.01, "Quilt")
        return
    framed(p, 0.0, W, 0.0, H, 0.0, 0.03, 0.035, "Gilt" if image == "Painting" else "Walnut", image, 0.01)
    for side in (-1.0, 1.0):
        p.stick((W / 2.0 + side * 0.12, H - 0.04, 0.004), (W / 2.0, H + 0.1, 0.004), 0.002, "Iron")


# --- Living room ----------------------------------------------------------------------------

def sofa(p, seats=3, fabric="Upholstery"):
    W, D, H = p.W, p.D, p.H
    arm = 0.16
    legs(p, 0.1, 0.06, "Walnut", inset=0.04)
    p.box(0.0, W, 0.1, 0.42, 0.0, D, fabric)
    p.box(0.0, arm, 0.42, 0.66, 0.0, D, fabric)
    p.box(W - arm, W, 0.42, 0.66, 0.0, D, fabric)
    p.box(arm, W - arm, 0.42, H, 0.0, 0.2, fabric)
    width = (W - 2.0 * arm) / seats
    for i in range(seats):
        x = arm + i * width
        p.box(x + 0.005, x + width - 0.005, 0.42, 0.53, 0.2, D - 0.02, fabric)
        p.box(x + 0.01, x + width - 0.01, 0.53, H - 0.04, 0.17, 0.3, fabric)
    p.box(arm + 0.05, arm + 0.45, 0.53, 0.56, 0.32, D - 0.06, "Quilt")                 # a folded throw


def armchair(p):
    sofa(p, seats=1)


def wrapped_figure(p):
    """The Wrapper sitting in the armchair, dark and bound, its arms wrapped round itself: only
    the dollhouse has this one, in its living room. Drawn in the armchair's frame (see sofa: seat
    top 0.53, back cushion at the back)."""
    W, D = p.W, p.D
    cx = W / 2.0
    cloth, band = "Fabric", "Screen"
    for side in (-1.0, 1.0):
        x0, x1 = sorted((cx + side * 0.03, cx + side * 0.16))
        p.box(x0, x1, 0.53, 0.68, 0.3, D + 0.02, cloth)                                  # thighs
        p.box(x0, x1, 0.06, 0.62, D - 0.1, D + 0.02, cloth)                              # shins
        p.box(x0, x1, 0.0, 0.07, D - 0.1, D + 0.12, band)                                # feet
        a0, a1 = sorted((cx + side * 0.2, cx + side * 0.27))
        p.box(a0, a1, 0.8, 1.08, 0.3, 0.42, cloth)                                       # upper arms
    p.box(cx - 0.22, cx + 0.22, 0.86, 0.94, 0.44, 0.5, cloth)                            # arms across the chest
    p.box(cx - 0.2, cx + 0.2, 0.55, 1.12, 0.24, 0.46, cloth)                             # body
    p.box(cx - 0.05, cx + 0.05, 1.12, 1.18, 0.3, 0.4, cloth)                             # neck
    p.cyl((cx, 0.36), 0.1, 1.17, 1.42, cloth, sides=10)                                  # head
    for y in (0.7, 0.86, 1.0):                                                           # bindings
        p.box(cx - 0.205, cx + 0.205, y, y + 0.03, 0.235, 0.465, band)
    p.cyl((cx, 0.36), 0.103, 1.27, 1.31, band, sides=10)                                 # across the face


def console_tv(p):
    W, D, H = p.W, p.D, p.H
    for x in (0.06, W - 0.06):
        for z in (0.06, D - 0.06):
            p.stick((x, 0.0, z), (x, 0.13, z), 0.018, "Walnut")
    p.box(0.0, W, 0.12, H - 0.04, 0.0, D, "Walnut")
    p.box(-0.01, W + 0.01, H - 0.04, H, -0.01, D + 0.01, "Walnut")
    framed(p, 0.06, W - 0.06, 0.5, H - 0.1, D, D + 0.02, 0.03, "Iron", "Screen", 0.008)
    p.box(0.07, W - 0.2, 0.18, 0.44, D, D + 0.008, "Fabric")
    for y in (0.37, 0.26):
        p.stick((W - 0.12, y, D), (W - 0.12, y, D + 0.03), 0.02, "Brass")
    p.box(W / 2.0 - 0.05, W / 2.0 + 0.05, H, H + 0.03, D / 2.0 - 0.04, D / 2.0 + 0.04, "Iron")
    p.stick((W / 2.0, H + 0.03, D / 2.0), (W / 2.0 - 0.25, H + 0.45, D / 2.0 - 0.05), 0.004, "Chrome")
    p.stick((W / 2.0, H + 0.03, D / 2.0), (W / 2.0 + 0.22, H + 0.48, D / 2.0 - 0.08), 0.004, "Chrome")


def fireplace(p):
    """Brick chimney breast with a firebox, oak mantel, overmantel mirror, papered above."""
    W, D, H = p.W, p.D, p.H
    left, right, top, mantel = 0.42, W - 0.42, 0.78, 1.26
    back = D - 0.32
    p.box(0.0, left, 0.0, mantel, 0.0, D, "Brick")
    p.box(right, W, 0.0, mantel, 0.0, D, "Brick")
    p.box(left, right, top, mantel, 0.0, D, "Brick")
    p.box(left, right, 0.0, top, 0.0, back, "Void")
    p.box(0.0, W, mantel, H, 0.0, D - 0.04, "PaperOgee")
    p.box(-0.06, W + 0.06, mantel, mantel + 0.06, D - 0.06, D + 0.16, "Walnut")
    p.box(0.05, W - 0.05, mantel - 0.16, mantel, D, D + 0.05, "Walnut")
    for x in (0.12, W - 0.2):
        p.box(x, x + 0.08, mantel - 0.32, mantel - 0.16, D, D + 0.1, "Walnut")
    p.box(left + 0.08, right - 0.08, 0.0, 0.03, back + 0.02, back + 0.26, "Iron")         # grate
    for k in range(6):
        x = left + 0.1 + k * (right - left - 0.2) / 5.0
        p.box(x - 0.008, x + 0.008, 0.03, 0.16, back + 0.24, back + 0.26, "Iron")
    p.stick((left + 0.12, 0.08, back + 0.1), (right - 0.15, 0.1, back + 0.17), 0.045, "Coal")
    p.stick((left + 0.2, 0.15, back + 0.18), (right - 0.1, 0.13, back + 0.08), 0.04, "Coal")
    framed(p, 0.3, W - 0.3, mantel + 0.22, mantel + 1.02, D - 0.04, D + 0.01, 0.06, "Walnut", "Mirror")
    c = W / 2.0                                                                          # mantel clock
    p.box(c - 0.13, c + 0.13, mantel + 0.06, mantel + 0.3, D + 0.01, D + 0.12, "Walnut")
    p.box(c - 0.07, c + 0.07, mantel + 0.12, mantel + 0.26, D + 0.12, D + 0.125, "Paper")
    for x in (0.18, W - 0.18):                                                           # candlesticks
        p.cyl((x, D + 0.06), 0.04, mantel + 0.06, mantel + 0.08, "Brass")
        p.cyl((x, D + 0.06), 0.012, mantel + 0.08, mantel + 0.3, "Brass")
        p.cyl((x, D + 0.06), 0.01, mantel + 0.3, mantel + 0.4, "Paper")
    p.box(W - 0.48, W - 0.34, mantel + 0.06, mantel + 0.24, D + 0.05, D + 0.07, "Walnut")   # photo frame
    p.box(W - 0.46, W - 0.36, mantel + 0.08, mantel + 0.22, D + 0.07, D + 0.072, "Photo")


def hearth(p):
    p.box(0.0, p.W, 0.0, p.H, 0.0, p.D, "Brick")


def floor_lamp(p):
    W, D, H = p.W, p.D, p.H
    c = (W / 2.0, D / 2.0)
    p.cyl(c, 0.14, 0.0, 0.03, "Brass", sides=10)
    p.cyl(c, 0.014, 0.03, H - 0.25, "Brass")
    p.cyl(c, 0.12, H - 0.3, H, "Lampshade", sides=10, r2=0.2)


def rug(p, mat="Rug"):
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, 0.0, H, 0.0, D, mat)
    p.box(0.12, W - 0.12, H, H + 0.002, 0.12, D - 0.12, "RugBlue" if mat == "Rug" else "Rug")
    p.box(0.2, W - 0.2, H + 0.002, H + 0.004, 0.2, D - 0.2, mat)


def runner(p):
    rug(p, "RugBlue")


def rag_rug(p):
    W, D, H = p.W, p.D, p.H
    for k, mat in enumerate(("Quilt", "RugBlue", "Curtain", "Rug", "QuiltBlue")):
        inset = k * min(W, D) / 11.0
        p.box(inset, W - inset, k * 0.002, H + k * 0.002, inset, D - inset, mat)


# --- Hall ---------------------------------------------------------------------------------------

def hall_tree(p):
    W, D, H = p.W, p.D, p.H
    cx, cz = W / 2.0, D / 2.0
    p.stick((cx - 0.2, 0.02, cz), (cx + 0.2, 0.02, cz), 0.02, "Walnut")
    p.stick((cx, 0.02, cz - 0.2), (cx, 0.02, cz + 0.2), 0.02, "Walnut")
    p.box(cx - 0.025, cx + 0.025, 0.0, H, cz - 0.025, cz + 0.025, "Walnut")
    p.cyl((cx, cz), 0.035, H, H + 0.06, "Walnut")
    for dx, dz in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
        p.stick((cx, H - 0.16, cz), (cx + dx * 0.17, H - 0.06, cz + dz * 0.17), 0.009, "Brass")
    p.box(cx + 0.06, cx + 0.2, 0.72, H - 0.1, cz - 0.21, cz + 0.21, "Fabric")             # long coat
    p.box(cx - 0.2, cx - 0.06, 1.05, H - 0.1, cz - 0.18, cz + 0.18, "Upholstery")         # short jacket
    p.cyl((cx + 0.05, cz + 0.12), 0.1, H - 0.08, H - 0.07, "Fabric", sides=10)            # hat brim
    p.cyl((cx + 0.05, cz + 0.12), 0.065, H - 0.07, H + 0.02, "Fabric", sides=10)


def hall_table(p):
    W, D, H = p.W, p.D, p.H
    legs(p, H - 0.04, 0.04, "Walnut")
    p.box(0.0, W, H - 0.04, H, 0.0, D, "Walnut")
    p.box(0.04, W - 0.04, H - 0.14, H - 0.04, 0.04, D - 0.04, "Walnut")
    panel_door(p, 0.08, W - 0.08, H - 0.13, H - 0.05, D - 0.04, "Walnut", knob_x=W / 2.0)
    p.box(0.04, W - 0.04, 0.1, 0.12, 0.04, D - 0.04, "Walnut")                            # shelf
    c = (W / 2.0 + 0.08, D / 2.0)                                                        # candlestick telephone
    p.cyl(c, 0.055, H, H + 0.03, "Iron", sides=10)
    p.cyl(c, 0.013, H + 0.03, H + 0.3, "Iron")
    p.cyl(c, 0.025, H + 0.3, H + 0.34, "Iron", sides=10)
    p.stick((c[0], H + 0.33, c[1]), (c[0] + 0.03, H + 0.36, c[1] + 0.05), 0.01, "Iron")
    p.stick((c[0] - 0.03, H + 0.21, c[1]), (c[0] - 0.03, H + 0.33, c[1]), 0.016, "Iron")   # receiver on its hook
    p.box(0.06, 0.2, H, H + 0.006, 0.08, 0.3, "Paper")                                   # a note


# --- Dining room ----------------------------------------------------------------------------

def dining_table(p, wood="Walnut", top_mat=None):
    W, D, H = p.W, p.D, p.H
    legs(p, H - 0.04, 0.08, wood, inset=0.08)
    p.box(0.0, W, H - 0.04, H, 0.0, D, top_mat or wood)
    p.box(0.1, W - 0.1, H - 0.14, H - 0.04, 0.1, D - 0.1, wood)
    if top_mat:
        return
    p.box(-0.15, W + 0.15, H, H + 0.004, D / 2.0 - 0.17, D / 2.0 + 0.17, "Curtain")        # runner
    for x in (-0.15, W + 0.146):
        p.box(x, x + 0.004, H - 0.25, H, D / 2.0 - 0.17, D / 2.0 + 0.17, "Curtain")
    c = (W / 2.0, D / 2.0)                                                               # candelabra
    p.cyl(c, 0.07, H, H + 0.02, "Brass")
    p.cyl(c, 0.012, H + 0.02, H + 0.3, "Brass")
    p.stick((c[0] - 0.14, H + 0.26, c[1]), (c[0] + 0.14, H + 0.26, c[1]), 0.01, "Brass")
    for x in (c[0] - 0.14, c[0], c[0] + 0.14):
        p.cyl((x, c[1]), 0.012, H + 0.27, H + 0.4, "Paper")
    for x in (W * 0.3, W * 0.7):                                                         # places
        for z in (0.25, D - 0.25):
            p.cyl((x, z), 0.13, H, H + 0.012, "Enamel", sides=12)


def dining_chair(p, wood="Walnut", seat_mat=None):
    W, D, H = p.W, p.D, p.H
    seat = 0.45
    for x in (0.03, W - 0.07):
        p.box(x, x + 0.04, 0.0, seat, D - 0.07, D - 0.03, wood)
        p.box(x, x + 0.04, 0.0, H, 0.03, 0.07, wood)
    p.box(0.02, W - 0.02, seat - 0.04, seat, 0.02, D - 0.02, seat_mat or wood)
    p.box(0.07, W - 0.07, H - 0.12, H - 0.04, 0.035, 0.065, wood)
    p.box(0.07, W - 0.07, seat + 0.18, seat + 0.23, 0.035, 0.065, wood)
    for k in range(3):
        x = 0.13 + k * (W - 0.26) / 2.0
        p.box(x - 0.015, x + 0.015, seat + 0.23, H - 0.12, 0.04, 0.06, wood)
    p.box(0.05, W - 0.05, 0.14, 0.17, D - 0.065, D - 0.035, wood)
    p.box(0.05, W - 0.05, 0.14, 0.17, 0.035, 0.065, wood)


def china_cabinet(p):
    W, D, H = p.W, p.D, p.H
    shallow = D - 0.15
    p.box(0.02, W - 0.02, 0.0, 0.08, 0.02, D - 0.02, "Walnut")
    p.box(0.0, W, 0.08, 0.9, 0.0, D, "Walnut")
    p.box(-0.02, W + 0.02, 0.9, 0.93, 0.0, D + 0.02, "Walnut")
    panel_door(p, 0.03, W / 2.0 - 0.005, 0.12, 0.62, D, "Walnut", knob_x=W / 2.0 - 0.05)
    panel_door(p, W / 2.0 + 0.005, W - 0.03, 0.12, 0.62, D, "Walnut", knob_x=W / 2.0 + 0.05)
    for x0, x1 in ((0.03, W / 2.0 - 0.005), (W / 2.0 + 0.005, W - 0.03)):
        panel_door(p, x0, x1, 0.66, 0.86, D, "Walnut", knob_x=(x0 + x1) / 2.0)
    p.box(0.04, 0.08, 0.93, H - 0.08, 0.0, shallow, "Walnut")
    p.box(W - 0.08, W - 0.04, 0.93, H - 0.08, 0.0, shallow, "Walnut")
    p.box(0.08, W - 0.08, 0.93, H - 0.08, 0.0, 0.02, "Walnut")
    for y in (1.22, 1.52):
        p.box(0.08, W - 0.08, y, y + 0.02, 0.02, shallow - 0.03, "Walnut")
    for y in (0.93, 1.24, 1.54):
        for k in range(3):
            x = 0.16 + k * (W - 0.32) / 2.0
            p.cyl((x, y + 0.125), 0.1, 0.035, 0.047, "Enamel", axis="z", sides=12)              # plates on edge
    for x0, x1 in ((0.04, W / 2.0), (W / 2.0, W - 0.04)):                               # glazed doors
        framed(p, x0, x1, 0.93, H - 0.08, shallow, shallow + 0.025, 0.04, "Walnut", "WindowGlass")
    p.box(0.0, W, H - 0.08, H, -0.0, shallow + 0.04, "Walnut")


# --- Kitchen ----------------------------------------------------------------------------------

def sink_counter(p):
    W, D, H = p.W, p.D, p.H
    p.box(0.04, W - 0.04, 0.0, 0.1, 0.0, D - 0.08, "Void")
    p.box(0.02, W - 0.02, 0.1, H - 0.04, 0.0, D - 0.04, "PaintedWood")
    panel_door(p, 0.04, W / 2.0 - 0.005, 0.14, H - 0.1, D - 0.04, "PaintedWood", knob_x=W / 2.0 - 0.05)
    panel_door(p, W / 2.0 + 0.005, W - 0.04, 0.14, H - 0.1, D - 0.04, "PaintedWood", knob_x=W / 2.0 + 0.05)
    basin = (0.08, 0.58, 0.08, D - 0.1)
    p.box(0.0, basin[0], H - 0.04, H, 0.0, D, "Enamel")
    p.box(basin[1], W, H - 0.04, H, 0.0, D, "Enamel")
    p.box(basin[0], basin[1], H - 0.04, H, 0.0, basin[2], "Enamel")
    p.box(basin[0], basin[1], H - 0.04, H, basin[3], D, "Enamel")
    p.tray(basin[0], basin[1], H - 0.22, H - 0.04, basin[2], basin[3], 0.015, "Enamel")
    for k in range(6):                                                                   # drainboard ribs
        x = basin[1] + 0.05 + k * (W - basin[1] - 0.1) / 5.0
        p.box(x - 0.006, x + 0.006, H, H + 0.004, 0.1, D - 0.1, "Enamel")
    for x in ((basin[0] + basin[1]) / 2.0 - 0.1, (basin[0] + basin[1]) / 2.0 + 0.1):     # taps
        p.cyl((x, 0.05), 0.012, H, H + 0.16, "Chrome")
        p.stick((x, H + 0.15, 0.05), (x, H + 0.15, 0.15), 0.01, "Chrome")
        p.box(x - 0.03, x + 0.03, H + 0.16, H + 0.18, 0.04, 0.06, "Chrome")
    for k in range(3):                                                                   # dishes drying
        x = basin[1] + 0.12 + k * 0.05
        p.box(x, x + 0.012, H + 0.004, H + 0.2, 0.15, 0.37, "Enamel")


def range_stove(p):
    W, D, H = p.W, p.D, p.H
    legs(p, 0.2, 0.045, "Iron")
    p.box(0.0, W, 0.18, H - 0.03, 0.0, D, "Enamel")
    p.box(-0.01, W + 0.01, H - 0.03, H, -0.01, D + 0.01, "Iron")
    for x in (W * 0.28, W * 0.72):
        for z in (D * 0.32, D * 0.72):
            p.cyl((x, z), 0.09, H, H + 0.012, "Iron", sides=10)
    p.box(0.0, W, H, H + 0.35, 0.0, 0.04, "Enamel")
    p.box(0.0, W, H + 0.35, H + 0.38, 0.0, 0.13, "Enamel")
    framed(p, 0.06, W - 0.06, 0.28, 0.76, D, D + 0.02, 0.06, "Enamel", "Screen")
    p.box(0.14, W - 0.14, 0.7, 0.72, D + 0.02, D + 0.05, "Chrome")
    for k in range(4):
        x = 0.12 + k * (W - 0.24) / 3.0
        p.stick((x, 0.84, D), (x, 0.84, D + 0.035), 0.016, "Iron")
    p.cyl((W * 0.72, D * 0.72), 0.1, H + 0.012, H + 0.17, "Gutter", sides=10, r2=0.085)      # kettle


def icebox(p):
    W, D, H = p.W, p.D, p.H
    legs(p, 0.08, 0.06, "Oak")
    p.box(0.0, W, 0.08, H, 0.0, D, "Oak")
    p.box(-0.015, W + 0.015, H - 0.04, H, -0.015, D + 0.015, "Oak")
    panel_door(p, 0.05, W - 0.05, 1.08, H - 0.08, D, "Oak", knob_x=W - 0.1)
    panel_door(p, 0.05, W - 0.05, 0.14, 1.02, D, "Oak", knob_x=W - 0.1)
    for y in (1.12, 1.5, 0.2, 0.9):                                                       # hinges
        p.box(0.03, 0.08, y, y + 0.05, D + 0.01, D + 0.03, "Brass")


def kitchen_table(p):
    dining_table(p, wood="PaintedWood", top_mat="Enamel")
    W, D, H = p.W, p.D, p.H
    p.cyl((W * 0.35, D * 0.5), 0.1, H, H + 0.06, "Enamel", sides=12, r2=0.13)             # bowl
    p.cyl((W * 0.62, D * 0.4), 0.04, H, H + 0.09, "Enamel", sides=10)                     # cup


def radio(p):
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, 0.0, H * 0.66, 0.0, D, "Walnut")
    for k, y in enumerate((H * 0.66, H * 0.82, H * 0.93)):
        inset = 0.03 + k * 0.045
        p.box(inset, W - inset, y, y + H * 0.17 if k < 2 else H, 0.0, D, "Walnut")
    p.box(0.08, W - 0.08, H * 0.32, H * 0.86, D, D + 0.004, "Fabric")
    for k in range(5):
        x = 0.1 + k * (W - 0.2) / 4.0
        p.box(x - 0.006, x + 0.006, H * 0.32, H * 0.86, D + 0.004, D + 0.01, "Walnut")
    p.box(W / 2.0 - 0.04, W / 2.0 + 0.04, H * 0.12, H * 0.25, D, D + 0.004, "Paper")
    for x in (0.05, W - 0.05):
        p.stick((x, H * 0.18, D), (x, H * 0.18, D + 0.025), 0.016, "Walnut")


# --- Carrie's room ----------------------------------------------------------------------------

def child_bed(p):
    """White iron bed; the head is against the wall (z 0) and the space under it stays clear."""
    W, D, H = p.W, p.D, p.H
    iron = "PaintedIron"
    for x in (0.0, W - 0.04):
        p.box(x, x + 0.04, 0.0, 1.05, 0.0, 0.04, iron)
        p.box(x, x + 0.04, 0.0, 0.8, D - 0.04, D, iron)
        p.box(x, x + 0.04, 0.3, 0.36, 0.04, D - 0.04, iron)
    for z, low, high, count in ((0.02, 0.5, 0.98, 7), (D - 0.02, 0.45, 0.74, 6)):
        p.box(0.04, W - 0.04, high - 0.03, high, z - 0.012, z + 0.012, iron)
        p.box(0.04, W - 0.04, low, low + 0.03, z - 0.012, z + 0.012, iron)
        for k in range(count):
            x = 0.04 + (k + 1) * (W - 0.08) / (count + 1)
            p.stick((x, low + 0.03, z), (x, high - 0.03, z), 0.007, iron)
    p.box(0.05, W - 0.05, 0.34, 0.5, 0.05, D - 0.05, "Bedding")
    p.box(0.02, W - 0.02, 0.5, 0.54, 0.5, D - 0.05, "Quilt")
    for x in (0.0, W - 0.02):
        p.box(x, x + 0.02, 0.27, 0.54, 0.5, D - 0.05, "Quilt")
    p.box(0.15, W - 0.15, 0.5, 0.62, 0.07, 0.42, "Bedding")


WARDROBE_GAP = 0.05         # how far apart the wardrobe doors stand, as on the hospital's supply closet


def wardrobe(p):
    """Hollow, with its doors left a little apart: hiding inside, the player watches the room through the gap."""
    W, D, H = p.W, p.D, p.H
    side = 0.03
    p.box(0.03, W - 0.03, 0.0, 0.1, 0.02, D - 0.03, "Walnut")                            # plinth
    for x in (0.0, W - side):
        p.box(x, x + side, 0.1, H - 0.08, 0.0, D, "Walnut")                              # sides
    p.box(side, W - side, 0.1, H - 0.08, 0.0, 0.02, "Walnut")                            # back
    p.box(side, W - side, 0.1, 0.15, 0.02, D, "Walnut")                                  # floor
    p.box(side, W - side, H - 0.12, H - 0.08, 0.02, D, "Walnut")                         # top
    p.box(-0.03, W + 0.03, H - 0.08, H, 0.0, D + 0.03, "Walnut")                         # cornice
    gap = WARDROBE_GAP / 2.0
    panel_door(p, side, W / 2.0 - gap, 0.15, H - 0.12, D, "Walnut", knob_x=W / 2.0 - gap - 0.04, inner="Mirror")
    panel_door(p, W / 2.0 + gap, W - side, 0.15, H - 0.12, D, "Walnut", knob_x=W / 2.0 + gap + 0.04)


def play_table(p):
    """Low table under the dollhouse, with a drawer in its front."""
    W, D, H = p.W, p.D, p.H
    legs(p, H - 0.04, 0.05, "PaintedWood", inset=0.04)
    p.box(-0.02, W + 0.02, H - 0.04, H, -0.02, D + 0.02, "PaintedWood")
    p.box(0.05, W - 0.05, H - 0.15, H - 0.04, 0.05, D - 0.05, "PaintedWood")
    panel_door(p, W / 2.0 - 0.3, W / 2.0 + 0.3, H - 0.14, H - 0.05, D - 0.05, "PaintedWood", knob_x=W / 2.0)


def desk(p):
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, H - 0.03, H, 0.0, D, "Oak")
    p.box(0.02, 0.42, 0.04, H - 0.03, 0.02, D - 0.02, "Oak")
    for y0, y1 in ((0.08, 0.3), (0.32, 0.5), (0.52, H - 0.06)):
        panel_door(p, 0.04, 0.4, y0, y1, D - 0.02, "Oak", knob_x=0.22)
    for z in (0.03, D - 0.07):
        p.box(W - 0.07, W - 0.03, 0.0, H - 0.03, z, z + 0.04, "Oak")
    p.box(0.42, W - 0.03, 0.42, H - 0.03, 0.02, 0.04, "Oak")
    p.stick((0.9, H + 0.006, 0.3), (1.05, H + 0.006, 0.2), 0.004, "Quilt")              # crayons
    p.stick((0.92, H + 0.006, 0.36), (1.06, H + 0.006, 0.3), 0.004, "RugBlue")
    p.cyl((0.18, 0.3), 0.07, H, H + 0.02, "Brass", sides=10)                             # lamp
    p.cyl((0.18, 0.3), 0.01, H + 0.02, H + 0.32, "Brass")
    p.cyl((0.18, 0.3), 0.1, H + 0.25, H + 0.4, "Lampshade", sides=10, r2=0.06)


def desk_chair(p):
    dining_chair(p, wood="Oak")


def doll(p):
    """A porcelain doll sitting against the pillow."""
    W, D, H = p.W, p.D, p.H
    cx = W / 2.0
    p.box(cx - 0.07, cx + 0.07, 0.0, 0.05, 0.05, 0.2, "Quilt")                           # skirt
    p.box(cx - 0.05, cx + 0.05, 0.05, 0.2, 0.05, 0.13, "Quilt")                          # body
    for side in (-1.0, 1.0):
        p.stick((cx + side * 0.04, 0.02, 0.15), (cx + side * 0.04, 0.015, D), 0.014, "Porcelain")          # legs out in front
        p.stick((cx + side * 0.055, 0.18, 0.09), (cx + side * 0.07, 0.08, 0.14), 0.012, "Porcelain")      # arms
    p.cyl((cx, 0.09), 0.05, 0.2, 0.3, "Porcelain", sides=10)                             # head
    p.cyl((cx, 0.085), 0.055, 0.27, 0.32, "Leather", sides=10)                           # hair
    for x in (cx - 0.018, cx + 0.018):
        p.box(x - 0.007, x + 0.007, 0.25, 0.262, 0.135, 0.142, "Void")                   # eyes


# --- Parents' room ----------------------------------------------------------------------------

def double_bed(p):
    """Walnut bed. Its rails and the quilt's hem stand 0.3 m up, so a player hiding under it can see out."""
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, 0.0, 1.25, 0.0, 0.06, "Walnut")
    framed(p, 0.12, W - 0.12, 0.55, 1.12, 0.06, 0.08, 0.05, "Walnut", "Walnut", 0.01)
    p.box(-0.02, W + 0.02, 1.25, 1.3, -0.01, 0.07, "Walnut")
    p.box(0.0, W, 0.0, 0.8, D - 0.06, D, "Walnut")
    for x in (0.0, W - 0.05):
        p.box(x, x + 0.05, 0.3, 0.42, 0.06, D - 0.06, "Walnut")
    p.box(0.05, W - 0.05, 0.4, 0.56, 0.06, D - 0.06, "Bedding")
    p.box(0.0, W, 0.56, 0.6, 0.6, D - 0.07, "QuiltBlue")
    for x in (-0.02, W):
        p.box(x, x + 0.02, 0.3, 0.6, 0.6, D - 0.07, "QuiltBlue")
    p.box(0.12, W / 2.0 - 0.04, 0.56, 0.69, 0.1, 0.48, "Bedding")
    p.box(W / 2.0 + 0.04, W - 0.12, 0.56, 0.69, 0.1, 0.48, "Bedding")


def nightstand(p):
    W, D, H = p.W, p.D, p.H
    legs(p, 0.1, 0.04, "Walnut")
    p.box(0.0, W, 0.1, H, 0.0, D, "Walnut")
    panel_door(p, 0.03, W - 0.03, H - 0.16, H - 0.03, D, "Walnut", knob_x=W / 2.0)
    p.cyl((W / 2.0, D / 2.0), 0.06, H, H + 0.02, "Brass", sides=10)                       # lamp
    p.cyl((W / 2.0, D / 2.0), 0.01, H + 0.02, H + 0.3, "Brass")
    p.cyl((W / 2.0, D / 2.0), 0.11, H + 0.22, H + 0.38, "Lampshade", sides=10, r2=0.07)
    p.box(0.04, 0.18, H, H + 0.04, 0.05, 0.25, "Leather")                                # a bible


def dresser(p):
    W, D, H = p.W, p.D, p.H
    legs(p, 0.08, 0.05, "Walnut")
    p.box(0.0, W, 0.08, H - 0.03, 0.0, D, "Walnut")
    p.box(-0.02, W + 0.02, H - 0.03, H, 0.0, D + 0.02, "Walnut")
    for y0, y1 in ((0.12, 0.34), (0.36, 0.58), (0.6, 0.78)):
        panel_door(p, 0.03, W - 0.03, y0, y1, D, "Walnut")
        for x in (W * 0.25, W * 0.75):
            p.box(x - 0.03, x + 0.03, (y0 + y1) / 2.0 - 0.01, (y0 + y1) / 2.0 + 0.01, D + 0.025, D + 0.045, "Brass")
    for x0, x1 in ((0.03, W / 2.0 - 0.005), (W / 2.0 + 0.005, W - 0.03)):
        panel_door(p, x0, x1, 0.8, H - 0.05, D, "Walnut", knob_x=(x0 + x1) / 2.0)
    for x in (0.12, W - 0.16):                                                           # mirror posts
        p.box(x, x + 0.04, H, H + 0.85, 0.02, 0.06, "Walnut")
    framed(p, 0.16, W - 0.16, H + 0.1, H + 0.8, 0.02, 0.06, 0.05, "Walnut", "Mirror", 0.015)
    p.box(W * 0.15, W * 0.15 + 0.2, H, H + 0.03, D * 0.45, D * 0.45 + 0.07, "Walnut")       # brush
    for k in range(3):                                                                   # perfume
        p.cyl((W * 0.62 + k * 0.07, D * 0.55), 0.025, H, H + 0.09 + k * 0.02, "Jar")
    p.box(W * 0.78, W * 0.92, H, H + 0.08, D * 0.3, D * 0.6, "Leather")                    # jewellery box


# --- Sewing room ------------------------------------------------------------------------------

def sewing_machine(p):
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, H - 0.04, H, 0.0, D, "Walnut")
    p.box(0.02, 0.32, H - 0.32, H - 0.04, 0.05, D - 0.05, "Walnut")
    for y0, y1 in ((H - 0.3, H - 0.18), (H - 0.17, H - 0.06)):
        panel_door(p, 0.04, 0.3, y0, y1, D - 0.05, "Walnut", knob_x=0.17)
    for x in (0.06, W - 0.1):                                                            # cast-iron treadle frame
        p.box(x, x + 0.04, 0.0, H - 0.04, 0.12, 0.16, "Iron")
        p.box(x, x + 0.04, 0.0, H - 0.04, D - 0.16, D - 0.12, "Iron")
        p.stick((x + 0.02, 0.05, 0.14), (x + 0.02, H - 0.1, D - 0.14), 0.015, "Iron")
        p.box(x, x + 0.04, 0.0, 0.04, 0.1, D - 0.1, "Iron")
    p.box(0.06, W - 0.06, 0.1, 0.13, D / 2.0 - 0.02, D / 2.0 + 0.02, "Iron")
    p.box(0.45, 0.95, 0.08, 0.1, 0.2, 0.6, "Iron")                                        # treadle
    p.cyl((0.3, D / 2.0), 0.22, W - 0.16, W - 0.13, "Iron", axis="x", sides=12)           # band wheel
    p.box(0.45, 1.0, H, H + 0.03, 0.25, 0.55, "Iron")                                    # machine head
    p.box(0.86, 0.96, H + 0.03, H + 0.3, 0.32, 0.48, "Iron")
    p.box(0.45, 0.96, H + 0.24, H + 0.32, 0.34, 0.46, "Iron")
    p.box(0.42, 0.5, H + 0.08, H + 0.32, 0.33, 0.47, "Iron")
    p.box(0.452, 0.458, H + 0.02, H + 0.08, 0.397, 0.403, "Chrome")
    p.cyl((H + 0.2, 0.4), 0.07, 0.96, 0.99, "Chrome", axis="x", sides=12)                # hand wheel
    p.cyl((0.72, 0.4), 0.014, H + 0.32, H + 0.37, "Quilt")                               # spool
    p.box(0.2, 0.9, H, H + 0.004, 0.12, 0.72, "QuiltBlue")                               # cloth
    p.stick((1.05, H + 0.006, 0.15), (1.22, H + 0.006, 0.28), 0.008, "Iron")            # shears
    p.stick((1.05, H + 0.006, 0.2), (1.22, H + 0.006, 0.25), 0.008, "Iron")


def nailed_boards(p):
    """Rough planks nailed across the sewing-room door from the landing side."""
    W, D, H = p.W, p.D, p.H
    for y in (0.35, 0.95, 1.6):
        p.box(-0.08, W + 0.08, y, y + 0.15, 0.03, 0.055, "OldWood")
        for x in (-0.03, W + 0.03):
            p.box(x - 0.008, x + 0.008, y + 0.06, y + 0.076, 0.055, 0.062, "Iron")
    p.stick((-0.02, 0.2, 0.07), (W + 0.02, 1.95, 0.07), 0.07, "OldWood", r2=0.012, normal=(0.0, 0.0, 1.0))
    p.stick((-0.02, 1.95, 0.085), (W + 0.02, 0.25, 0.085), 0.065, "OldWood", r2=0.012, normal=(0.0, 0.0, 1.0))


def dress_form(p):
    """A dressmaker's dummy on a tripod: the shape that stands in the dark."""
    W, D, H = p.W, p.D, p.H
    c = (W / 2.0, D / 2.0)
    for angle in (0.0, 2.1, 4.2):
        p.stick((c[0], 0.3, c[1]), (c[0] + 0.24 * cos(angle), 0.0, c[1] + 0.24 * sin(angle)), 0.012, "Walnut")
    p.cyl(c, 0.014, 0.3, H - 0.6, "Walnut")
    p.cyl(c, 0.13, H - 0.62, H - 0.4, "Fabric", sides=12, r2=0.16)                        # hips
    p.cyl(c, 0.16, H - 0.4, H - 0.3, "Fabric", sides=12, r2=0.12)                         # waist
    p.cyl(c, 0.12, H - 0.3, H - 0.1, "Fabric", sides=12, r2=0.17)                         # chest
    p.cyl(c, 0.17, H - 0.1, H - 0.04, "Fabric", sides=12, r2=0.08)                        # shoulders
    p.cyl(c, 0.04, H - 0.04, H, "Fabric", sides=10)
    p.cyl(c, 0.05, H, H + 0.03, "Walnut", sides=10)


# --- Bathroom ----------------------------------------------------------------------------------

def clawfoot_tub(p):
    W, D, H = p.W, p.D, p.H
    base = 0.14
    p.tray(0.0, W, base, H - 0.03, 0.0, D, 0.05, "Enamel", floor=0.06)
    for z0, z1 in ((-0.02, 0.03), (D - 0.03, D + 0.02)):                                 # rolled rim
        p.box(-0.02, W + 0.02, H - 0.04, H, z0, z1, "Enamel")
    for x0, x1 in ((-0.02, 0.03), (W - 0.03, W + 0.02)):
        p.box(x0, x1, H - 0.04, H, -0.02, D + 0.02, "Enamel")
    for x in (0.12, W - 0.2):
        for z in (0.06, D - 0.14):
            p.box(x, x + 0.08, 0.0, base + 0.04, z, z + 0.08, "Brass")
    p.cyl((W - 0.12, 0.05), 0.014, H, H + 0.22, "Chrome")
    p.stick((W - 0.12, H + 0.21, 0.05), (W - 0.12, H + 0.18, 0.2), 0.012, "Chrome")
    for x in (W - 0.2, W - 0.04):
        p.box(x - 0.02, x + 0.02, H + 0.08, H + 0.11, 0.03, 0.07, "Chrome")


def pedestal_sink(p):
    W, D, H = p.W, p.D, p.H
    p.cyl((W / 2.0, D * 0.45), 0.09, 0.0, H - 0.15, "Enamel", sides=10, r2=0.07)
    p.tray(0.0, W, H - 0.15, H, 0.0, D, 0.035, "Enamel", floor=0.05)
    for x in (W * 0.3, W * 0.7):
        p.cyl((x, 0.04), 0.012, H, H + 0.1, "Chrome")
        p.box(x - 0.025, x + 0.025, H + 0.1, H + 0.12, 0.02, 0.06, "Chrome")
    p.stick((W / 2.0, H + 0.04, 0.03), (W / 2.0, H + 0.04, 0.12), 0.012, "Chrome")
    p.box(0.04, W - 0.04, 1.25, 1.8, 0.0, 0.12, "Walnut")                                 # medicine cabinet
    p.box(0.07, W - 0.07, 1.28, 1.77, 0.12, 0.125, "Mirror")
    p.cyl((W - 0.08, D - 0.08), 0.03, H, H + 0.1, "Jar")                                 # tooth mug


def toilet(p):
    """Bowl with a wooden seat, and a high wooden cistern with a pull chain."""
    W, D, H = p.W, p.D, p.H
    p.box(0.1, W - 0.1, 0.0, 0.06, 0.25, D - 0.08, "Enamel")
    p.box(0.07, W - 0.07, 0.06, H - 0.04, 0.2, D - 0.02, "Enamel")
    p.box(0.05, W - 0.05, H - 0.04, H, 0.22, D, "Walnut")
    p.box(0.08, W - 0.08, H, H + 0.02, 0.2, 0.26, "Walnut")
    p.box(0.02, W - 0.02, 1.85, 2.12, 0.0, 0.22, "Walnut")
    p.cyl((W / 2.0, 0.12), 0.02, 0.3, 1.85, "Chrome")
    p.stick((W - 0.08, 1.85, 0.18), (W - 0.08, 1.35, 0.18), 0.003, "Chrome")
    p.box(W - 0.1, W - 0.06, 1.25, 1.35, 0.16, 0.2, "Walnut")


# --- Attic ------------------------------------------------------------------------------------

def trunk(p):
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, 0.0, H - 0.16, 0.0, D, "Leather")
    p.box(0.0, W, H - 0.15, H, 0.0, D, "Leather")
    p.box(0.01, W - 0.01, H - 0.16, H - 0.15, 0.01, D - 0.01, "Void")
    for x in (0.18, W / 2.0 - 0.03, W - 0.24):
        p.box(x, x + 0.06, 0.0, H, D, D + 0.012, "Oak")
        p.box(x, x + 0.06, H, H + 0.012, 0.0, D + 0.012, "Oak")
    for y in (0.06, H - 0.24):
        p.box(0.0, W, y, y + 0.05, D, D + 0.008, "Oak")
    for x in (-0.006, W - 0.06):
        for y in (-0.006, H - 0.06):
            p.box(x, x + 0.066, y, y + 0.066, D - 0.06, D + 0.016, "Brass")
    p.box(W / 2.0 - 0.04, W / 2.0 + 0.04, H - 0.22, H - 0.12, D + 0.012, D + 0.025, "Brass")


def box_stack(p):
    for x0, x1, y0, y1, z0, z1 in ((0.0, 0.6, 0.0, 0.45, 0.0, 0.5), (0.65, 1.35, 0.0, 0.4, 0.05, 0.55),
                                   (0.1, 0.55, 0.45, 0.8, 0.05, 0.45), (0.7, 1.2, 0.0, 0.3, 0.6, 1.15),
                                   (0.0, 0.5, 0.0, 0.32, 0.6, 1.1), (0.75, 1.15, 0.3, 0.55, 0.65, 1.05)):
        p.box(x0, x1, y0, y1, z0, z1, "Cardboard")
        p.box(x0 - 0.002, x1 + 0.002, y1 - 0.001, y1 + 0.002, (z0 + z1) / 2.0 - 0.03, (z0 + z1) / 2.0 + 0.03, "Paper")


# --- Cellar ------------------------------------------------------------------------------------

def furnace(p):
    """A gravity "octopus" furnace: round firebox, dome, ducts reaching for the ceiling, and a
    stovepipe to the chimney."""
    W, D, H = p.W, p.D, p.H
    c = (W / 2.0, D / 2.0)
    p.cyl(c, 0.6, 0.0, 1.15, "Rust", sides=12)
    p.cyl(c, 0.6, 1.15, 1.45, "Rust", sides=12, r2=0.35)
    p.cyl(c, 0.3, 1.45, 1.6, "Gutter", sides=12)
    for k in range(6):
        angle = 0.4 + k * 1.05
        p.tube((c[0] + 0.15 * cos(angle), 1.55, c[1] + 0.15 * sin(angle)),
               (c[0] + 1.6 * cos(angle), 2.12, c[1] + 1.6 * sin(angle)), 0.11, "Gutter")
    p.box(c[0] - 0.2, c[0] + 0.2, 0.3, 0.62, c[1] + 0.56, c[1] + 0.63, "Iron")
    p.box(c[0] - 0.15, c[0] + 0.15, 0.06, 0.22, c[1] + 0.56, c[1] + 0.63, "Iron")
    p.box(c[0] + 0.08, c[0] + 0.14, 0.42, 0.48, c[1] + 0.63, c[1] + 0.67, "Brass")
    p.tube((c[0] - 0.2, 1.35, c[1] - 0.2), (-3.9, 2.05, 1.65), 0.075, "Iron")            # stovepipe


def shelves(p):
    W, D, H = p.W, p.D, p.H
    posts = [0.0, W / 3.0, 2.0 * W / 3.0, W - 0.04]
    for x in posts:
        for z in (0.0, D - 0.04):
            p.box(x, x + 0.04, 0.0, H, z, z + 0.04, "OldWood")
    rnd = scatter(11, 400)
    k = 0
    for level, y in enumerate((0.1, 0.55, 1.0, 1.45, 1.9)):
        p.box(0.0, W, y, y + 0.025, 0.0, D, "OldWood")
        if level == 4:
            continue
        x = 0.06
        while x < W - 0.12:
            kind = rnd[k % 400]; size = rnd[(k + 1) % 400]; k += 2
            if kind < 0.45:
                p.cyl((x + 0.045, D * 0.5 + (size - 0.5) * 0.2), 0.045, y + 0.025, y + 0.16 + size * 0.04, "Jar")
                x += 0.11
            elif kind < 0.75:
                p.cyl((x + 0.04, D * 0.4), 0.04, y + 0.025, y + 0.135, "Gutter")
                x += 0.09
            elif kind < 0.9:
                p.box(x, x + 0.22, y + 0.025, y + 0.2 + size * 0.1, 0.06, D - 0.06, "Cardboard")
                x += 0.26
            else:
                x += 0.15


def wringer_washer(p):
    W, D, H = p.W, p.D, p.H
    c = (W / 2.0, D / 2.0)
    for dx in (-0.2, 0.2):
        for dz in (-0.18, 0.18):
            p.stick((c[0] + dx, 0.0, c[1] + dz), (c[0] + dx * 0.8, 0.38, c[1] + dz * 0.8), 0.018, "Iron")
    p.cyl(c, 0.27, 0.36, 0.84, "Gutter", sides=14)
    p.cyl(c, 0.29, 0.82, 0.86, "Gutter", sides=14)
    for dz in (-0.27, 0.27):
        p.box(c[0] - 0.03, c[0] + 0.03, 0.84, 1.18, c[1] + dz - 0.025, c[1] + dz + 0.025, "Iron")
    for y in (1.0, 1.07):
        p.cyl((c[0], y), 0.033, c[1] - 0.25, c[1] + 0.25, "Fabric", axis="z", sides=10)
    p.box(c[0] - 0.04, c[0] + 0.04, 1.15, 1.2, c[1] - 0.3, c[1] + 0.3, "Iron")
    p.stick((c[0], 1.035, c[1] + 0.3), (c[0], 1.035, c[1] + 0.42), 0.012, "Iron")       # crank
    p.stick((c[0], 1.035, c[1] + 0.42), (c[0] + 0.15, 1.15, c[1] + 0.42), 0.012, "Iron")


def laundry_tub(p):
    W, D, H = p.W, p.D, p.H
    legs(p, H - 0.38, 0.04, "Iron")
    p.tray(0.0, W, H - 0.38, H, 0.0, D, 0.05, "Concrete", floor=0.06)
    p.cyl((W / 2.0, 0.03), 0.015, H, H + 0.25, "Chrome")
    p.stick((W / 2.0, H + 0.24, 0.03), (W / 2.0, H + 0.2, 0.18), 0.012, "Chrome")


def coal_bin(p):
    """A plank bin open at the front, heaped with coal, a shovel leaning in it."""
    W, D, H = p.W, p.D, p.H
    p.box(0.0, W, 0.0, H, 0.0, 0.04, "OldWood")
    p.box(0.0, 0.04, 0.0, H, 0.0, D, "OldWood")
    p.box(W - 0.04, W, 0.0, H, 0.0, D, "OldWood")
    p.box(0.0, W, 0.0, 0.35, D - 0.04, D, "OldWood")
    p.box(0.04, W - 0.04, 0.0, 0.5, 0.04, D - 0.04, "Coal")
    p.box(0.1, W - 0.15, 0.5, 0.68, 0.05, D * 0.6, "Coal")
    p.box(0.25, W - 0.35, 0.68, 0.8, 0.06, D * 0.35, "Coal")
    p.stick((W - 0.25, 0.45, D * 0.55), (W - 0.15, 1.35, D * 0.2), 0.016, "Walnut")
    p.stick((W - 0.27, 0.32, D * 0.62), (W - 0.24, 0.5, D * 0.53), 0.11, "Iron", r2=0.006, normal=(1.0, 0.0, 0.0))
