"""Generate the original Corrupted Friend rig, animations, preview, and GLB.

Run with Blender rather than ordinary Python:
  blender --background --factory-startup --python tools/blender/build_corrupted_friend_3d.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "models" / "source" / "corrupted_friend"
OUTPUT_DIR = ROOT / "models" / "enemies" / "corrupted_friend"
BLEND_PATH = SOURCE_DIR / "corrupted_friend_v1.blend"
PREVIEW_PATH = SOURCE_DIR / "corrupted_friend_v1_preview.png"
GLB_PATH = OUTPUT_DIR / "corrupted_friend_v1.glb"

SOURCE_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

CHARACTER_OBJECTS: list[bpy.types.Object] = []


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (
        bpy.data.meshes,
        bpy.data.curves,
        bpy.data.armatures,
        bpy.data.materials,
        bpy.data.cameras,
        bpy.data.lights,
    ):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.8,
    metallic: float = 0.0,
    emission: tuple[float, float, float, float] | None = None,
    emission_strength: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        if emission_input is not None:
            emission_input.default_value = emission
        strength_input = shader.inputs.get("Emission Strength")
        if strength_input is not None:
            strength_input.default_value = emission_strength
    return material


def bind_to_bone(
    obj: bpy.types.Object,
    armature: bpy.types.Object,
    bone_name: str,
) -> bpy.types.Object:
    bpy.context.view_layer.objects.active = obj
    obj.parent = armature
    modifier = obj.modifiers.new(name="Rig", type="ARMATURE")
    modifier.object = armature
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    CHARACTER_OBJECTS.append(obj)
    return obj


def finish_mesh(
    obj: bpy.types.Object,
    name: str,
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
    shade_smooth: bool = False,
) -> bpy.types.Object:
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = shade_smooth
    return bind_to_bone(obj, armature, bone_name)


def create_ellipsoid(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
    subdivisions: int = 2,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdivisions,
        radius=1.0,
        location=location,
    )
    obj = bpy.context.object
    obj.scale = scale
    return finish_mesh(obj, name, material, armature, bone_name, True)


def create_box(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=location, rotation=rotation)
    obj = bpy.context.object
    obj.scale = scale
    bevel = obj.modifiers.new(name="Soft edges", type="BEVEL")
    bevel.width = min(scale) * 0.16
    bevel.segments = 1
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return finish_mesh(obj, name, material, armature, bone_name)


def create_cone(
    name: str,
    location: tuple[float, float, float],
    depth: float,
    radius_bottom: float,
    radius_top: float,
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        location=location,
    )
    return finish_mesh(bpy.context.object, name, material, armature, bone_name)


def create_segment(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
    vertices: int = 8,
) -> bpy.types.Object:
    start_vector = Vector(start)
    end_vector = Vector(end)
    direction = end_vector - start_vector
    midpoint = (start_vector + end_vector) * 0.5
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=vertices,
        radius=radius,
        depth=direction.length,
        location=midpoint,
        rotation=rotation,
    )
    return finish_mesh(bpy.context.object, name, material, armature, bone_name)


def create_directional_cone(
    name: str,
    base: tuple[float, float, float],
    tip: tuple[float, float, float],
    radius: float,
    material: bpy.types.Material,
    armature: bpy.types.Object,
    bone_name: str,
) -> bpy.types.Object:
    base_vector = Vector(base)
    tip_vector = Vector(tip)
    direction = tip_vector - base_vector
    midpoint = (base_vector + tip_vector) * 0.5
    rotation = direction.to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_cone_add(
        vertices=5,
        radius1=radius,
        radius2=0.0,
        depth=direction.length,
        location=midpoint,
        rotation=rotation,
    )
    return finish_mesh(bpy.context.object, name, material, armature, bone_name)


def create_rig() -> tuple[bpy.types.Object, dict[str, tuple[Vector, Vector]]]:
    armature_data = bpy.data.armatures.new("CorruptedFriendRig")
    armature = bpy.data.objects.new("CorruptedFriendRig", armature_data)
    bpy.context.collection.objects.link(armature)
    armature.show_in_front = True
    CHARACTER_OBJECTS.append(armature)

    bones: dict[str, tuple[tuple[float, float, float], tuple[float, float, float], str | None]] = {
        "root": ((0.0, 0.0, 0.0), (0.0, 0.0, 0.14), None),
        "hips": ((0.0, 0.0, 0.86), (0.0, 0.0, 1.02), "root"),
        "spine": ((0.0, 0.0, 1.0), (0.0, 0.0, 1.30), "hips"),
        "chest": ((0.0, 0.0, 1.28), (0.0, 0.0, 1.49), "spine"),
        "neck": ((0.0, 0.0, 1.47), (0.0, 0.0, 1.57), "chest"),
        "head": ((0.0, 0.0, 1.55), (0.0, 0.0, 1.76), "neck"),
        "upper_arm.L": ((0.23, 0.0, 1.43), (0.36, 0.0, 1.20), "chest"),
        "forearm.L": ((0.36, 0.0, 1.20), (0.39, -0.015, 0.98), "upper_arm.L"),
        "hand.L": ((0.39, -0.015, 0.98), (0.39, -0.03, 0.88), "forearm.L"),
        "upper_arm.R": ((-0.23, 0.0, 1.43), (-0.36, 0.0, 1.20), "chest"),
        "forearm.R": ((-0.36, 0.0, 1.20), (-0.39, -0.015, 0.98), "upper_arm.R"),
        "hand.R": ((-0.39, -0.015, 0.98), (-0.39, -0.03, 0.88), "forearm.R"),
        "thigh.L": ((0.11, 0.0, 0.91), (0.12, 0.0, 0.53), "hips"),
        "shin.L": ((0.12, 0.0, 0.53), (0.12, -0.01, 0.15), "thigh.L"),
        "foot.L": ((0.12, -0.01, 0.15), (0.12, -0.19, 0.08), "shin.L"),
        "thigh.R": ((-0.11, 0.0, 0.91), (-0.12, 0.0, 0.53), "hips"),
        "shin.R": ((-0.12, 0.0, 0.53), (-0.12, -0.01, 0.15), "thigh.R"),
        "foot.R": ((-0.12, -0.01, 0.15), (-0.12, -0.19, 0.08), "shin.R"),
    }

    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, parent_name) in bones.items():
        bone = armature_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent_name is not None:
            bone.parent = armature_data.edit_bones[parent_name]
        axis = (Vector(tail) - Vector(head)).normalized()
        roll_target = Vector((0.0, -1.0, 0.0))
        if abs(axis.dot(roll_target)) > 0.98:
            roll_target = Vector((0.0, 0.0, 1.0))
        bone.align_roll(roll_target)
    bpy.ops.object.mode_set(mode="POSE")
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")

    points = {
        name: (Vector(head), Vector(tail))
        for name, (head, tail, _parent_name) in bones.items()
    }
    return armature, points


def create_character(
    armature: bpy.types.Object,
    points: dict[str, tuple[Vector, Vector]],
) -> dict[str, bpy.types.Material]:
    materials = {
        "skin": make_material("Skin_Pale", (0.58, 0.50, 0.44, 1.0), 0.92),
        "shirt": make_material("Shirt_Dirty_Beige", (0.31, 0.27, 0.21, 1.0), 0.98),
        "undershirt": make_material("Undershirt_Charcoal", (0.035, 0.04, 0.045, 1.0), 0.94),
        "jeans": make_material("Jeans_Blue_Gray", (0.10, 0.15, 0.17, 1.0), 0.9),
        "shoe": make_material("Shoes_Worn", (0.055, 0.045, 0.038, 1.0), 0.88),
        "sole": make_material("Soles_Dirty", (0.20, 0.17, 0.13, 1.0), 0.9),
        "hair": make_material("Hair_Brown", (0.10, 0.06, 0.035, 1.0), 0.96),
        "stain": make_material("Grime_Dark", (0.09, 0.045, 0.025, 1.0), 1.0),
        "cyber": make_material("Cybernetic_Black", (0.015, 0.018, 0.022, 1.0), 0.32, 0.72),
        "metal": make_material("Cybernetic_Metal", (0.16, 0.18, 0.19, 1.0), 0.25, 0.82),
        "red": make_material(
            "Implant_Red",
            (0.42, 0.005, 0.003, 1.0),
            0.28,
            0.3,
            (1.0, 0.005, 0.002, 1.0),
            8.0,
        ),
    }

    create_box("Pelvis", (0.0, 0.0, 0.88), (0.20, 0.13, 0.14), materials["jeans"], armature, "hips")
    create_cone("Torn_Shirt", (0.0, 0.0, 1.27), 0.56, 0.285, 0.225, materials["shirt"], armature, "chest", 9)
    create_cone("Undershirt_Torso", (0.0, 0.015, 1.28), 0.50, 0.245, 0.205, materials["undershirt"], armature, "chest", 9)
    create_segment("Neck", (0.0, 0.0, 1.47), (0.0, 0.0, 1.58), 0.072, materials["skin"], armature, "neck")
    create_ellipsoid("Head", (0.0, -0.012, 1.68), (0.135, 0.12, 0.165), materials["skin"], armature, "head")
    create_ellipsoid("Hair_Cap", (0.0, 0.008, 1.735), (0.155, 0.135, 0.145), materials["hair"], armature, "head")

    hair_tips = [
        ((-0.11, -0.03, 1.80), (-0.19, -0.08, 1.86)),
        ((-0.05, -0.05, 1.82), (-0.07, -0.15, 1.89)),
        ((0.02, -0.05, 1.82), (0.04, -0.16, 1.87)),
        ((0.09, -0.03, 1.80), (0.17, -0.10, 1.84)),
        ((0.02, 0.04, 1.84), (0.03, 0.11, 1.91)),
        ((-0.07, 0.03, 1.82), (-0.13, 0.09, 1.88)),
        ((0.115, 0.015, 1.76), (0.20, 0.045, 1.79)),
        ((-0.115, 0.015, 1.76), (-0.20, 0.035, 1.80)),
    ]
    for index, (base, tip) in enumerate(hair_tips):
        create_directional_cone(
            f"Hair_Tuft_{index:02d}", base, tip, 0.05, materials["hair"], armature, "head"
        )
    create_directional_cone("Bang_Left", (0.045, -0.105, 1.77), (0.085, -0.15, 1.60), 0.055, materials["hair"], armature, "head")
    create_directional_cone("Bang_Right", (-0.045, -0.105, 1.77), (-0.075, -0.15, 1.59), 0.06, materials["hair"], armature, "head")

    create_ellipsoid("Cyber_Eye_Socket", (0.048, -0.119, 1.692), (0.035, 0.012, 0.035), materials["cyber"], armature, "head", 2)
    create_ellipsoid("Cyber_Eye", (0.048, -0.132, 1.692), (0.017, 0.008, 0.017), materials["red"], armature, "head", 2)
    create_box("Mouth", (0.0, -0.128, 1.625), (0.038, 0.005, 0.006), materials["stain"], armature, "head")

    for side in ("L", "R"):
        upper = f"upper_arm.{side}"
        forearm = f"forearm.{side}"
        hand = f"hand.{side}"
        create_segment(f"UpperArm_{side}", *points[upper], 0.072, materials["undershirt"], armature, upper)
        sleeve_end = points[upper][0].lerp(points[upper][1], 0.42)
        create_segment(f"ShirtSleeve_{side}", points[upper][0], sleeve_end, 0.092, materials["shirt"], armature, upper)
        create_segment(f"Forearm_{side}", *points[forearm], 0.062, materials["undershirt"], armature, forearm)
        hand_center = (points[hand][0] + points[hand][1]) * 0.5
        create_ellipsoid(f"Hand_{side}", hand_center, (0.062, 0.052, 0.075), materials["skin"], armature, hand, 1)

    cuff_start = points["forearm.R"][0].lerp(points["forearm.R"][1], 0.47)
    cuff_end = points["forearm.R"][0].lerp(points["forearm.R"][1], 0.75)
    create_segment("Cyber_Cuff", cuff_start, cuff_end, 0.085, materials["cyber"], armature, "forearm.R", 10)
    cuff_light = (cuff_start + cuff_end) * 0.5 + Vector((0.0, -0.07, 0.0))
    create_ellipsoid("Cuff_Light", cuff_light, (0.018, 0.012, 0.018), materials["red"], armature, "forearm.R", 2)

    for side in ("L", "R"):
        thigh = f"thigh.{side}"
        shin = f"shin.{side}"
        foot = f"foot.{side}"
        create_segment(f"Thigh_{side}", *points[thigh], 0.105, materials["jeans"], armature, thigh)
        create_segment(f"Shin_{side}", *points[shin], 0.09, materials["jeans"], armature, shin)
        foot_sign = 1.0 if side == "L" else -1.0
        create_box(
            f"Shoe_{side}",
            (0.12 * foot_sign, -0.11, 0.075),
            (0.105, 0.17, 0.075),
            materials["shoe"],
            armature,
            foot,
        )
        create_box(
            f"Sole_{side}",
            (0.12 * foot_sign, -0.115, 0.018),
            (0.112, 0.178, 0.022),
            materials["sole"],
            armature,
            foot,
        )
        rip_center = points[thigh][0].lerp(points[thigh][1], 0.58)
        rip_center.y -= 0.095
        create_ellipsoid(f"Jeans_Rip_{side}", rip_center, (0.055, 0.016, 0.065), materials["skin"], armature, thigh, 1)

    for index, x_position in enumerate((-0.20, -0.08, 0.07, 0.19)):
        create_directional_cone(
            f"Shirt_Rag_{index:02d}",
            (x_position, -0.02, 1.01),
            (x_position + (0.018 if index % 2 else -0.015), -0.035, 0.91 - 0.02 * (index % 2)),
            0.055,
            materials["shirt"],
            armature,
            "chest",
        )
    for index, (x_position, z_position, size) in enumerate(
        ((-0.10, 1.39, 0.035), (0.13, 1.20, 0.042), (-0.18, 1.10, 0.026))
    ):
        create_ellipsoid(
            f"Shirt_Stain_{index:02d}",
            (x_position, -0.257, z_position),
            (size, 0.008, size * 1.3),
            materials["stain"],
            armature,
            "chest",
            1,
        )
    return materials


def radians(values: tuple[float, float, float]) -> tuple[float, float, float]:
    return tuple(math.radians(value) for value in values)


def key_pose(
    armature: bpy.types.Object,
    frame: int,
    rotations: dict[str, tuple[float, float, float]] | None = None,
    locations: dict[str, tuple[float, float, float]] | None = None,
) -> None:
    rotations = rotations or {}
    locations = locations or {}
    bpy.context.scene.frame_set(frame)
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_euler = (0.0, 0.0, 0.0)
        pose_bone.location = (0.0, 0.0, 0.0)
    for bone_name, rotation in rotations.items():
        armature.pose.bones[bone_name].rotation_euler = radians(rotation)
    for bone_name, location in locations.items():
        armature.pose.bones[bone_name].location = location
    for pose_bone in armature.pose.bones:
        pose_bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=pose_bone.name)
        pose_bone.keyframe_insert(data_path="location", frame=frame, group=pose_bone.name)


def create_action(
    armature: bpy.types.Object,
    name: str,
    poses: list[
        tuple[
            int,
            dict[str, tuple[float, float, float]],
            dict[str, tuple[float, float, float]],
        ]
    ],
) -> bpy.types.Action:
    action = bpy.data.actions.new(name=name)
    action.use_fake_user = True
    armature.animation_data.action = action
    for frame, rotations, locations in poses:
        key_pose(armature, frame, rotations, locations)
    return action


def create_animations(armature: bpy.types.Object) -> dict[str, bpy.types.Action]:
    armature.animation_data_create()
    actions: dict[str, bpy.types.Action] = {}

    idle_a = {
        "chest": (2.0, 0.0, 0.0),
        "head": (-4.0, 0.0, -4.0),
        "upper_arm.L": (-3.0, 0.0, 2.0),
        "upper_arm.R": (4.0, 0.0, -2.0),
    }
    idle_b = {
        "chest": (-1.0, 0.0, 0.0),
        "head": (2.0, 0.0, 3.0),
        "upper_arm.L": (2.0, 0.0, 0.0),
        "upper_arm.R": (-2.0, 0.0, 0.0),
    }
    actions["idle"] = create_action(
        armature,
        "idle",
        [(1, idle_a, {"hips": (0.0, 0.0, 0.0)}), (13, idle_b, {"hips": (0.0, 0.0, 0.012)}), (25, idle_a, {"hips": (0.0, 0.0, 0.0)})],
    )

    walk_forward = {
        "chest": (5.0, 0.0, 0.0),
        "thigh.L": (28.0, 0.0, 0.0),
        "thigh.R": (-28.0, 0.0, 0.0),
        "shin.L": (-12.0, 0.0, 0.0),
        "shin.R": (38.0, 0.0, 0.0),
        "upper_arm.L": (-24.0, 0.0, 0.0),
        "upper_arm.R": (24.0, 0.0, 0.0),
        "forearm.L": (-15.0, 0.0, 0.0),
        "forearm.R": (-15.0, 0.0, 0.0),
    }
    walk_back = {
        "chest": (5.0, 0.0, 0.0),
        "thigh.L": (-28.0, 0.0, 0.0),
        "thigh.R": (28.0, 0.0, 0.0),
        "shin.L": (38.0, 0.0, 0.0),
        "shin.R": (-12.0, 0.0, 0.0),
        "upper_arm.L": (24.0, 0.0, 0.0),
        "upper_arm.R": (-24.0, 0.0, 0.0),
        "forearm.L": (-15.0, 0.0, 0.0),
        "forearm.R": (-15.0, 0.0, 0.0),
    }
    walk_mid = {"chest": (4.0, 0.0, 0.0), "shin.L": (8.0, 0.0, 0.0), "shin.R": (8.0, 0.0, 0.0)}
    actions["walk"] = create_action(
        armature,
        "walk",
        [(1, walk_forward, {"hips": (0.0, 0.0, 0.0)}), (7, walk_mid, {"hips": (0.0, 0.0, 0.025)}), (13, walk_back, {"hips": (0.0, 0.0, 0.0)}), (19, walk_mid, {"hips": (0.0, 0.0, 0.025)}), (25, walk_forward, {"hips": (0.0, 0.0, 0.0)})],
    )

    run_forward = {
        "spine": (12.0, 0.0, 0.0),
        "chest": (12.0, 0.0, 0.0),
        "head": (-8.0, 0.0, 0.0),
        "thigh.L": (48.0, 0.0, 0.0),
        "thigh.R": (-44.0, 0.0, 0.0),
        "shin.L": (-12.0, 0.0, 0.0),
        "shin.R": (70.0, 0.0, 0.0),
        "upper_arm.L": (-48.0, 0.0, 0.0),
        "upper_arm.R": (48.0, 0.0, 0.0),
        "forearm.L": (-48.0, 0.0, 0.0),
        "forearm.R": (-48.0, 0.0, 0.0),
    }
    run_back = {
        "spine": (12.0, 0.0, 0.0),
        "chest": (12.0, 0.0, 0.0),
        "head": (-8.0, 0.0, 0.0),
        "thigh.L": (-44.0, 0.0, 0.0),
        "thigh.R": (48.0, 0.0, 0.0),
        "shin.L": (70.0, 0.0, 0.0),
        "shin.R": (-12.0, 0.0, 0.0),
        "upper_arm.L": (48.0, 0.0, 0.0),
        "upper_arm.R": (-48.0, 0.0, 0.0),
        "forearm.L": (-48.0, 0.0, 0.0),
        "forearm.R": (-48.0, 0.0, 0.0),
    }
    run_mid = {
        "spine": (15.0, 0.0, 0.0),
        "chest": (13.0, 0.0, 0.0),
        "thigh.L": (5.0, 0.0, 0.0),
        "thigh.R": (5.0, 0.0, 0.0),
        "shin.L": (42.0, 0.0, 0.0),
        "shin.R": (42.0, 0.0, 0.0),
        "upper_arm.L": (4.0, 0.0, 0.0),
        "upper_arm.R": (4.0, 0.0, 0.0),
        "forearm.L": (-58.0, 0.0, 0.0),
        "forearm.R": (-58.0, 0.0, 0.0),
    }
    actions["run"] = create_action(
        armature,
        "run",
        [(1, run_forward, {"hips": (0.0, 0.0, 0.0)}), (5, run_mid, {"hips": (0.0, 0.0, 0.055)}), (9, run_back, {"hips": (0.0, 0.0, 0.0)}), (13, run_mid, {"hips": (0.0, 0.0, 0.055)}), (17, run_forward, {"hips": (0.0, 0.0, 0.0)})],
    )

    windup_start = {"chest": (8.0, 0.0, 0.0), "head": (-6.0, 0.0, 0.0)}
    windup_mid = {
        "spine": (7.0, 12.0, 0.0),
        "chest": (10.0, 18.0, 0.0),
        "upper_arm.R": (-48.0, 0.0, -18.0),
        "forearm.R": (-72.0, 0.0, 0.0),
        "upper_arm.L": (25.0, 0.0, 10.0),
        "forearm.L": (-35.0, 0.0, 0.0),
    }
    windup_hold = dict(windup_mid)
    windup_hold.update({"upper_arm.R": (-78.0, 0.0, -22.0), "forearm.R": (-92.0, 0.0, 0.0), "head": (-10.0, -12.0, 0.0)})
    actions["windup"] = create_action(
        armature,
        "windup",
        [(1, windup_start, {}), (9, windup_mid, {}), (17, windup_hold, {})],
    )

    strike = {
        "spine": (18.0, -12.0, 0.0),
        "chest": (22.0, -25.0, 0.0),
        "head": (-12.0, 14.0, 0.0),
        "upper_arm.R": (98.0, 0.0, -8.0),
        "forearm.R": (8.0, 0.0, 0.0),
        "upper_arm.L": (-18.0, 0.0, 8.0),
        "forearm.L": (-38.0, 0.0, 0.0),
        "thigh.L": (10.0, 0.0, 0.0),
        "thigh.R": (-12.0, 0.0, 0.0),
    }
    follow_through = dict(strike)
    follow_through.update({"upper_arm.R": (72.0, 0.0, -28.0), "forearm.R": (28.0, 0.0, 0.0), "chest": (17.0, -34.0, 0.0)})
    actions["attack"] = create_action(
        armature,
        "attack",
        [(1, windup_hold, {}), (5, strike, {"hips": (0.0, -0.035, 0.0)}), (10, follow_through, {"hips": (0.0, -0.018, 0.0)}), (15, windup_start, {})],
    )

    hit_pose = {
        "spine": (-16.0, -9.0, 8.0),
        "chest": (-22.0, -12.0, 10.0),
        "head": (20.0, 12.0, -12.0),
        "upper_arm.L": (-36.0, 0.0, 24.0),
        "upper_arm.R": (-28.0, 0.0, -24.0),
        "forearm.L": (-35.0, 0.0, 0.0),
        "forearm.R": (-35.0, 0.0, 0.0),
    }
    actions["hit"] = create_action(
        armature,
        "hit",
        [(1, windup_start, {}), (4, hit_pose, {"hips": (0.04, 0.035, 0.0)}), (10, windup_start, {})],
    )

    collapse = {
        "spine": (24.0, 0.0, 8.0),
        "chest": (20.0, 0.0, -10.0),
        "head": (28.0, 0.0, 15.0),
        "thigh.L": (22.0, 0.0, 0.0),
        "thigh.R": (18.0, 0.0, 0.0),
        "shin.L": (55.0, 0.0, 0.0),
        "shin.R": (48.0, 0.0, 0.0),
        "upper_arm.L": (35.0, 0.0, 18.0),
        "upper_arm.R": (40.0, 0.0, -15.0),
    }
    fallen = dict(collapse)
    fallen.update({"root": (86.0, 0.0, -8.0), "head": (12.0, 0.0, 20.0), "upper_arm.L": (62.0, 0.0, 35.0), "upper_arm.R": (48.0, 0.0, -32.0)})
    actions["death"] = create_action(
        armature,
        "death",
        [(1, windup_start, {}), (10, collapse, {"hips": (0.0, 0.0, -0.08)}), (22, fallen, {"root": (0.0, 0.0, 0.06)}), (36, fallen, {"root": (0.0, 0.0, 0.06)})],
    )

    armature.animation_data.action = actions["idle"]
    bpy.context.scene.frame_set(1)
    return actions


def point_camera(camera: bpy.types.Object, target: Vector) -> None:
    direction = target - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def build_preview(materials: dict[str, bpy.types.Material]) -> None:
    bpy.ops.mesh.primitive_plane_add(size=12.0, location=(0.0, 0.0, -0.025))
    ground = bpy.context.object
    ground.name = "Preview_Ground"
    ground.data.materials.append(
        make_material("Preview_Ground_Material", (0.018, 0.022, 0.028, 1.0), 0.92)
    )

    bpy.ops.object.camera_add(location=(3.1, -5.0, 2.25))
    camera = bpy.context.object
    camera.name = "Preview_Camera"
    camera.data.lens = 62.0
    point_camera(camera, Vector((0.0, 0.0, 0.95)))
    bpy.context.scene.camera = camera

    bpy.ops.object.light_add(type="AREA", location=(1.8, -2.8, 3.5))
    key = bpy.context.object
    key.name = "Preview_Key"
    key.data.energy = 850.0
    key.data.shape = "DISK"
    key.data.size = 3.0
    point_camera(key, Vector((0.0, 0.0, 1.0)))

    bpy.ops.object.light_add(type="AREA", location=(-2.8, -0.5, 2.0))
    fill = bpy.context.object
    fill.name = "Preview_Fill"
    fill.data.energy = 420.0
    fill.data.color = (0.18, 0.28, 0.48)
    fill.data.size = 2.5
    point_camera(fill, Vector((0.0, 0.0, 1.0)))

    bpy.ops.object.light_add(type="POINT", location=(0.7, -1.0, 1.7))
    red = bpy.context.object
    red.name = "Preview_Red_Rim"
    red.data.energy = 65.0
    red.data.color = (1.0, 0.015, 0.005)

    scene = bpy.context.scene
    # Blender 4.x exposed Eevee as BLENDER_EEVEE_NEXT while Blender 5.x uses
    # BLENDER_EEVEE again. Pick the identifier the running build supports.
    engine_items = scene.bl_rna.properties["render"].fixed_type.properties["engine"].enum_items
    engine_ids = {item.identifier for item in engine_items}
    scene.render.engine = (
        "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engine_ids else "BLENDER_EEVEE"
    )
    scene.render.resolution_x = 720
    scene.render.resolution_y = 900
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = str(PREVIEW_PATH)
    scene.render.film_transparent = False
    scene.world.color = (0.006, 0.008, 0.012)
    scene.render.image_settings.color_mode = "RGBA"
    bpy.ops.render.render(write_still=True)


def export_character(armature: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in CHARACTER_OBJECTS:
        obj.hide_viewport = False
        obj.hide_render = False
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
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


def main() -> None:
    clear_scene()
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = 24

    armature, points = create_rig()
    materials = create_character(armature, points)
    actions = create_animations(armature)
    build_preview(materials)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    export_character(armature)

    triangle_count = 0
    for obj in CHARACTER_OBJECTS:
        if obj.type != "MESH":
            continue
        obj.data.calc_loop_triangles()
        triangle_count += len(obj.data.loop_triangles)
    print(f"BLEND={BLEND_PATH}")
    print(f"GLB={GLB_PATH}")
    print(f"PREVIEW={PREVIEW_PATH}")
    print("ACTIONS=" + ",".join(sorted(actions)))
    print(f"CHARACTER_OBJECTS={len(CHARACTER_OBJECTS)}")
    print(f"TRIANGLES={triangle_count}")


if __name__ == "__main__":
    main()
