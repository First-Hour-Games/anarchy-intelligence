"""Build the hospital staff locker, supply closet, and ward bed GLBs used as hiding spots.

Run: blender --background --factory-startup --python tools/blender/build_hospital_hiding_props.py

Each prop is exported with its origin on the floor at the footprint center and
its doors facing Godot +Z (Blender -Y). Doors are separate objects whose origins
sit on their hinge line so Godot can swing them by rotating around Y. The locker
door has open vent slats at the player's 1.65 m eye height; the closet doors
stand 5 cm ajar at the center. The ward bed's long axis is X with 0.4 m of open
space beneath for the under-bed spot. Collision is authored in Godot, not in
these files.
"""

from pathlib import Path

import bpy
from mathutils import Matrix


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = PROJECT_ROOT / "models" / "source" / "hospital_props" / "hospital_hiding_props.blend"
OUTPUT_ROOT = PROJECT_ROOT / "models" / "props" / "hospital"
LOCKER_PATH = OUTPUT_ROOT / "staff_locker.glb"
CLOSET_PATH = OUTPUT_ROOT / "supply_closet.glb"
BED_PATH = OUTPUT_ROOT / "ward_bed.glb"

WALL = 0.02


def clear_scene() -> None:
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for datablocks in (bpy.data.meshes, bpy.data.materials, bpy.data.collections):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def material(name: str, color: tuple[float, float, float], metallic: float, roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.use_nodes = True
    shader = next(node for node in result.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return result


def box(name: str, low: tuple[float, float, float], high: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    """Axis-aligned box spanning low..high in Blender coordinates."""
    x0, y0, z0 = low
    x1, y1, z1 = high
    vertices = [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1),
    ]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def join(name: str, parts: list[bpy.types.Object], origin: tuple[float, float, float] = (0.0, 0.0, 0.0)) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    # Move the origin to the hinge (or floor center) without moving the geometry.
    joined.data.transform(Matrix.Translation((-origin[0], -origin[1], -origin[2])))
    joined.location = origin
    return joined


def cabinet_body(prefix: str, width: float, depth: float, height: float, paint: bpy.types.Material) -> list[bpy.types.Object]:
    """Open-fronted shell: back, sides, top, bottom, plus a base plinth."""
    hw, hd = width / 2.0, depth / 2.0
    return [
        box(prefix + "Back", (-hw, hd - WALL, 0.0), (hw, hd, height), paint),
        box(prefix + "Left", (-hw, -hd, 0.0), (-hw + WALL, hd, height), paint),
        box(prefix + "Right", (hw - WALL, -hd, 0.0), (hw, hd, height), paint),
        box(prefix + "Top", (-hw, -hd, height - WALL), (hw, hd, height), paint),
        box(prefix + "Bottom", (-hw, -hd, 0.06), (hw, hd, 0.06 + WALL), paint),
        box(prefix + "Plinth", (-hw + 0.01, -hd + 0.04, 0.0), (hw - 0.01, hd - 0.01, 0.06), paint),
    ]


def build_locker(paint, vent_dark, handle) -> list[bpy.types.Object]:
    width, depth, height = 0.62, 0.56, 2.0
    hw, hd = width / 2.0, depth / 2.0
    body_parts = cabinet_body("Locker", width, depth, height, paint)
    # Small dark ventilation louvres on the side panels read as a locker silhouette.
    for side in (-1.0, 1.0):
        x = side * (hw + 0.002)
        for index in range(4):
            z = 1.72 + index * 0.05
            body_parts.append(box("LockerSideVent", (min(x, x - side * 0.004), -0.12, z), (max(x, x - side * 0.004), 0.12, z + 0.02), vent_dark))
    body = join("Body", body_parts)

    door_front, door_back = -hd - WALL, -hd
    left, right = -hw + 0.005, hw - 0.005
    vent_low, vent_high = 1.48, 1.80
    vent_left, vent_right = left + 0.08, right - 0.08
    door_parts = [
        box("DoorLower", (left, door_front, 0.065), (right, door_back, vent_low), paint),
        box("DoorUpper", (left, door_front, vent_high), (right, door_back, height - 0.025), paint),
        box("DoorVentLeft", (left, door_front, vent_low), (vent_left, door_back, vent_high), paint),
        box("DoorVentRight", (vent_right, door_front, vent_low), (right, door_back, vent_high), paint),
        box("Handle", (right - 0.09, door_front - 0.03, 0.98), (right - 0.06, door_front, 1.16), handle),
        box("NamePlate", (-0.08, door_front - 0.002, 1.28), (0.08, door_front, 1.33), handle),
    ]
    # Open slats with real gaps so the hidden player can see out at eye height.
    slat, gap = 0.016, 0.034
    z = vent_low + gap
    while z + slat < vent_high - 0.005:
        door_parts.append(box("DoorSlat", (vent_left, door_front + 0.004, z), (vent_right, door_back - 0.004, z + slat), paint))
        z += slat + gap
    # Bottom louvres are decorative insets.
    for index in range(3):
        z = 0.18 + index * 0.05
        door_parts.append(box("DoorLowerVent", (left + 0.12, door_front - 0.003, z), (right - 0.12, door_front, z + 0.02), vent_dark))
    door = join("Door", door_parts, origin=(left, door_back, 0.0))
    return [body, door]


def build_closet(paint, trim, handle) -> list[bpy.types.Object]:
    width, depth, height = 1.12, 0.62, 2.06
    hw, hd = width / 2.0, depth / 2.0
    body_parts = cabinet_body("Closet", width, depth, height, paint)
    body_parts.append(box("ClosetCornice", (-hw - 0.02, -hd - 0.03, height - 0.07), (hw + 0.02, hd, height), trim))
    body = join("Body", body_parts)

    door_front, door_back = -hd - WALL, -hd
    # Doors left slightly ajar so the hidden player can watch through the gap.
    center_gap = 0.05
    leaf_width = hw - 0.005 - center_gap / 2.0
    doors = []
    for side, name in ((-1.0, "DoorLeft"), (1.0, "DoorRight")):
        hinge_x = side * (hw - 0.005)
        inner_x = hinge_x - side * leaf_width
        x0, x1 = min(hinge_x, inner_x), max(hinge_x, inner_x)
        parts = [
            box(name + "Leaf", (x0, door_front, 0.065), (x1, door_back, height - 0.075), paint),
            box(name + "PanelUpper", (x0 + 0.07, door_front - 0.006, 1.12), (x1 - 0.07, door_front, 1.86), trim),
            box(name + "PanelLower", (x0 + 0.07, door_front - 0.006, 0.2), (x1 - 0.07, door_front, 0.98), trim),
            box(name + "Handle", (inner_x + side * 0.045 - 0.012, door_front - 0.03, 0.95), (inner_x + side * 0.045 + 0.012, door_front, 1.2), handle),
        ]
        doors.append(join(name, parts, origin=(hinge_x, door_back, 0.0)))
    return [body] + doors


def build_ward_bed(steel, mattress, blanket, board) -> list[bpy.types.Object]:
    """Steel-framed ward bed, long axis on X, with 0.4 m of open space underneath."""
    half_length, half_width = 1.0, 0.45
    parts = []
    for x in (-half_length + 0.04, half_length - 0.04):
        for y in (-half_width + 0.03, half_width - 0.03):
            parts.append(box("Leg", (x - 0.02, y - 0.02, 0.07), (x + 0.02, y + 0.02, 0.42), steel))
            parts.append(box("Caster", (x - 0.035, y - 0.025, 0.0), (x + 0.035, y + 0.025, 0.07), board))
    for y in (-half_width, half_width - 0.04):
        parts.append(box("SideRail", (-half_length, y, 0.40), (half_length, y + 0.04, 0.45), steel))
    for x in (-half_length, half_length - 0.04):
        parts.append(box("EndRail", (x, -half_width, 0.40), (x + 0.04, half_width, 0.45), steel))
    parts.append(box("Deck", (-half_length + 0.04, -half_width + 0.04, 0.45), (half_length - 0.04, half_width - 0.04, 0.47), steel))
    parts.append(box("Mattress", (-half_length + 0.02, -half_width + 0.02, 0.47), (half_length - 0.02, half_width - 0.02, 0.62), mattress))
    parts.append(box("Pillow", (half_length - 0.32, -0.3, 0.62), (half_length - 0.06, 0.3, 0.7), mattress))
    # Blanket over the foot end, draping a little down both long sides.
    parts.append(box("Blanket", (-half_length, -half_width - 0.01, 0.62), (half_length - 0.38, half_width + 0.01, 0.645), blanket))
    for y0, y1 in ((-half_width - 0.02, -half_width - 0.01), (half_width + 0.01, half_width + 0.02)):
        parts.append(box("BlanketDrape", (-half_length, y0, 0.5), (half_length - 0.38, y1, 0.645), blanket))
    parts.append(box("Headboard", (half_length, -half_width, 0.42), (half_length + 0.04, half_width, 1.05), board))
    parts.append(box("Footboard", (-half_length - 0.04, -half_width, 0.42), (-half_length, half_width, 0.85), board))
    for x in (half_length + 0.005, -half_length - 0.035):
        for y in (-half_width - 0.01, half_width - 0.02):
            parts.append(box("BoardPost", (x, y, 0.07), (x + 0.03, y + 0.03, 1.08 if x > 0 else 0.88), steel))
    return [join("Body", parts)]


def export(objects: list[bpy.types.Object], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_yup=True,
        export_apply=True,
    )


def main() -> None:
    clear_scene()
    locker_paint = material("LockerPaint", (0.32, 0.39, 0.36), 0.35, 0.55)
    vent_dark = material("VentShadow", (0.03, 0.035, 0.035), 0.0, 0.9)
    handle = material("BrushedSteel", (0.62, 0.62, 0.6), 1.0, 0.35)
    closet_paint = material("ClosetPaint", (0.66, 0.64, 0.57), 0.0, 0.7)
    closet_trim = material("ClosetTrim", (0.58, 0.56, 0.5), 0.0, 0.75)

    # Both GLBs use the node names Body/Door*; prefix each prop after export so
    # the shared source file keeps unique names.
    locker = build_locker(locker_paint, vent_dark, handle)
    export(locker, LOCKER_PATH)
    for obj in locker:
        obj.name = "Locker" + obj.name
    closet = build_closet(closet_paint, closet_trim, handle)
    export(closet, CLOSET_PATH)
    for obj in closet:
        obj.name = "Closet" + obj.name
        obj.location.x += 1.5
    bed = build_ward_bed(
        handle,
        material("Mattress", (0.74, 0.76, 0.72), 0.0, 0.85),
        material("Blanket", (0.42, 0.5, 0.55), 0.0, 0.9),
        material("BedBoard", (0.56, 0.6, 0.57), 0.2, 0.6),
    )
    export(bed, BED_PATH)
    for obj in bed:
        obj.name = "Bed" + obj.name
        obj.location.x += 4.0

    SOURCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE_PATH))
    for obj in locker + closet + bed:
        print(f"OBJECT {obj.name} origin={tuple(round(v, 3) for v in obj.location)} faces={len(obj.data.polygons)}")
    print("EXPORTED", LOCKER_PATH, CLOSET_PATH, BED_PATH)


main()
