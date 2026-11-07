"""Rebuild The Ridgeback's GLB from the creator's Blender file, with the clips authored for it.

The creator's THE_RIDGEBACK.blend holds the mesh, its control rig (IK hands and feet with elbow and
knee poles) and the five original clips (ManThing_*). This script opens it without saving it, wires
the "flesh" skin onto the material (the file's own image path points at the creator's disk; the
artist ships eight interchangeable skins as loose PNGs), keys the clips from
tools/blender/ridgeback/clips.py onto the same rig, and exports the mesh and rig with every clip,
sampled per frame so the IK is baked into the bones. The original clips stay in the GLB as the
visual adapter's fallback. Every authored clip has to pass the joint check in
tools/blender/ridgeback/anatomy.py (no joint past its twist or bend range, nothing through the
floor) or the build stops before exporting.

A copy of the authored file is saved beside the source for looking at the clips in Blender; change
clips.py and rebuild rather than editing that copy.

It also exports what the alt route's rooftop fall leaves of it (scenes/monsters/the_ridgeback/
ridgeback_faller.gd): THE_RIDGEBACK_crawler.glb, the same mesh, rig and clips with the skin of the legs
(clips.LEGS) cut away at the hips and the holes closed with wounds, and THE_RIDGEBACK_legs.glb, that
skin on its own, baked into the pose the splat clip ends in, so it lies where the legs lay.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_the_ridgeback.py
"""

import random
import sys
from pathlib import Path

import bmesh
import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent / "ridgeback"))

import anatomy  # noqa: E402
import clips  # noqa: E402
from rig import Rig  # noqa: E402

SOURCE_DIR = PROJECT_ROOT / "models" / "source" / "the_ridgeback"
SOURCE_BLEND = SOURCE_DIR / "vendor" / "THE_RIDGEBACK.blend"
DEFAULT_SKIN = SOURCE_DIR / "vendor" / "textures" / "ManThing_flesh.png"
ANIMATED_BLEND = SOURCE_DIR / "THE_RIDGEBACK_animated.blend"
GLB_PATH = PROJECT_ROOT / "models" / "enemies" / "the_ridgeback" / "THE_RIDGEBACK.glb"
CRAWLER_PATH = GLB_PATH.with_name("THE_RIDGEBACK_crawler.glb")
LEGS_PATH = GLB_PATH.with_name("THE_RIDGEBACK_legs.glb")

KEEP_OBJECTS = ("ManThing_PSX", "PSX_Rig")
# A vertex belongs to the legs when this much of its weight is on clips.LEGS.
LEG_SHARE = 0.5
# The wound over each cut bulges out this far, unevenly.
WOUND_BULGE = (0.015, 0.045)


def assign_default_skin(mesh: bpy.types.Object) -> None:
    """The flesh skin on a plain PBR material: double-sided, matte, as the GLB has always shipped."""
    material = mesh.data.materials[0]
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(DEFAULT_SKIN), check_existing=True)
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 0.4
    links = material.node_tree.links
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    material.use_backface_culling = False


def gore_material() -> bpy.types.Material:
    """Raw, wet meat for the cut ends."""
    material = bpy.data.materials.new("PSX_Gore")
    material.use_nodes = True
    shader = next(node for node in material.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (0.22, 0.012, 0.01, 1.0)
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 0.22
    material.use_backface_culling = False
    return material


def leg_vertices(mesh: bpy.types.Object) -> set:
    legs = {mesh.vertex_groups[name].index for name in clips.LEGS}
    found = set()
    for vertex in mesh.data.vertices:
        total = sum(group.weight for group in vertex.groups)
        share = sum(group.weight for group in vertex.groups if group.group in legs)
        if total > 0.0 and share / total >= LEG_SHARE:
            found.add(vertex.index)
    return found


def cut(mesh: bpy.types.Object, name: str, keep_legs: bool, gore: bpy.types.Material) -> bpy.types.Object:
    """A copy of the mesh with the legs cut away (or only the legs kept), each opening closed with a
    wound: a fan from a centre pushed out from the cut, skinned like the edge round it."""
    copy = mesh.copy()
    copy.data = mesh.data.copy()
    copy.name = copy.data.name = name
    bpy.context.scene.collection.objects.link(copy)
    copy.data.materials.append(gore)
    legs = leg_vertices(mesh)
    bm = bmesh.new()
    bm.from_mesh(copy.data)
    bm.verts.ensure_lookup_table()
    deform = bm.verts.layers.deform.verify()
    # Borders the creator's mesh already had stay open; only the cut is closed.
    was_open = {_ends(edge) for edge in bm.edges if edge.is_boundary}
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if (v.index in legs) != keep_legs], context="VERTS")
    fresh = [edge for edge in bm.edges if edge.is_boundary and _ends(edge) not in was_open]
    filled = bmesh.ops.holes_fill(bm, edges=fresh, sides=0)["faces"]
    poked = bmesh.ops.poke(bm, faces=filled)
    rng = random.Random(name)
    for face in poked["faces"]:
        face.material_index = len(copy.data.materials) - 1
    for centre in poked["verts"]:
        ring = [edge.other_vert(centre) for edge in centre.link_edges]
        weights = {}
        for vertex in ring:
            for group, weight in vertex[deform].items():
                weights[group] = weights.get(group, 0.0) + weight / len(ring)
        centre[deform].clear()
        for group, weight in weights.items():
            centre[deform][group] = weight
        bm.normal_update()
        normal = centre.normal.copy()
        centre.co += normal * rng.uniform(*WOUND_BULGE)
        for vertex in ring:
            if rng.random() < 0.5:
                vertex.co += normal * rng.uniform(0.0, WOUND_BULGE[0])
    bm.normal_update()
    bm.to_mesh(copy.data)
    bm.free()
    copy.data.update()
    return copy


def _ends(edge) -> tuple:
    return tuple(sorted(tuple(round(c, 5) for c in vertex.co) for vertex in edge.verts))


def bake_splat_pose(legs: bpy.types.Object, armature: bpy.types.Object, rig: Rig) -> None:
    """The legs frozen as the splat clip leaves them, and freed from the rig."""
    action = bpy.data.actions["splat"]
    armature.animation_data.action = action
    armature.animation_data.action_slot = action.slots[0]
    bpy.context.scene.frame_set(int(action.frame_end))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    baked = bpy.data.meshes.new_from_object(legs.evaluated_get(depsgraph))
    old = legs.data
    legs.modifiers.clear()
    legs.data = baked
    bpy.data.meshes.remove(old)
    legs.vertex_groups.clear()
    legs.parent = None
    legs.matrix_world = armature.matrix_world.copy()
    armature.animation_data.action = None
    rig.clear()


def export_glb(path: Path, objects: list, animations: bool = True) -> None:
    # The creator saved the rig in Pose Mode.
    active = bpy.context.view_layer.objects.active
    if active is not None and active.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[-1]
    settings = {
        "filepath": str(path),
        "export_format": "GLB",
        "use_selection": True,
        "export_yup": True,
        "export_apply": False,
        "export_materials": "EXPORT",
        "export_animations": animations,
        "export_animation_mode": "ACTIONS",
        "export_force_sampling": True,
        "export_anim_slide_to_zero": True,
        "export_skins": animations,
        "export_def_bones": False,
        "export_cameras": False,
        "export_lights": False,
    }
    available = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(**{key: value for key, value in settings.items() if key in available})


def main() -> None:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND), load_ui=False, use_scripts=False)
    mesh = bpy.data.objects.get(KEEP_OBJECTS[0])
    armature = bpy.data.objects.get(KEEP_OBJECTS[1])
    if mesh is None or armature is None:
        raise RuntimeError("Expected the ManThing_PSX mesh and PSX_Rig armature in %s." % SOURCE_BLEND)
    assign_default_skin(mesh)
    rig = Rig(armature)
    failures = []
    for clip in clips.CLIPS:
        action = clips.author(rig, clip)
        failures += ["%s: %s" % (clip.name, problem) for problem in anatomy.check(armature, mesh, clip, action)]
    if failures:
        raise RuntimeError("Clips fail the joint check (tools/blender/ridgeback/anatomy.py):\n" + "\n".join(failures))
    # Export from the bind pose, with no clip left playing on the rig.
    armature.animation_data.action = None
    rig.clear()
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(ANIMATED_BLEND), copy=True)
    export_glb(GLB_PATH, [mesh, armature])
    print("GLB=%s" % GLB_PATH)
    gore = gore_material()
    crawler = cut(mesh, "ManThing_Crawler", False, gore)
    export_glb(CRAWLER_PATH, [crawler, armature])
    print("GLB=%s" % CRAWLER_PATH)
    legs = cut(mesh, "ManThing_Legs", True, gore)
    bake_splat_pose(legs, armature, rig)
    export_glb(LEGS_PATH, [legs], animations=False)
    print("GLB=%s" % LEGS_PATH)
    print("CLIPS=%s" % ", ".join(sorted(action.name for action in bpy.data.actions)))


if __name__ == "__main__":
    main()
