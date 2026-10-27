"""Export models/buildings/downtown/downtown.gltf and downtown_markers.json.

blender --background --python tools/blender/prepare_downtown.py

Opens models/source/buildings/Downtown.blend (never saved here), rebuilds the downtown from
tools/blender/build_downtown.py and exports every object in world coordinates, each with its
origin at the middle of its base so Godot measures draw distances from the building. The .gltf
points at the texture files in assets/local_licensed and models/buildings/downtown/textures
instead of carrying copies.

When Godot imports the .gltf, tools/import/downtown_post_import.gd reads the markers: collision
boxes, occluders, sign lettering, lights, the glass and detail objects, the blinking signal, and
the street furniture, trees and cars that scenes/environment/civic_finishing.gd places. Nothing is
exported while tools/blender/downtown/validate.py finds a problem with the plan.
"""

import hashlib
import json
import runpy
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "models" / "buildings" / "downtown"
OUTPUT = OUTPUT_DIR / "downtown.gltf"
MARKERS = OUTPUT_DIR / "downtown_markers.json"
TEXTURE_DIRS = [ROOT / "assets" / "local_licensed", OUTPUT_DIR / "textures"]

builder = runpy.run_path(str(ROOT / "tools" / "blender" / "build_downtown.py"), run_name="export")
checker = builder["load_module"]("validate")
problems = checker.problems()
if problems:
    raise SystemExit("The downtown plan has problems, nothing exported:\n  " + "\n  ".join(problems))
bpy.ops.wm.open_mainfile(filepath=str(builder["SOURCE_PATH"]))
markers = builder["build"]()
plan = builder["load_module"]("plan")

for name in (builder["AIDS"],):
    found = bpy.data.collections.get(name)
    if found is not None:
        for obj in list(found.all_objects):
            bpy.data.objects.remove(obj, do_unlink=True)

depsgraph = bpy.context.evaluated_depsgraph_get()
downtown = bpy.data.collections[builder["COLLECTION"]]
exported = []
for obj in list(downtown.all_objects):
    if obj.type != "MESH":
        continue
    data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    data.transform(obj.matrix_world)
    corners = [Vector(v.co) for v in data.vertices]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    base = Vector(((low.x + high.x) / 2.0, (low.y + high.y) / 2.0, low.z))
    data.transform(Matrix.Translation(-base))
    name, old = obj.name, obj.data
    bpy.data.objects.remove(obj, do_unlink=True)
    if old.users == 0:
        bpy.data.meshes.remove(old)
    target = bpy.data.objects.new(name, data)
    data.name = name
    target.location = base
    bpy.context.scene.collection.objects.link(target)
    exported.append(name)
for obj in list(bpy.data.objects):
    if obj.type != "MESH" or obj.name not in exported:
        bpy.data.objects.remove(obj, do_unlink=True)

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
copies = OUTPUT_DIR / "downtown_images"
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLTF_SEPARATE", export_apply=True, use_visible=True,
                          export_image_format="AUTO", export_texture_dir="downtown_images")

# Point the images at the project's texture files rather than the exporter's copies, and stamp the
# markers' hash into the file so a change to the markers alone still makes Godot reimport it.
sources = {}
for folder in TEXTURE_DIRS:
    for path in folder.rglob("*"):
        if path.suffix.lower() in (".jpg", ".png"):
            sources.setdefault(path.name, path)
gltf = json.loads(OUTPUT.read_text(encoding="utf-8"))
for image in gltf.get("images", []):
    file_name = Path(image["uri"]).name
    source = sources.get(file_name)
    if source is None:
        raise SystemExit(f"no project texture for exported image {file_name}")
    image["uri"] = Path("../../..", source.relative_to(ROOT)).as_posix()
if copies.exists():
    for path in copies.iterdir():
        path.unlink()
    copies.rmdir()

objects = {"glass": sorted(n for n in exported if n.endswith("_Glass")),
           "details": sorted(n for n in exported if n.endswith("_Details"))}
furniture = [{"kind": kind, "position": [x, z], "yaw": yaw} for kind, x, z, yaw in plan.FURNITURE]
furniture += [{"kind": "lamp", "position": [x, z], "yaw": 0.0 if z < 225.0 else 180.0} for x, z in plan.LAMPS]
furniture += [{"kind": "tree", "position": [x, z], "yaw": (x * 37.0) % 360.0} for x, z in plan.TREES]
markers["cars"] += [{"scene": model, "position": [x, 0.1, z], "yaw": yaw} for model, x, z, yaw in plan.CURB_CARS]
# Points the tests walk between, all on the ground or the sidewalks.
points = {
    "corner_north": [107.6, 0.1, 219.0], "corner_south": [107.6, 0.1, 231.5],
    "north_walk_west": [110.0, 0.1, 218.3], "north_walk_east": [270.0, 0.1, 218.3],
    "south_walk_west": [110.0, 0.1, 232.4], "south_walk_east": [220.0, 0.1, 232.4],
    "hospital_path": [plan.HOSPITAL_DOOR[0], 0.1, 233.0], "hospital_door": [plan.HOSPITAL_DOOR[0], 0.1, 247.0],
    "service_lane_west": [109.0, 0.0, 270.0], "service_lane_east": [237.0, 0.0, 270.0],
}
for line in plan.SOUTH_ALLEY_LINES:
    points[f"alley_{int(line)}_street"] = [line, 0.0, plan.SOUTH_FRONT + 0.5]
    points[f"alley_{int(line)}_lane"] = [line, 0.0, 270.0]
markers.update({"objects": objects, "furniture": furniture, "points": points,
                "corner_street_sign": list(plan.CORNER_STREET_SIGN), "corner_stop_sign": list(plan.CORNER_STOP_SIGN),
                "sidewalk_top": plan.SIDEWALK_TOP})
text = json.dumps(markers, indent=1)
MARKERS.write_text(text, encoding="utf-8")
gltf.setdefault("asset", {})["extras"] = {"markers_sha1": hashlib.sha1(text.encode("utf-8")).hexdigest()}
OUTPUT.write_text(json.dumps(gltf, indent=1), encoding="utf-8")
print(f"exported {OUTPUT.name}: {len(exported)} objects, {len(gltf.get('images', []))} images, "
      f"{len(gltf.get('materials', []))} materials; markers: {len(markers['colliders'])} colliders, "
      f"{len(markers['signs'])} signs, {len(markers['lights'])} lights, {len(furniture)} furniture")
