"""Export models/buildings/hospital/hospital.glb and hospital_markers.json.

blender --background --python tools/blender/prepare_story_hospital.py

Opens models/source/buildings/Hospital_V2.blend (never saved here) and rebuilds the interior
from tools/blender/build_hospital_interior.py. It clips the original exterior's ground floor
open and merges the interior into a few meshes per area of the building:
- GroundFloor_*: floors (collision; the name selects tile footsteps).
- Interior_*: walls and furniture (collision).
- Decor_*: equipment without collision, text, the ceiling grid and light fittings.
Godot (scenes/environment/story_building.gd) adds collision to everything but Decor_* and
spawns hiding spots, bottles, documents, props and lights from hospital_markers.json.
"""

import runpy
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = ROOT / "models" / "buildings" / "hospital" / "hospital.glb"
# Area boundaries along game x (west wing, lobby, tower core, east halves).
AREAS = [("West", -12.6), ("Lobby", -4.2), ("Core", 0.2), ("EastA", 9.0), ("EastB", 99.0)]
# Interior pieces at ceiling height that need no collision.
NO_COLLISION = ("Decor_", "CeilingGrid", "CeilingPanel", "Emergency_")

builder = runpy.run_path(str(ROOT / "tools" / "blender" / "build_hospital_interior.py"), run_name="export")
runpy.run_path(str(ROOT / "tools" / "blender" / "hospital_layout" / "export_markers.py"), run_name="__main__")
bpy.ops.wm.open_mainfile(filepath=str(builder["SOURCE_PATH"]))
builder["build"](builder["EXPORT_STAGES"])


def clip(poly, axis, limit, greater):
    result = []
    for index, current in enumerate(poly):
        previous = poly[index - 1]
        current_in = current[axis] >= limit if greater else current[axis] <= limit
        previous_in = previous[axis] >= limit if greater else previous[axis] <= limit
        if current_in != previous_in:
            weight = (limit - previous[axis]) / (current[axis] - previous[axis])
            result.append(previous.lerp(current, weight))
        if current_in:
            result.append(current)
    return result


def subtract(poly, low, high):
    outside = []
    remainder = poly
    for axis in range(3):
        for limit, greater in [(low[axis], True), (high[axis], False)]:
            if len(remainder) < 3:
                return outside
            piece = clip(remainder, axis, limit, not greater)
            if len(piece) >= 3:
                outside.append(piece)
            remainder = clip(remainder, axis, limit, greater)
    return outside


def clip_exterior() -> None:
    """Cut the entrance opening and the ground-floor volume out of the original shell, without
    Boolean caps on its overlapping joined cubes; the rebuilt interior lines that volume."""
    cuts = [((-19.6, -1, -0.05), (-14.4, 1, 5.2)), ((-33.5, 0.5, 0.15), (29.5, 15.5, 5.65))]
    for obj in list(bpy.data.collections["HospitalExterior"].all_objects):
        if obj.type != "MESH" or obj.name == "RC_concrete":
            continue
        original = obj.data
        original.calc_loop_triangles()
        verts, faces, materials = [], [], []
        inverse = obj.matrix_world.inverted()
        for triangle in original.loop_triangles:
            fragments = [[obj.matrix_world @ original.vertices[index].co for index in triangle.vertices]]
            for low, high in cuts:
                fragments = [part for fragment in fragments for part in subtract(fragment, low, high)]
            for fragment in fragments:
                start = len(verts)
                verts.extend([inverse @ point for point in fragment])
                faces.append(tuple(range(start, len(verts))))
                materials.append(triangle.material_index)
        mesh = bpy.data.meshes.new(original.name + "_playable")
        mesh.from_pydata(verts, [], faces)
        for material in original.materials:
            mesh.materials.append(material)
        for polygon, material_index in zip(mesh.polygons, materials):
            polygon.material_index = material_index
        mesh.update()
        obj.data = mesh


def merge_interior() -> int:
    """Replace the interior objects with one world-space mesh per (class, area)."""
    from mathutils import Vector
    collection = bpy.data.collections[builder["COLLECTION"]]
    root = bpy.data.objects[builder["ROOT_NAME"]]
    to_game = root.matrix_world.inverted()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    groups: dict = {}
    for obj in collection.objects:
        if obj.type not in ("MESH", "FONT"):
            continue
        corners = [to_game @ (obj.matrix_world @ Vector(corner)) for corner in obj.bound_box]
        game_x = sum(c.x for c in corners) / 8.0
        area = next(label for label, limit in AREAS if game_x < limit)
        if obj.name.startswith("GroundFloor"):
            key = "GroundFloor_" + area
        elif obj.type == "FONT" or obj.name.startswith(NO_COLLISION):
            key = "Decor_" + area
        else:
            key = "Interior_" + area
        groups.setdefault(key, []).append(obj)
    for key, members in sorted(groups.items()):
        merged = bmesh.new()
        materials: list = []
        for obj in members:
            data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
            data.transform(obj.matrix_world)
            remap = []
            for material in data.materials:
                if material not in materials:
                    materials.append(material)
                remap.append(materials.index(material))
            for polygon in data.polygons:
                polygon.material_index = remap[polygon.material_index] if remap else 0
            merged.from_mesh(data)
            bpy.data.meshes.remove(data)
        mesh = bpy.data.meshes.new(key)
        merged.to_mesh(mesh)
        merged.free()
        for material in materials:
            mesh.materials.append(material)
        target = bpy.data.objects.new(key, mesh)
        bpy.context.scene.collection.objects.link(target)
    for obj in list(collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    return len(groups)


def show_everything(layer) -> None:
    layer.exclude = False
    layer.hide_viewport = False
    for child in layer.children:
        show_everything(child)


show_everything(bpy.context.view_layer.layer_collection)
for obj in bpy.context.scene.objects:
    obj.hide_viewport = False
    obj.hide_set(False)
clip_exterior()
print("merged interior into", merge_interior(), "meshes")
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_apply=True, use_visible=True)
print("exported", OUTPUT)
