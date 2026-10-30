"""Check that Carrie's house leaves room for the game's bodies, using the layout data alone.

python tools/blender/carrie_house/validate.py      (exit code 1 when there are problems)

The player is 0.7 m across and the monsters 0.8 m. Along the open route that needs:
- every doorway that stands open at least 1.0 m wide, with nothing that blocks in front of it;
- 1.2 m of clear floor beyond both ends of each stair people use: no wall, no blocking furniture and
  no hole in the floor there;
- on each floor, every open doorway and stair end reachable from the others by a monster;
- pictures hung on solid wall, not across a doorway or opening.
prepare_carrie_house.py runs this before it exports and stops on any problem.
"""

import sys
import types
from collections import deque
from pathlib import Path

HERE = Path(__file__).resolve().parent
DOOR_WIDTH = 1.0        # monsters are 0.8 m across
DOOR_CLEAR = 0.9        # free floor on each side of an open doorway
STAIR_CLEAR = 1.2       # free floor beyond each end of a stair
WALKED_STAIRS = ("MainStair", "BackStair")
EDGE = 0.05             # rectangles may touch, or overlap by this much
# How far a monster's route keeps from walls and furniture: its 0.4 m radius plus the navigation
# mesh's cells, which close any gap much under 1.2 m. Open doorways are narrower, so links cross them.
NAV_CLEAR = 0.55
CELL = 0.05             # grid for the reachability check
STEP_OFF = 0.6          # how far beyond a doorway or stair end the check starts and ends
LINK_REACH = 0.8        # how far a doorway's navigation link runs out on each side


def load(name: str):
    """A module from this folder, run without leaving a __pycache__ behind."""
    path = HERE / f"{name}.py"
    module = types.ModuleType(name)
    module.__file__ = str(path)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def overlap(a: tuple, b: tuple) -> bool:
    """Whether two (x0, x1, z0, z1) rectangles overlap by more than EDGE."""
    return min(a[1], b[1]) - max(a[0], b[0]) > EDGE and min(a[3], b[3]) - max(a[2], b[2]) > EDGE


def storey_of(layout, y: float) -> float:
    return max(f for f in (layout.CELLAR, layout.GROUND, layout.UPPER, layout.ATTIC) if f <= y + 0.01)


def blocking_furniture(layout, furniture) -> list:
    """(name, storey, rectangle) for every piece the player and monsters can't walk through."""
    pieces = []
    for name, _role, y, x0, x1, z0, z1, _height in layout.objects:
        if (name in furniture.PIECES or name == "Dollhouse") and name not in furniture.PASSABLE:
            pieces.append((name, storey_of(layout, y), (x0, x1, z0, z1)))
    floors = {"CELLAR": layout.CELLAR, "GROUND": layout.GROUND, "UPPER": layout.UPPER, "ATTIC": layout.ATTIC}
    for name, _model, storey, _lift, x0, x1, z0, z1, _height, _facing in furniture.DRESSING:
        if name not in furniture.PASSABLE:
            pieces.append((name, floors[storey], (x0, x1, z0, z1)))
    return pieces


def door_angle(layout, w: dict, o: dict):
    """How far the opening's door stands open in degrees, or None for an opening with no door."""
    if w["id"] in layout.exterior_doors and o["kind"] == "door" and o["y0"] >= layout.GROUND - 0.01:
        return layout.exterior_doors[w["id"]][3]
    leaf = layout.door_leaves.get((w["id"], round(o["a"], 2)))
    return leaf[3] if leaf else None


def walked_through(layout, w: dict, o: dict) -> bool:
    """Whether people pass through this opening: a cased opening or a door left open."""
    if o["kind"] not in ("door", "opening", "closet"):
        return False
    if w["id"].startswith("Ext") and not (w["id"] in layout.exterior_doors and o["y0"] >= layout.GROUND - 0.01):
        return False
    angle = door_angle(layout, w, o)
    return angle is None or angle > 1.0


def solid_walls(layout, storey: float) -> list:
    """(wall id, rectangle) for the parts of each wall that stop someone walking on this storey."""
    parts = []
    for w in layout.walls:
        if w["y0"] > storey + 0.1 or w["y1"] < storey + 1.0:
            continue
        gaps = sorted((o["a"], o["b"]) for o in w["openings"]
                      if o["y0"] <= storey + 0.05 and o["y1"] > storey + 1.0 and walked_through(layout, w, o))
        start = w["start"]
        for a, b in gaps + [(w["end"], w["end"])]:
            if a > start:
                half = w["t"] / 2.0
                rect = ((start, a, w["fixed"] - half, w["fixed"] + half) if w["axis"] == "x"
                        else (w["fixed"] - half, w["fixed"] + half, start, a))
                parts.append((w["id"], rect))
            start = max(start, b)
    return parts


def floor_holes(layout, storey: float) -> list:
    return [hole for name, y_top, _t, _rect, holes in layout.floors if abs(y_top - storey) < 0.01 for hole in holes]


def check_clear(problems: list, label: str, rect: tuple, storey: float, layout, pieces: list, walls=True) -> None:
    for name, at, area in pieces:
        if at == storey and overlap(rect, area):
            problems.append(f"{label}: {name} stands in it")
    if walls:
        for wall_id, area in solid_walls(layout, storey):
            if overlap(rect, area):
                problems.append(f"{label}: wall {wall_id} crosses it")
    for hole in floor_holes(layout, storey):
        if overlap(rect, hole):
            problems.append(f"{label}: the floor has a hole there")


def route_points(layout, storey: float) -> list:
    """(label, x, z): where someone steps off each stair end and stands each side of each open
    doorway on this storey (inside only, for doors in the outside walls)."""
    points = []
    for st in layout.stairs:
        if st["id"] not in WALKED_STAIRS:
            continue
        (x0, x1), (foot, top), (y_foot, y_top) = st["x"], st["z"], st["y"]
        up = 1.0 if top > foot else -1.0
        if abs(y_foot - storey) < 0.01:
            points.append((f"{st['id']} foot", (x0 + x1) / 2.0, foot - up * STEP_OFF))
        if abs(y_top - storey) < 0.01:
            points.append((f"{st['id']} top", (x0 + x1) / 2.0, top + up * STEP_OFF))
    for w in layout.walls:
        for o in w["openings"]:
            if not walked_through(layout, w, o) or abs(storey_of(layout, o["y0"]) - storey) > 0.01:
                continue
            middle = (o["a"] + o["b"]) / 2.0
            inward = 1.0 if (-5.0 if w["axis"] == "x" else 0.0) > w["fixed"] else -1.0
            for side in (inward,) if w["id"].startswith("Ext") else (-1.0, 1.0):
                across = w["fixed"] + side * STEP_OFF
                x, z = (middle, across) if w["axis"] == "x" else (across, middle)
                points.append((f"{w['id']} doorway at {o['a']:.2f}..{o['b']:.2f} ({side:+.0f})", x, z))
    return points


def check_routes(found: list, layout, pieces: list) -> None:
    """On each open floor, every stair end and doorway side must connect to the others the way a
    monster's navigation does: free cells at least NAV_CLEAR from anything solid, joined through
    open doorways by their links. A grid of free cells, flooded from the first point."""
    for storey in (layout.GROUND, layout.UPPER):
        obstacles = [rect for _id, rect in solid_walls(layout, storey)]
        obstacles += [area for _name, at, area in pieces if at == storey]
        obstacles += floor_holes(layout, storey)
        # A stair's own run is no floor on the storey it starts from.
        obstacles += [(st["x"][0], st["x"][1], *sorted(st["z"])) for st in layout.stairs
                      if st["id"] in WALKED_STAIRS and abs(st["y"][0] - storey) < 0.01]
        # The grid spans the inside of the outer walls: x -5..5, z -10..0.
        columns, rows = round(10.0 / CELL), round(10.0 / CELL)
        free = [[True] * rows for _ in range(columns)]
        for x0, x1, z0, z1 in obstacles:
            for i in range(max(0, int((x0 - NAV_CLEAR + 5.0) / CELL)), min(columns, int((x1 + NAV_CLEAR + 5.0) / CELL) + 1)):
                x = -5.0 + (i + 0.5) * CELL
                dx = max(x0 - x, x - x1, 0.0)
                for j in range(max(0, int((z0 - NAV_CLEAR + 10.0) / CELL)), min(rows, int((z1 + NAV_CLEAR + 10.0) / CELL) + 1)):
                    z = -10.0 + (j + 0.5) * CELL
                    dz = max(z0 - z, z - z1, 0.0)
                    if dx * dx + dz * dz < NAV_CLEAR * NAV_CLEAR:
                        free[i][j] = False
        for w in layout.walls:
            for o in w["openings"]:
                if walked_through(layout, w, o) and abs(storey_of(layout, o["y0"]) - storey) < 0.01:
                    near, far = w["fixed"] - LINK_REACH, w["fixed"] + LINK_REACH
                    x0, x1, z0, z1 = (o["a"], o["b"], near, far) if w["axis"] == "x" else (near, far, o["a"], o["b"])
                    for i in range(max(0, int((x0 + 5.0) / CELL)), min(columns, int((x1 + 5.0) / CELL) + 1)):
                        for j in range(max(0, int((z0 + 10.0) / CELL)), min(rows, int((z1 + 10.0) / CELL) + 1)):
                            free[i][j] = True
        cells = []
        for label, x, z in route_points(layout, storey):
            i, j = int((x + 5.0) / CELL), int((z + 10.0) / CELL)
            if not free[i][j]:
                found.append(f"{label}: no room for a monster to stand where it steps off")
            cells.append((label, i, j))
        if not cells:
            continue
        start_label, i, j = cells[0]
        reached = {(i, j)} if free[i][j] else set()
        queue = deque(reached)
        while queue:
            i, j = queue.popleft()
            for ni, nj in ((i + 1, j), (i - 1, j), (i, j + 1), (i, j - 1)):
                if 0 <= ni < columns and 0 <= nj < rows and free[ni][nj] and (ni, nj) not in reached:
                    reached.add((ni, nj))
                    queue.append((ni, nj))
        for label, i, j in cells[1:]:
            if free[i][j] and (i, j) not in reached:
                found.append(f"{label}: can't be reached from {start_label} on that floor")


def problems(layout=None, furniture=None) -> list:
    layout, furniture = layout or load("layout"), furniture or load("furniture")
    found = []
    pieces = blocking_furniture(layout, furniture)

    # Doorways that stand open: wide enough, with nothing in front on either side.
    for w in layout.walls:
        for o in w["openings"]:
            if not walked_through(layout, w, o) or o["y0"] > layout.ATTIC:
                continue
            storey = storey_of(layout, o["y0"])
            label = f"{w['id']} doorway at {o['a']:.2f}..{o['b']:.2f}"
            if o["b"] - o["a"] < DOOR_WIDTH - 1e-6:
                found.append(f"{label}: {o['b'] - o['a']:.2f} m wide, under {DOOR_WIDTH} m")
            # Both sides of an inside wall; only the inside of an outside wall (the house's middle is
            # at x 0, z -5).
            inward = 1.0 if (-5.0 if w["axis"] == "x" else 0.0) > w["fixed"] else -1.0
            sides = (inward,) if w["id"].startswith("Ext") else (-1.0, 1.0)
            for side in sides:
                near, far = sorted((w["fixed"], w["fixed"] + side * DOOR_CLEAR))
                rect = (o["a"], o["b"], near, far) if w["axis"] == "x" else (near, far, o["a"], o["b"])
                across = "z" if w["axis"] == "x" else "x"
                check_clear(found, f"{label}, {'+' if side > 0 else '-'}{across} side", rect, storey, layout, pieces,
                            walls=False)

    # Stairs people use: clear floor beyond the foot and the top.
    for st in layout.stairs:
        if st["id"] not in WALKED_STAIRS:
            continue
        (x0, x1), (foot, top), (y_foot, y_top) = st["x"], st["z"], st["y"]
        up = 1.0 if top > foot else -1.0
        for label, edge, storey, outward in ((f"{st['id']} foot", foot, y_foot, -up), (f"{st['id']} top", top, y_top, up)):
            near, far = sorted((edge, edge + outward * STAIR_CLEAR))
            check_clear(found, label, (x0, x1, near, far), storey, layout, pieces)

    check_routes(found, layout, pieces)

    # Pictures on solid wall, inside the wall's length.
    walls = {w["id"]: w for w in layout.walls}
    for name, wall_id, _side, along, centre, width, height, _image in furniture.PICTURES:
        w = walls[wall_id]
        a, b = along - width / 2.0, along + width / 2.0
        y0, y1 = w["y0"] + centre - height / 2.0, w["y0"] + centre + height / 2.0
        if a < w["start"] or b > w["end"]:
            found.append(f"picture {name}: runs past the end of {wall_id}")
        for o in w["openings"]:
            if min(b, o["b"]) - max(a, o["a"]) > 0.0 and min(y1, o["y1"]) - max(y0, o["y0"]) > 0.0:
                found.append(f"picture {name}: hangs across an opening in {wall_id} ({o['a']:.2f}..{o['b']:.2f})")
    return found


if __name__ == "__main__":
    issues = problems()
    for issue in issues:
        print("PROBLEM", issue)
    print(f"{len(issues)} problems" if issues else "Carrie's house layout: no problems")
    sys.exit(1 if issues else 0)
