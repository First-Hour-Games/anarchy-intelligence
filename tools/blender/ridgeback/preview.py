"""Contact sheets of The Ridgeback's authored clips, for reviewing poses without leaving Blender.

blender --background --factory-startup --disable-autoexec --python tools/blender/ridgeback/preview.py \
    -- [clip names...] [--out path.png] [--columns 8]

Opens the creator's THE_RIDGEBACK.blend (never saved), authors the named clips (all by default) and
renders each as two rows of frames, side on and from three-quarters front, in grey Workbench shading
on a floor, so stance, reach and silhouette read at a glance.
"""

import sys
from pathlib import Path

import bpy
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import clips  # noqa: E402
from rig import Rig  # noqa: E402

PROJECT = HERE.parents[2]
SOURCE = PROJECT / "models" / "source" / "the_ridgeback" / "vendor" / "THE_RIDGEBACK.blend"
CELL = (256, 288)


def stage():
    """A floor, two cameras and grey studio shading; everything else in the file stays hidden."""
    scene = bpy.context.scene
    keep = {"ManThing_PSX", "PSX_Rig"}
    for obj in scene.objects:
        obj.hide_render = obj.name not in keep
    bpy.ops.mesh.primitive_plane_add(size=8.0)
    scene.render.engine = "BLENDER_WORKBENCH"
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "SINGLE"
    shading.single_color = (0.72, 0.7, 0.66)
    shading.show_shadows = True
    shading.show_cavity = True
    scene.render.resolution_x, scene.render.resolution_y = CELL
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.world.color = (0.12, 0.13, 0.15)
    cameras = {}
    for name, place, target, ortho in (("side", (5.0, -0.25, 1.0), (0.0, -0.25, 0.95), True),
                                       ("front", (2.7, -3.6, 1.5), (0.0, -0.15, 0.95), False)):
        data = bpy.data.cameras.new("Preview_" + name)
        if ortho:
            data.type = "ORTHO"
            data.ortho_scale = 2.9
        else:
            data.lens = 42.0
        camera = bpy.data.objects.new("Preview_" + name, data)
        scene.collection.objects.link(camera)
        camera.location = place
        direction = (np_vector(target) - np_vector(place))
        camera.rotation_mode = "QUATERNION"
        camera.rotation_quaternion = to_track(direction)
        cameras[name] = camera
    return cameras


def np_vector(values):
    from mathutils import Vector
    return Vector(values)


def to_track(direction):
    return direction.to_track_quat("-Z", "Y")


def render_sheet(rig_object, actions, out_path, columns=8):
    scene = bpy.context.scene
    cameras = stage()
    rows = len(actions) * len(cameras)
    width, height = CELL
    sheet = np.zeros((rows * height, columns * width, 4), dtype=np.float32)
    scratch = Path(bpy.app.tempdir) / "ridgeback_preview_cell.png"
    row = 0
    for action in actions:
        rig_object.animation_data.action = action
        if rig_object.animation_data.action_slot is None and len(action.slots):
            rig_object.animation_data.action_slot = action.slots[0]
        start, end = (int(action.frame_start), int(action.frame_end))
        for camera in cameras.values():
            scene.camera = camera
            for column in range(columns):
                frame = start + (end - start) * column / columns
                scene.frame_set(int(frame), subframe=frame % 1.0)
                scene.render.filepath = str(scratch)
                bpy.ops.render.render(write_still=True)
                image = bpy.data.images.load(str(scratch), check_existing=False)
                pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
                bpy.data.images.remove(image)
                top = (rows - 1 - row) * height
                sheet[top:top + height, column * width:(column + 1) * width] = pixels
            row += 1
    result = bpy.data.images.new("ridgeback_sheet", columns * width, rows * height, alpha=False)
    result.pixels = sheet.ravel()
    result.filepath_raw = str(out_path)
    result.file_format = "PNG"
    result.save()
    print("SHEET", out_path, [action.name for action in actions])


VIDEO_SIZE = (640, 720)
VIEWS = {   # camera place, target, lens
    "front": ((2.3, -3.6, 1.3), (0.0, -0.2, 0.95), 52.0),
    "side": ((4.7, -0.3, 1.05), (0.0, -0.3, 0.95), 50.0),
}


def video_stage():
    """The textured creature on a dark checker floor: warm key light, cold rim from behind, a weak
    fill, EEVEE, H.264. Everything else in the creator's file stays hidden."""
    scene = bpy.context.scene
    for obj in scene.objects:
        obj.hide_render = obj.name not in ("ManThing_PSX", "PSX_Rig")
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.eevee.taa_render_samples = 12
    scene.render.resolution_x, scene.render.resolution_y = VIDEO_SIZE
    scene.render.resolution_percentage = 100
    scene.world.use_nodes = True
    background = next(node for node in scene.world.node_tree.nodes if node.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.012, 0.013, 0.016, 1.0)
    background.inputs["Strength"].default_value = 1.0
    bpy.ops.mesh.primitive_plane_add(size=14.0)
    floor = bpy.context.active_object
    material = bpy.data.materials.new("PreviewFloor")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    checker = nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 28.0
    checker.inputs["Color1"].default_value = (0.045, 0.045, 0.05, 1.0)
    checker.inputs["Color2"].default_value = (0.075, 0.075, 0.08, 1.0)
    material.node_tree.links.new(checker.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.9
    floor.data.materials.append(material)
    for name, rotation, energy, colour in (("Key", (52.0, 0.0, -38.0), 3.2, (1.0, 0.86, 0.7)),
                                          ("Rim", (60.0, 0.0, 160.0), 4.0, (0.55, 0.68, 1.0)),
                                          ("Fill", (70.0, 0.0, 60.0), 0.6, (0.7, 0.75, 0.85))):
        data = bpy.data.lights.new("Preview" + name, "SUN")
        data.energy = energy
        data.color = colour
        light = bpy.data.objects.new("Preview" + name, data)
        light.rotation_euler = [radian for radian in map(lambda d: d * 3.14159265 / 180.0, rotation)]
        scene.collection.objects.link(light)
    settings = scene.render.image_settings
    try:
        settings.media_type = "VIDEO"
    except (AttributeError, TypeError):
        pass
    settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    scene.render.ffmpeg.ffmpeg_preset = "GOOD"
    cameras = {}
    for name, (place, target, lens) in VIEWS.items():
        data = bpy.data.cameras.new("Video_" + name)
        data.lens = lens
        camera = bpy.data.objects.new("Video_" + name, data)
        scene.collection.objects.link(camera)
        camera.location = place
        camera.rotation_mode = "QUATERNION"
        camera.rotation_quaternion = to_track(np_vector(target) - np_vector(place))
        cameras[name] = camera
    return cameras


def render_videos(rig_object, actions, out_dir, views=("front", "side")):
    """One MP4 per clip and view. Loops cover one cycle so the video loops cleanly; one-shots hold
    their first pose for a third of a second and their last for half a second."""
    scene = bpy.context.scene
    cameras = video_stage()
    out_dir.mkdir(parents=True, exist_ok=True)
    for action in actions:
        rig_object.animation_data.action = action
        if len(action.slots):
            rig_object.animation_data.action_slot = action.slots[0]
        start, end = (int(round(value)) for value in action.frame_range)
        if action.use_cyclic:
            scene.frame_start, scene.frame_end = start, end - 1
        else:
            scene.frame_start, scene.frame_end = start - 8, end + 12
        for view in views:
            scene.camera = cameras[view]
            target = out_dir / ("%s_%s.mp4" % (action.name, view))
            for old in out_dir.glob("%s_%s*.mp4" % (action.name, view)):
                old.unlink()
            scene.render.filepath = str(out_dir / ("%s_%s" % (action.name, view)))
            bpy.ops.render.render(animation=True)
            made = sorted(out_dir.glob("%s_%s*.mp4" % (action.name, view)))
            if made and made[0] != target:
                made[0].rename(target)
            print("VIDEO", target.name)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    out = PROJECT.parent / "captures" / "ridgeback_preview.png"
    columns = 8
    video_dir = None
    originals = False
    names = []
    index = 0
    while index < len(argv):
        if argv[index] == "--out":
            out = Path(argv[index + 1]).resolve()
            index += 2
        elif argv[index] == "--columns":
            columns = int(argv[index + 1])
            index += 2
        elif argv[index] == "--video":
            video_dir = Path(argv[index + 1]).resolve()
            index += 2
        elif argv[index] == "--originals":
            originals = True
            index += 1
        else:
            names.append(argv[index])
            index += 1
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    rig = Rig(bpy.data.objects["PSX_Rig"])
    chosen = [clip for clip in clips.CLIPS if not names or clip.name in names]
    actions = [clips.author(rig, clip) for clip in chosen]
    if video_dir is None:
        render_sheet(rig.object, actions, out, columns)
        return
    skin = PROJECT / "models" / "source" / "the_ridgeback" / "vendor" / "textures" / "ManThing_flesh.png"
    for node in bpy.data.objects["ManThing_PSX"].data.materials[0].node_tree.nodes:
        if node.type == "TEX_IMAGE":
            node.image = bpy.data.images.load(str(skin), check_existing=True)
    if originals:
        for action in bpy.data.actions:
            if action.name.startswith("ManThing_"):
                # Their manual range is unset; cycling over it would freeze them on one pose.
                start, end = action.frame_range
                action.use_frame_range = True
                action.frame_start, action.frame_end = start, end
                action.use_cyclic = action.name in ("ManThing_IDLE", "ManThing_WALK", "ManThing_CHASE")
                actions.append(action)
    render_videos(rig.object, actions, video_dir,
                  views=("front", "side"))


if __name__ == "__main__":
    main()
