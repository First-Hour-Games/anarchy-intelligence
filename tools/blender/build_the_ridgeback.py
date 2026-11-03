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

blender --background --factory-startup --disable-autoexec --python tools/blender/build_the_ridgeback.py
"""

import sys
from pathlib import Path

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

KEEP_OBJECTS = ("ManThing_PSX", "PSX_Rig")


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


def export_glb(mesh: bpy.types.Object, armature: bpy.types.Object) -> None:
    # The creator saved the rig in Pose Mode.
    active = bpy.context.view_layer.objects.active
    if active is not None and active.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    settings = {
        "filepath": str(GLB_PATH),
        "export_format": "GLB",
        "use_selection": True,
        "export_yup": True,
        "export_apply": False,
        "export_materials": "EXPORT",
        "export_animations": True,
        "export_animation_mode": "ACTIONS",
        "export_force_sampling": True,
        "export_anim_slide_to_zero": True,
        "export_skins": True,
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
    export_glb(mesh, armature)
    print("GLB=%s" % GLB_PATH)
    print("CLIPS=%s" % ", ".join(sorted(action.name for action in bpy.data.actions)))


if __name__ == "__main__":
    main()
