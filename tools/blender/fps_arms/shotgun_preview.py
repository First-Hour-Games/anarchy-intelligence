"""Review renders and the game export of the shotgun clips in tools/blender/fps_arms/shotgun.py.

blender --background --factory-startup --disable-autoexec --python tools/blender/fps_arms/shotgun_preview.py \
    -- [--sheet out.png [--view game|outside]] [--video folder] [--export clips.glb] [clip names...]

Imports models/player/fpsWhite_holding_idle.glb (never written) and the shotgun and the shells the
left hand carries from models/props/weapons/shotgun/, authors the clips, puts the gun in the right hand
and the shells in the left, and swings the barrels open and shows the shells as each clip says. --sheet
and --video render as preview.py does for the pipe swings. --export writes the arms with the clips and
two empties, "ShotgunMount" on the right hand where the gun sits and "HandShellsMount" on the left where
the carried shells sit, with each clip's per-frame barrels and shells and its shot, loading and sound
times in a JSON file beside it, for tools/build_shotgun_clips.gd.
"""

import json
import math
import sys
from pathlib import Path
from types import SimpleNamespace

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import preview  # noqa: E402
import shotgun  # noqa: E402
import shotgun_layout as layout  # noqa: E402
import swings  # noqa: E402

GUN = preview.PROJECT / "models" / "props" / "weapons" / "shotgun" / "shotgun.glb"
SHELLS = GUN.with_name("shell_pair.glb")


def _import(path: Path) -> list:
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in before]


def load_gun(arms: swings.Arms, rig: shotgun.ShotgunRig) -> SimpleNamespace:
    """Imports the shotgun and hangs it from the right hand bone, and the shells the left hand carries
    from the left hand bone, each with a bare mount empty beside it for the export."""
    gun = _import(GUN)
    root = next(obj for obj in gun if obj.name.startswith("Shotgun") and obj.parent is None)
    carried = next(obj for obj in _import(SHELLS) if obj.type == "MESH")
    mount = bpy.data.objects.new("ShotgunMount", None)
    hand_mount = bpy.data.objects.new("HandShellsMount", None)
    for empty in (mount, hand_mount):
        bpy.context.scene.collection.objects.link(empty)
    arms.use(bpy.data.actions[swings.IDLE_ACTION])
    bpy.context.scene.frame_set(0)
    right = arms.world @ arms.bones["Hand.R"].matrix @ rig.mount()
    left = arms.world @ arms.bones["Hand.L"].matrix @ rig.shells_in_hand()
    for obj, bone, matrix in ((root, "Hand.R", right), (mount, "Hand.R", right), (carried, "Hand.L", left),
                              (hand_mount, "Hand.L", left)):
        obj.parent = arms.object
        obj.parent_type = "BONE"
        obj.parent_bone = bone
        bpy.context.view_layer.update()
        obj.matrix_world = matrix
    pipe = bpy.data.objects.get("MetalPipe_Hand_R")
    if pipe is not None:
        pipe.hide_render = True
        pipe.hide_viewport = True
    return SimpleNamespace(root=root, mount=mount, hand_mount=hand_mount, carried=carried,
                           barrels=next(obj for obj in gun if obj.name.startswith("Barrels")),
                           chamber=next(obj for obj in gun if obj.name.startswith("ChamberShells")))


def follow_gun(arms: swings.Arms, parts: SimpleNamespace) -> None:
    """While rendering, swings the barrels down on their hinge, shows the shells in the left hand and
    slides the shells in the chambers, by the playing clip's per-frame amounts."""
    parts.barrels.rotation_mode = "XYZ"
    rest = parts.barrels.rotation_euler.copy()
    seated = parts.chamber.location.copy()

    def follow(scene, *_):
        action = arms.object.animation_data.action

        def at(name, default):
            values = list(action.get(name, [])) if action else []
            return values[min(max(scene.frame_current, 0), len(values) - 1)] if values else default

        parts.barrels.rotation_euler = (rest.x - math.radians(layout.BREAK_ANGLE * at("open", 0.0)), rest.y, rest.z)
        parts.carried.hide_render = at("hand_shells", 0.0) < 0.5
        out = at("chamber_shells", 0.0)
        parts.chamber.hide_render = out < 0.0
        parts.chamber.location = seated + Vector((0.0, -max(out, 0.0), 0.0))

    bpy.app.handlers.frame_change_post.append(follow)


def export(arms: swings.Arms, parts: SimpleNamespace, actions, path: Path) -> None:
    arms.object.animation_data.action = None
    bpy.context.scene.render.fps = swings.FPS
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in (arms.object, parts.mount, parts.hand_mount) or
                       (obj.type == "MESH" and obj.parent == arms.object and obj.name.startswith("FPS_Arms")))
    bpy.context.view_layer.objects.active = arms.object
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
                              export_cameras=False, export_lights=False)
    notes = {action.name: {"fps": swings.FPS, "open": list(action["open"]), "break_angle": layout.BREAK_ANGLE,
                           "hand_shells": list(action["hand_shells"]), "chamber_shells": list(action["chamber_shells"]),
                           "loop": bool(action["loop"]), "shot": action.get("shot"), "loaded": action.get("loaded"),
                           "sounds": action["sounds"].to_dict() if "sounds" in action else {}}
             for action in actions}
    path.with_suffix(".json").write_text(json.dumps(notes), encoding="utf-8")
    print("EXPORT", path)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sheet = video = out = None
    view = "game"
    names = []
    index = 0
    while index < len(argv):
        if argv[index] in ("--sheet", "--view", "--video", "--export"):
            value = argv[index + 1]
            if argv[index] == "--sheet":
                sheet = Path(value).resolve()
            elif argv[index] == "--view":
                view = value
            elif argv[index] == "--video":
                video = Path(value).resolve()
            else:
                out = Path(value).resolve()
            index += 2
        else:
            names.append(argv[index])
            index += 1
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(preview.GLB))
    for obj in [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name == "Icosphere"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    arms = swings.Arms(next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"))
    rig = shotgun.ShotgunRig(arms)
    parts = load_gun(arms, rig)
    actions = [shotgun.author(rig, clip) for clip in shotgun.CLIPS if not names or clip.name in names]
    for action in actions:
        print("CLIP %-14s %s" % (action.name, preview.report(arms, action)))
    if out:
        export(arms, parts, actions, out)
    follow_gun(arms, parts)
    cameras = preview.stage()
    if sheet:
        preview.render_sheet(arms, actions, sheet, cameras[view])
    if video:
        preview.render_videos(arms, actions, video, cameras)


if __name__ == "__main__":
    main()
