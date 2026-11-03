"""Review renders of the pipe swings in tools/blender/fps_arms/swings.py, from the game's own camera.

blender --background --factory-startup --disable-autoexec --python tools/blender/fps_arms/preview.py \
    -- [--sheet out.png [--view game|outside]] [--video folder] [--export clips.glb] [swing names...]

Imports models/player/fpsWhite_holding_idle.glb (never written), authors the swings plus the team's
Pipe_Swing resampled the way the game used to play it ("swing_original"), and prints each one's joint
report: the elbow's bend, and how far the wrist and the upper arm turn from the idle pose. --sheet
renders a contact sheet from the game camera, one row per swing, a frame every 0.05 s. --video renders
MP4s from the game camera (4:3, 74 degrees, as in the game) and from outside, holding the idle pose a
moment before and after the swing. tools/blender/build_pipe_swings.py builds the swings for the game.
"""

import math
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import swings  # noqa: E402

PROJECT = HERE.parents[2]
GLB = PROJECT / "models" / "player" / "fpsWhite_holding_idle.glb"
FEET = swings.EYE.z - 1.65
HOLD_BEFORE, HOLD_AFTER = 8, 12


def follow_slides(arms):
    """While rendering, slides the pipe up through the right hand by the playing clip's per-frame amount,
    so the hands sit lower on it, as the game does with a track on the pipe."""
    pipe = bpy.data.objects["MetalPipe_Hand_R"]
    hand = arms.world @ arms.bones["Hand.R"].matrix
    offset = hand.inverted() @ pipe.matrix_world

    def slide(scene, *_):
        action = arms.object.animation_data.action
        slides = list(action.get("slide", [])) if action else []
        index = min(max(scene.frame_current, 0), len(slides) - 1) if slides else -1
        hand = arms.world @ arms.bones["Hand.R"].matrix
        amount = slides[index] if index >= 0 else 0.0
        axis = (hand.to_3x3() @ arms.pipe_axis).normalized()
        pipe.matrix_world = Matrix.Translation(axis * amount) @ hand @ offset

    bpy.app.handlers.frame_change_post.append(slide)


def stage():
    scene = bpy.context.scene
    scene.render.fps = swings.FPS
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.eevee.taa_render_samples = 16
    scene.world = bpy.data.worlds.new("Night")
    scene.world.use_nodes = True
    background = next(n for n in scene.world.node_tree.nodes if n.type == "BACKGROUND")
    background.inputs["Color"].default_value = (0.02, 0.022, 0.028, 1.0)
    for name, size, place, rotation in (("Floor", 30.0, (0.0, -4.0, FEET), (0.0, 0.0, 0.0)),
                                        ("Wall", 12.0, (0.0, -6.0, FEET + 6.0), (math.radians(90), 0.0, 0.0))):
        bpy.ops.mesh.primitive_plane_add(size=size, location=place, rotation=rotation)
        plane = bpy.context.active_object
        plane.name = name
        material = bpy.data.materials.new(name)
        material.use_nodes = True
        nodes = material.node_tree.nodes
        shader = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
        checker = nodes.new("ShaderNodeTexChecker")
        checker.inputs["Scale"].default_value = size * 1.5
        checker.inputs["Color1"].default_value = (0.05, 0.05, 0.055, 1.0)
        checker.inputs["Color2"].default_value = (0.085, 0.085, 0.09, 1.0)
        material.node_tree.links.new(checker.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = 0.9
        plane.data.materials.append(material)
    for name, kind, energy, place, colour in (("Held", "POINT", 25.0, (0.15, 0.2, 0.45), (0.85, 0.9, 1.0)),
                                              ("Moon", "SUN", 1.2, None, (0.6, 0.68, 0.9))):
        data = bpy.data.lights.new(name, kind)
        data.energy = energy
        data.color = colour
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        if place:
            light.location = place
        else:
            light.rotation_euler = (math.radians(55), 0.0, math.radians(-30))
    cameras = {}
    game = bpy.data.cameras.new("Game")
    game.sensor_fit = "VERTICAL"
    game.angle_y = math.radians(swings.FOV_Y)
    game.clip_start = 0.05
    cameras["game"] = bpy.data.objects.new("Game", game)
    cameras["game"].location = swings.EYE
    cameras["game"].rotation_mode = "QUATERNION"
    cameras["game"].rotation_quaternion = swings.FORWARD.to_track_quat("-Z", "Y")
    outside = bpy.data.cameras.new("Outside")
    outside.lens = 32.0
    cameras["outside"] = bpy.data.objects.new("Outside", outside)
    place, target = Vector((-0.95, -1.05, 0.42)), Vector((-0.05, -0.32, -0.02))
    cameras["outside"].location = place
    cameras["outside"].rotation_mode = "QUATERNION"
    cameras["outside"].rotation_quaternion = (target - place).to_track_quat("-Z", "Y")
    for camera in cameras.values():
        scene.collection.objects.link(camera)
    return cameras


def report(arms, action):
    """For each arm, the largest elbow bend, and how far the wrist and the upper arm turn from idle."""
    arms.use(action)
    worst = {}
    idle = {side: (arms.idle_basis["Hand." + side].to_quaternion(),
                   (arms.world @ arms.idle_upper["UpperArm." + side]).to_quaternion()) for side in swings.SIDES}
    for frame in range(int(action.frame_end) + 1):
        bpy.context.scene.frame_set(frame)
        for side in swings.SIDES:
            pb = arms.bones
            upper = arms.world @ pb["UpperArm." + side].matrix
            lower = arms.world @ pb["LowerArm." + side].matrix
            bend = math.degrees(upper.to_3x3().col[1].angle(lower.to_3x3().col[1]))
            wrist = math.degrees(idle[side][0].rotation_difference(pb["Hand." + side].matrix_basis.to_quaternion()).angle)
            turn = idle[side][1].rotation_difference(upper.to_quaternion())
            axis = upper.to_3x3().col[1].normalized()
            twist = abs(math.degrees(2.0 * math.atan2(Vector(turn[1:]).dot(axis), turn.w)))
            twist = min(twist, 360.0 - twist)
            # The forearm's roll round its own length against the upper arm, from the rest pose the skin
            # is bound to: what twists the skin at the elbow.
            change = pb["LowerArm." + side].matrix_basis.to_quaternion()
            elbow_twist = abs(swings.signed_angle(Quaternion((change.w, 0.0, change.y, 0.0)).normalized()))
            for key, value in (("elbow", bend), ("wrist", wrist), ("shoulder twist", twist), ("elbow twist", elbow_twist)):
                key = "%s %s" % (side, key)
                if value > worst.get(key, (0.0, 0))[0]:
                    worst[key] = (value, frame)
    parts = ["%s %.0f (f%d)" % (key, value, frame) for key, (value, frame) in sorted(worst.items())]
    if "pipe_error" in action:
        parts.append("pipe short of its keys by up to %.0f deg" % action["pipe_error"])
    if "eye_gap" in action:
        parts.append("pipe comes within %.2f m of the eye" % action["eye_gap"])
    return ", ".join(parts)


def render_sheet(arms, actions, out, camera, columns=16, cell=(320, 240)):
    scene = bpy.context.scene
    scene.camera = camera
    scene.render.resolution_x, scene.render.resolution_y = cell
    width, height = cell
    sheet = np.zeros((len(actions) * height, columns * width, 4), dtype=np.float32)
    scratch = Path(bpy.app.tempdir) / "fps_arms_cell.png"
    for row, action in enumerate(actions):
        arms.use(action)
        for column in range(columns):
            frame = round(column * 0.05 * swings.FPS)
            scene.frame_set(min(frame, int(action.frame_end)))
            scene.render.filepath = str(scratch)
            bpy.ops.render.render(write_still=True)
            image = bpy.data.images.load(str(scratch), check_existing=False)
            pixels = np.array(image.pixels[:], dtype=np.float32).reshape(height, width, 4)
            bpy.data.images.remove(image)
            top = (len(actions) - 1 - row) * height
            sheet[top:top + height, column * width:(column + 1) * width] = pixels
    result = bpy.data.images.new("sheet", columns * width, len(actions) * height, alpha=False)
    result.pixels = sheet.ravel()
    result.filepath_raw = str(out)
    result.file_format = "PNG"
    result.save()
    print("SHEET", out)


def render_videos(arms, actions, folder, cameras):
    scene = bpy.context.scene
    folder.mkdir(parents=True, exist_ok=True)
    settings = scene.render.image_settings
    try:
        settings.media_type = "VIDEO"
    except (AttributeError, TypeError):
        pass
    settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    sizes = {"game": (640, 480), "outside": (640, 480)}
    for action in actions:
        arms.use(action)
        scene.frame_start, scene.frame_end = -HOLD_BEFORE, int(action.frame_end) + HOLD_AFTER
        for view, camera in cameras.items():
            scene.camera = camera
            scene.render.resolution_x, scene.render.resolution_y = sizes[view]
            target = folder / ("%s_%s.mp4" % (action.name, view))
            for old in folder.glob("%s_%s*.mp4" % (action.name, view)):
                old.unlink()
            scene.render.filepath = str(folder / ("%s_%s" % (action.name, view)))
            bpy.ops.render.render(animation=True)
            made = sorted(folder.glob("%s_%s*.mp4" % (action.name, view)))
            if made and made[0] != target:
                made[0].rename(target)
            print("VIDEO", target.name)


def export_clips(arms, path):
    """Writes the arms with every clip to a GLB, for playing the swings in the game without touching
    the model the game loads."""
    arms.object.animation_data.action = None
    bpy.context.scene.render.fps = swings.FPS        # the clips are keyed at FPS; the export times them by it
    for obj in bpy.context.scene.objects:
        obj.select_set(obj.type in ("ARMATURE", "MESH"))
    bpy.context.view_layer.objects.active = arms.object
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_cameras=False, export_lights=False)
    # How far the pipe slides up through the hands, per frame, for the game to key on the pipe, and
    # when each swing's hit lands.
    import json
    impacts = {swing.name: swing.impact for swing in swings.SWINGS}
    slides = {action.name: {"fps": swings.FPS, "slide": list(action.get("slide", [])),
                            "impact": impacts.get(action.name)}
              for action in bpy.data.actions if "slide" in action}
    path.with_suffix(".json").write_text(json.dumps(slides), encoding="utf-8")
    print("EXPORT", path)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sheet = video = export = None
    view = "game"
    names = []
    index = 0
    while index < len(argv):
        if argv[index] == "--sheet":
            sheet = Path(argv[index + 1]).resolve()
            index += 2
        elif argv[index] == "--view":
            view = argv[index + 1]
            index += 2
        elif argv[index] == "--video":
            video = Path(argv[index + 1]).resolve()
            index += 2
        elif argv[index] == "--export":
            export = Path(argv[index + 1]).resolve()
            index += 2
        else:
            names.append(argv[index])
            index += 1
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    for obj in [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name == "Icosphere"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    arms = swings.Arms(armature)
    actions = [swings.retime_original(arms)]
    actions += [swings.author(arms, swing) for swing in swings.SWINGS if not names or swing.name in names]
    for action in actions:
        print("CLIP %-16s %s" % (action.name, report(arms, action)))
    if export:
        export_clips(arms, export)
    follow_slides(arms)
    cameras = stage()
    if sheet:
        render_sheet(arms, actions, sheet, cameras[view])
    if video:
        render_videos(arms, actions, video, cameras)


if __name__ == "__main__":
    main()
