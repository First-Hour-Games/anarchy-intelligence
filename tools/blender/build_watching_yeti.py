"""Build the animated watching-yeti GLB from the pinned Quaternius source."""

from math import radians
from pathlib import Path

import bpy
from mathutils import Matrix, Quaternion, Vector


PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_ROOT = PROJECT_ROOT / "models" / "source" / "watching_yeti"
VENDOR_GLB_PATH = SOURCE_ROOT / "vendor" / "Yeti.glb"
BLEND_PATH = SOURCE_ROOT / "watching_yeti.blend"
PREVIEW_PATH = SOURCE_ROOT / "watching_yeti_preview.png"
GLB_PATH = PROJECT_ROOT / "models" / "enemies" / "watching_yeti" / "watching_yeti.glb"
TARGET_HEIGHT = 1.9

SOURCE_CLIPS = {
    "idle": "CharacterArmature|Idle",
    "walk": "CharacterArmature|Walk",
    "run": "CharacterArmature|Run",
    "attack": "CharacterArmature|Punch",
    "hit": "CharacterArmature|HitReact",
    "death": "CharacterArmature|Death",
}

MATERIAL_COLORS = {
    "Yeti_Main": (0.07, 0.025, 0.012, 1.0),
    "Yeti_Secondary": (0.16, 0.055, 0.018, 1.0),
    "Eye_White": (0.24, 0.19, 0.055, 1.0),
    "Eye_Black": (0.003, 0.002, 0.002, 1.0),
    "Tongue": (0.055, 0.008, 0.016, 1.0),
    "Yeti_Teeth": (0.32, 0.21, 0.105, 1.0),
}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def mesh_bounds(mesh: bpy.types.Object) -> tuple[Vector, Vector]:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    evaluated = mesh.evaluated_get(depsgraph)
    corners = [evaluated.matrix_world @ vertex.co for vertex in evaluated.data.vertices]
    return (
        Vector((min(v.x for v in corners), min(v.y for v in corners), min(v.z for v in corners))),
        Vector((max(v.x for v in corners), max(v.y for v in corners), max(v.z for v in corners))),
    )


def clean_import() -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    bpy.ops.import_scene.gltf(filepath=str(VENDOR_GLB_PATH))
    root = bpy.data.objects.get("RootNode")
    armature = bpy.data.objects.get("CharacterArmature")
    mesh = bpy.data.objects.get("Yeti")
    if root is None or armature is None or mesh is None:
        raise RuntimeError("The pinned Yeti GLB no longer matches its expected hierarchy.")

    keep = {root, armature, mesh}
    for obj in list(bpy.data.objects):
        if obj not in keep:
            bpy.data.objects.remove(obj, do_unlink=True)

    root.name = "WatchingYeti"
    armature.name = "WatchingYetiRig"
    mesh.name = "WatchingYetiMesh"
    for polygon in mesh.data.polygons:
        polygon.use_smooth = False

    # The source faces Blender -Y. Turn its authored root so its face points
    # Blender +Y, which exports as Godot -Z.
    root.rotation_mode = "XYZ"
    root.rotation_euler.z = radians(180.0)
    bpy.context.view_layer.update()
    return root, armature, mesh


def prepare_materials() -> None:
    for material in bpy.data.materials:
        material.use_nodes = True
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is None:
            continue
        color = MATERIAL_COLORS.get(material.name)
        if color is not None:
            principled.inputs["Base Color"].default_value = color
            material.diffuse_color = color
        principled.inputs["Roughness"].default_value = 0.9
        principled.inputs["Metallic"].default_value = 0.0
        if material.name == "Eye_White":
            emission = principled.inputs.get("Emission Color") or principled.inputs.get("Emission")
            strength = principled.inputs.get("Emission Strength")
            if emission is not None:
                emission.default_value = color
            if strength is not None:
                strength.default_value = 0.18


def prepare_animations(armature: bpy.types.Object) -> dict[str, bpy.types.Action]:
    animation_data = armature.animation_data_create()
    animation_data.action = None
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)

    source_actions = {action.name: action for action in bpy.data.actions}
    clips: dict[str, bpy.types.Action] = {}
    for clip_name, source_name in SOURCE_CLIPS.items():
        source = source_actions.get(source_name)
        if source is None:
            raise RuntimeError(f"Missing required source animation: {source_name}")
        source.name = clip_name
        clips[clip_name] = source

    windup = clips["attack"].copy()
    windup.name = "windup"
    clips["windup"] = windup

    for action in clips.values():
        action.use_fake_user = True

    for action in list(bpy.data.actions):
        if action not in clips.values():
            bpy.data.actions.remove(action)

    animation_data.action = clips["idle"]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()
    return clips


def lower_animated_arms(
    armature: bpy.types.Object,
    clips: dict[str, bpy.types.Action],
) -> None:
    corrections = {
        "UpperArm.L": radians(62.0),
        "UpperArm.R": radians(-62.0),
    }
    for action in clips.values():
        armature.animation_data.action = action
        first = int(round(action.frame_range[0]))
        last = int(round(action.frame_range[1]))
        samples: dict[int, dict[str, Quaternion]] = {}
        for frame in range(first, last + 1):
            bpy.context.scene.frame_set(frame)
            bpy.context.view_layer.update()
            samples[frame] = {}
            for bone_name, angle in corrections.items():
                bone = armature.pose.bones.get(bone_name)
                if bone is None:
                    raise RuntimeError(f"Missing arm correction bone: {bone_name}")
                pivot = bone.head.copy()
                correction = (
                    Matrix.Translation(pivot)
                    @ Matrix.Rotation(angle, 4, "Y")
                    @ Matrix.Translation(-pivot)
                )
                bone.matrix = correction @ bone.matrix.copy()
                bone.rotation_mode = "QUATERNION"
                samples[frame][bone_name] = bone.rotation_quaternion.copy()

        for frame, rotations in samples.items():
            bpy.context.scene.frame_set(frame)
            for bone_name, rotation in rotations.items():
                bone = armature.pose.bones[bone_name]
                bone.rotation_mode = "QUATERNION"
                bone.rotation_quaternion = rotation
                bone.keyframe_insert(
                    data_path="rotation_quaternion",
                    frame=frame,
                    group=bone_name,
                )

    armature.animation_data.action = clips["idle"]
    bpy.context.scene.frame_set(0)
    bpy.context.view_layer.update()


def normalize_character(root: bpy.types.Object, mesh: bpy.types.Object) -> None:
    low, high = mesh_bounds(mesh)
    scale = TARGET_HEIGHT / (high.z - low.z)
    root.scale *= scale
    bpy.context.view_layer.update()
    low, high = mesh_bounds(mesh)
    root.location += Vector((-(low.x + high.x) * 0.5, -(low.y + high.y) * 0.5, -low.z))
    bpy.context.view_layer.update()


def export_character(
    root: bpy.types.Object,
    armature: bpy.types.Object,
    mesh: bpy.types.Object,
) -> None:
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (root, armature, mesh):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=False,
        export_materials="EXPORT",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_force_sampling=True,
        export_frame_range=False,
        export_skins=True,
        export_def_bones=True,
        export_leaf_bone=False,
        export_morph=False,
        export_cameras=False,
        export_lights=False,
        export_extras=True,
    )


def point_at(obj: bpy.types.Object, target: Vector) -> None:
    obj.rotation_euler = (target - obj.location).to_track_quat("-Z", "Y").to_euler()


def render_preview(mesh: bpy.types.Object, armature: bpy.types.Object) -> None:
    armature.animation_data.action = bpy.data.actions["idle"]
    bpy.context.scene.frame_set(12)
    bpy.context.view_layer.update()
    world = bpy.context.scene.world or bpy.data.worlds.new("PreviewWorld")
    bpy.context.scene.world = world
    world.color = (0.006, 0.008, 0.013)

    bpy.ops.mesh.primitive_plane_add(size=18.0, location=(0.0, 0.0, -0.01))
    floor = bpy.context.object
    floor.name = "PreviewFloor"
    floor_material = bpy.data.materials.new("PreviewFloorMaterial")
    floor_material.diffuse_color = (0.012, 0.017, 0.022, 1.0)
    floor.data.materials.append(floor_material)

    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    bpy.context.scene.collection.objects.link(camera)
    camera.location = (2.9, 5.5, 2.25)
    point_at(camera, Vector((0.0, 0.0, 0.95)))
    camera_data.lens = 62
    bpy.context.scene.camera = camera

    for name, location, energy, color, size in (
        ("Key", (2.6, 3.4, 4.2), 900.0, (0.72, 0.82, 1.0), 3.0),
        ("Rim", (-2.8, -1.4, 3.0), 650.0, (0.18, 0.28, 0.55), 2.2),
        ("EyeFill", (0.0, 2.0, 1.5), 120.0, (0.75, 0.16, 0.06), 1.2),
    ):
        light_data = bpy.data.lights.new(name, "AREA")
        light_data.energy = energy
        light_data.color = color
        light_data.shape = "DISK"
        light_data.size = size
        light = bpy.data.objects.new(name, light_data)
        bpy.context.scene.collection.objects.link(light)
        light.location = location
        point_at(light, Vector((0.0, 0.0, 1.0)))

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 760
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.view_settings.look = "AgX - Medium High Contrast"
    bpy.ops.render.render(write_still=True)


def main() -> None:
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 24

    root, armature, mesh = clean_import()
    prepare_materials()
    clips = prepare_animations(armature)
    lower_animated_arms(armature, clips)
    normalize_character(root, mesh)
    export_character(root, armature, mesh)
    render_preview(mesh, armature)

    low, high = mesh_bounds(mesh)
    mesh.data.calc_loop_triangles()
    print(f"BLEND={BLEND_PATH}")
    print(f"GLB={GLB_PATH}")
    print(f"PREVIEW={PREVIEW_PATH}")
    print(f"BOUNDS min={tuple(round(v, 4) for v in low)} max={tuple(round(v, 4) for v in high)}")
    print(f"TRIANGLES={len(mesh.data.loop_triangles)}")
    print(f"CLIPS={','.join(sorted(clips))}")


if __name__ == "__main__":
    main()
