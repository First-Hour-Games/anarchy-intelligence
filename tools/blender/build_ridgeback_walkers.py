"""Build the ten walkers, the alt route's rooftop Ridgebacks, from the creator's Ridgeback.

Each walker (tools/blender/ridgeback/walkers.py) is the creator's mesh grown into something new on the same
rig, so every clip in THE_RIDGEBACK.glb plays on it. One GLB a walker, in models/enemies/the_ridgeback/
walkers/, holds three meshes and no clips:
  Walker         the whole body, skinned to the rig;
  WalkerCrawler  the same with its legs cut away and the stumps closed, as THE_RIDGEBACK_crawler.glb is;
  WalkerLegs     the legs on their own, posed as the splat clip ends, as THE_RIDGEBACK_legs.glb is.
The game draws them on the original models' skeletons (scenes/monsters/the_ridgeback/
ridgeback_faller_visual.gd). walkers.json beside them lists each walker's look: its skin, its eyes (bone,
place and glow), how much bigger it is drawn and its voice's pitch. The creator's file is opened, never
saved, and the original Ridgeback's GLBs are not touched.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_ridgeback_walkers.py \
    [-- [--only spine,twin] [--preview <folder>]]

--preview also renders each walker standing on its ledge (three-quarters front, side, three-quarters back),
the crawler mid-crawl and the fallen legs, as PNGs in the folder.
"""

import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "ridgeback"))

import build_the_ridgeback as base  # noqa: E402
import clips  # noqa: E402
import walkers  # noqa: E402
from rig import Rig  # noqa: E402

OUT_DIR = base.PROJECT_ROOT / "models" / "enemies" / "the_ridgeback" / "walkers"
SKINS = base.SOURCE_DIR / "vendor" / "textures"
MANIFEST = OUT_DIR / "walkers.json"


def assign_skin(mesh: bpy.types.Object, skin: str) -> None:
    """One of the creator's skins on the plain material the original ships with."""
    material = mesh.data.materials[0]
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(SKINS / ("ManThing_%s.png" % skin)), check_existing=True)
    shader.inputs["Metallic"].default_value = 0.0
    shader.inputs["Roughness"].default_value = 0.4
    links = material.node_tree.links
    links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    material.use_backface_culling = False


def godot(point: Vector) -> list:
    """A rest-space point in the GLB's (and the Skeleton3D's) axes: y up, the body facing +z."""
    return [round(point.x, 4), round(point.z, 4), round(-point.y, 4)]


def export(path: Path, objects: list) -> None:
    active = bpy.context.view_layer.objects.active
    if active is not None and active.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[-1]
    settings = {
        "filepath": str(path), "export_format": "GLB", "use_selection": True, "export_yup": True,
        "export_apply": False, "export_materials": "EXPORT", "export_animations": False, "export_skins": True,
        "export_def_bones": False, "export_cameras": False, "export_lights": False,
    }
    available = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(**{key: value for key, value in settings.items() if key in available})


def build(walker: dict, preview: Path = None) -> dict:
    bpy.ops.wm.open_mainfile(filepath=str(base.SOURCE_BLEND), load_ui=False, use_scripts=False)
    mesh = bpy.data.objects[base.KEEP_OBJECTS[0]]
    armature = bpy.data.objects[base.KEEP_OBJECTS[1]]
    rig = Rig(armature)
    armature.animation_data_create()
    armature.animation_data.action = None
    rig.clear()
    assign_skin(mesh, walker["skin"])
    gore = base.gore_material()
    gore.diffuse_color = (0.22, 0.012, 0.01, 1.0)
    body = walkers.Body(mesh, random.Random(walker["name"]), gore)
    walker["build"](body)
    eyes = body.eyes
    body.finish()
    mesh.name = mesh.data.name = "Walker"
    crawler = base.cut(mesh, "WalkerCrawler", False, gore)
    legs = base.cut(mesh, "WalkerLegs", True, gore)
    clips.author(rig, next(clip for clip in clips.CLIPS if clip.name == "splat"))
    base.bake_splat_pose(legs, armature, rig)
    path = OUT_DIR / ("walker_%s.glb" % walker["name"])
    export(path, [mesh, crawler, legs, armature])
    print("GLB=%s faces=%d" % (path, len(mesh.data.polygons)))
    if preview is not None:
        render_preview(walker["name"], preview, mesh, crawler, legs, armature, rig)
    glow = walker["eyes"]
    second = walker.get("second", glow)
    return dict(
        title=walker["title"], model="res://models/enemies/the_ridgeback/walkers/" + path.name, skin=walker["skin"],
        scale=walker["scale"], pitch=walker["pitch"],
        eyes=[dict(bone=eye["bone"], position=godot(eye["at"]), glow=list(second if eye["second"] else glow)) for eye in eyes])


def render_preview(name: str, folder: Path, whole, crawler, legs, armature, rig: Rig) -> None:
    scene = bpy.context.scene
    keep = {whole.name, crawler.name, legs.name, armature.name}
    for obj in scene.objects:
        obj.hide_render = obj.name not in keep
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "TEXTURE"
    shading.show_shadows = False
    scene.render.resolution_x, scene.render.resolution_y = 360, 480
    scene.world.color = (0.16, 0.17, 0.19)
    camera = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = "ORTHO"
    folder.mkdir(parents=True, exist_ok=True)

    def shoot(label: str, yaw: float, centre: tuple, size: float, show: set) -> None:
        for obj in (whole, crawler, legs):
            obj.hide_render = obj.name not in show
        camera.data.ortho_scale = size
        a = math.radians(yaw)
        target = Vector(centre)
        camera.location = target + Vector((math.sin(a) * 6.0, -math.cos(a) * 6.0, 0.6))
        camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(folder / ("%s_%s.png" % (name, label)))
        bpy.ops.render.render(write_still=True)

    clips.author(rig, next(clip for clip in clips.CLIPS if clip.name == "ledge"))
    scene.frame_set(8)
    for label, yaw in (("front", 30.0), ("side", 90.0), ("back", 150.0)):
        shoot(label, yaw, (0.0, 0.0, 1.15), 2.9, {whole.name})
    shoot("bust", 25.0, (0.0, -0.2, 1.62), 1.25, {whole.name})
    clips.author(rig, next(clip for clip in clips.CLIPS if clip.name == "crawl"))
    scene.frame_set(6)
    shoot("crawler", 40.0, (0.0, -0.4, 0.35), 2.6, {crawler.name})
    armature.animation_data.action = None
    rig.clear()
    shoot("legs", 40.0, (0.0, 0.3, 0.3), 2.6, {legs.name})


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = None
    preview = None
    for index, arg in enumerate(args):
        if arg == "--only":
            only = set(args[index + 1].split(","))
        elif arg == "--preview":
            preview = Path(args[index + 1])
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8")) if MANIFEST.exists() else {}
    for walker in walkers.WALKERS:
        if only is not None and walker["name"] not in only:
            continue
        manifest[walker["name"]] = build(walker, preview)
    order = [walker["name"] for walker in walkers.WALKERS]
    manifest = {name: manifest[name] for name in order if name in manifest}
    MANIFEST.write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8", newline="\n")
    print("WALKERS=%s" % ", ".join(manifest))


if __name__ == "__main__":
    main()
