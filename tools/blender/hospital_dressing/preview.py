"""Headless preview of one hospital equipment module.

blender --background --factory-startup --python tools/blender/hospital_dressing/preview.py -- --module carts --out <dir> [--props crash_cart,med_cart] [--size 520]

Builds each prop of the module (one instance per preview variant) in an empty scene, against a
sample hospital wall (wainscot, chair rail, skirting), floor, counter (surface props) and
ceiling strip (ceiling props). Prints a size, placement and triangle report, then renders
Workbench images into --out: overview.png and <instance>.png (two angles side by side).
Never opens or saves Hospital_V2.blend.
"""

import argparse
import runpy
import sys
from math import atan, radians, sin, tan
from pathlib import Path

import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
BUILDER = HERE.parent / "build_hospital_interior.py"
WALL_Z = -0.5          # room face of the sample wall (game z); props face +Z
GAP = 0.5
COUNTER_H = 0.9
TRIANGLE_BUDGET = {"floor": 1500, "wall": 700, "surface": 700, "ceiling": 300}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--module", required=True, help="module file name without .py")
    parser.add_argument("--out", required=True)
    parser.add_argument("--props", default="", help="comma-separated prop keys (default: all)")
    parser.add_argument("--size", type=int, default=520)
    return parser.parse_args(argv)


def game_dir(x: float, y: float, z: float) -> Vector:
    """A direction in game axes (y up, +z toward the viewer) as a Blender world vector."""
    return Vector((x, -z, y)).normalized()


def world_bounds(objects: list) -> tuple:
    depsgraph = bpy.context.evaluated_depsgraph_get()
    points = []
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        points += [obj.matrix_world @ v.co for v in mesh.vertices]
        evaluated.to_mesh_clear()
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high


def game_bounds(objects: list, root) -> tuple:
    """Bounds in game coordinates (the InteriorRoot's local space)."""
    depsgraph = bpy.context.evaluated_depsgraph_get()
    to_game = root.matrix_world.inverted()
    points = []
    triangles = 0
    for obj in objects:
        evaluated = obj.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        mesh.calc_loop_triangles()
        triangles += len(mesh.loop_triangles)
        points += [to_game @ (obj.matrix_world @ v.co) for v in mesh.vertices]
        evaluated.to_mesh_clear()
    if not points:
        return None, None, 0
    low = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    high = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return low, high, triangles


def setup_render(size: int) -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = size
    scene.render.resolution_y = int(size * 0.8)
    scene.render.film_transparent = False
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.shadow_intensity = 0.35
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.show_object_outline = True
    scene.display.render_aa = "8"
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    if scene.world is None:
        scene.world = bpy.data.worlds.new("Preview")
    scene.world.color = (0.05, 0.05, 0.055)
    camera_data = bpy.data.cameras.new("PreviewCamera")
    camera_data.lens = 35.0
    camera_data.clip_end = 500.0
    camera = bpy.data.objects.new("PreviewCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera


def shoot(path: Path, objects: list, direction: Vector, margin: float = 1.08) -> None:
    scene = bpy.context.scene
    camera = scene.camera
    low, high = world_bounds(objects)
    centre = (low + high) / 2.0
    radius = max((high - low).length / 2.0, 0.05)
    sensor = camera.data.sensor_width
    fov_h = 2.0 * atan(sensor / (2.0 * camera.data.lens))
    fov_v = 2.0 * atan(tan(fov_h / 2.0) * scene.render.resolution_y / scene.render.resolution_x)
    distance = radius / sin(min(fov_h, fov_v) / 2.0) * margin
    camera.location = centre + direction * distance
    camera.rotation_euler = (centre - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.clip_start = max(0.01, distance / 200.0)
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def side_by_side(paths: list, out: Path) -> None:
    import numpy as np
    images = [bpy.data.images.load(str(p)) for p in paths]
    width = sum(i.size[0] for i in images)
    height = max(i.size[1] for i in images)
    canvas = np.zeros((height, width, 4), dtype=np.float32)
    x = 0
    for image in images:
        w, h = image.size
        pixels = np.empty(w * h * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        canvas[:h, x:x + w] = pixels.reshape(h, w, 4)
        x += w + 0
    sheet = bpy.data.images.new("sheet", width, height, alpha=True)
    sheet.pixels.foreach_set(canvas.ravel())
    sheet.filepath_raw = str(out)
    sheet.file_format = "PNG"
    sheet.save()
    for image in images:
        bpy.data.images.remove(image)
    bpy.data.images.remove(sheet)
    for p in paths:
        Path(p).unlink(missing_ok=True)


def main() -> None:
    options = parse_args()
    out = Path(options.out)
    out.mkdir(parents=True, exist_ok=True)
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    ns = runpy.run_path(str(BUILDER), run_name="dressing_preview")
    catalog = ns["load_dressing_catalog"]()
    wanted = [k for k in options.props.split(",") if k]
    module_file = options.module + ".py"
    keys = [k for k, spec in catalog.items() if spec["module"] == module_file and (not wanted or k in wanted)]
    if not keys:
        sys.exit(f"no props found for module {module_file} {wanted or ''}")
    floor_y, ceiling_y = ns["FLOOR_Y"], ns["CEILING_Y"]
    api = ns["dressing_api"]()
    root = ns["interior_root"]()
    box = ns["box"]

    instances = []
    cursor = 0.0
    for key in keys:
        spec = catalog[key]
        variants = spec.get("variants") or [{}]
        for index, variant in enumerate(variants):
            w, h, d = spec["size"]
            name = key if len(variants) == 1 else f"{key}_v{index}"
            x = cursor + w / 2.0
            mount = spec["mount"]
            z = WALL_Z + d / 2.0 + (0.0 if mount == "wall" else 0.03)
            if mount == "wall":
                y = spec["y"]
            elif mount == "ceiling":
                y = ceiling_y - h
                box(f"Ctx_Ceiling_{name}", (x - w / 2 - 0.3, ceiling_y, WALL_Z), (x + w / 2 + 0.3, ceiling_y + 0.04, WALL_Z + max(d, 0.6) + 0.6), "Ceiling")
                z = WALL_Z + max(d, 0.6) / 2.0 + 0.3
            elif mount == "surface":
                depth = max(d + 0.1, 0.6)
                box(f"Ctx_Counter_{name}", (x - w / 2 - 0.1, floor_y, WALL_Z), (x + w / 2 + 0.1, floor_y + COUNTER_H, WALL_Z + depth), "Laminate")
                y = floor_y + COUNTER_H
                z = WALL_Z + depth / 2.0
            else:
                y = floor_y
            before = set(bpy.data.objects)
            entry = {"prop": key, "name": name, "x": x, "y": y, "z": z, "yaw": 0.0, "opts": variant}
            made = ns["place_dressing"](catalog, api, entry)
            if not made:
                made = [o for o in bpy.data.objects if o not in before]
            instances.append(dict(key=key, name=name, spec=spec, x=x, y=y, z=z, objects=made, variant=variant))
            cursor += w + GAP
    span = (-2.5, cursor + 2.0)
    # Sample room: wall with wainscot, chair rail and skirting, and the floor in front of it.
    box("Ctx_Wall", (span[0], floor_y, WALL_Z - 0.15), (span[1], ceiling_y, WALL_Z), "WallUpper")
    box("Ctx_Wainscot", (span[0], floor_y, WALL_Z), (span[1], 1.0, WALL_Z + 0.004), "WallLower")
    box("Ctx_ChairRail", (span[0], 0.98, WALL_Z), (span[1], 1.04, WALL_Z + 0.025), "Trim")
    box("Ctx_Skirting", (span[0], floor_y, WALL_Z), (span[1], floor_y + 0.1, WALL_Z + 0.012), "Baseboard")
    box("Ctx_Floor", (span[0], 0.0, WALL_Z - 0.15), (span[1], floor_y, WALL_Z + 3.0), "HospitalFloor")

    print("\nPREVIEW REPORT", module_file)
    print("instance | mount | declared w,h,d | measured w,h,d | base y | tris | objects | flags")
    problems = 0
    for inst in instances:
        spec = inst["spec"]
        low, high, tris = game_bounds(inst["objects"], root)
        flags = []
        if low is None:
            flags.append("NO GEOMETRY")
            measured = (0.0, 0.0, 0.0)
        else:
            measured = (high.x - low.x, high.y - low.y, high.z - low.z)
            for axis, label in enumerate("whd"):
                declared = spec["size"][axis]
                if measured[axis] > declared + 0.02:
                    flags.append(f"{label} {measured[axis]:.3f} exceeds declared {declared:.3f}")
                elif measured[axis] < declared - 0.05:
                    flags.append(f"{label} {measured[axis]:.3f} well under declared {declared:.3f}")
            if abs(low.y - inst["y"]) > 0.01:
                flags.append(f"base at y={low.y:.3f}, expected {inst['y']:.3f}")
            centre_x = (low.x + high.x) / 2.0
            if abs(centre_x - inst["x"]) > 0.03:
                flags.append(f"footprint centre off by {centre_x - inst['x']:+.3f} in x")
            if spec["mount"] == "wall":
                if low.z < WALL_Z - 0.005:
                    flags.append(f"goes {WALL_Z - low.z:.3f} into the wall")
                elif low.z > WALL_Z + 0.01:
                    flags.append(f"back floats {low.z - WALL_Z:.3f} off the wall")
            else:
                centre_z = (low.z + high.z) / 2.0
                if abs(centre_z - inst["z"]) > 0.03:
                    flags.append(f"footprint centre off by {centre_z - inst['z']:+.3f} in z")
            if spec["mount"] == "ceiling" and abs(high.y - ns["CEILING_Y"]) > 0.01:
                flags.append(f"top at y={high.y:.3f}, ceiling is {ns['CEILING_Y']:.3f}")
        budget = TRIANGLE_BUDGET[spec["mount"]] * (2 if spec["size"][0] * spec["size"][2] > 1.0 else 1)
        if tris > budget:
            flags.append(f"{tris} triangles > budget {budget}")
        problems += bool(flags)
        print(f"{inst['name']} | {spec['mount']} | {tuple(round(v, 3) for v in spec['size'])} | "
              f"{tuple(round(v, 3) for v in measured)} | {inst['y']:.3f} | {tris} | {len(inst['objects'])} | "
              f"{'; '.join(flags) or 'ok'}")
    print(f"{len(instances)} instances, {problems} with flags\n")

    setup_render(options.size)
    context = [o for o in bpy.data.objects if o.name.startswith("Ctx_")]
    every = [o for inst in instances for o in inst["objects"] if o.type in ("MESH", "FONT")]
    shoot(out / "overview.png", every, game_dir(0.0, 0.55, 1.0), margin=1.0)
    for inst in instances:
        shown = [o for o in inst["objects"] if o.type in ("MESH", "FONT")]
        if not shown:
            continue
        for other in every:
            other.hide_render = other not in shown
        mount = inst["spec"]["mount"]
        if mount == "ceiling":
            views = [game_dir(-0.5, -0.55, 1.0), game_dir(0.6, -0.35, 0.8)]
        elif mount == "wall":
            views = [game_dir(-0.45, 0.25, 1.0), game_dir(0.5, -0.1, 0.9)]
        else:
            views = [game_dir(-0.6, 0.5, 1.0), game_dir(0.75, 0.45, 0.8)]
        parts = []
        for index, direction in enumerate(views):
            part = out / f"_{inst['name']}_{index}.png"
            shoot(part, shown, direction, margin=1.25)
            parts.append(part)
        side_by_side(parts, out / f"{inst['name']}.png")
    for other in every:
        other.hide_render = False
    print("images written to", out)
    del context


main()
