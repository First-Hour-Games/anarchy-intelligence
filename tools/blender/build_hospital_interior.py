"""Build the hospital's ground-floor interior inside Hospital_V2.blend.

Headless: blender --background --factory-startup --python tools/blender/build_hospital_interior.py
Live (Blender MCP): runpy.run_path(<this file>, run_name="live")["build"](["shell"])

Everything is created inside the "HospitalInterior" collection under the
"InteriorRoot" empty, which is rebuilt from scratch on each run; the original
exterior objects are never modified. InteriorRoot converts game metres to the
source file's units: children are authored in Godot hospital-local coordinates
(x east, y up, z = 0 at the front facade and negative going inward). Godot
shows the exported model at 0.6 scale, so the root scales by 1/0.6 and rotates
+90 degrees about X (game +Y up -> Blender +Z, game +Z -> Blender -Y).
tools/blender/prepare_story_hospital.py must skip this collection when it clips
the exterior's ground floor.
"""

from math import copysign as math_copysign, radians
from pathlib import Path

import bpy


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = PROJECT_ROOT / "models" / "source" / "buildings" / "Hospital_V2.blend"
# Room layout data (walls, furniture, Godot markers) in hospital-local game metres.
LAYOUT_DIR = Path(__file__).resolve().parent / "hospital_layout"
COLLECTION = "HospitalInterior"
# Editing-only previews of the models Godot spawns at the markers; never exported.
PREVIEW_COLLECTION = "GodotPreview"
ROOT_NAME = "InteriorRoot"
GODOT_SCALE = 0.6

# Footprint (game metres): inner faces of the exterior walls and floor/ceiling levels.
FRONT_Z, BACK_Z = -0.30, -9.30
WEST_X, EAST_X = -20.10, 17.70
FLOOR_Y = 0.12
CEILING_Y = 2.95
SLAB_TOP_Y = 3.39
PERIMETER_THICKNESS = 0.15
ENTRANCE = (-11.76, -8.64)

# Exterior openings measured from the shell (game metres): (start, end, sill_y, head_y).
FRONT_OPENINGS = [
    (-19.33, -16.85, 0.54, 2.10), (-15.67, -13.19, 0.54, 2.10),
    (-8.35, -5.87, 0.54, 2.10), (-3.96, -1.56, FLOOR_Y, 1.80),
    (0.83, 2.38, 0.54, 1.98), (3.31, 4.85, 0.54, 1.98), (5.78, 7.33, 0.54, 1.98),
    (8.27, 9.82, 0.54, 1.98), (10.75, 12.29, 0.54, 1.98), (13.22, 14.77, 0.54, 1.98),
    (ENTRANCE[0], ENTRANCE[1], FLOOR_Y, 2.40),
]
BACK_OPENINGS = [
    (0.82, 2.36, 0.54, 1.98), (3.29, 4.83, 0.54, 1.98), (5.76, 7.30, 0.54, 1.98),
    (8.23, 9.77, 0.54, 1.98), (10.70, 12.25, 0.54, 1.98), (13.17, 14.71, 0.54, 1.98),
    (15.64, 17.18, 0.54, 1.98),
]
# East wall openings run along z (start/end given as z values).
EAST_OPENINGS = [
    (-1.78, -0.56, 0.54, 1.98), (-4.48, -3.20, 0.54, 1.98),
    (-6.64, -5.36, 0.54, 1.98), (-8.80, -7.52, 0.54, 1.98),
]

PALETTE = {
    "WallUpper": ((0.66, 0.70, 0.64), 0.0, 0.85),
    "WallLower": ((0.36, 0.43, 0.38), 0.0, 0.8),
    "Baseboard": ((0.11, 0.12, 0.12), 0.0, 0.6),
    "Ceiling": ((0.80, 0.79, 0.74), 0.0, 0.9),
    "CeilingGrid": ((0.58, 0.58, 0.55), 0.3, 0.6),
    "HospitalFloor": ((0.56, 0.58, 0.53), 0.0, 0.7),
    "Trim": ((0.83, 0.82, 0.78), 0.1, 0.5),
    "SillStone": ((0.70, 0.69, 0.66), 0.0, 0.6),
    "DoorFrame": ((0.20, 0.20, 0.19), 0.6, 0.45),
    "DoorGlass": ((0.06, 0.09, 0.10), 0.0, 0.05),
    "Plywood": ((0.60, 0.48, 0.32), 0.0, 0.85),
    "SprayPaint": ((0.55, 0.06, 0.05), 0.0, 0.9),
    "ExitHousing": ((0.86, 0.86, 0.82), 0.0, 0.5),
    "ExitGlow": ((1.0, 0.12, 0.08), 0.0, 0.4),
    "Laminate": ((0.70, 0.66, 0.58), 0.0, 0.6),
    "Countertop": ((0.34, 0.31, 0.28), 0.0, 0.45),
    "Vinyl": ((0.25, 0.34, 0.40), 0.0, 0.55),
    "Chrome": ((0.74, 0.74, 0.73), 1.0, 0.3),
    "Canvas": ((0.33, 0.36, 0.24), 0.0, 0.9),
    "Curtain": ((0.55, 0.67, 0.71), 0.0, 0.9),
    "Linen": ((0.86, 0.86, 0.82), 0.0, 0.85),
    "Blanket": ((0.40, 0.40, 0.43), 0.0, 0.95),
    "Rubber": ((0.07, 0.07, 0.07), 0.0, 0.8),
    "Cork": ((0.58, 0.42, 0.26), 0.0, 0.95),
    "Paper": ((0.92, 0.91, 0.86), 0.0, 0.9),
    "VendingBody": ((0.52, 0.10, 0.08), 0.2, 0.5),
    "VendingWindow": ((0.05, 0.06, 0.07), 0.0, 0.05),
    "PanelLit": ((0.95, 0.95, 0.90), 0.0, 0.4),
    "PanelDead": ((0.70, 0.70, 0.68), 0.0, 0.5),
    "SignBlue": ((0.11, 0.23, 0.42), 0.0, 0.5),
    "SignWhite": ((0.95, 0.95, 0.94), 0.0, 0.5),
    "FilingGrey": ((0.50, 0.52, 0.50), 0.4, 0.5),
    "ShelfSteel": ((0.44, 0.47, 0.46), 0.6, 0.45),
    "Wood": ((0.44, 0.31, 0.19), 0.0, 0.7),
    "Cardboard": ((0.60, 0.47, 0.30), 0.0, 0.95),
    "DoorPaint": ((0.62, 0.66, 0.62), 0.0, 0.6),
    "Appliance": ((0.88, 0.88, 0.85), 0.1, 0.4),
    "Mattress": ((0.70, 0.72, 0.66), 0.0, 0.9),
    "BookRed": ((0.48, 0.12, 0.10), 0.0, 0.8),
    "BookBlue": ((0.14, 0.22, 0.42), 0.0, 0.8),
    "BookGreen": ((0.16, 0.34, 0.20), 0.0, 0.8),
    "Plenum": ((0.015, 0.015, 0.015), 0.0, 1.0),
    "TVStatic": ((0.70, 0.74, 0.80), 0.0, 0.5),
    "LampGlow": ((1.0, 0.85, 0.55), 0.0, 0.4),
    "FridgeLight": ((0.90, 0.95, 1.0), 0.0, 0.4),
    "VendingLit": ((0.55, 0.75, 1.0), 0.0, 0.4),
    # Hospital equipment (tools/blender/hospital_dressing).
    "CartRed": ((0.62, 0.05, 0.04), 0.1, 0.45),
    "CartBlue": ((0.12, 0.26, 0.48), 0.1, 0.45),
    "PlasticWhite": ((0.90, 0.90, 0.88), 0.0, 0.45),
    "PlasticBeige": ((0.78, 0.74, 0.62), 0.0, 0.5),
    "PlasticGrey": ((0.42, 0.43, 0.44), 0.0, 0.5),
    "ScreenDark": ((0.03, 0.04, 0.04), 0.0, 0.15),
    "ScreenGreen": ((0.25, 0.95, 0.45), 0.0, 0.3),
    "OxygenGreen": ((0.10, 0.45, 0.20), 0.2, 0.4),
    "AirYellow": ((0.85, 0.70, 0.10), 0.0, 0.5),
    "MedicalRed": ((0.70, 0.08, 0.06), 0.0, 0.5),
    "SafetyYellow": ((0.90, 0.75, 0.05), 0.0, 0.6),
    "SignGreen": ((0.05, 0.42, 0.20), 0.0, 0.5),
    "ScrubTeal": ((0.20, 0.50, 0.50), 0.0, 0.9),
    "GloveBlue": ((0.25, 0.45, 0.85), 0.0, 0.7),
    "GlovePurple": ((0.45, 0.25, 0.65), 0.0, 0.7),
    "FilmLit": ((0.85, 0.90, 1.0), 0.0, 0.4),
    "FilmDark": ((0.08, 0.09, 0.10), 0.0, 0.2),
    "Brass": ((0.72, 0.55, 0.25), 1.0, 0.35),
    "VinylTeal": ((0.20, 0.42, 0.42), 0.0, 0.55),
    "VinylMauve": ((0.45, 0.30, 0.38), 0.0, 0.55),
    "MattressBlue": ((0.25, 0.38, 0.55), 0.0, 0.7),
    "AlarmRed": ((0.80, 0.04, 0.03), 0.0, 0.4),
    # Floor finishes by room, and the corridor's wayfinding lines.
    "FloorBeige": ((0.60, 0.56, 0.48), 0.0, 0.75),
    "FloorTerrazzo": ((0.55, 0.56, 0.55), 0.0, 0.45),
    "FloorGreen": ((0.50, 0.57, 0.49), 0.0, 0.6),
    "FloorGreenDark": ((0.30, 0.38, 0.32), 0.0, 0.6),
    "FloorLightGrey": ((0.66, 0.67, 0.66), 0.0, 0.55),
    "FloorWood": ((0.45, 0.33, 0.22), 0.0, 0.7),
    "FloorConcrete": ((0.44, 0.44, 0.43), 0.0, 0.85),
    "FloorCarpet": ((0.28, 0.32, 0.38), 0.0, 1.0),
    "FloorSafety": ((0.46, 0.48, 0.48), 0.0, 0.8),
    "FloorLineBlue": ((0.10, 0.28, 0.62), 0.0, 0.5),
    "FloorLineYellow": ((0.85, 0.68, 0.10), 0.0, 0.5),
}
# Extra material settings: alpha for glass, emission for lit signs and lights.
ALPHA = {"DoorGlass": 0.35, "VendingWindow": 0.6}
EMISSION = {"ExitGlow": 4.0, "PanelLit": 3.0, "TVStatic": 2.0, "LampGlow": 3.0, "FridgeLight": 2.5, "VendingLit": 2.5,
            "ScreenGreen": 1.5, "FilmLit": 2.0, "AlarmRed": 2.0}


def material(name: str) -> bpy.types.Material:
    """The palette material, created on first use and refreshed so palette edits apply on rebuild."""
    result = bpy.data.materials.get("Interior_" + name)
    if result is not None and result.get("palette_entry") == repr((PALETTE[name], ALPHA.get(name), EMISSION.get(name))):
        return result
    color, metallic, roughness = PALETTE[name]
    if result is None:
        result = bpy.data.materials.new("Interior_" + name)
    result["palette_entry"] = repr((PALETTE[name], ALPHA.get(name), EMISSION.get(name)))
    result.use_nodes = True
    shader = next(node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    # Solid-mode viewport and Workbench previews show the display colour.
    result.diffuse_color = (*color, 1.0)
    result.metallic = metallic
    result.roughness = roughness
    if name in ALPHA:
        shader.inputs["Alpha"].default_value = ALPHA[name]
        result.surface_render_method = "BLENDED"
    if name in EMISSION:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = EMISSION[name]
    return result


def organize_exterior() -> None:
    """Group the original building pieces so they can be hidden with one toggle while editing."""
    exterior = bpy.data.collections.get("HospitalExterior")
    if exterior is None:
        exterior = bpy.data.collections.new("HospitalExterior")
        bpy.context.scene.collection.children.link(exterior)
    interior = bpy.data.collections.get(COLLECTION)
    preview = bpy.data.collections.get(PREVIEW_COLLECTION)
    for obj in list(bpy.context.scene.objects):
        if (interior is not None and obj.name in interior.objects) or obj.name in exterior.objects:
            continue
        if preview is not None and obj.name in preview.objects:
            continue
        for owner in list(obj.users_collection):
            owner.objects.unlink(obj)
        exterior.objects.link(obj)


def interior_collection() -> bpy.types.Collection:
    collection = bpy.data.collections.get(COLLECTION)
    if collection is None:
        collection = bpy.data.collections.new(COLLECTION)
        bpy.context.scene.collection.children.link(collection)
    return collection


def clear_interior() -> None:
    for name in (PREVIEW_COLLECTION, COLLECTION):
        collection = bpy.data.collections.get(name)
        if collection is None:
            continue
        for obj in list(collection.objects):
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)
            elif isinstance(data, bpy.types.Curve) and data.users == 0:
                bpy.data.curves.remove(data)


def interior_root() -> bpy.types.Object:
    root = bpy.data.objects.get(ROOT_NAME)
    if root is None:
        root = bpy.data.objects.new(ROOT_NAME, None)
        root.empty_display_type = "ARROWS"
        interior_collection().objects.link(root)
    root.location = (0.0, 0.0, 0.0)
    root.rotation_euler = (radians(90.0), 0.0, 0.0)
    root.scale = (1.0 / GODOT_SCALE,) * 3
    return root


def box(name: str, low: tuple, high: tuple, mat: str) -> bpy.types.Object:
    """Axis-aligned box in game coordinates, parented to InteriorRoot."""
    x0, y0, z0 = low
    x1, y1, z1 = high
    vertices = [
        (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
        (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1),
    ]
    # Outward-facing winding in a right-handed, Y-up space.
    faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(material(mat))
    obj = bpy.data.objects.new(name, mesh)
    interior_collection().objects.link(obj)
    obj.parent = interior_root()
    return obj


def wall_with_openings(name: str, axis: str, fixed_low: float, fixed_high: float, start: float, end: float,
                       openings: list, top: float = SLAB_TOP_Y) -> None:
    """A wall running along `axis` ("x" or "z") from start to end, with rectangular openings.

    fixed_low/fixed_high span the wall's thickness on the other axis. Openings are
    (a, b, sill_y, head_y) along the running axis.
    """
    def piece(label: str, a: float, b: float, y0: float, y1: float, mat: str) -> None:
        if b - a < 0.005 or y1 - y0 < 0.005:
            return
        if axis == "x":
            box(f"{name}_{label}", (a, y0, fixed_low), (b, y1, fixed_high), mat)
        else:
            box(f"{name}_{label}", (fixed_low, y0, a), (fixed_high, y1, b), mat)

    cursor = start
    spans = sorted((min(a, b), max(a, b), sill, head) for a, b, sill, head in openings)
    for index, (a, b, sill, head) in enumerate(spans):
        piece(f"Solid{index}", cursor, a, FLOOR_Y, top, "WallUpper")
        piece(f"Below{index}", a, b, FLOOR_Y, sill, "WallUpper")
        piece(f"Above{index}", a, b, head, top, "WallUpper")
        cursor = b
    piece("SolidEnd", cursor, end, FLOOR_Y, top, "WallUpper")


def build_shell() -> None:
    """Floor, drop ceiling with grid, and the inside faces of the exterior walls."""
    t = PERIMETER_THICKNESS
    build_floors()
    wall_with_openings("WallFront", "x", FRONT_Z - t, FRONT_Z, WEST_X, EAST_X, FRONT_OPENINGS)
    wall_with_openings("WallBack", "x", BACK_Z, BACK_Z + t, WEST_X, EAST_X, BACK_OPENINGS)
    wall_with_openings("WallWest", "z", WEST_X, WEST_X + t, BACK_Z, FRONT_Z, [])
    wall_with_openings("WallEast", "z", EAST_X - t, EAST_X, BACK_Z, FRONT_Z, EAST_OPENINGS)
    # Interior window sills.
    for a, b, sill, _head in FRONT_OPENINGS:
        if sill > FLOOR_Y + 0.01:
            box("WindowSillFront", (a, sill - 0.03, FRONT_Z - t - 0.06), (b, sill, FRONT_Z), "SillStone")
    for a, b, sill, _head in BACK_OPENINGS:
        box("WindowSillBack", (a, sill - 0.03, BACK_Z), (b, sill, BACK_Z + t + 0.06), "SillStone")
    for a, b, sill, _head in EAST_OPENINGS:
        box("WindowSillEast", (EAST_X - t - 0.06, sill - 0.03, min(a, b)), (EAST_X, sill, max(a, b)), "SillStone")


# (word in a room's floor_finish, material); rooms tile the footprint, so their floors do too.
FLOOR_FINISHES = [("carpet", "FloorCarpet"), ("wood-look", "FloorWood"), ("concrete", "FloorConcrete"),
                  ("terrazzo", "FloorTerrazzo"), ("lobby vinyl", "FloorTerrazzo"), ("beige", "FloorBeige"),
                  ("safety", "FloorSafety"), ("green", "FloorGreen"), ("light grey", "FloorLightGrey")]
# Corridor sheet vinyl as strips across z: darker border bands and two wayfinding lines.
CORRIDOR_STRIPS = [(-5.25, -4.95, "FloorGreenDark"), (-4.95, -4.30, "FloorGreen"), (-4.30, -4.22, "FloorLineBlue"),
                   (-4.22, -4.16, "FloorGreen"), (-4.16, -4.08, "FloorLineYellow"), (-4.08, -3.35, "FloorGreen"),
                   (-3.35, -3.05, "FloorGreenDark")]


def build_floors() -> None:
    """One floor slab per room ("GroundFloor" names keep the tile footsteps), no overlaps."""
    layout = load_layout()
    for room in layout.rooms:
        x0, x1, z0, z1 = room["x_min"], room["x_max"], room["z_min"], room["z_max"]
        label = "".join(part for part in room["name"].split("(")[0].title() if part.isalnum())
        if "Corridor" in room["name"]:
            for s0, s1, mat in CORRIDOR_STRIPS:
                box(f"GroundFloor_{label}", (x0, 0.0, max(z0, s0)), (x1, FLOOR_Y, min(z1, s1)), mat)
            continue
        finish = room["floor_finish"]
        mat = next((m for word, m in FLOOR_FINISHES if word in finish), "HospitalFloor")
        box(f"GroundFloor_{label}", (x0, 0.0, z0), (x1, FLOOR_Y, z1), mat)


WAINSCOT_Y = 1.0
TOWER_DOOR = (-3.96, -1.56)


def band_along(name: str, axis: str, face: float, inward: float, start: float, end: float, openings: list,
               y0: float, y1: float, mat: str, depth: float) -> None:
    """A thin horizontal band (paint, skirting, rail) on a wall face, broken by openings
    wherever the band's height range overlaps them."""
    cuts = sorted((min(a, b), max(a, b)) for a, b, sill, head in openings if sill < y1 and head > y0)
    cursor = start
    pieces = []
    for a, b in cuts:
        pieces.append((cursor, a))
        cursor = max(cursor, b)
    pieces.append((cursor, end))
    low, high = sorted((face, face + inward * depth))
    for index, (a, b) in enumerate(pieces):
        if b - a < 0.01:
            continue
        if axis == "x":
            box(f"{name}{index}", (a, y0, low), (b, y1, high), mat)
        else:
            box(f"{name}{index}", (low, y0, a), (high, y1, b), mat)
    # Under each window the band still runs below the sill.
    for a, b, sill, head in openings:
        if sill > y0 + 0.01 and sill < y1:
            top = min(sill, y1)
            if axis == "x":
                box(f"{name}Under", (min(a, b), y0, low), (max(a, b), top, high), mat)
            else:
                box(f"{name}Under", (low, y0, min(a, b)), (high, top, max(a, b)), mat)


def window_casing(prefix: str, axis: str, face: float, inward: float, a: float, b: float, sill: float, head: float) -> None:
    """A painted casing around an interior window opening: two jambs and a head."""
    w = 0.07
    low, high = sorted((face, face + inward * 0.03))
    a, b = min(a, b), max(a, b)
    if axis == "x":
        box(prefix + "JambA", (a - w, sill - 0.04, low), (a, head + w, high), "Trim")
        box(prefix + "JambB", (b, sill - 0.04, low), (b + w, head + w, high), "Trim")
        box(prefix + "Head", (a, head, low), (b, head + w, high), "Trim")
    else:
        box(prefix + "JambA", (low, sill - 0.04, a - w), (high, head + w, a), "Trim")
        box(prefix + "JambB", (low, sill - 0.04, b), (high, head + w, b + w), "Trim")
        box(prefix + "Head", (low, head, a), (high, head + w, b), "Trim")


def build_details() -> None:
    """Layout-independent finishes on the exterior walls, the entrance, and the sealed tower door."""
    t = PERIMETER_THICKNESS
    walls = [
        ("Front", "x", FRONT_Z - t, -1.0, WEST_X, EAST_X, FRONT_OPENINGS),
        ("Back", "x", BACK_Z + t, 1.0, WEST_X, EAST_X, BACK_OPENINGS),
        ("West", "z", WEST_X + t, 1.0, BACK_Z, FRONT_Z, []),
        ("East", "z", EAST_X - t, -1.0, BACK_Z, FRONT_Z, EAST_OPENINGS),
    ]
    for label, axis, face, inward, start, end, openings in walls:
        # Two-tone paint: darker lower wall, a trim rail, and dark rubber skirting.
        band_along(f"Wainscot{label}", axis, face, inward, start, end, openings, FLOOR_Y, WAINSCOT_Y, "WallLower", 0.004)
        band_along(f"ChairRail{label}", axis, face, inward, start, end, openings, WAINSCOT_Y - 0.02, WAINSCOT_Y + 0.04, "Trim", 0.025)
        band_along(f"Skirting{label}", axis, face, inward, start, end, openings, FLOOR_Y, FLOOR_Y + 0.1, "Baseboard", 0.012)
        for index, (a, b, sill, head) in enumerate(openings):
            if sill > FLOOR_Y + 0.01:
                window_casing(f"Casing{label}{index}", axis, face, inward, a, b, sill, head)

    # Main entrance: aluminium frame, one sliding leaf jammed half open, the other shattered.
    face = FRONT_Z - t
    x0, x1 = ENTRANCE
    head = 2.40
    box("EntranceJambWest", (x0, FLOOR_Y, face - 0.12), (x0 + 0.08, head, face + 0.12), "DoorFrame")
    box("EntranceJambEast", (x1 - 0.08, FLOOR_Y, face - 0.12), (x1, head, face + 0.12), "DoorFrame")
    box("EntranceHeader", (x0, head - 0.1, face - 0.12), (x1, head, face + 0.12), "DoorFrame")
    box("EntranceTrack", (x0, FLOOR_Y, face - 0.04), (x1, FLOOR_Y + 0.015, face + 0.04), "DoorFrame")
    leaf = (x1 - x0 - 0.16) / 2.0
    # West leaf jammed half open; the part beyond the jamb is hidden in the wall pocket.
    a = x0 + 0.08 - leaf * 0.5
    b = a + leaf
    box("JammedLeafTop", (a, head - 0.18, face + 0.03), (b, head - 0.1, face + 0.07), "DoorFrame")
    box("JammedLeafBottom", (a, FLOOR_Y + 0.02, face + 0.03), (b, FLOOR_Y + 0.12, face + 0.07), "DoorFrame")
    box("JammedLeafStileA", (a, FLOOR_Y + 0.02, face + 0.03), (a + 0.05, head - 0.1, face + 0.07), "DoorFrame")
    box("JammedLeafStileB", (b - 0.05, FLOOR_Y + 0.02, face + 0.03), (b, head - 0.1, face + 0.07), "DoorFrame")
    box("JammedLeafGlass", (a + 0.05, FLOOR_Y + 0.12, face + 0.045), (b - 0.05, head - 0.18, face + 0.055), "DoorGlass")
    # East leaf torn off its track and lying flat on the floor inside, glass gone (a 5 cm step).
    fallen = Kit("EntranceLeafEast_Fallen")
    fallen.box((-0.78, 0.0, -1.225), (0.78, 0.05, -1.145), "DoorFrame")
    fallen.box((-0.78, 0.0, 1.145), (0.78, 0.05, 1.225), "DoorFrame")
    fallen.box((-0.78, 0.0, -1.225), (-0.70, 0.05, 1.225), "DoorFrame")
    fallen.box((0.70, 0.0, -1.225), (0.78, 0.05, 1.225), "DoorFrame")
    fallen.build(-9.32, -1.85, 8.0)
    # Tempered-glass crumbs and a muddy mat just inside the doorway.
    shards = Kit("EntranceGlassShards")
    for index in range(26):
        sx = -0.95 + (index * 0.37) % 1.9
        sz = -0.8 + (index * 0.53) % 1.6
        size = 0.02 + (index % 3) * 0.012
        shards.box((sx, 0.0, sz), (sx + size, 0.008, sz + size * 0.8), "DoorGlass")
    shards.box((-0.75, 0.0, -0.45), (0.75, 0.012, 0.45), "Rubber")
    shards.build(-9.75, -1.33)
    # Lit EXIT sign above the entrance, inside.
    mid = (x0 + x1) / 2.0
    box("ExitSignHousing", (mid - 0.2, head + 0.12, face - 0.08), (mid + 0.2, head + 0.32, face), "ExitHousing")
    box("ExitSignFace", (mid - 0.17, head + 0.15, face - 0.085), (mid + 0.17, head + 0.29, face - 0.08), "ExitGlow")

    # The building's real glass door under the tower, boarded up from inside by the shelter.
    d0, d1 = TOWER_DOOR
    inner = FRONT_Z - t
    boards = [(0.35, 0.0), (0.85, 0.0), (1.35, 0.0), (0.6, 22.0), (1.15, -18.0)]
    for index, (y, tilt) in enumerate(boards):
        board = box(f"TowerDoorBoard{index}", (d0 - 0.25, y - 0.1, inner - 0.05), (d1 + 0.25, y + 0.1, inner - 0.02), "Plywood")
        if tilt:
            # Rotate the board in place around its centre (game Z axis -> Blender local Z).
            board.data.transform(_rotation_about((mid_of(d0, d1), y, inner - 0.035), tilt))
    box("TowerDoorSprayNote", (mid_of(d0, d1) - 0.5, 1.55, inner - 0.055), (mid_of(d0, d1) + 0.5, 1.75, inner - 0.05), "SprayPaint")


def mid_of(a: float, b: float) -> float:
    return (a + b) / 2.0


def _rotation_about(center: tuple, degrees: float):
    """Matrix rotating mesh data (authored in game coordinates) about the game Z axis through center."""
    from mathutils import Matrix
    to_origin = Matrix.Translation((-center[0], -center[1], -center[2]))
    back = Matrix.Translation(center)
    return back @ Matrix.Rotation(radians(degrees), 4, "Z") @ to_origin


class Kit:
    """Accumulates boxes and cylinders (local game metres, base at y=0, front facing +Z)
    into one mesh object, placed on the floor with a yaw about the vertical axis."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.verts: list = []
        self.faces: list = []
        self.face_materials: list = []
        self.materials: list = []

    def _material_index(self, mat: str) -> int:
        if mat not in self.materials:
            self.materials.append(mat)
        return self.materials.index(mat)

    def box(self, low: tuple, high: tuple, mat: str) -> "Kit":
        x0, y0, z0 = low
        x1, y1, z1 = high
        base = len(self.verts)
        self.verts += [
            (x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
            (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1),
        ]
        index = self._material_index(mat)
        for face in [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]:
            self.faces.append(tuple(base + i for i in face))
            self.face_materials.append(index)
        return self

    def cylinder(self, center: tuple, radius: float, length: float, mat: str, axis: str = "y", segments: int = 12) -> "Kit":
        """A capped cylinder centred on `center`, running along `axis`."""
        from math import cos, sin, pi
        cx, cy, cz = center
        base = len(self.verts)
        for end in (-0.5, 0.5):
            for step in range(segments):
                angle = 2.0 * pi * step / segments
                u, v = radius * cos(angle), radius * sin(angle)
                along = end * length
                if axis == "y":
                    self.verts.append((cx + u, cy + along, cz + v))
                elif axis == "x":
                    self.verts.append((cx + along, cy + u, cz + v))
                else:
                    self.verts.append((cx + u, cy + v, cz + along))
        index = self._material_index(mat)
        for step in range(segments):
            a, b = step, (step + 1) % segments
            self.faces.append((base + a, base + b, base + segments + b, base + segments + a))
            self.face_materials.append(index)
        self.faces.append(tuple(base + s for s in reversed(range(segments))))
        self.face_materials.append(index)
        self.faces.append(tuple(base + segments + s for s in range(segments)))
        self.face_materials.append(index)
        return self

    def build(self, x: float, z: float, yaw: float = 0.0, y: float = FLOOR_Y,
              pitch: float = 0.0, roll: float = 0.0) -> bpy.types.Object:
        """Place the kit: roll about local Z, then pitch about local X, then yaw about Y."""
        from mathutils import Matrix
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata(self.verts, [], self.faces)
        for mat in self.materials:
            mesh.materials.append(material(mat))
        for polygon, index in zip(mesh.polygons, self.face_materials):
            polygon.material_index = index
        mesh.transform(Matrix.Translation((x, y, z)) @ Matrix.Rotation(radians(yaw), 4, "Y")
                       @ Matrix.Rotation(radians(pitch), 4, "X") @ Matrix.Rotation(radians(roll), 4, "Z"))
        mesh.update()
        obj = bpy.data.objects.new(self.name, mesh)
        interior_collection().objects.link(obj)
        obj.parent = interior_root()
        return obj


def text_label(name: str, words: str, x: float, y: float, z: float, yaw: float = 0.0, size: float = 0.12,
               mat: str = "SignWhite") -> bpy.types.Object:
    """Flat text facing +Z (rotated by yaw), exported to glTF as a mesh."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = words
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.002
    curve.resolution_u = 3  # glyph outlines stay legible at a fraction of the default triangles
    curve.materials.append(material(mat))
    obj = bpy.data.objects.new(name, curve)
    interior_collection().objects.link(obj)
    obj.parent = interior_root()
    obj.location = (x, y, z)
    obj.rotation_euler = (0.0, radians(yaw), 0.0)
    return obj


def kit_text(name: str, words: str, x: float, z: float, yaw: float, y: float, local: tuple, size: float = 0.05,
             mat: str = "SignWhite", turn: float = 0.0) -> bpy.types.Object:
    """Text at a kit-local point (lx, ly, lz) of a prop placed at (x, y, z) with yaw, facing the
    prop's +Z (plus `turn` degrees, e.g. 90 for its +X side)."""
    from mathutils import Matrix, Vector
    offset = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector(local)
    return text_label(name, words, x + offset.x, y + offset.y, z + offset.z, yaw + turn, size=size, mat=mat)


# --- Furniture kit. Each returns the placed object; front faces +Z before yaw. ---

def reception_counter(name: str, x: float, z: float, yaw: float = 0.0, length: float = 3.6, depth: float = 0.8) -> bpy.types.Object:
    h, d = length / 2.0, depth / 2.0
    kit = Kit(name)
    kit.box((-h, 0.1, d - 0.05), (h, 1.08, d), "Laminate")                       # visitor-side panel
    kit.box((-h, 0.0, d - 0.04), (h, 0.1, d - 0.01), "Baseboard")                 # kick plate
    kit.box((-h - 0.03, 1.08, d - 0.18), (h + 0.03, 1.12, d + 0.12), "Countertop")  # transaction ledge
    kit.box((-h, 0.0, -d), (-h + 0.05, 1.08, d), "Laminate")                      # end returns
    kit.box((h - 0.05, 0.0, -d), (h, 1.08, d), "Laminate")
    kit.box((-h + 0.05, 0.72, -d), (h - 0.05, 0.76, d - 0.05), "Countertop")      # staff desk surface
    kit.box((-h + 0.08, 0.0, -d + 0.05), (-h + 0.55, 0.72, d - 0.08), "Laminate") # drawer pedestal
    return kit.build(x, z, yaw)


def waiting_chairs(name: str, x: float, z: float, yaw: float = 0.0, seats: int = 4) -> bpy.types.Object:
    pitch = 0.58
    width = seats * pitch
    kit = Kit(name)
    kit.box((-width / 2.0, 0.3, -0.05), (width / 2.0, 0.34, 0.05), "Chrome")       # beam
    for leg in (-width / 2.0 + 0.1, width / 2.0 - 0.1):
        kit.box((leg - 0.03, 0.0, -0.25), (leg + 0.03, 0.3, 0.25), "Chrome")
    for seat in range(seats):
        left = -width / 2.0 + seat * pitch + 0.04
        kit.box((left, 0.38, -0.22), (left + pitch - 0.08, 0.45, 0.22), "Vinyl")    # seat pan
        kit.box((left, 0.45, -0.26), (left + pitch - 0.08, 0.86, -0.2), "Vinyl")   # back
        kit.box((left - 0.035, 0.34, -0.2), (left - 0.005, 0.62, 0.18), "Chrome")  # arm
    return kit.build(x, z, yaw)


def shelter_cot(name: str, x: float, z: float, yaw: float = 0.0, made: bool = True) -> bpy.types.Object:
    kit = Kit(name)
    kit.box((-0.95, 0.34, -0.36), (0.95, 0.4, 0.36), "Canvas")
    for side in (-0.37, 0.33):
        kit.box((-0.97, 0.36, side), (0.97, 0.41, side + 0.04), "ShelfSteel")       # side rails
    for end in (-0.8, 0.0, 0.8):
        kit.box((end - 0.02, 0.0, -0.36), (end + 0.02, 0.36, -0.32), "ShelfSteel")
        kit.box((end - 0.02, 0.0, 0.32), (end + 0.02, 0.36, 0.36), "ShelfSteel")
    if made:
        kit.box((-0.95, 0.4, -0.34), (0.35, 0.47, 0.34), "Blanket")                 # rumpled blanket
        kit.box((0.6, 0.4, -0.22), (0.9, 0.5, 0.22), "Linen")                       # pillow
    return kit.build(x, z, yaw)


def wheelchair(name: str, x: float, z: float, yaw: float = 0.0) -> bpy.types.Object:
    return wheelchair_kit(name).build(x, z, yaw)


def wheelchair_kit(name: str) -> "Kit":
    """Wheelchair geometry (occupant faces local -Z), unplaced."""
    kit = Kit(name)
    for side in (-0.29, 0.29):
        kit.cylinder((side, 0.3, 0.05), 0.3, 0.03, "Rubber", axis="x", segments=16)  # rear wheels
        kit.cylinder((side * 0.8, 0.08, -0.38), 0.08, 0.03, "Rubber", axis="x", segments=10)  # casters
        kit.box((side - 0.015, 0.08, -0.4), (side + 0.015, 0.95, 0.1), "Chrome")      # side frame
    kit.box((-0.26, 0.46, -0.25), (0.26, 0.5, 0.18), "Vinyl")                       # seat
    kit.box((-0.26, 0.5, 0.14), (0.26, 0.92, 0.18), "Vinyl")                        # back
    kit.box((-0.2, 0.12, -0.5), (0.2, 0.15, -0.38), "Chrome")                       # footplate
    kit.box((-0.3, 0.92, 0.12), (0.3, 0.95, 0.2), "Rubber")                         # push handles
    return kit


def iv_stand(name: str, x: float, z: float, yaw: float = 0.0, bag: bool = True) -> bpy.types.Object:
    kit = Kit(name)
    kit.box((-0.3, 0.02, -0.025), (0.3, 0.06, 0.025), "Chrome")
    kit.box((-0.025, 0.02, -0.3), (0.025, 0.06, 0.3), "Chrome")
    kit.cylinder((0.0, 1.0, 0.0), 0.015, 1.9, "Chrome", segments=8)
    kit.box((-0.18, 1.92, -0.01), (0.18, 1.94, 0.01), "Chrome")                     # hook bar
    if bag:
        kit.box((0.08, 1.62, -0.02), (0.2, 1.88, 0.03), "Linen")                    # saline bag
        kit.box((0.135, 0.9, -0.004), (0.145, 1.62, 0.004), "Linen")                # line
    return kit.build(x, z, yaw)


def gurney(name: str, x: float, z: float, yaw: float = 0.0) -> bpy.types.Object:
    kit = Kit(name)
    kit.box((-1.0, 0.7, -0.33), (1.0, 0.76, 0.33), "Chrome")                        # deck
    kit.box((-0.98, 0.76, -0.31), (0.98, 0.86, 0.31), "Linen")                      # pad
    for lx in (-0.85, 0.85):
        for lz in (-0.28, 0.28):
            kit.box((lx - 0.02, 0.1, lz - 0.02), (lx + 0.02, 0.7, lz + 0.02), "Chrome")
            kit.cylinder((lx, 0.06, lz), 0.06, 0.04, "Rubber", axis="z", segments=10)
    for rz in (-0.36, 0.33):
        kit.box((-0.6, 0.86, rz), (0.6, 0.9, rz + 0.03), "Chrome")                  # side rails
    return kit.build(x, z, yaw)


def privacy_curtain(name: str, x: float, z: float, yaw: float = 0.0, length: float = 2.4, drawn: float = 0.7) -> bpy.types.Object:
    """Ceiling track along local X with a pleated curtain covering `drawn` of it."""
    kit = Kit(name)
    track_y = CEILING_Y - FLOOR_Y - 0.06
    kit.box((-length / 2.0, track_y, -0.02), (length / 2.0, track_y + 0.03, 0.02), "Chrome")
    pleat = 0.12
    span = length * drawn
    pos = -length / 2.0
    flip = 1.0
    while pos < -length / 2.0 + span - 0.01:
        kit.box((pos, 0.25, -0.03 * flip - 0.008), (pos + pleat, track_y, -0.03 * flip + 0.008), "Curtain")
        pos += pleat
        flip = -flip
    return kit.build(x, z, yaw)


def vending_machine(name: str, x: float, z: float, yaw: float = 0.0, lit: bool = False) -> bpy.types.Object:
    kit = Kit(name)
    kit.box((-0.45, 0.0, -0.4), (0.45, 1.85, 0.38), "VendingBody")
    kit.box((-0.38, 0.55, 0.38), (0.12, 1.72, 0.4), "VendingWindow")
    kit.box((0.18, 0.95, 0.38), (0.4, 1.5, 0.41), "VendingLit" if lit else "PanelDead")   # selection panel
    kit.box((-0.38, 0.12, 0.38), (0.12, 0.4, 0.405), "Rubber")                      # pickup flap
    return kit.build(x, z, yaw)


def notice_board(name: str, x: float, z: float, yaw: float = 0.0, wall_y: float = 1.1) -> bpy.types.Object:
    """Wall-mounted: its back sits at local z=0, so place it on the wall face."""
    kit = Kit(name)
    kit.box((-0.6, wall_y, 0.0), (0.6, wall_y + 0.9, 0.025), "Cork")
    kit.box((-0.63, wall_y - 0.03, 0.0), (0.63, wall_y, 0.035), "Wood")
    kit.box((-0.63, wall_y + 0.9, 0.0), (0.63, wall_y + 0.93, 0.035), "Wood")
    notes = [(-0.45, 0.55, 0.18, 0.24), (-0.18, 0.62, 0.21, 0.28), (0.12, 0.5, 0.2, 0.26),
             (0.38, 0.6, 0.16, 0.22), (-0.3, 0.12, 0.25, 0.3), (0.2, 0.1, 0.22, 0.3)]
    for nx, ny, nw, nh in notes:
        kit.box((nx, wall_y + ny, 0.025), (nx + nw, wall_y + ny + nh, 0.03), "Paper")
    return kit.build(x, z, yaw, y=FLOOR_Y)


def ceiling_panel(name: str, x: float, z: float, yaw: float = 0.0, lit: bool = False) -> bpy.types.Object:
    """2 x 4 ft troffer set into the drop ceiling."""
    kit = Kit(name)
    top = CEILING_Y - FLOOR_Y
    kit.box((-0.3, top - 0.03, -0.6), (0.3, top, 0.6), "Trim")
    kit.box((-0.26, top - 0.035, -0.56), (0.26, top - 0.03, 0.56), "PanelLit" if lit else "PanelDead")
    return kit.build(x, z, yaw)


def filing_cabinet(name: str, x: float, z: float, yaw: float = 0.0, open_drawer: int = -1) -> bpy.types.Object:
    kit = Kit(name)
    kit.box((-0.23, 0.0, -0.31), (0.23, 1.32, 0.31), "FilingGrey")
    for drawer in range(4):
        y0 = 0.04 + drawer * 0.32
        out = 0.35 if drawer == open_drawer else 0.0
        kit.box((-0.21, y0, 0.31 + out - 0.02), (0.21, y0 + 0.29, 0.33 + out), "FilingGrey")
        kit.box((-0.07, y0 + 0.2, 0.33 + out), (0.07, y0 + 0.23, 0.36 + out), "Chrome")
        if out:
            kit.box((-0.19, y0 + 0.05, 0.05), (0.19, y0 + 0.27, 0.31 + out - 0.02), "Paper")
    return kit.build(x, z, yaw)


def office_desk(name: str, x: float, z: float, yaw: float = 0.0, width: float = 1.6, depth: float = 0.8) -> bpy.types.Object:
    w, d = width / 2.0, depth / 2.0
    kit = Kit(name)
    kit.box((-w, 0.72, -d), (w, 0.76, d), "Wood")
    kit.box((-w, 0.0, -d), (-w + 0.04, 0.72, d), "Wood")
    kit.box((w - 0.45, 0.0, -d), (w, 0.72, d), "Wood")                               # drawer pedestal
    kit.box((-w + 0.04, 0.35, -d), (w - 0.45, 0.72, -d + 0.03), "Wood")             # modesty panel
    return kit.build(x, z, yaw)


def shelving_unit(name: str, x: float, z: float, yaw: float = 0.0, width: float = 1.2, depth: float = 0.45) -> bpy.types.Object:
    w, d = width / 2.0, depth / 2.0
    kit = Kit(name)
    for px in (-w, w - 0.03):
        for pz in (-d, d - 0.03):
            kit.box((px, 0.0, pz), (px + 0.03, 1.85, pz + 0.03), "ShelfSteel")
    for level in (0.12, 0.55, 0.98, 1.41, 1.82):
        kit.box((-w, level, -d), (w, level + 0.03, d), "ShelfSteel")
    return kit.build(x, z, yaw)


def double_door(name: str, x: float, z: float, yaw: float = 0.0, width: float = 1.6, swing: float = 70.0) -> bpy.types.Object:
    """Frame centred on local x=0 in a wall along local X; both leaves swung `swing` degrees toward +Z."""
    from mathutils import Matrix, Vector
    kit = Kit(name)
    h = 2.1
    half = width / 2.0
    kit.box((-half - 0.06, 0.0, -0.1), (-half, h + 0.06, 0.1), "DoorFrame")
    kit.box((half, 0.0, -0.1), (half + 0.06, h + 0.06, 0.1), "DoorFrame")
    kit.box((-half, h, -0.1), (half, h + 0.06, 0.1), "DoorFrame")
    leaf, thickness = half - 0.01, 0.045
    # Each leaf is modelled hinge-at-origin along +X. A yaw of -swing turns +X toward +Z for the
    # left leaf; 180 + swing points the right leaf back along -X and also toward +Z.
    for suffix, hinge_x, leaf_yaw in (("LeafL", -half, -swing), ("LeafR", half, 180.0 + swing)):
        leaf_kit = Kit(name + suffix)
        leaf_kit.box((0.0, 0.01, -thickness / 2.0), (leaf, h - 0.01, thickness / 2.0), "DoorPaint")
        leaf_kit.box((leaf * 0.25, 1.3, -thickness / 2.0 - 0.002), (leaf * 0.75, 1.8, thickness / 2.0 + 0.002), "DoorGlass")
        hinge = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((hinge_x, 0.0, 0.1))
        leaf_kit.build(x + hinge.x, z + hinge.z, yaw + leaf_yaw)
    return kit.build(x, z, yaw)


def wall_sign(name: str, words: str, x: float, y: float, z: float, yaw: float = 0.0, width: float = 0.9) -> bpy.types.Object:
    """Blue plate with white text; its back sits at local z=0 so it mounts on a wall face."""
    kit = Kit(name + "Plate")
    kit.box((-width / 2.0, -0.11, 0.0), (width / 2.0, 0.11, 0.02), "SignBlue")
    plate = kit.build(x, z, yaw, y=y)
    from mathutils import Matrix, Vector
    offset = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((0.0, 0.0, 0.023))
    text_label(name + "Text", words, x + offset.x, y, z + offset.z, yaw, size=0.1)
    return plate


def load_layout():
    """Import (fresh) the layout data module from tools/blender/hospital_layout."""
    import sys
    path = str(LAYOUT_DIR)
    if path not in sys.path:
        sys.path.insert(0, path)
    for module in ("layout", "markers"):
        sys.modules.pop(module, None)
    import layout
    return layout


CORRIDOR_MID_Z = -4.15


def wall_runs(wall: dict) -> tuple:
    """(axis, fixed coordinate, start, end, direction) for an axis-aligned wall."""
    if abs(wall["z1"] - wall["z2"]) < 1e-6:
        return "x", wall["z1"], wall["x1"], wall["x2"], 1.0 if wall["x2"] >= wall["x1"] else -1.0
    return "z", wall["x1"], wall["z1"], wall["z2"], 1.0 if wall["z2"] >= wall["z1"] else -1.0


def opening_spans(wall: dict) -> list:
    """Openings as (a, b, sill_y, head_y, opening) along the wall's running axis."""
    _axis, _fixed, start, _end, direction = wall_runs(wall)
    spans = []
    for opening in wall["openings"]:
        centre = start + direction * opening["center_along"]
        half = opening["width"] / 2.0
        sill = FLOOR_Y if opening["kind"] == "door" else opening["sill"]
        spans.append((centre - half, centre + half, sill, opening["head"], opening))
    return spans


def door_casing(prefix: str, axis: str, face: float, outward: float, a: float, b: float, head: float) -> None:
    """Architrave on one wall face around a door opening."""
    w = 0.06
    low, high = sorted((face, face + outward * 0.025))
    if axis == "x":
        box(prefix + "JambA", (a - w, FLOOR_Y, low), (a, head + w, high), "Trim")
        box(prefix + "JambB", (b, FLOOR_Y, low), (b + w, head + w, high), "Trim")
        box(prefix + "Head", (a, head, low), (b, head + w, high), "Trim")
    else:
        box(prefix + "JambA", (low, FLOOR_Y, a - w), (high, head + w, a), "Trim")
        box(prefix + "JambB", (low, FLOOR_Y, b), (high, head + w, b + w), "Trim")
        box(prefix + "Head", (low, head, a), (high, head + w, b), "Trim")


def door_leaf_flat(name: str, axis: str, face: float, outward: float, hinge: float, extend: float, head: float) -> None:
    """A door leaf swung 90 degrees to lie flat against the wall face, from `hinge` along `extend`.
    Skipped when less than 0.2 m of wall is available to rest against."""
    if abs(extend) < 0.2:
        return
    a, b = sorted((hinge, hinge + extend))
    low, high = sorted((face + outward * 0.05, face + outward * 0.095))
    glass_a, glass_b = a + (b - a) * 0.3, a + (b - a) * 0.7
    free = hinge + extend
    lever = sorted((free - math_copysign(0.2, extend), free - math_copysign(0.07, extend)))
    if axis == "x":
        box(name, (a, FLOOR_Y + 0.01, low), (b, head - 0.01, high), "DoorPaint")
        box(name + "Vision", (glass_a, 1.3, low - 0.002), (glass_b, 1.8, high + 0.002), "DoorGlass")
        box(name + "Kick", (a + 0.03, FLOOR_Y + 0.04, low - 0.002), (b - 0.03, FLOOR_Y + 0.28, high + 0.002), "Chrome")
        box(name + "Lever", (lever[0], 1.0, low - 0.04), (lever[1], 1.03, high + 0.04), "Chrome")
    else:
        box(name, (low, FLOOR_Y + 0.01, a), (high, head - 0.01, b), "DoorPaint")
        box(name + "Vision", (low - 0.002, 1.3, glass_a), (high + 0.002, 1.8, glass_b), "DoorGlass")
        box(name + "Kick", (low - 0.002, FLOOR_Y + 0.04, a + 0.03), (high + 0.002, FLOOR_Y + 0.28, b - 0.03), "Chrome")
        box(name + "Lever", (low - 0.04, 1.0, lever[0]), (high + 0.04, 1.03, lever[1]), "Chrome")


def build_partition(wall: dict) -> None:
    axis, fixed, start, end, _direction = wall_runs(wall)
    t = wall["thickness"]
    lo_run, hi_run = min(start, end), max(start, end)
    spans = opening_spans(wall)
    wall_with_openings(wall["id"], axis, fixed - t / 2.0, fixed + t / 2.0, lo_run, hi_run,
                       [(a, b, sill, head) for a, b, sill, head, _o in spans])
    plain = [(a, b, sill, head) for a, b, sill, head, _o in spans]
    for side in (-1.0, 1.0):
        face = fixed + side * t / 2.0
        tag = f"{wall['id']}{'N' if side > 0 else 'S'}"
        band_along(f"Wainscot{tag}", axis, face, side, lo_run, hi_run, plain, FLOOR_Y, WAINSCOT_Y, "WallLower", 0.004)
        band_along(f"ChairRail{tag}", axis, face, side, lo_run, hi_run, plain, WAINSCOT_Y - 0.02, WAINSCOT_Y + 0.04, "Trim", 0.025)
        band_along(f"Skirting{tag}", axis, face, side, lo_run, hi_run, plain, FLOOR_Y, FLOOR_Y + 0.1, "Baseboard", 0.012)
    # Leaves swing into the room, away from the corridor (or toward +X/+Z between two rooms).
    room_side = (-1.0 if fixed < CORRIDOR_MID_Z else 1.0) if axis == "x" else 1.0
    for index, (a, b, sill, head, opening) in enumerate(spans):
        if opening["kind"] == "window":
            continue
        if opening["kind"] == "pass_through":
            ledge_low, ledge_high = fixed - t / 2.0 - 0.12, fixed + t / 2.0 + 0.12
            if axis == "x":
                box(f"{wall['id']}PassLedge{index}", (a, sill - 0.04, ledge_low), (b, sill, ledge_high), "Countertop")
            else:
                box(f"{wall['id']}PassLedge{index}", (ledge_low, sill - 0.04, a), (ledge_high, sill, b), "Countertop")
            continue
        for side in (-1.0, 1.0):
            door_casing(f"{wall['id']}Casing{index}{'N' if side > 0 else 'S'}", axis, fixed + side * t / 2.0, side, a, b, head)
        if opening["door_state"] == "locked_blocked":
            # Closed leaf filling the opening; story barricades are added as furniture.
            if axis == "x":
                box(f"{wall['id']}ClosedLeaf{index}", (a, FLOOR_Y + 0.01, fixed - 0.025), (b, head - 0.01, fixed + 0.025), "DoorPaint")
            else:
                box(f"{wall['id']}ClosedLeaf{index}", (fixed - 0.025, FLOOR_Y + 0.01, a), (fixed + 0.025, head - 0.01, b), "DoorPaint")
            continue
        if opening["door_state"] == "missing":
            continue
        face = fixed + room_side * t / 2.0
        width = b - a
        # Never let a swung leaf run past the end of its wall.
        room_before = max(0.0, a - lo_run - 0.05)
        room_after = max(0.0, hi_run - b - 0.05)
        if width >= 1.5:
            leaf = width / 2.0 - 0.02
            door_leaf_flat(f"{wall['id']}Leaf{index}A", axis, face, room_side, a, -min(leaf, room_before), head)
            door_leaf_flat(f"{wall['id']}Leaf{index}B", axis, face, room_side, b, min(leaf, room_after), head)
        else:
            leaf = width - 0.04
            if room_before >= room_after:
                door_leaf_flat(f"{wall['id']}Leaf{index}", axis, face, room_side, a, -min(leaf, room_before), head)
            else:
                door_leaf_flat(f"{wall['id']}Leaf{index}", axis, face, room_side, b, min(leaf, room_after), head)


def build_partitions() -> None:
    """Room partitions from the layout; the measured shell supplies the perimeter."""
    layout = load_layout()
    for wall in layout.walls:
        if not wall["id"].startswith("P_"):
            build_partition(wall)


# ---------------------------------------------------------------------------
# Layout furniture. Objects use the layout's convention: footprint size [w, h, d]
# along local X/Y/Z before yaw, centred on (x, z), base at y, Godot-style yaw.
# ---------------------------------------------------------------------------

def quoted(notes: str) -> list:
    """Sign texts quoted in a layout note, e.g. 'STAFF LOUNGE'."""
    import re
    # A quote mark only opens or closes when it is not inside a word, so DON'T stays whole.
    found = re.findall(r"(?<![A-Za-z0-9])'(.+?)'(?![A-Za-z0-9])", notes)
    return [text.strip() for text in found if len(text.strip()) >= 2]


def wrap(words: str, width_m: float, size: float) -> str:
    """Wrap text to fit width_m at the given glyph size (about 0.6 em per character)."""
    limit = max(6, int(width_m / (size * 0.62)))
    lines, line = [], ""
    for word in words.replace(" / ", " \n ").split(" "):
        if word == "\n":
            lines.append(line.strip())
            line = ""
        elif len(line) + len(word) + 1 > limit and line:
            lines.append(line.strip())
            line = word
        else:
            line += " " + word
    lines.append(line.strip())
    return "\n".join(part for part in lines if part)


def room_at(layout, x: float, z: float):
    for room in layout.rooms:
        if room["x_min"] - 0.3 <= x <= room["x_max"] + 0.3 and room["z_min"] - 0.3 <= z <= room["z_max"] + 0.3:
            return room
    return None


def face_yaw(layout, o: dict) -> float:
    """Yaw that turns a wall-mounted panel's +Z face toward its room (thin axis from the size)."""
    w, _h, d = o["size"]
    room = room_at(layout, o["x"], o["z"])
    cx = (room["x_min"] + room["x_max"]) / 2.0 if room else 0.0
    cz = (room["z_min"] + room["z_max"]) / 2.0 if room else -4.8
    if w <= d:
        return 90.0 if cx >= o["x"] else -90.0
    return 0.0 if cz >= o["z"] else 180.0


def panel_object(layout, o: dict, board: str, words: str = "", ink: str = "Rubber", double_sided: bool = False):
    """A flat wall panel or hanging sign of the layout size, with optional text."""
    w, h, d = o["size"]
    width, thick = (d, w) if w <= d else (w, d)
    yaw = face_yaw(layout, o) if not double_sided else (90.0 if w <= d else 0.0)
    kit = Kit(o["name"]).box((-width / 2.0, 0.0, -thick / 2.0), (width / 2.0, h, thick / 2.0), board)
    obj = kit.build(o["x"], o["z"], yaw, y=o["y"])
    if words:
        size = min(0.11, h / max(2.5, words.count("\n") + 2.2))
        from mathutils import Matrix, Vector
        for side, extra in ((1.0, 0.0), (-1.0, 180.0)) if double_sided else ((1.0, 0.0),):
            offset = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((0.0, 0.0, side * (thick / 2.0 + 0.003)))
            text_label(o["name"] + ("Text" if side > 0 else "TextBack"), words, o["x"] + offset.x, o["y"] + h / 2.0,
                       o["z"] + offset.z, yaw + extra, size=size, mat=ink)
    return obj


def fb_counter(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    if "Reception" in o["name"]:
        desk = 0.75
        kit.box((-hw, 0.1, hd - 0.05), (hw, h - 0.04, hd), "Laminate")
        kit.box((-hw, 0.0, hd - 0.04), (hw, 0.1, hd - 0.01), "Baseboard")
        kit.box((-hw - 0.03, h - 0.04, hd - 0.3), (hw + 0.03, h, hd + 0.05), "Countertop")
        kit.box((-hw, 0.0, -hd), (-hw + 0.05, h - 0.04, hd), "Laminate")
        kit.box((hw - 0.05, 0.0, -hd), (hw, h - 0.04, hd), "Laminate")
        kit.box((-hw + 0.05, desk - 0.04, -hd), (hw - 0.05, desk, hd - 0.05), "Countertop")
        kit.box((-hw + 0.08, 0.0, -hd + 0.05), (-hw + 0.5, desk - 0.04, hd - 0.1), "Laminate")
        obj = kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
        text_label(o["name"] + "Lettering", "REGISTRATION", o["x"], o["y"] + 0.75, o["z"] + hd + 0.004, 0.0, size=0.11, mat="SignBlue")
        return obj
    if "Kitchenette" in o["name"]:
        kit.box((-hw, 0.08, -hd), (hw, h - 0.04, hd - 0.02), "Laminate")
        kit.box((-hw, 0.0, -hd), (hw, 0.08, hd - 0.06), "Baseboard")
        kit.box((-hw - 0.02, h - 0.04, -hd - 0.02), (hw + 0.02, h, hd + 0.02), "Countertop")
        kit.box((-0.25, h - 0.045, -0.2), (0.25, h + 0.004, 0.15), "Chrome")          # sink
        kit.box((hw - 0.55, h, -hd + 0.05), (hw - 0.1, h + 0.28, hd - 0.12), "Appliance")  # microwave
        kit.box((-hw + 0.15, h, -0.1), (-hw + 0.4, h + 0.32, 0.12), "Rubber")          # coffee maker
        for door in range(int(o["size"][0] // 0.6)):
            dx = -hw + 0.02 + door * 0.6
            kit.box((dx, 0.12, hd - 0.02), (dx + 0.56, h - 0.08, hd), "DoorPaint")
        return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
    # Nurse-station style solid counter with a worktop (its equipment is dressing).
    kit.box((-hw, 0.0, -hd), (hw, h - 0.04, hd), "Laminate")
    kit.box((-hw - 0.02, h - 0.04, -hd - 0.02), (hw + 0.02, h, hd + 0.02), "Countertop")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_cot(layout, o, index: int = 0):
    unmade = index % 3 == 1
    shelter_cot(o["name"], o["x"], o["z"], o["rotation_deg"] + (90.0 if o["size"][2] > o["size"][0] else 0.0), made=not unmade)


def fb_wheelchair(layout, o):
    if "Tipped" in o["name"]:
        kit = wheelchair_kit(o["name"])
        return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"] + 0.3, roll=90.0)
    return wheelchair_kit(o["name"]).build(o["x"], o["z"], o["rotation_deg"] + 180.0, y=o["y"])


def fb_privacy_screen(layout, o):
    w, h, d = o["size"]
    along_z = d >= w
    length = d if along_z else w
    kit = Kit(o["name"])
    panels = 3
    pw = length / panels
    for i in range(panels):
        a = -length / 2.0 + i * pw
        off = 0.1 if i % 2 == 0 else -0.1
        kit.box((off - 0.02, 0.0, a), (off + 0.02, h, a + 0.03), "Chrome")
        kit.box((off - 0.02, 0.0, a + pw - 0.03), (off + 0.02, h, a + pw), "Chrome")
        kit.box((off - 0.008, 0.15, a + 0.03), (off + 0.008, h - 0.05, a + pw - 0.03), "Curtain")
    return kit.build(o["x"], o["z"], o["rotation_deg"] + (0.0 if along_z else 90.0), y=o["y"])


def fb_folding_table(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, h - 0.03, -hd), (hw, h, hd), "Laminate")
    for lx in (-hw + 0.05, hw - 0.08):
        for lz in (-hd + 0.05, hd - 0.08):
            kit.box((lx, 0.0, lz), (lx + 0.03, h - 0.03, lz + 0.03), "ShelfSteel")
    if "Water" in o["name"]:
        for i, lz in enumerate((-hd + 0.25, -hd + 0.55)):
            kit.cylinder((-hw + 0.2, h + 0.18, lz), 0.11, 0.36, "DoorGlass", segments=10)   # water jugs
        kit.box((0.05, h, -0.1), (0.3, h + 0.12, 0.15), "Cardboard")                       # toiletries box
        kit.box((-0.05, h, 0.25), (0.1, h + 0.25, 0.4), "Rubber")                           # lantern body
        kit.box((-0.03, h + 0.05, 0.27), (0.08, h + 0.2, 0.38), "LampGlow")                 # lantern glow
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


SHELF_TOPS = (0.22, 0.62, 1.02, 1.42, 1.82)


def fb_shelving(layout, o):
    w, h, d = o["size"]
    hw, hd = w / 2.0, d / 2.0
    top = o["y"] + h
    kit = Kit(o["name"])
    posts = [-hw, hw - 0.03] + ([-0.015] if w > 1.6 else [])
    for px in posts:
        for pz in (-hd, hd - 0.03):
            kit.box((px, 0.0, pz), (px + 0.03, h, pz + 0.03), "ShelfSteel")
    levels = [t for t in SHELF_TOPS if t < top - 0.05] + [top]
    if d > 0.7:
        kit.box((-hw, 0.1, -0.01), (hw, h, 0.01), "ShelfSteel")                           # gondola spine
    # Spots kept clear for pickups and documents resting on these shelves.
    from mathutils import Matrix, Vector
    to_local = Matrix.Rotation(radians(-o["rotation_deg"]), 4, "Y")
    reserved = []
    for marker in layout.markers:
        local = to_local @ Vector((marker["x"] - o["x"], 0.0, marker["z"] - o["z"]))
        if abs(local.x) < hw + 0.1 and abs(local.z) < hd + 0.1:
            reserved.append((local.x, marker["y"]))
    for li, level in enumerate(levels):
        y = level - o["y"]
        kit.box((-hw, y - 0.03, -hd), (hw, y, hd), "ShelfSteel")
        if level >= top - 0.01 or li % 2 == 1 and "Island" in o["name"]:
            continue
        x = -hw + 0.08
        step = 0
        while x < hw - 0.3:
            size = 0.18 + (step % 3) * 0.06
            clear = all(abs(x + size / 2.0 - rx) > 0.32 or abs(level - ry) > 0.15 for rx, ry in reserved)
            if clear and step % 4 != 2:
                mat = "Linen" if "Linen" in o["name"] else "Cardboard"
                kit.box((x, y, -hd + 0.06), (x + size, y + min(0.32, 0.12 + (step % 2) * 0.1), hd - 0.06), mat)
            x += size + 0.08
            step += 1
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_fridge(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, 0.0, -hd), (hw, h, hd - 0.04), "Appliance")
    lit = "Lounge" in o["name"]
    kit.box((-hw + 0.04, 0.1, hd - 0.1), (hw - 0.04, h - 0.1, hd - 0.04), "FridgeLight" if lit else "Plenum")
    obj = kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
    from mathutils import Matrix, Vector
    hinge = Matrix.Rotation(radians(o["rotation_deg"]), 4, "Y") @ Vector((-hw, 0.0, hd))
    door = Kit(o["name"] + "Door").box((0.0, 0.0, 0.0), (o["size"][0], h - 0.02, 0.05), "DoorGlass" if "Medicine" in o["name"] else "Appliance")
    door.build(o["x"] + hinge.x, o["z"] + hinge.z, o["rotation_deg"] - 35.0, y=o["y"] + 0.01)
    return obj


def fb_desk(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, h - 0.04, -hd), (hw, h, hd), "Wood" if "Records" in o["name"] else "FilingGrey")
    kit.box((-hw, 0.0, -hd), (-hw + 0.04, h - 0.04, hd), "FilingGrey")
    kit.box((hw - 0.42, 0.0, -hd), (hw, h - 0.04, hd), "FilingGrey")
    kit.box((-hw + 0.04, 0.32, -hd), (hw - 0.42, h - 0.04, -hd + 0.03), "FilingGrey")
    if "Office" in o["name"]:
        kit.box((-hw + 0.15, h, -hd + 0.1), (-hw + 0.55, h + 0.16, -hd + 0.38), "Rubber")   # radio
        kit.box((0.05, h, -0.1), (0.38, h + 0.04, 0.15), "BookBlue")                        # logbook
        kit.cylinder((0.5, h + 0.05, 0.15), 0.04, 0.1, "Appliance", segments=8)            # mug
    if "Records" in o["name"]:
        kit.box((-hw + 0.1, h, -hd + 0.15), (-hw + 0.45, h + 0.12, hd - 0.15), "Paper")    # paper piles
        kit.box((hw - 0.3, h, -hd + 0.08), (hw - 0.22, h + 0.32, -hd + 0.16), "Chrome")    # lamp stem
        kit.box((hw - 0.42, h + 0.3, -hd + 0.05), (hw - 0.1, h + 0.38, -hd + 0.25), "BookGreen")  # green shade
        kit.box((hw - 0.38, h + 0.28, -hd + 0.08), (hw - 0.14, h + 0.3, -hd + 0.22), "LampGlow")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_filing(layout, o):
    count = max(1, round(o["size"][0] / 0.47))
    from mathutils import Matrix, Vector
    for i in range(count):
        offset = Matrix.Rotation(radians(o["rotation_deg"]), 4, "Y") @ Vector(((i - (count - 1) / 2.0) * 0.47, 0.0, 0.0))
        filing_cabinet(f"{o['name']}_{i + 1}", o["x"] + offset.x, o["z"] + offset.z, o["rotation_deg"], open_drawer=3 if i == 0 else -1)


def fb_notice(layout, o):
    obj = panel_object(layout, o, "Cork")
    w, h, d = o["size"]
    width = d if w <= d else w
    yaw = face_yaw(layout, o)
    kit = Kit(o["name"] + "Notes")
    thick = min(w, d)
    for i in range(int(width // 0.28)):
        nx = -width / 2.0 + 0.08 + i * 0.28
        ny = 0.12 + (i % 2) * 0.38
        kit.box((nx, ny, thick / 2.0), (nx + 0.2, ny + 0.27, thick / 2.0 + 0.004), "Paper")
    kit.build(o["x"], o["z"], yaw, y=o["y"])
    texts = quoted(o["notes"])
    if texts and ("IT DOESN'T" in o["notes"] or "EVAC" in o["notes"] or "YOU ARE HERE" in o["notes"]):
        from mathutils import Matrix, Vector
        offset = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((0.0, 0.0, thick / 2.0 + 0.008))
        text_label(o["name"] + "Text", wrap(texts[-1], width * 0.8, 0.05), o["x"] + offset.x, o["y"] + h * 0.75,
                   o["z"] + offset.z, yaw, size=0.05, mat="Rubber")
    return obj


def fb_sign(layout, o):
    texts = quoted(o["notes"])
    words = "\n".join(texts) if texts else o["name"]
    w, h, d = o["size"]
    width = d if w <= d else w
    if o["kind"] == "whiteboard":
        return panel_object(layout, o, "Appliance", wrap(words, width * 0.9, 0.06), ink="Rubber")
    if o["kind"] == "sign_wall":
        return panel_object(layout, o, "SignBlue", wrap(words, width * 0.9, 0.07), ink="SignWhite")
    banner = "banner" in o["notes"].lower() or "bedsheet" in o["notes"].lower()
    board, ink = ("Linen", "SprayPaint") if banner else ("SignBlue", "SignWhite")
    obj = panel_object(layout, o, board, wrap(words, width * 0.92, 0.09), ink=ink, double_sided=True)
    if o["kind"] == "sign_hanging":
        # Cords up to the ceiling grid.
        top = o["y"] + h
        for side in (-0.4, 0.4):
            from mathutils import Matrix, Vector
            yaw = 90.0 if w <= d else 0.0
            p = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((side * width, 0.0, 0.0))
            Kit(o["name"] + "Cord").box((-0.004, 0.0, -0.004), (0.004, CEILING_Y - top, 0.004), "Rubber").build(
                o["x"] + p.x, o["z"] + p.z, 0.0, y=top)
    return obj


def fb_decal(layout, o):
    w, h, d = o["size"]
    width = d if w <= d else w
    yaw = face_yaw(layout, o)
    kit = Kit(o["name"])
    colors = ["Paper", "Paper", "Paper"]
    for i in range(5):
        nx = -width / 2.0 + i * width / 5.0 + 0.02
        ny = (i % 2) * 0.3
        kit.box((nx, ny, 0.0), (nx + width / 5.0 - 0.04, ny + 0.32, 0.003), colors[i % 3])
        kit.box((nx + 0.04, ny + 0.06, 0.003), (nx + 0.12, ny + 0.2, 0.005), ["SprayPaint", "SignBlue", "Canvas", "Rubber", "BookGreen"][i])
    kit.build(o["x"], o["z"], yaw, y=o["y"])
    from mathutils import Matrix, Vector
    offset = Matrix.Rotation(radians(yaw), 4, "Y") @ Vector((0.0, 0.0, 0.006))
    text_label(o["name"] + "Text", "WE ARE SAFE HERE", o["x"] + offset.x, o["y"] + 0.62, o["z"] + offset.z, yaw, size=0.05, mat="SignBlue")


def fb_wall_cabinet(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"]).box((-hw, 0.0, -hd), (hw, h, hd - 0.02), "FilingGrey" if "Med" in o["name"] else "Laminate")
    obj = kit.build(o["x"], o["z"], o["rotation_deg"] if o["size"][0] > o["size"][2] else face_yaw(layout, o), y=o["y"])
    return obj


def fb_barricade(layout, o):
    name = o["name"]
    if "Window" in name:
        w, h, d = o["size"]
        kit = Kit(name)
        for i in range(3):
            y0 = i * (h / 3.0) + 0.02
            kit.box((-w / 2.0, y0, -d / 2.0), (w / 2.0, y0 + h / 3.0 - 0.05, d / 2.0), "Plywood")
        return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
    if "Isolation" in name:
        kit = Kit(name)
        for i, (y, tilt) in enumerate(((0.5, 0.0), (1.05, 12.0), (1.6, -10.0))):
            kit.box((-0.65, y - 0.08, 0.0), (0.65, y + 0.08, 0.03), "Plywood")
        obj = kit.build(o["x"], -5.15, 0.0, y=FLOOR_Y)
        chair = Kit(name + "Chair")
        chair.box((-0.22, 0.42, -0.2), (0.22, 0.46, 0.2), "Wood")
        for lx in (-0.2, 0.17):
            for lz in (-0.18, 0.15):
                chair.box((lx, 0.0, lz), (lx + 0.03, 0.42, lz + 0.03), "Wood")
        chair.box((-0.22, 0.46, -0.2), (0.22, 0.85, -0.17), "Wood")
        chair.build(o["x"] + 0.1, -4.75, 180.0, y=FLOOR_Y, pitch=18.0)
        text_label(name + "Spray", "DON'T ANSWER IT", o["x"], 1.35, -5.11, 0.0, size=0.13, mat="SprayPaint")
        return obj
    # Main door barricade: a pile in front of the boarded glass doors.
    kit = Kit(name)
    kit.box((-1.25, 0.0, -0.1), (-0.35, 1.9, 0.08), "Mattress")                          # leaning mattress
    kit.box((0.35, 0.0, -0.15), (1.25, 1.85, 0.05), "Mattress")
    kit.box((-1.3, 0.0, -0.55), (-0.5, 0.45, -0.15), "Chrome")                           # gurney on its side
    kit.box((-1.3, 0.45, -0.5), (-0.5, 0.5, -0.2), "Linen")
    for i in range(4):
        kit.box((0.55, i * 0.12, -0.6), (1.0, i * 0.12 + 0.08, -0.15), "Vinyl")          # stacked chairs
    obj = kit.build(o["x"], o["z"] - 0.1, o["rotation_deg"], y=o["y"])
    return obj


def fb_curtain(layout, o):
    w, h, d = o["size"]
    if "Blanket" in o["name"]:
        return Kit(o["name"]).box((-w / 2.0, 0.0, -d / 2.0), (w / 2.0, h, d / 2.0), "Blanket").build(
            o["x"], o["z"], o["rotation_deg"], y=o["y"], roll=3.0)
    if "Bunched" in o["name"]:
        kit = Kit(o["name"])
        for i in range(4):
            kit.box((-0.1 + i * 0.05, 0.0, -0.12 + (i % 2) * 0.05), (-0.05 + i * 0.05, h, 0.12), "Curtain")
        return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
    along_z = d >= w
    length = d if along_z else w
    kit = Kit(o["name"])
    pleat, pos, flip = 0.12, -length / 2.0, 1.0
    while pos < length / 2.0 - 0.01:
        kit.box((-0.03 * flip - 0.008, 0.0, pos), (-0.03 * flip + 0.008, h, pos + pleat), "Curtain")
        pos += pleat
        flip = -flip
    return kit.build(o["x"], o["z"], o["rotation_deg"] + (0.0 if along_z else 90.0), y=o["y"])


def fb_tracks(layout, o):
    y = o["y"]
    kit = Kit(o["name"])
    x0, x1 = o["x"] - o["size"][0] / 2.0, o["x"] + o["size"][0] / 2.0
    z_front = o["z"] + o["size"][2] / 2.0
    z_back = o["z"] - o["size"][2] / 2.0
    kit.box((x0, 0.0, z_front - 0.015), (x1, 0.03, z_front + 0.015), "Chrome")
    for divider in (x0 + (x1 - x0) / 3.0, x0 + 2.0 * (x1 - x0) / 3.0):
        kit.box((divider - 0.015, 0.0, z_back), (divider + 0.015, 0.03, z_front), "Chrome")
    for x in (x0, (x0 + x1) / 2.0, x1):
        kit.box((x - 0.008, 0.03, z_front - 0.008), (x + 0.008, CEILING_Y - y, z_front + 0.008), "Chrome")
    return kit.build(0.0, 0.0, 0.0, y=y)


def fb_clutter(layout, o):
    w, h, d = o["size"]
    kit = Kit(o["name"])
    mats = ["Canvas", "Cardboard", "BookBlue", "Blanket", "BookRed"]
    pieces = 4 if w * d > 0.2 else 3
    for i in range(pieces):
        px = -w / 2.0 + (i % 2) * w / 2.0
        pz = -d / 2.0 + (i // 2) * d / 2.0
        ph = h * (0.45 + 0.15 * (i % 3))
        kit.box((px + 0.02, 0.0, pz + 0.02), (px + w / 2.0 - 0.02, ph, pz + d / 2.0 - 0.02), mats[i % len(mats)])
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_debris(layout, o):
    if "Glass" in o["name"]:
        return None
    w, _h, d = o["size"]
    kit = Kit(o["name"])
    for i in range(14):
        px = -w / 2.0 + (i * 0.41) % w
        pz = -d / 2.0 + (i * 0.29) % d
        kit.box((px, 0.0, pz), (px + 0.21, 0.004 + i * 0.0003, pz + 0.29), "Paper")
    return kit.build(o["x"], o["z"], 0.0, y=o["y"])


def fb_cart(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    for lx in (-hw, hw - 0.03):
        for lz in (-hd, hd - 0.03):
            kit.box((lx, 0.08, lz), (lx + 0.03, h, lz + 0.03), "Chrome")
            kit.cylinder((lx + 0.015, 0.04, lz + 0.015), 0.04, 0.03, "Rubber", axis="x", segments=8)
    kit.box((-hw + 0.03, 0.25, -hd + 0.03), (hw - 0.03, h - 0.05, hd - 0.03), "Canvas")
    kit.box((-hw + 0.08, h - 0.08, -hd + 0.08), (hw - 0.08, h + 0.05, hd - 0.08), "Linen")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_ceiling_tile(layout, o):
    w, _h, d = o["size"]
    kit = Kit(o["name"]).box((-w / 2.0, -0.01, 0.0), (w / 2.0, 0.0, d), "Ceiling")
    tile = kit.build(o["x"], o["z"] + d / 2.0, 0.0, y=CEILING_Y - 0.01, pitch=-38.0)
    Kit(o["name"] + "Cable").box((-0.006, 0.0, -0.006), (0.006, 0.45, 0.006), "Rubber").build(o["x"] + 0.15, o["z"] - 0.1, 0.0, y=CEILING_Y - 0.45)
    return tile


def fb_blind(layout, o):
    w, h, d = o["size"]
    along_z = d >= w
    length = d if along_z else w
    kit = Kit(o["name"])
    y = 0.0
    index = 0
    while y < h:
        if index % 7 != 4:
            kit.box((-0.03, y, -length / 2.0), (0.03, y + 0.012, length / 2.0), "Trim")
        y += 0.055
        index += 1
    kit.box((-0.04, h, -length / 2.0), (0.04, h + 0.05, length / 2.0), "Trim")
    return kit.build(o["x"], o["z"], o["rotation_deg"] + (0.0 if along_z else 90.0), y=o["y"])


def fb_sink(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    if o["y"] > FLOOR_Y + 0.1:
        kit.box((-hw, 0.0, -hd), (hw, 0.25, hd), "Appliance")                          # wall-hung basin
        basin_top = 0.25
    else:
        kit.box((-hw, 0.0, -hd), (hw, 0.86, hd), "Laminate")                           # base cabinet
        kit.box((-hw - 0.01, 0.86, -hd - 0.01), (hw + 0.01, 0.9, hd + 0.01), "Countertop")
        basin_top = 0.9
    kit.box((-hw + 0.08, basin_top - 0.12, -hd + 0.08), (hw - 0.08, basin_top + 0.002, hd - 0.05), "Chrome")
    kit.box((-0.02, basin_top, -hd + 0.03), (0.02, basin_top + 0.25, -hd + 0.07), "Chrome")   # faucet
    kit.box((-hw + 0.03, basin_top + 0.35, -hd), (hw - 0.03, h, -hd + 0.015), "DoorGlass")    # mirror
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_rail(layout, o):
    """Corridor handrail: a timber rail with a vinyl bumper strip, on chrome brackets, ends returned to the wall."""
    h, d = o["size"][1], o["size"][2]
    segments = o.get("segments") or [(o["x"] - o["size"][0] / 2.0, o["x"] + o["size"][0] / 2.0)]
    toward_wall = 1.0 if o["z"] > CORRIDOR_MID_Z else -1.0
    face = o["z"] + toward_wall * d / 2.0
    gap = face - toward_wall * 0.025                     # rail stands 25 mm off the wall
    rail = sorted((gap, face - toward_wall * d))
    strip = sorted((face - toward_wall * d, face - toward_wall * (d + 0.004)))
    brackets = sorted((face, gap))
    kit = Kit(o["name"])
    for a, b in segments:
        kit.box((a + 0.03, 0.015, rail[0]), (b - 0.03, h - 0.015, rail[1]), "Wood")
        kit.box((a + 0.03, 0.05, strip[0]), (b - 0.03, 0.09, strip[1]), "Vinyl")
        for end in (a, b - 0.03):
            kit.box((end, 0.015, min(brackets[0], rail[0])), (end + 0.03, h - 0.015, max(brackets[1], rail[1])), "Wood")
        count = max(1, round((b - a) / 1.1))
        for i in range(count + 1):
            bx = a + 0.25 + (b - a - 0.5) * i / count
            kit.box((bx - 0.02, 0.04, brackets[0]), (bx + 0.02, 0.1, brackets[1]), "Chrome")
    return kit.build(0.0, 0.0, 0.0, y=o["y"])


def fb_armchair(layout, o):
    kit = Kit(o["name"])
    kit.box((-0.38, 0.0, -0.36), (0.38, 0.42, 0.36), "Vinyl")
    kit.box((-0.38, 0.42, -0.4), (0.38, 0.95, -0.24), "Vinyl")
    for side in (-0.38, 0.3):
        kit.box((side, 0.42, -0.36), (side + 0.08, 0.62, 0.36), "Vinyl")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_sofa(layout, o):
    hw = o["size"][0] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, 0.0, -0.4), (hw, 0.42, 0.4), "Vinyl")
    kit.box((-hw, 0.42, -0.42), (hw, 0.85, -0.25), "Vinyl")
    for side in (-hw, hw - 0.12):
        kit.box((side, 0.42, -0.4), (side + 0.12, 0.62, 0.4), "Vinyl")
    kit.box((-hw + 0.2, 0.42, -0.2), (-hw + 0.75, 0.48, 0.3), "Blanket")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_tv(layout, o):
    kit = Kit(o["name"])
    kit.box((-0.45, 0.08, -0.28), (0.45, 0.7, 0.28), "ShelfSteel")
    kit.box((-0.38, 0.7, -0.3), (0.38, 1.25, 0.25), "Rubber")
    kit.box((-0.32, 0.76, 0.25), (0.32, 1.19, 0.26), "TVStatic")
    for lx in (-0.42, 0.39):
        for lz in (-0.25, 0.22):
            kit.cylinder((lx, 0.04, lz), 0.04, 0.03, "Rubber", axis="x", segments=8)
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_piano(layout, o):
    hw = o["size"][0] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, 0.0, -0.3), (hw, 1.25, 0.05), "Wood")
    kit.box((-hw, 0.62, 0.05), (hw, 0.72, 0.3), "Wood")
    kit.box((-hw + 0.08, 0.72, 0.05), (hw - 0.08, 0.75, 0.25), "Appliance")            # keys
    kit.box((-hw, 1.25, -0.3), (hw, 1.28, -0.05), "Wood")
    kit.box((-0.2, 0.9, 0.04), (0.2, 1.15, 0.06), "Paper")                              # sheet music
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_bookcase(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"])
    kit.box((-hw, 0.0, -hd), (hw, h, -hd + 0.02), "Wood")
    for side in (-hw, hw - 0.02):
        kit.box((side, 0.0, -hd), (side + 0.02, h, hd), "Wood")
    mats = ["BookRed", "BookBlue", "BookGreen", "Paper", "Cardboard"]
    for level in range(5):
        y = 0.05 + level * h / 5.0
        kit.box((-hw, y - 0.02, -hd), (hw, y, hd), "Wood")
        x = -hw + 0.03
        i = 0
        while x < hw - 0.06 and level < 4:
            bw = 0.03 + (i % 3) * 0.015
            kit.box((x, y, -hd + 0.03), (x + bw, y + 0.18 + (i % 2) * 0.05, hd - 0.03), mats[(i + level) % 5])
            x += bw + 0.004
            i += 1
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_small_cabinet(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"]).box((-hw, 0.0, -hd), (hw, h, hd), "Laminate")
    kit.box((-hw + 0.03, h - 0.3, hd), (hw - 0.03, h - 0.05, hd + 0.01), "DoorPaint")
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_coat_rack(layout, o):
    kit = Kit(o["name"])
    kit.cylinder((0.0, 0.03, 0.0), 0.2, 0.06, "Wood", segments=10)
    kit.cylinder((0.0, 0.9, 0.0), 0.02, 1.75, "Wood", segments=8)
    kit.box((-0.18, 1.1, -0.12), (0.12, 1.72, 0.1), "Canvas")                            # raincoat
    kit.box((0.05, 1.4, 0.0), (0.12, 1.7, 0.18), "BookRed")                              # scarf
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_table(layout, o):
    r = o["size"][0] / 2.0
    h = o["size"][1]
    kit = Kit(o["name"])
    kit.cylinder((0.0, h - 0.02, 0.0), r, 0.04, "Laminate", segments=16)
    kit.cylinder((0.0, (h - 0.04) / 2.0, 0.0), 0.04, h - 0.04, "Chrome", segments=8)
    kit.cylinder((0.0, 0.01, 0.0), 0.25, 0.02, "Chrome", segments=12)
    kit.box((-0.15, h, -0.1), (0.1, h + 0.04, 0.12), "Appliance")                          # plate
    kit.box((0.12, h, 0.05), (0.3, h + 0.01, 0.2), "Paper")                               # playing cards
    return kit.build(o["x"], o["z"], o["rotation_deg"], y=o["y"])


def fb_fountain(layout, o):
    hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
    kit = Kit(o["name"]).box((-hw, 0.0, -hd), (hw, h * 0.6, hd), "Chrome")
    kit.box((-hw + 0.05, h * 0.6 - 0.05, -hd + 0.05), (hw - 0.05, h * 0.6 + 0.002, hd - 0.05), "ShelfSteel")
    # Wall-hung: turn its front toward the room like a thin panel along the wall.
    return kit.build(o["x"], o["z"], face_yaw(layout, dict(o, size=[0.45, h, 0.02])), y=o["y"])


def fb_stair_door(layout, o):
    kit = Kit(o["name"] + "Chain")
    for i in range(9):
        kit.box((-0.35 + i * 0.08, 1.0 + (i % 2) * 0.02, 0.03), (-0.29 + i * 0.08, 1.04 + (i % 2) * 0.02, 0.05), "Chrome")
    kit.box((-0.06, 0.88, 0.04), (0.06, 1.0, 0.07), "Chrome")                             # padlock
    kit.build(o["x"], o["z"], 0.0, y=o["y"])
    text_label(o["name"] + "Sign", "STAIR 1\nUPPER FLOORS CLOSED", o["x"], 1.65, o["z"] + 0.06, 0.0, size=0.06, mat="SprayPaint")


def fb_vending(layout, o):
    vending_machine(o["name"], o["x"], o["z"], o["rotation_deg"], lit="lit" in o["notes"])


# Object kinds handled by other stages (shell, details, partitions, ceiling).
SKIP_KINDS = {"floor_slab", "drop_ceiling", "light_fixture_set", "trim_set", "door_frame", "door_frame_set", "door_leaf_set"}


def build_furniture() -> None:
    layout = load_layout()
    cot_index = 0
    handlers = {
        "counter": fb_counter, "privacy_screen": fb_privacy_screen, "folding_table": fb_folding_table,
        "shelving_unit": fb_shelving, "fridge": fb_fridge, "desk": fb_desk, "filing_cabinet": fb_filing,
        "notice_board": fb_notice, "sign_wall": fb_sign, "sign_hanging": fb_sign, "sign_projecting": fb_sign,
        "whiteboard": fb_sign, "wall_decal": fb_decal, "wall_cabinet": fb_wall_cabinet, "barricade": fb_barricade,
        "curtain": fb_curtain, "curtain_track": fb_tracks, "clutter": fb_clutter, "debris": fb_debris,
        "cart": fb_cart, "ceiling_tile": fb_ceiling_tile, "blind": fb_blind, "sink_unit": fb_sink,
        "bumper_rail": fb_rail, "armchair": fb_armchair, "sofa": fb_sofa, "tv_stand": fb_tv, "piano": fb_piano,
        "bookcase": fb_bookcase, "bedside_cabinet": fb_small_cabinet, "coat_rack": fb_coat_rack, "table": fb_table,
        "water_fountain": fb_fountain, "vending_machine": fb_vending, "wheelchair": fb_wheelchair,
    }
    for o in layout.objects:
        kind = o["kind"]
        if kind in SKIP_KINDS or o["name"].startswith("Entrance") and kind in {"door_leaf", "debris"}:
            continue
        if kind == "cot":
            fb_cot(layout, o, cot_index)
            cot_index += 1
        elif kind == "beam_seating":
            waiting_chairs(o["name"], o["x"], o["z"], o["rotation_deg"], max(1, round(o["size"][0] / 0.55)))
        elif kind == "iv_stand":
            iv_stand(o["name"], o["x"], o["z"], o["rotation_deg"])
        elif kind == "door_leaf" and "Stair" in o["name"]:
            fb_stair_door(layout, o)
        elif kind in handlers:
            handlers[kind](layout, o)
        else:
            hw, h, hd = o["size"][0] / 2.0, o["size"][1], o["size"][2] / 2.0
            Kit(o["name"]).box((-hw, 0.0, -hd), (hw, h, hd), "Laminate").build(o["x"], o["z"], o["rotation_deg"], y=o["y"])
            print("generic box for kind", kind, o["name"])


def build_ceiling() -> None:
    """Drop ceiling with missing tiles, the plenum above, light troffers and emergency fixtures."""
    layout = load_layout()
    holes = getattr(layout, "ceiling_holes", [])
    # Split the slab into strips around the holes.
    xs = sorted({WEST_X, EAST_X} | {h[0] for h in holes} | {h[1] for h in holes})
    for x0, x1 in zip(xs, xs[1:]):
        zs = sorted({BACK_Z, FRONT_Z} | {h[2] for h in holes if h[0] < x1 and h[1] > x0} | {h[3] for h in holes if h[0] < x1 and h[1] > x0})
        for z0, z1 in zip(zs, zs[1:]):
            inside = any(h[0] <= x0 and x1 <= h[1] and h[2] <= z0 and z1 <= h[3] for h in holes)
            if not inside:
                box("Ceiling_Drop", (x0, CEILING_Y, z0), (x1, CEILING_Y + 0.04, z1), "Ceiling")
    x = WEST_X + 0.6
    while x < EAST_X - 0.05:
        box("CeilingGridX", (x - 0.012, CEILING_Y - 0.012, BACK_Z), (x + 0.012, CEILING_Y, FRONT_Z), "CeilingGrid")
        x += 0.6
    z = FRONT_Z - 0.6
    while z > BACK_Z + 0.05:
        box("CeilingGridZ", (WEST_X, CEILING_Y - 0.012, z - 0.012), (EAST_X, CEILING_Y, z + 0.012), "CeilingGrid")
        z -= 0.6
    # Black plenum lid and a few ducts visible through the gaps.
    box("PlenumLid", (WEST_X, SLAB_TOP_Y - 0.05, BACK_Z), (EAST_X, SLAB_TOP_Y, FRONT_Z), "Plenum")
    for x0, x1, z0, z1 in holes:
        box("PlenumDuct", (x0 - 1.0, CEILING_Y + 0.15, (z0 + z1) / 2.0 - 0.2), (x1 + 1.0, CEILING_Y + 0.4, (z0 + z1) / 2.0 + 0.2), "ShelfSteel")

    def in_hole(px: float, pz: float) -> bool:
        return any(h[0] - 0.4 <= px <= h[1] + 0.4 and h[2] - 0.7 <= pz <= h[3] + 0.7 for h in holes)

    lit_spots = [(m["x"], m["z"]) for m in layout.markers if m["type"] in ("light", "light_flicker") and m["y"] > 2.5]
    fixtures = [(fx, getattr(layout, "corridor_fixtures_z", -4.15)) for fx in getattr(layout, "corridor_fixtures_x", [])]
    for room in layout.rooms:
        if "Corridor" in room["name"] or "void" in room["floor_finish"]:
            continue
        nx = max(1, round((room["x_max"] - room["x_min"]) / 2.4))
        nz = max(1, round((room["z_max"] - room["z_min"]) / 2.4))
        for i in range(nx):
            for j in range(nz):
                fixtures.append((room["x_min"] + (i + 0.5) * (room["x_max"] - room["x_min"]) / nx,
                                 room["z_min"] + (j + 0.5) * (room["z_max"] - room["z_min"]) / nz))
    for fx, fz in fixtures:
        if in_hole(fx, fz):
            continue
        lit = any(abs(fx - lx) < 0.9 and abs(fz - lz) < 0.9 for lx, lz in lit_spots)
        ceiling_panel("CeilingPanel", fx, fz, 0.0, lit=lit)
    # Red emergency lights and EXIT signs from the light markers.
    for m in layout.markers:
        if m["type"] != "light_emergency":
            continue
        if abs(m["x"] - (ENTRANCE[0] + ENTRANCE[1]) / 2.0) < 0.6 and m["z"] > -0.8:
            continue  # the entrance EXIT sign is built with the doors
        kit = Kit("Emergency_" + m["name"])
        if "EXIT" in m["params"]:
            kit.box((-0.18, -0.08, -0.04), (0.18, 0.08, 0.04), "ExitHousing")
            kit.box((-0.15, -0.06, 0.04), (0.15, 0.06, 0.045), "ExitGlow")
            kit.box((-0.15, -0.06, -0.045), (0.15, 0.06, -0.04), "ExitGlow")
            yaw = 90.0 if "passage" in m["params"] else 0.0
        else:
            kit.box((-0.12, -0.05, -0.12), (0.12, 0.0, 0.12), "ExitHousing")
            kit.box((-0.09, -0.07, -0.09), (0.09, -0.05, 0.09), "ExitGlow")
            yaw = 0.0
        kit.build(m["x"], m["z"], yaw, y=m["y"])


MARKER_DISPLAY = {
    "hiding_locker": ("CUBE", (0.31, 1.0, 0.3)), "hiding_closet": ("CUBE", (0.58, 1.03, 0.33)),
    "hiding_bed": ("CUBE", (1.04, 0.54, 0.47)), "bottle": ("SPHERE", (0.06, 0.06, 0.06)),
    "document": ("PLAIN_AXES", (0.16, 0.05, 0.12)), "clawman_spawn": ("CONE", (0.4, 0.95, 0.4)),
    "pack_prop": ("CUBE", None), "light": ("SPHERE", (0.12,) * 3), "light_flicker": ("SPHERE", (0.12,) * 3),
    "light_emergency": ("SPHERE", (0.1,) * 3), "moonlight": ("SINGLE_ARROW", (0.5,) * 3),
}


def build_markers() -> None:
    """Empties for everything Godot spawns. Custom properties carry the base transform and
    parameters (exported as glTF extras); the empty's own shape only visualises the footprint."""
    layout = load_layout()
    for m in layout.markers:
        shape, half = MARKER_DISPLAY.get(m["type"], ("PLAIN_AXES", (0.15,) * 3))
        if half is None:
            w, h, d = m.get("foot", (0.4, 0.4, 0.4))
            half = (w / 2.0, h / 2.0, d / 2.0)
        empty = bpy.data.objects.new("MK_" + m["name"], None)
        empty.empty_display_type = shape
        empty.empty_display_size = 1.0
        interior_collection().objects.link(empty)
        empty.parent = interior_root()
        lift = half[1] if shape == "CUBE" or m["type"] == "clawman_spawn" else 0.0
        empty.location = (m["x"], m["y"] + lift, m["z"])
        empty.rotation_euler = (0.0, radians(m["rotation_deg"]), 0.0)
        empty.scale = half
        empty["godot_type"] = m["type"]
        empty["godot_name"] = m["name"]
        empty["base_position"] = [m["x"], m["y"], m["z"]]
        empty["yaw_degrees"] = m["rotation_deg"]
        empty["params"] = m["params"]


def build_showroom() -> None:
    """Preview row of the furniture kit in front of the building (never exported)."""
    z = 4.0
    x = WEST_X
    def nxt(step: float) -> float:
        nonlocal x
        x += step
        return x
    reception_counter("Show_Reception", nxt(2.0), z)
    waiting_chairs("Show_Waiting", nxt(3.2), z)
    shelter_cot("Show_Cot", nxt(2.4), z)
    wheelchair("Show_Wheelchair", nxt(1.8), z)
    iv_stand("Show_IVStand", nxt(1.2), z)
    gurney("Show_Gurney", nxt(1.8), z, yaw=90.0)
    privacy_curtain("Show_Curtain", nxt(2.2), z)
    vending_machine("Show_Vending", nxt(2.2), z)
    notice_board("Show_NoticeBoard", nxt(1.6), z)
    filing_cabinet("Show_Filing", nxt(1.4), z, open_drawer=1)
    office_desk("Show_Desk", nxt(1.6), z)
    shelving_unit("Show_Shelving", nxt(1.8), z)
    double_door("Show_DoubleDoor", nxt(2.2), z)
    ceiling_panel("Show_LightPanel", nxt(1.8), z, lit=True)
    wall_sign("Show_Sign", "RECEPTION", nxt(1.6), 2.2, z)


# ---------------------------------------------------------------------------
# Hospital equipment. Prop builders live in tools/blender/hospital_dressing (see its
# README); placements live in hospital_layout/dressing_*.py.
# ---------------------------------------------------------------------------

DRESSING_DIR = Path(__file__).resolve().parent / "hospital_dressing"


def _load_module(path: Path, name: str):
    import importlib.util
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_dressing_catalog() -> dict:
    """Every prop by key; each module's extra materials are merged into the palette."""
    return _load_module(DRESSING_DIR / "catalog.py", "hospital_dressing_catalog").load(PALETTE, EMISSION, ALPHA)


def local_point(x: float, z: float, yaw: float, lx: float, lz: float) -> tuple:
    """Game (x, z) of the kit-local offset (lx, lz) of a prop placed at (x, z) with yaw."""
    from math import cos, sin
    r = radians(yaw)
    return x + lx * cos(r) + lz * sin(r), z - lx * sin(r) + lz * cos(r)


def dressing_api():
    """What prop builders may use (passed as their first argument, `B`)."""
    from types import SimpleNamespace
    return SimpleNamespace(Kit=Kit, kit_text=kit_text, text_label=text_label, local_point=local_point,
                           FLOOR_Y=FLOOR_Y, CEILING_Y=CEILING_Y)


def load_dressing_entries() -> list:
    """Placements from hospital_layout/dressing_*.py, or only the files named (without .py) in
    the comma-separated HOSPITAL_DRESSING_FILES environment variable."""
    import os
    import sys
    load_layout()  # puts hospital_layout on sys.path for modules that read the layout
    sys.modules.pop("placing", None)
    only = [name for name in os.environ.get("HOSPITAL_DRESSING_FILES", "").split(",") if name]
    entries = []
    for path in sorted(LAYOUT_DIR.glob("dressing_*.py")):
        if only and path.stem not in only:
            continue
        module = _load_module(path, "hospital_" + path.stem)
        entries += [dict(entry, source=path.stem) for entry in module.dressing]
    return entries


def dressing_base_y(spec: dict, entry: dict) -> float:
    if entry.get("y") is not None:
        return entry["y"]
    if spec["mount"] == "ceiling":
        return CEILING_Y - spec["size"][1]
    if spec["mount"] == "wall":
        return spec["y"]
    return FLOOR_Y


def place_dressing(catalog: dict, api, entry: dict) -> list:
    """Build one placement; returns the objects it created. Props without collision get a
    Decor_ name prefix, which Godot skips when it generates the building's collision."""
    spec = catalog[entry["prop"]]
    name = entry["name"] if spec.get("collide", True) else "Decor_" + entry["name"]
    before = set(bpy.data.objects)
    spec["build"](api, name, entry["x"], entry["z"], yaw=entry.get("yaw", 0.0), y=dressing_base_y(spec, entry),
                  **entry.get("opts", {}))
    return [obj for obj in bpy.data.objects if obj not in before]


def build_dressing() -> None:
    catalog = load_dressing_catalog()
    api = dressing_api()
    for entry in load_dressing_entries():
        if entry["prop"] not in catalog:
            print(f"dressing: unknown prop {entry['prop']!r} for {entry['name']} ({entry['source']}), skipped")
            continue
        place_dressing(catalog, api, entry)


# Models Godot spawns at the markers, shown in Blender while editing (never exported).
ASSETS = PROJECT_ROOT / "assets" / "local_licensed"
HIDING_MODELS = {
    "hiding_locker": PROJECT_ROOT / "models" / "props" / "hospital" / "staff_locker.glb",
    "hiding_closet": PROJECT_ROOT / "models" / "props" / "hospital" / "supply_closet.glb",
    "hiding_bed": PROJECT_ROOT / "models" / "props" / "hospital" / "ward_bed.glb",
}
PACK_FOLDERS = {
    "clinic_hospital": ASSETS / "clinic_hospital",
    "clinic_medical": ASSETS / "clinic_medical",
    "furniture_kit": ASSETS / "furniture_kit" / "Models" / "GLTF format",
}


def preview_collection() -> bpy.types.Collection:
    collection = bpy.data.collections.get(PREVIEW_COLLECTION)
    if collection is None:
        collection = bpy.data.collections.new(PREVIEW_COLLECTION)
        bpy.context.scene.collection.children.link(collection)
    return collection


def marker_model(m: dict):
    """(glb path, target height or None for native size) for a marker, or None."""
    import re
    if m["type"] in HIDING_MODELS:
        return HIDING_MODELS[m["type"]], None
    if m["type"] == "bottle":
        return PACK_FOLDERS["clinic_medical"] / "Med_12.glb", 0.22
    if m["type"] != "pack_prop":
        return None
    if "ward_bed.glb" in m["params"]:
        return HIDING_MODELS["hiding_bed"], None
    found = re.search(r"(clinic_hospital|clinic_medical|furniture_kit) (\w+)", m["params"])
    height = re.search(r"target_height (\d+(?:\.\d+)?)", m["params"])
    if found is None:
        return None
    return PACK_FOLDERS[found.group(1)] / (found.group(2) + ".glb"), float(height.group(1)) if height else None


def model_mesh(path: Path, target: float | None, cache: dict) -> bpy.types.Mesh:
    """One merged mesh of a glTF file in game coordinates, scaled like PropSizing.fit_height
    (footprint centred, resting on y=0) when a target height is given."""
    import bmesh
    from mathutils import Matrix
    key = (str(path), target)
    if key in cache:
        return cache[key]
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    imported = [obj for obj in bpy.data.objects if obj not in before]
    merged = bmesh.new()
    materials: list = []
    to_game = Matrix.Rotation(radians(-90.0), 4, "X")  # Blender Z-up -> game Y-up
    for obj in imported:
        if obj.type != "MESH":
            continue
        data = obj.data.copy()
        data.transform(to_game @ obj.matrix_world)
        offset = len(materials)
        materials += [slot.material for slot in obj.material_slots]
        for polygon in data.polygons:
            polygon.material_index += offset
        merged.from_mesh(data)
        bpy.data.meshes.remove(data)
    for obj in imported:
        bpy.data.objects.remove(obj, do_unlink=True)
    mesh = bpy.data.meshes.new("Preview_" + path.stem)
    merged.to_mesh(mesh)
    merged.free()
    for mat in materials:
        mesh.materials.append(mat)
    if target is not None and len(mesh.vertices) > 0:
        xs = [v.co.x for v in mesh.vertices]
        ys = [v.co.y for v in mesh.vertices]
        zs = [v.co.z for v in mesh.vertices]
        scale = target / max(max(ys) - min(ys), 1e-4)
        mesh.transform(Matrix.Scale(scale, 4) @ Matrix.Translation((-(min(xs) + max(xs)) / 2.0, -min(ys), -(min(zs) + max(zs)) / 2.0)))
    cache[key] = mesh
    return mesh


def build_godot_preview() -> None:
    """The lockers, beds, pack props and bottles Godot places at the markers, for editing views."""
    layout = load_layout()
    cache: dict = {}
    collection = preview_collection()
    for m in layout.markers:
        model = marker_model(m)
        if model is None or not model[0].exists():
            continue
        obj = bpy.data.objects.new("GP_" + m["name"], model_mesh(model[0], model[1], cache))
        collection.objects.link(obj)
        obj.parent = interior_root()
        obj.location = (m["x"], m["y"], m["z"])
        obj.rotation_euler = (0.0, radians(m["rotation_deg"]), 0.0)
        obj.hide_select = True


STAGES = {
    "shell": build_shell,
    "details": build_details,
    "partitions": build_partitions,
    "ceiling": build_ceiling,
    "furniture": build_furniture,
    "dressing": build_dressing,
    "markers": build_markers,
    "showroom": build_showroom,
    "preview": build_godot_preview,
}
# Everything that ships. Markers and Godot previews are editing aids: Godot reads the marker
# data from hospital_markers.json (hospital_layout/export_markers.py). The showroom is a preview.
EXPORT_STAGES = ["shell", "details", "partitions", "ceiling", "furniture", "dressing"]
EDIT_STAGES = EXPORT_STAGES + ["markers", "preview"]


def build(stages: list | None = None) -> None:
    """Rebuild the interior from scratch, running the named stages in order."""
    clear_interior()
    interior_root()
    organize_exterior()
    for stage in stages or EXPORT_STAGES:
        STAGES[stage]()
    count = len(interior_collection().objects)
    print(f"HospitalInterior rebuilt: stages={stages or EXPORT_STAGES} objects={count}")


if __name__ == "__main__":
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_PATH))
    build()
    bpy.ops.wm.save_mainfile()
