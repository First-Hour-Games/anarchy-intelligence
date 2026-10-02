"""Build the static watching-bear GLB from its pinned no-rig source."""

from pathlib import Path
from math import cos, radians, sin

import bpy
from mathutils import Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "models" / "source" / "watching_bear"
FBX_PATH = SOURCE_ROOT / "vendor" / "Character_Killer_10.fbx"
TEXTURE_PATH = SOURCE_ROOT / "vendor" / "Character_Killer_10.png"
BLEND_PATH = SOURCE_ROOT / "watching_bear.blend"
PREVIEW_PATH = SOURCE_ROOT / "watching_bear_preview.png"
GLB_PATH = PROJECT_ROOT / "models" / "enemies" / "watching_bear" / "watching_bear.glb"
TARGET_HEIGHT = 1.9


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def bounds(obj: bpy.types.Object) -> tuple[Vector, Vector]:
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return (
        Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners))),
        Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners))),
    )


def build_material() -> bpy.types.Material:
    material = bpy.data.materials.new("WatchingBearMaterial")
    material.use_nodes = True
    material.surface_render_method = "DITHERED"
    nodes = material.node_tree.nodes
    links = material.node_tree.links
    principled = nodes.get("Principled BSDF")
    image_node = nodes.new("ShaderNodeTexImage")
    image_node.name = "BearPixelTexture"
    image_node.image = bpy.data.images.load(str(TEXTURE_PATH), check_existing=True)
    image_node.interpolation = "Closest"
    links.new(image_node.outputs["Color"], principled.inputs["Base Color"])
    links.new(image_node.outputs["Alpha"], principled.inputs["Alpha"])
    principled.inputs["Roughness"].default_value = 0.88
    principled.inputs["Metallic"].default_value = 0.0
    return material


def build_solid_material(name: str, color: tuple[float, float, float, float]) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    principled.inputs["Roughness"].default_value = 0.95
    principled.inputs["Metallic"].default_value = 0.0
    return material


def _rotated_arm_vertex(co: Vector, side: float) -> Vector:
    """Lower an A-pose arm toward the body around an approximate shoulder."""
    side_x = side * co.x
    if side_x <= 0.18 or co.z <= 0.58 or co.z >= 1.62:
        return co.copy()
    influence = min(max((side_x - 0.18) / 0.18, 0.0), 1.0)
    angle = radians(24.0) * side * influence
    pivot = Vector((side * 0.23, co.y, 1.48))
    relative = co - pivot
    rotated = Vector((
        cos(angle) * relative.x + sin(angle) * relative.z,
        relative.y,
        -sin(angle) * relative.x + cos(angle) * relative.z,
    ))
    return pivot + rotated


def lower_arms_and_add_paws(bear: bpy.types.Object) -> bpy.types.Object:
    hand_indices: dict[float, list[int]] = {-1.0: [], 1.0: []}
    for vertex in bear.data.vertices:
        for side in (-1.0, 1.0):
            if side * vertex.co.x > 0.58 and 0.52 < vertex.co.z < 1.12:
                hand_indices[side].append(vertex.index)
        side = 1.0 if vertex.co.x >= 0.0 else -1.0
        vertex.co = _rotated_arm_vertex(vertex.co, side)
    bear.data.update()

    paw_material = build_solid_material("BearPawFur", (0.16, 0.075, 0.028, 1.0))
    pad_material = build_solid_material("BearPawPad", (0.035, 0.018, 0.012, 1.0))
    paw_parts: list[bpy.types.Object] = []
    for side in (-1.0, 1.0):
        indices = hand_indices[side]
        if not indices:
            raise RuntimeError(f"Could not locate the bear's {'left' if side < 0 else 'right'} hand.")
        center = sum((bear.data.vertices[index].co for index in indices), Vector()) / len(indices)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.0, location=center)
        paw = bpy.context.object
        paw.name = "LeftPaw" if side < 0 else "RightPaw"
        paw.scale = (0.108, 0.096, 0.14)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        paw.data.materials.append(paw_material)
        paw_parts.append(paw)

        # A dark palm pad makes the mitten read as a paw from the front.
        bpy.ops.mesh.primitive_ico_sphere_add(
            subdivisions=2,
            radius=1.0,
            location=center + Vector((0.0, 0.083, -0.01)),
        )
        pad = bpy.context.object
        pad.name = "LeftPawPad" if side < 0 else "RightPawPad"
        pad.scale = (0.061, 0.024, 0.078)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        pad.data.materials.append(pad_material)
        paw_parts.append(pad)

    bpy.ops.object.select_all(action="DESELECT")
    bear.select_set(True)
    for part in paw_parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = bear
    bpy.ops.object.join()
    bear.name = "WatchingBear"
    return bear


def import_and_normalize() -> bpy.types.Object:
    bpy.ops.import_scene.fbx(filepath=str(FBX_PATH), use_anim=False)
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for obj in list(bpy.data.objects):
        if obj.type != "MESH":
            bpy.data.objects.remove(obj, do_unlink=True)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("The watching-bear FBX did not contain a mesh.")
    bpy.ops.object.select_all(action="DESELECT")
    for mesh in meshes:
        mesh.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    bear = bpy.context.view_layer.objects.active
    bear.name = "WatchingBear"

    # The source faces +X. Blender +Y becomes Godot -Z after glTF export.
    bear.rotation_euler.z += radians(90.0)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    low, high = bounds(bear)
    scale = TARGET_HEIGHT / (high.z - low.z)
    bear.scale = (scale, scale, scale)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    low, high = bounds(bear)
    bear.location += Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z))
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)

    bear.data.materials.clear()
    bear.data.materials.append(build_material())
    bear = lower_arms_and_add_paws(bear)
    for polygon in bear.data.polygons:
        polygon.use_smooth = False
    return bear


def export_asset(bear: bpy.types.Object) -> None:
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="DESELECT")
    bear.select_set(True)
    bpy.context.view_layer.objects.active = bear
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_animations=False,
        export_yup=True,
        export_apply=True,
    )


def render_preview(bear: bpy.types.Object) -> None:
    world = bpy.context.scene.world or bpy.data.worlds.new("PreviewWorld")
    bpy.context.scene.world = world
    world.color = (0.018, 0.022, 0.03)

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (2.8, 4.8, 2.4)
    direction = Vector((0.0, 0.0, 0.95)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera_data.lens = 58
    bpy.context.scene.camera = camera

    for name, location, energy, size in (
        ("Key", (2.8, 3.3, 4.5), 850.0, 3.0),
        ("Rim", (-2.5, -1.5, 3.0), 500.0, 2.0),
    ):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        bpy.context.scene.collection.objects.link(light)
        light.location = location
        light.rotation_euler = (Vector((0.0, 0.0, 1.0)) - light.location).to_track_quat("-Z", "Y").to_euler()

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 600
    scene.render.resolution_y = 700
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()
    bear = import_and_normalize()
    export_asset(bear)
    render_preview(bear)
    low, high = bounds(bear)
    print(f"BUILT {GLB_PATH}")
    print(f"BOUNDS min={tuple(round(v, 4) for v in low)} max={tuple(round(v, 4) for v in high)}")
    print(f"MESH vertices={len(bear.data.vertices)} polygons={len(bear.data.polygons)} actions={len(bpy.data.actions)}")


if __name__ == "__main__":
    main()
