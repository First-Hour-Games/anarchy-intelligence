"""Build the first-person pipe swings the game plays: models/player/pipe_swings.tres.

Authors every swing in tools/blender/fps_arms/swings.py onto the arms of
models/player/fpsWhite_holding_idle.glb (read, never written) and exports them with the arms to a
temporary GLB, with each swing's impact time and per-frame pipe slide in a JSON file beside it. Then
it runs Godot's tools/build_pipe_swings.gd, which turns the clips into one AnimationLibrary keyed on
the arms' own node paths, adding the pipe's slide through the hands as a track on the pipe.
pipe_weapon.gd adds that library to the arms and plays its swing_clip. The library holds
swing_downswing, the game's swing, and swing_bat, kept for later.

To change a swing, edit its keys in swings.py, review it with tools/blender/fps_arms/preview.py, and
rebuild with this script.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_pipe_swings.py

Set GODOT_CONSOLE to the Godot console executable if it is not under %LOCALAPPDATA%\\Programs\\Godot.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent / "fps_arms"))

import preview  # noqa: E402
import swings  # noqa: E402

LIBRARY = PROJECT_ROOT / "models" / "player" / "pipe_swings.tres"


def godot_console() -> str:
    if os.environ.get("GODOT_CONSOLE"):
        return os.environ["GODOT_CONSOLE"]
    found = sorted((Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Godot").rglob("Godot_v4.7*_console.exe"))
    if not found:
        raise SystemExit("Godot 4.7 console executable not found. Set GODOT_CONSOLE to its path.")
    return str(found[-1])


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(preview.GLB))
    for obj in [obj for obj in bpy.context.scene.objects if obj.type == "MESH" and obj.name == "Icosphere"]:
        bpy.data.objects.remove(obj, do_unlink=True)
    arms = swings.Arms(next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"))
    for swing in swings.SWINGS:
        action = swings.author(arms, swing)
        print("CLIP %-16s %s" % (action.name, preview.report(arms, action)))
    folder = Path(tempfile.mkdtemp(prefix="pipe_swings_"))
    clips = folder / "pipe_swings.glb"
    preview.export_clips(arms, clips)
    result = subprocess.run([godot_console(), "--headless", "--path", str(PROJECT_ROOT),
                             "--script", "res://tools/build_pipe_swings.gd", "--",
                             clips.as_posix(), clips.with_suffix(".json").as_posix(),
                             "res://" + LIBRARY.relative_to(PROJECT_ROOT).as_posix()])
    if result.returncode != 0:
        raise SystemExit("tools/build_pipe_swings.gd failed")
    print("LIBRARY", LIBRARY)


if __name__ == "__main__":
    main()
