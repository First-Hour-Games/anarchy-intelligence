"""Headless renders of the built hospital interior, for checking equipment placements.

blender --background --python tools/blender/hospital_dressing/render_zone.py -- --out <dir>
    [--plan=x0,x1,z0,z1]... [--shot=ex,ey,ez,tx,ty,tz]... [--files dressing_rules,dressing_west] [--size 900]
(write --plan=... and --shot=... with "=" so negative numbers are not read as options)

Opens Hospital_V2.blend without saving it, rebuilds the interior (with the Godot model
previews) and renders Workbench images into --out:
- plan_<n>.png: orthographic top-down view of a rectangle in game x/z, with the ceiling and
  exterior hidden and a 1 m floor grid labelled every 2 m. Image right is +x (east), image up is
  -z (toward the back wall).
- shot_<n>.png: perspective view from an eye point to a target point (game metres; eye height
  is about 1.65 above the 0.12 floor).
--files limits which hospital_layout/dressing_*.py files are built (default: all).
"""

import argparse
import os
import runpy
import sys
from math import radians
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
BUILDER = HERE.parent / "build_hospital_interior.py"
CEILING_PREFIXES = ("Ceiling_Drop", "CeilingGrid", "PlenumLid", "PlenumDuct", "CeilingPanel", "CorridorSaggingTile")


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--plan", action="append", default=[])
    parser.add_argument("--shot", action="append", default=[])
    parser.add_argument("--files", default="")
    parser.add_argument("--size", type=int, default=900)
    return parser.parse_args(argv)


def numbers(text: str, count: int) -> list:
    values = [float(v) for v in text.replace(" ", "").split(",")]
    if len(values) != count:
        sys.exit(f"expected {count} numbers in {text!r}")
    return values


def setup(size: int) -> bpy.types.Object:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 0.75)
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = False
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    scene.display.render_aa = "8"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Zone")
    scene.world.color = (0.03, 0.03, 0.035)
    data = bpy.data.cameras.new("ZoneCamera")
    data.clip_start = 0.02
    data.clip_end = 400.0
    camera = bpy.data.objects.new("ZoneCamera", data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def main() -> None:
    options = parse_args()
    out = Path(options.out)
    out.mkdir(parents=True, exist_ok=True)
    if options.files:
        os.environ["HOSPITAL_DRESSING_FILES"] = options.files
    ns = runpy.run_path(str(BUILDER), run_name="render_zone")
    bpy.ops.wm.open_mainfile(filepath=str(ns["SOURCE_PATH"]))
    ns["build"](ns["EDIT_STAGES"])
    root = ns["interior_root"]()
    to_world = root.matrix_world.copy()
    shown = set(bpy.data.collections[ns["COLLECTION"]].objects) | set(bpy.data.collections[ns["PREVIEW_COLLECTION"]].objects)
    for obj in bpy.context.scene.objects:
        obj.hide_render = obj not in shown    # the exterior shell and anything else in the file
    camera = setup(options.size)
    scene = bpy.context.scene
    ceiling = [o for o in bpy.data.collections[ns["COLLECTION"]].objects if o.name.startswith(CEILING_PREFIXES)]
    floor_y = ns["FLOOR_Y"]

    for index, text in enumerate(options.plan):
        x0, x1, z0, z1 = numbers(text, 4)
        for obj in ceiling:
            obj.hide_render = True
        grid = []
        letters = max(0.18, (x1 - x0) / 55.0)
        x = float(int(x0)) - 1.0
        while x <= x1 + 1.0:
            major = abs(x % 5.0) < 1e-6
            grid.append(ns["box"]("ZoneGrid", (x - 0.008, floor_y, z0 - 0.5), (x + 0.008, floor_y + 0.004, z1 + 0.5), "FloorLineYellow" if major else "Trim"))
            if abs(x % 2.0) < 1e-6:
                label = ns["text_label"]("ZoneGridText", f"x {x:g}", x, floor_y + 0.006, z1 + 0.45, 0.0, size=letters, mat="SprayPaint")
                label.rotation_euler = (radians(-90.0), 0.0, 0.0)
                grid.append(label)
            x += 1.0
        z = float(int(z1)) + 1.0
        while z >= z0 - 1.0:
            major = abs(z % 5.0) < 1e-6
            grid.append(ns["box"]("ZoneGrid", (x0 - 0.5, floor_y, z - 0.008), (x1 + 0.5, floor_y + 0.004, z + 0.008), "FloorLineYellow" if major else "Trim"))
            if abs(z % 2.0) < 1e-6:
                label = ns["text_label"]("ZoneGridText", f"z {z:g}", x0 - 0.9, floor_y + 0.006, z, 0.0, size=letters, mat="SprayPaint")
                label.rotation_euler = (radians(-90.0), 0.0, 0.0)
                grid.append(label)
            z -= 1.0
        x0, x1, z1 = x0 - 1.6, x1 + 0.3, z1 + 0.9   # room for the grid labels
        centre = to_world @ Vector(((x0 + x1) / 2.0, 12.0, (z0 + z1) / 2.0))
        camera.data.type = "ORTHO"
        aspect = scene.render.resolution_x / scene.render.resolution_y
        width = (x1 - x0) / ns["GODOT_SCALE"]
        depth = (z1 - z0) / ns["GODOT_SCALE"]
        camera.data.ortho_scale = max(width, depth * aspect) * 1.04
        camera.location = centre
        camera.rotation_euler = (0.0, 0.0, 0.0)
        scene.render.filepath = str(out / f"plan_{index}.png")
        bpy.ops.render.render(write_still=True)
        for obj in grid:
            bpy.data.objects.remove(obj, do_unlink=True)
        for obj in ceiling:
            obj.hide_render = False

    for index, text in enumerate(options.shot):
        ex, ey, ez, tx, ty, tz = numbers(text, 6)
        eye = to_world @ Vector((ex, ey, ez))
        target = to_world @ Vector((tx, ty, tz))
        camera.data.type = "PERSP"
        camera.data.lens = 18.0
        camera.location = eye
        camera.rotation_euler = (target - eye).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out / f"shot_{index}.png")
        bpy.ops.render.render(write_still=True)
    print("zone renders written to", out)


main()
