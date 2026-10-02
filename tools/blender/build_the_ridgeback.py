"""Rebuild The Ridgeback as a GLB with a default skin assigned.

The vendor FBX's "PSX_ManThing" material has no texture wired up (the
artist ships eight interchangeable skins as loose PNGs instead of baking
one in). This script imports the FBX, wires the "flesh" skin onto the
material's base color, and re-exports as a GLB so it renders textured out
of the box. The other seven skins remain available under
models/enemies/the_ridgeback/textures/ for a future material-swap system.
"""

from pathlib import Path

import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_FBX = PROJECT_ROOT / "models" / "source" / "the_ridgeback" / "vendor" / "THE_RIDGEBACK.fbx"
DEFAULT_SKIN = PROJECT_ROOT / "models" / "source" / "the_ridgeback" / "vendor" / "textures" / "ManThing_flesh.png"
GLB_PATH = PROJECT_ROOT / "models" / "enemies" / "the_ridgeback" / "THE_RIDGEBACK.glb"

KEEP_OBJECTS = {"ManThing_PSX", "PSX_Rig"}


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.actions, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            datablocks.remove(datablock)


def assign_default_skin(mesh: bpy.types.Object) -> None:
    material = mesh.data.materials[0]
    material.use_nodes = True
    node_tree = material.node_tree
    principled = node_tree.nodes.get("Principled BSDF")
    if principled is None:
        raise RuntimeError("Expected a Principled BSDF node on PSX_ManThing.")

    image = bpy.data.images.load(str(DEFAULT_SKIN))
    texture_node = node_tree.nodes.new("ShaderNodeTexImage")
    texture_node.image = image
    node_tree.links.new(texture_node.outputs["Color"], principled.inputs["Base Color"])


def clean_action_names() -> None:
    # Blender's FBX importer keeps the original take name ("PSX_Rig|ManThing_IDLE")
    # as the Action name, which then doubles up with the armature name again when
    # the glTF exporter writes "ArmatureName|ActionName". Strip the FBX-side
    # prefix so the exported clips are just "ManThing_IDLE" etc.
    for action in bpy.data.actions:
        if "|" in action.name:
            action.name = action.name.split("|")[-1]


def main() -> None:
    clear_scene()
    bpy.ops.import_scene.fbx(filepath=str(SOURCE_FBX))
    clean_action_names()

    for obj in list(bpy.data.objects):
        if obj.name not in KEEP_OBJECTS:
            bpy.data.objects.remove(obj, do_unlink=True)
    for light in list(bpy.data.lights):
        bpy.data.lights.remove(light)
    for camera in list(bpy.data.cameras):
        bpy.data.cameras.remove(camera)

    mesh = bpy.data.objects.get("ManThing_PSX")
    armature = bpy.data.objects.get("PSX_Rig")
    if mesh is None or armature is None:
        raise RuntimeError("Expected ManThing_PSX mesh and PSX_Rig armature not found.")

    assign_default_skin(mesh)

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
