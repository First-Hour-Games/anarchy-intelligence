"""Build the game over's phone: the tutorial's old telephone with its handset as its own node.

The Sketchfab model (Old telephone by Termi1, CC BY 4.0) is one mesh. This script imports
models/tutorial/old_telephone.glb, scales it from centimetres to metres, and splits it by loose part.
The parts that lie inside the handset's box (the handle across the top and the earpiece and mouthpiece
cups at its ends) become "Handset"; everything else (the cradle and its prongs, the plungers, the
keypad and the coiled cord) becomes "Body". The handset's origin goes at the bottom of its corded cup,
so the game over can rock it on that end while the bell rings and the cord stays attached.

The tutorial's model is not changed. The result is models/tutorial/old_telephone_split.glb, which
only scenes/ui/game_over/phone_game_over.gd uses.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_game_over_phone.py
"""

from pathlib import Path

import bpy
from mathutils import Vector

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT_ROOT / "models" / "tutorial" / "old_telephone.glb"
TARGET = PROJECT_ROOT / "models" / "tutorial" / "old_telephone_split.glb"

# In metres, Blender axes (x along the handset, -y toward the keypad, z up), after the scale: the
# handset lies across the top at the back. Parts reaching outside this box belong to the body: the
# cradle prongs and plungers reach further forward, the cord and its plug further out to the side.
HANDSET_BOX = (Vector((-0.133, 0.046, 0.050)), Vector((0.133, 0.123, 0.131)))
# The handset's corded cup, where it rests and rocks: the left one, with the cord coming out of its end.
CORDED_CUP_X = -0.0945


def inside(obj, box):
    low, high = box
    points = [obj.matrix_world @ vertex.co for vertex in obj.data.vertices]
    return all(low[i] <= min(p[i] for p in points) and max(p[i] for p in points) <= high[i] for i in range(3))


def bounds(objects):
    points = [obj.matrix_world @ vertex.co for obj in objects for vertex in obj.data.vertices]
    return (Vector([min(p[i] for p in points) for i in range(3)]), Vector([max(p[i] for p in points) for i in range(3)]))


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    if len(objects) > 1:
        bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = name
    joined.data.name = name
    return joined


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for obj in [obj for obj in bpy.context.scene.objects if obj.type != "MESH"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    mesh.scale *= 0.01
    mesh.location *= 0.01
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    handset_parts = [obj for obj in parts if inside(obj, HANDSET_BOX)]
    body_parts = [obj for obj in parts if obj not in handset_parts]
    low, high = bounds(handset_parts)
    size = high - low
    # The handle and both cups, about 26 cm end to end: anything else means the box missed.
    if not (0.25 < size.x < 0.27 and 0.06 < size.y < 0.09 and 0.07 < size.z < 0.09):
        raise RuntimeError("Handset parts measure %s m; expected about 0.26 x 0.075 x 0.078." % tuple(round(v, 3) for v in size))
    handset = join(handset_parts, "Handset")
    body = join(body_parts, "Body")
    bpy.context.scene.cursor.location = Vector((CORDED_CUP_X, (low.y + high.y) / 2.0, low.z))
    bpy.ops.object.select_all(action="DESELECT")
    handset.select_set(True)
    bpy.context.view_layer.objects.active = handset
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
    bpy.ops.object.select_all(action="SELECT")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(TARGET), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_materials="EXPORT", export_animations=False,
                              export_cameras=False, export_lights=False)
    print("HANDSET parts %d, size %s, pivot %s" % (len(handset_parts), tuple(round(v, 3) for v in size),
                                                    tuple(round(v, 3) for v in handset.location)))
    print("BODY parts %d" % len(body_parts))
    print("GLB=%s" % TARGET)


if __name__ == "__main__":
    main()
