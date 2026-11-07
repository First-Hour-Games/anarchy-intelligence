"""The alt route's downtown: the street of plan.py walled in by tall buildings for the rooftop ambush
(scenes/chapters/alt_route/rooftop_street.gd).

Everything not changed here is plan.py's. Build it with DOWNTOWN_PLAN=plan_alt (see
build_downtown.py); prepare_downtown.py exports it to models/buildings/downtown_alt.

The variety store, the post office and the diner in the north row, and the hardware store and the
bakery in the south row, become five-storey apartment blocks with the same shops below them; the
bank and the police station gain a storey. The rows then stand as two walls with nearly level
roofs, 15 to 19 m up, along which the Ridgebacks stand in a line. The dead cars at the curbs go: the
ambush brings its own jam of cars.
"""

from pathlib import Path

_base = Path(__file__).with_name("plan.py")
exec(compile(_base.read_text(encoding="utf-8"), str(_base), "exec"))

SOUTH_ROW = [
    dict(id="Bank", kind="bank", x0=WEST_EDGE, x1=124.6, depth=20.0, floors=4, wall="Limestone",
         sign="CICELY SAVINGS BANK", corner="west", sides=("west",)),
    dict(id="Garnet", kind="apartments", x0=124.6, x1=137.25, depth=18.0, floors=5, wall="BrickRed",
         shops=[("HARDWARE", "AwningGreen"), ("SHOE REPAIR", "AwningNavy")], entry="GARNET HOUSE", escape=1,
         tank=False),
    dict(id="AlleySouth1", kind="alley", x0=137.25, x1=140.75),
    dict(id="Alder", kind="apartments", x0=140.75, x1=167.25, depth=22.0, floors=5, wall="BrickBrown",
         shops=[("PHARMACY", "AwningBlue"), ("LAUNDROMAT", "AwningRed")], entry="THE ALDER", escape=1, tank=True),
    dict(id="AlleySouth2", kind="alley", x0=167.25, x1=170.75),
    dict(id="Aurora", kind="cinema", x0=170.75, x1=186.75, depth=28.0, wall="Stucco", sign="AURORA",
         marquee=("CLOSED", "UNTIL FURTHER NOTICE")),
    dict(id="Crown", kind="apartments", x0=186.75, x1=199.25, depth=18.0, floors=5, wall="BrickCream",
         shops=[("BAKERY", "AwningOchre"), ("BARBER", "AwningNavy")], entry="CROWN FLATS", escape=1, tank=True),
    dict(id="AlleySouth3", kind="alley", x0=199.25, x1=202.75),
    dict(id="Police", kind="civic", variant="police", x0=202.75, x1=222.0, depth=20.0, floors=4, wall="BrickBuff",
         sign="CICELY POLICE", sides=("east",)),
]

NORTH_ROW = [
    dict(id="CornerLot", kind="lot", x0=WEST_EDGE, x1=135.0, depth=13.5, sign="PARK", entrance=(127.0, 132.0),
         cars=("Car", "SUV")),
    dict(id="Hotel", kind="hotel", x0=135.0, x1=157.0, depth=20.0, floors=5, wall="BrickDark", sign="HOTEL NORTHWOOD",
         dead_letter=11, ghost=("HOTEL NORTHWOOD", "60 ROOMS  STEAM HEAT"), sides=("west",)),
    dict(id="Linden", kind="apartments", x0=157.0, x1=171.0, depth=16.0, floors=5, wall="BrickCream",
         shops=[("VARIETY STORE", "AwningRed"), ("DELI", "AwningGreen")], entry="THE LINDEN", escape=2, tank=True),
    dict(id="AlleyNorth1", kind="alley", x0=171.0, x1=174.5, depth=16.0),
    dict(id="Brighton", kind="apartments", x0=174.5, x1=196.5, depth=16.0, floors=5, wall="BrickBuff",
         shops=[("CLEANERS", "AwningTeal"), ("POST OFFICE", "AwningNavy")], entry="BRIGHTON COURT", escape=4,
         tank=False),
    dict(id="RadioBlock", kind="apartments", x0=196.5, x1=220.5, depth=16.0, floors=5, wall="BrickRed",
         shops=[("RADIO & TV", "AwningTeal"), ("BOOKS", "AwningOchre")], entry="APARTMENTS", escape=5, tank=True),
    dict(id="AlleyNorth2", kind="alley", x0=220.5, x1=224.5, depth=16.0),
    dict(id="Harbor", kind="apartments", x0=224.5, x1=240.5, depth=16.0, floors=5, wall="BrickBrown",
         shops=[("POLAR STAR DINER", "AwningRed"), ("TAILOR", "AwningOchre")], entry="THE HARBOR", escape=1,
         tank=False),
    dict(id="DinerLot", kind="lot", x0=240.5, x1=262.0, depth=15.0, sign="PARK", entrance=(252.0, 258.0),
         cars=("Taxi",)),
]

CURB_CARS = []
