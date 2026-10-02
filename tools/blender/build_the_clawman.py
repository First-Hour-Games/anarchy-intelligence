"""Rebuild The Clawman as a clean GLB.

The vendor FBX bundles the store-page render booth (CV_Floor, CV_WallL/R,
CV_Ceil, CV_Back, CV_Panel, CV_Crate(2), CV_Slab, plus CV_Key/Rim/Amb lights
and CV_Cam) alongside the actual "Monster_PSX" mesh and "Monster_Rig"
armature. This script keeps only the monster mesh and armature.

Separately, Godot's built-in FBX importer (modules/fbx/fbx_document.cpp)
crashes on a malformed light object embedded in the vendor FBX ("Parameter
'light' is null"), which aborts the whole scene import. Blender's FBX
importer tolerates it fine, so this script re-exports as a GLB with no light
or camera data, sidestepping the bug entirely.
"""

from pathlib import Path

import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_FBX = PROJECT_ROOT / "models" / "source" / "the_clawman" / "vendor" / "TheClawman.fbx"
GLB_PATH = PROJECT_ROOT / "models" / "enemies" / "the_clawman" / "TheClawman.glb"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


KEEP_OBJECTS = {"Monster_PSX", "Monster_Rig"}


def main() -> None:
    clear_scene()
    bpy.ops.import_scene.fbx(filepath=str(SOURCE_FBX))

    for obj in list(bpy.data.objects):
        if obj.name not in KEEP_OBJECTS:
            bpy.data.objects.remove(obj, do_unlink=True)
    for light in list(bpy.data.lights):
        bpy.data.lights.remove(light)
    for camera in list(bpy.data.cameras):
        bpy.data.cameras.remove(camera)

    mesh = bpy.data.objects.get("Monster_PSX")
    armature = bpy.data.objects.get("Monster_Rig")
    if mesh is None or armature is None:
        raise RuntimeError("Expected Monster_PSX mesh and Monster_Rig armature not found.")

    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    GLB_PATH.parent.mkdir(parents=True, exist_ok=True)
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
        export_skins=True,
        export_def_bones=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"GLB={GLB_PATH}")


if __name__ == "__main__":
    main()
