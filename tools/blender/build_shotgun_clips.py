"""Build the first-person shotgun clips the game plays: models/player/shotgun_clips.tres.

Authors every clip in tools/blender/fps_arms/shotgun.py onto the arms of
models/player/fpsWhite_holding_idle.glb (read, never written), with the gun from
models/props/weapons/shotgun/shotgun.glb (build_shotgun.py) in the right hand, and exports them to a
temporary GLB, with how far each clip opens the barrels per frame, its shot and loading times and
whether it loops in a JSON file beside it. Then it runs Godot's tools/build_shotgun_clips.gd, which
turns the clips into one AnimationLibrary on the arms' own node paths, with the barrels' swing on the
hinge as a track and where the gun sits in the hand as metadata. shotgun_weapon.gd hangs the gun from
the hand there and plays the clips.

To change a clip, edit its keys in shotgun.py, review it with tools/blender/fps_arms/shotgun_preview.py,
and rebuild with this script.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_shotgun_clips.py

Set GODOT_CONSOLE to the Godot console executable if it is not under %LOCALAPPDATA%\\Programs\\Godot.
"""

import subprocess
import sys
import tempfile
from pathlib import Path

import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(Path(__file__).resolve().parent / "fps_arms"))

from build_pipe_swings import godot_console  # noqa: E402
import preview  # noqa: E402
import shotgun  # noqa: E402
import shotgun_preview  # noqa: E402
import swings  # noqa: E402

LIBRARY = PROJECT_ROOT / "models" / "player" / "shotgun_clips.tres"


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(preview.GLB))
    for obj in [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name == "Icosphere"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    arms = swings.Arms(next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"))
    rig = shotgun.ShotgunRig(arms)
    parts = shotgun_preview.load_gun(arms, rig)
    actions = []
    for clip in shotgun.CLIPS:
        action = shotgun.author(rig, clip)
        actions.append(action)
        print("CLIP %-16s %s" % (action.name, preview.report(arms, action)))
    clips = Path(tempfile.mkdtemp(prefix="shotgun_clips_")) / "shotgun_clips.glb"
    shotgun_preview.export(arms, parts, actions, clips)
    result = subprocess.run([godot_console(), "--headless", "--path", str(PROJECT_ROOT),
                             "--script", "res://tools/build_shotgun_clips.gd", "--",
                             clips.as_posix(), clips.with_suffix(".json").as_posix(),
                             "res://" + LIBRARY.relative_to(PROJECT_ROOT).as_posix()])
    if result.returncode != 0:
        raise SystemExit("tools/build_shotgun_clips.gd failed")
    print("LIBRARY", LIBRARY)


if __name__ == "__main__":
    main()
