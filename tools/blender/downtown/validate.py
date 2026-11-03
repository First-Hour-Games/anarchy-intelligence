"""Check tools/blender/downtown/plan.py against the game's clearances, without Blender.

python -I tools/blender/downtown/validate.py         (exit code 1 on problems)

prepare_downtown.py runs these checks first and exports nothing while any fail:
- each row runs west to east without overlaps, inside its band between the streets;
- nothing reaches the hospital or the house on the corner;
- alleys are at least ALLEY_MIN wide, and the south alleys keep the walk lines the map's tests
  walk (x 139, 169 and 201) a capsule's width clear on both sides;
- sidewalks are at least SIDEWALK_MIN wide, the furniture stays in the strip by the curb, out of the
  clear walk, off the lot entrances, apart from each other and out of the buildings;
- the hospital's path from the curb to its door stays clear.
"""

import types
from pathlib import Path

HERE = Path(__file__).resolve().parent
ALLEY_MIN = 3.0
ALLEY_LINE_CLEAR = 1.0      # each side of a walk line: the player capsule (0.35) and a margin
SIDEWALK_MIN = 4.0
STRIP_GAP = 0.3             # between the edges of two things in the furniture strip
WALL_ITEM_WALK = 1.5        # clear walk left beside something standing against a wall
TALLEST = 20.0
SHOP_MIN = 4.5
# Half extents (along x, along z) of each kind of furniture, facing south or north.
HALF = {"lamp": (0.3, 0.3), "meter": (0.15, 0.15), "tree": (0.6, 0.6), "bench": (0.8, 0.35), "trash": (0.25, 0.25),
        "mailbox": (0.35, 0.3), "phone": (0.45, 0.45), "hydrant": (0.3, 0.25), "newspaper": (0.3, 0.25),
        "traffic_lights_ahead": (0.25, 0.25), "no_parking": (0.25, 0.25), "street_sign": (0.2, 0.2),
        "stop_sign": (0.2, 0.2), "signal": (0.3, 0.3), "dumpster": (1.0, 0.7)}
WALL_ITEMS = {"phone"}


def load_plan():
    path = HERE / "plan.py"
    module = types.ModuleType("downtown_plan")
    module.__file__ = str(path)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def overlaps(a: tuple, b: tuple, margin: float = 0.0) -> bool:
    """Rectangles (x0, x1, z0, z1) overlap by more than nothing, after growing b by margin."""
    return a[0] < b[1] + margin and b[0] - margin < a[1] and a[2] < b[3] + margin and b[2] - margin < a[3]


def problems(plan=None) -> list:
    plan = plan or load_plan()
    found = []
    footprints = []
    for row, items in plan.rows():
        previous = None
        for b in items:
            box = plan.footprint(row, b)
            footprints.append((b["id"], box))
            if b["x1"] <= b["x0"]:
                found.append(f"{b['id']}: x1 is not east of x0")
            if previous is not None and b["x0"] < previous["x1"] - 1e-6:
                found.append(f"{b['id']} overlaps {previous['id']} along the {row} row")
            previous = b
            if row == "north" and (box[2] < plan.NORTH_BACK_LIMIT - 1e-6 or box[3] > plan.NORTH_FRONT + 1e-6):
                found.append(f"{b['id']} leaves the north row's band (z {box[2]:.1f}-{box[3]:.1f})")
            if row == "south" and (box[2] < plan.SOUTH_FRONT - 1e-6 or box[3] > plan.SERVICE_LANE[0] + 1e-6):
                found.append(f"{b['id']} leaves the south row's band (z {box[2]:.1f}-{box[3]:.1f})")
            if b["x0"] < plan.WEST_EDGE - 1e-6 or b["x1"] > plan.CROSSROAD_END:
                found.append(f"{b['id']} runs past the ends of the street")
            for name, kept in (("the hospital", plan.HOSPITAL), ("the corner house", plan.CORNER_HOUSE)):
                if overlaps(box, kept, 0.5):
                    found.append(f"{b['id']} comes within 0.5 m of {name}")
            if b["kind"] == "alley" and b["x1"] - b["x0"] < ALLEY_MIN:
                found.append(f"{b['id']} is {b['x1'] - b['x0']:.2f} m wide; alleys need {ALLEY_MIN} m")
            if b["kind"] not in ("alley", "lot"):
                if plan.height(b) > TALLEST:
                    found.append(f"{b['id']} is {plan.height(b):.1f} m tall")
                for i, _shop in enumerate(b.get("shops", [])):
                    share = (b["x1"] - b["x0"]) / len(b["shops"])
                    if b["kind"] == "apartments":
                        share = (b["x1"] - b["x0"]) * 0.42
                    if share < SHOP_MIN:
                        found.append(f"{b['id']}: shopfront {i} is {share:.1f} m wide")
                if b["kind"] in ("bank", "cinema", "hotel", "civic", "diner") and not b.get("sign"):
                    found.append(f"{b['id']} has no sign")
    south_alleys = [b for b in plan.SOUTH_ROW if b["kind"] == "alley"]
    for line in plan.SOUTH_ALLEY_LINES:
        if not any(a["x0"] + ALLEY_LINE_CLEAR <= line <= a["x1"] - ALLEY_LINE_CLEAR for a in south_alleys):
            found.append(f"no south alley keeps the walk line at x {line} clear")
    if plan.CURB_NORTH[0] - plan.NORTH_FRONT < SIDEWALK_MIN:
        found.append("the north sidewalk is too narrow")
    if plan.SOUTH_FRONT - plan.CURB_SOUTH[1] < SIDEWALK_MIN:
        found.append("the south sidewalk is too narrow")
    found += furniture_problems(plan, footprints)
    return found


def item_box(kind: str, x: float, z: float) -> tuple:
    hx, hz = HALF[kind]
    return x - hx, x + hx, z - hz, z + hz


def furniture_problems(plan, footprints) -> list:
    found = []
    entrances = [b["entrance"] for b in plan.NORTH_ROW + plan.SOUTH_ROW if "entrance" in b]
    strips = {"north": [], "south": []}
    for kind, x, z in plan.strip_items():
        box = item_box(kind, x, z)
        north = z < (plan.CROSSROAD[0] + plan.CROSSROAD[1]) / 2.0
        walk = plan.NORTH_WALK if north else plan.SOUTH_WALK
        corner = x < plan.WEST_EDGE
        if kind in WALL_ITEMS:
            left = (walk[1] - box[3]) if north else (box[2] - walk[0])
            if left < WALL_ITEM_WALK and not corner:
                found.append(f"{kind} at ({x}, {z}) leaves {left:.2f} m of clear walk")
        elif box[2] < walk[1] and walk[0] < box[3] and not corner and x < plan.HOSPITAL[0] - 3.0:
            found.append(f"{kind} at ({x}, {z}) stands in the clear walk")
        if not corner and x < plan.HOSPITAL[0] - 3.0:
            strips["north" if north else "south"].append((kind, x, z, box))
        for entrance in entrances:
            if north and entrance[0] - 0.5 < box[1] and box[0] < entrance[1] + 0.5:
                found.append(f"{kind} at ({x}, {z}) blocks the lot entrance at x {entrance[0]}-{entrance[1]}")
        for name, foot in footprints:
            if overlaps(box, foot) and not name.startswith(("Alley", "CornerLot", "DinerLot")):
                found.append(f"{kind} at ({x}, {z}) stands inside {name}")
        if overlaps(box, (plan.HOSPITAL_DOOR[0] - 1.0, plan.HOSPITAL_DOOR[0] + 1.0, plan.CURB_SOUTH[1], plan.HOSPITAL_DOOR[1])):
            found.append(f"{kind} at ({x}, {z}) stands on the hospital's path")
    for side, items in strips.items():
        items.sort(key=lambda item: item[1])
        for (kind_a, xa, _za, a), (kind_b, xb, _zb, b) in zip(items, items[1:]):
            if kind_a == kind_b == "newspaper":
                continue            # newspaper boxes stand in a row on purpose
            if b[0] - a[1] < STRIP_GAP and overlaps(a, b, STRIP_GAP):
                found.append(f"{kind_a} at x {xa} and {kind_b} at x {xb} crowd the {side} strip")
    for kind, x, z, _yaw in plan.FURNITURE:
        if kind == "dumpster":
            box = item_box(kind, x, z)
            for line in plan.SOUTH_ALLEY_LINES:
                if box[0] - ALLEY_LINE_CLEAR < line < box[1] + ALLEY_LINE_CLEAR and box[3] > plan.SOUTH_FRONT:
                    found.append(f"dumpster at ({x}, {z}) blocks the alley walk line at x {line}")
            if box[3] > (plan.SERVICE_LANE[0] + plan.SERVICE_LANE[1]) / 2.0 - ALLEY_LINE_CLEAR:
                found.append(f"dumpster at ({x}, {z}) blocks the service lane's walk")
    return found


if __name__ == "__main__":
    import sys
    issues = problems()
    for issue in issues:
        print("PROBLEM", issue)
    print("downtown plan:", "ok" if not issues else f"{len(issues)} problems")
    sys.exit(1 if issues else 0)
