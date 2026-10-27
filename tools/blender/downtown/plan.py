"""Downtown Cicely: the street beside the hospital, laid out in the map's own coordinates.

x runs east, y up and z south, in metres, exactly as in scenes/chapters/main/map.tscn. The
Crossroad runs east-west across z 221-229 and the Connector road north-south across x 96-104. The
north row faces south across the Crossroad with its fronts on NORTH_FRONT; the south row faces
north with its fronts on SOUTH_FRONT. A building's setback moves its front back from that line.

tools/blender/build_downtown.py builds this, tools/blender/prepare_downtown.py exports it, and
validate.py checks it against the game's clearances first. Sign words are placeholders: change them
here and rebuild.
"""

# --- The streets and neighbours the downtown fits between ------------------------------------

CONNECTOR_ROAD = (96.0, 104.0)      # x, the north-south road
CROSSROAD = (221.0, 229.0)          # z, the east-west road
CROSSROAD_END = 275.0               # x where the Crossroad stops
CURB_NORTH = (220.8, 221.0)         # z, built here
CURB_SOUTH = (229.0, 229.2)         # z, the map's Curbs/Crossroad_South_2, kept
CONNECTOR_CURB_EAST = 104.1         # x, the map's east curb of the Connector road
NORTH_FRONT = 216.5                 # z of the north row's fronts
SOUTH_FRONT = 234.0                 # z of the south row's fronts
WEST_EDGE = 108.6                   # x where the rows start, behind the Connector road's sidewalk
NORTH_BACK_LIMIT = 194.0            # z: nothing of the north row reaches further north
SERVICE_LANE = (267.5, 272.5)       # z, the lane behind the south row
SERVICE_LANE_X = (104.2, 240.0)
REAR_FENCE_Z = 275.0
SIDEWALK_TOP = 0.13                 # 1 cm above the town's other sidewalks, so this paving wins where they meet
GROUND = 0.0

# Kept neighbours, as world rectangles (x0, x1, z0, z1) measured in the map.
HOSPITAL = (225.2, 267.2, 248.0, 262.4)
CORNER_HOUSE = (111.9, 132.1, 187.8, 202.2)
# Where the hospital's path meets its door (the entrance tests/opening_story_smoke.gd checks), and
# the walk-clearance lines through the south alleys that tests/civic_block_smoke.gd checks.
HOSPITAL_DOOR = (255.2, 248.0)
SOUTH_ALLEY_LINES = (139.0, 169.0, 201.0)

# --- Buildings, lots and alleys ------------------------------------------------------------------
# kind: shop, apartments, bank, cinema, hotel, civic (variant post or police), diner, lot, alley.
# wall: a facade material in build_downtown.WALLS. shops: (sign, awning colour) per shopfront,
# left to right as seen from the street. sides: side walls that face a street or an open space
# and get windows ("west" or "east"). Depths run back from the front.

SOUTH_ROW = [
    dict(id="Bank", kind="bank", x0=WEST_EDGE, x1=124.6, depth=20.0, floors=3, wall="Limestone",
         sign="CICELY SAVINGS BANK", corner="west", sides=("west",)),
    dict(id="Hardware", kind="shop", x0=124.6, x1=137.25, depth=18.0, floors=2, wall="BrickRed",
         shops=[("LINDQVIST HARDWARE", "AwningGreen")]),
    dict(id="AlleySouth1", kind="alley", x0=137.25, x1=140.75),
    dict(id="Alder", kind="apartments", x0=140.75, x1=167.25, depth=22.0, floors=4, wall="BrickBrown",
         shops=[("PHARMACY", "AwningBlue"), ("LAUNDROMAT", "AwningRed")], entry="THE ALDER", escape=1, tank=True),
    dict(id="AlleySouth2", kind="alley", x0=167.25, x1=170.75),
    dict(id="Aurora", kind="cinema", x0=170.75, x1=186.75, depth=28.0, wall="Stucco", sign="AURORA",
         marquee=("CLOSED", "UNTIL FURTHER NOTICE")),
    dict(id="Bakery", kind="shop", x0=186.75, x1=199.25, depth=18.0, floors=2, wall="BrickCream",
         shops=[("BAKERY", "AwningOchre"), ("BARBER", "AwningNavy")], barber_pole=True),
    dict(id="AlleySouth3", kind="alley", x0=199.25, x1=202.75),
    dict(id="Police", kind="civic", variant="police", x0=202.75, x1=222.0, depth=20.0, floors=3, wall="BrickBuff",
         sign="CICELY POLICE", sides=("east",)),
]

NORTH_ROW = [
    dict(id="CornerLot", kind="lot", x0=WEST_EDGE, x1=135.0, depth=13.5, sign="PARK", entrance=(127.0, 132.0),
         cars=("Car", "SUV")),
    dict(id="Hotel", kind="hotel", x0=135.0, x1=157.0, depth=20.0, floors=5, wall="BrickDark", sign="HOTEL NORTHWOOD",
         dead_letter=11, ghost=("HOTEL NORTHWOOD", "60 ROOMS  STEAM HEAT"), sides=("west",)),
    dict(id="Variety", kind="shop", x0=157.0, x1=171.0, depth=16.0, floors=2, wall="BrickCream",
         shops=[("VARIETY STORE", "AwningRed")]),
    dict(id="AlleyNorth1", kind="alley", x0=171.0, x1=174.5, depth=16.0),
    dict(id="PostOffice", kind="civic", variant="post", x0=174.5, x1=196.5, depth=16.0, setback=3.0, floors=2,
         wall="Limestone", sign="NORTHWOOD POST OFFICE"),
    dict(id="RadioBlock", kind="apartments", x0=196.5, x1=220.5, depth=16.0, floors=3, wall="BrickRed",
         shops=[("RADIO & TV", "AwningTeal"), ("BOOKS", "AwningOchre")], entry="APARTMENTS", escape=5, tank=False),
    dict(id="AlleyNorth2", kind="alley", x0=220.5, x1=224.5, depth=16.0),
    dict(id="Diner", kind="diner", x0=224.5, x1=240.5, depth=11.0, setback=4.0, sign="POLAR STAR"),
    dict(id="DinerLot", kind="lot", x0=240.5, x1=262.0, depth=15.0, sign="EAT", entrance=(252.0, 258.0),
         cars=("Taxi",)),
]

# Storey heights (ground floor, upper floors) and the height of the top of each kind's walls.
STOREYS = {"shop": (4.4, 3.4), "apartments": (4.4, 3.2), "bank": (5.6, 3.4), "hotel": (4.6, 3.3),
           "post": (4.8, 3.6), "police": (4.4, 3.4)}


def rows():
    """(row name, its buildings) for both rows."""
    return [("north", NORTH_ROW), ("south", SOUTH_ROW)]


def front_z(row: str, b: dict) -> float:
    """z of a building's front, after its setback."""
    setback = b.get("setback", 0.0)
    return NORTH_FRONT - setback if row == "north" else SOUTH_FRONT + setback


def footprint(row: str, b: dict) -> tuple:
    """(x0, x1, z0, z1) of a building, lot or alley. Alleys run from the sidewalk to the service
    lane in the south row, and as deep as their neighbours in the north row."""
    if b["kind"] == "alley":
        if row == "south":
            return b["x0"], b["x1"], SOUTH_FRONT, SERVICE_LANE[0]
        return b["x0"], b["x1"], NORTH_FRONT - b["depth"], NORTH_FRONT
    front = front_z(row, b)
    if row == "north":
        return b["x0"], b["x1"], front - b["depth"], front
    return b["x0"], b["x1"], front, front + b["depth"]


def height(b: dict) -> float:
    """Height of a building's front wall top (parapet), without roof signs or tanks."""
    kind = b["kind"]
    if kind in ("shop", "apartments", "bank", "hotel"):
        ground, upper = STOREYS[kind]
        top = ground + upper * (b["floors"] - 1)
        return top + {"shop": 1.0, "apartments": 1.1, "bank": 1.3, "hotel": 1.0}[kind]
    if kind == "civic":
        ground, upper = STOREYS[b["variant"]]
        top = ground + upper * (b["floors"] - 1)
        return top + (1.6 if b["variant"] == "post" else 1.0)
    return {"cinema": 14.6, "diner": 4.6}.get(kind, 0.0)


def buildings():
    """(row, building) for every building, without lots and alleys."""
    return [(row, b) for row, items in rows() for b in items if b["kind"] not in ("lot", "alley")]


# --- Street furniture ----------------------------------------------------------------------------
# Each sidewalk has a furniture strip by the curb (lamps, meters, trees, benches, hydrants) and a
# clear walk between the strip and the buildings. The phone box stands against a wall.
# Furniture: (kind, x, z, yaw degrees); yaw 0 faces south (+z), 180 north.
NORTH_STRIP = 220.15
SOUTH_STRIP = 229.85
NORTH_WALK = (217.0, 219.5)         # z of the clear walk on each sidewalk
SOUTH_WALK = (230.9, 233.9)
LAMPS = [(x, NORTH_STRIP) for x in (116.0, 140.0, 163.0, 186.0, 209.0, 232.0, 262.0)] + \
        [(x, SOUTH_STRIP) for x in (114.5, 139.0, 161.0, 183.0, 206.0, 231.0, 249.5)]
METERS = [(x, NORTH_STRIP) for x in (145.5, 151.5, 159.0, 178.0, 192.0, 201.0, 214.0)] + \
         [(x, SOUTH_STRIP) for x in (119.5, 125.5, 145.5, 152.0, 166.0, 175.0, 190.5, 196.0, 219.0)]
TREES = [(x, NORTH_STRIP) for x in (122.0, 174.5, 197.0, 221.0, 247.0)] + \
        [(x, SOUTH_STRIP) for x in (129.0, 156.0, 187.0, 215.0)]
FURNITURE = [
    ("bench", 166.5, 219.95, 180.0), ("trash", 168.6, 220.05, 180.0),
    ("bench", 235.0, 219.95, 180.0), ("trash", 237.1, 220.05, 180.0),
    ("bench", 131.5, 230.05, 0.0), ("trash", 133.6, 229.95, 0.0),
    ("bench", 211.0, 230.05, 0.0), ("trash", 213.1, 229.95, 0.0),
    ("mailbox", 180.5, 220.0, 0.0), ("phone", 137.7, 217.4, 0.0),
    ("hydrant", 148.6, 220.3, 0.0), ("hydrant", 217.4, 220.3, 0.0),
    ("hydrant", 135.6, 229.7, 180.0), ("hydrant", 204.4, 229.7, 180.0),
    ("newspaper", 154.2, 220.0, 0.0), ("newspaper", 155.0, 220.0, 0.0), ("newspaper", 238.7, 220.0, 0.0),
    ("newspaper", 180.0, 230.0, 180.0),
    ("traffic_lights_ahead", 226.0, 220.35, 90.0),
    ("no_parking", 258.0, 230.1, 180.0),
    # The hospital forecourt keeps its bench, bin, phone box and hydrant.
    ("bench", 239.0, 241.7, 180.0), ("trash", 241.0, 241.7, 180.0), ("phone", 230.0, 234.6, 180.0),
    ("hydrant", 237.0, 230.55, 180.0),
    # Behind the south row: dumpsters on the service lane, beside the alley mouths.
    ("dumpster", 145.0, 266.6, 180.0), ("dumpster", 176.0, 266.6, 180.0), ("dumpster", 208.5, 266.6, 180.0),
]
# Dead cars at the curbs, in the road's parking edge: (model, x, z, yaw degrees); yaw 90 faces east.
CURB_CARS = [("Police Car", 211.0, 227.85, 90.0), ("Taxi", 147.0, 222.15, -90.0)]
# Moved out of the new buildings: the decorator's Crossroad street sign and the stop sign on the
# Crossroad's east leg now stand on the corner sidewalks.
CORNER_STREET_SIGN = (106.4, 218.6)
CORNER_STOP_SIGN = (106.4, 232.6)
# A blinking signal on a mast arm over the intersection, from the corner by the bank.
SIGNAL_POLE = (106.3, 230.4)
SIGNAL_HEAD = (100.4, 225.2)
SIGNAL_HEIGHT = 6.1


def strip_items():
    """(kind, x, z) of everything standing on a sidewalk, for spacing checks."""
    items = [("lamp", x, z) for x, z in LAMPS] + [("meter", x, z) for x, z in METERS]
    items += [("tree", x, z) for x, z in TREES]
    items += [(kind, x, z) for kind, x, z, _yaw in FURNITURE if kind not in ("dumpster",)]
    items += [("street_sign", *CORNER_STREET_SIGN), ("stop_sign", *CORNER_STOP_SIGN), ("signal", *SIGNAL_POLE)]
    return items
