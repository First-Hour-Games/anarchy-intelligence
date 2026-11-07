"""Export models/buildings/carrie_house/carrie_house.gltf and carrie_house_markers.json.

blender --background --python tools/blender/prepare_carrie_house.py

Opens models/source/buildings/CarrieHouse.blend (never saved here), rebuilds the house from
tools/blender/build_carrie_house.py and merges it by collision role, in game coordinates:
- Floor_Wood / Floor_Tile / Floor_Concrete: the walkable tops of floors, stairs and steps
  (collision; the surface picks the footstep sound).
- Structure_<part>: walls, window and door frames, roof, chimney, porch, rails, closed doors and
  the rest of the floor slabs (collision).
- Decor_<part>: cladding, baseboards, gutters, curtains, pictures, light fittings, radiators and
  open doors (no collision).
- One node per piece of furniture, named as in the layout (TV, Radio, CarrieBed, Dollhouse...),
  with its origin at the middle of its base. Godot gives the blocking pieces box collision from
  the markers file.
The .gltf points at the texture files in assets/local_licensed/carrie_house_textures instead of
carrying copies. scenes/environment/carrie_house.gd reads the markers: furniture boxes, hiding
spots, lights, rooms, doors and the story points. Nothing is exported while
tools/blender/carrie_house/validate.py finds a problem with the layout.
"""

import json
import runpy
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[2]
OUTPUT_DIR = ROOT / "models" / "buildings" / "carrie_house"
OUTPUT = OUTPUT_DIR / "carrie_house.gltf"
MARKERS = OUTPUT_DIR / "carrie_house_markers.json"
# Floor materials and the footstep surface they sound like.
SURFACES = {"WoodFloor": "Wood", "WoodTread": "Wood", "Deck": "Wood", "Treads": "Wood", "AtticFloor": "Wood",
            "OldWood": "Wood", "Linoleum": "Tile", "HexTile": "Tile", "CellarFloor": "Concrete", "Concrete": "Concrete"}
FLOOR_OBJECTS = {"CellarFloor", "GroundFloor", "UpperFloor", "AtticFloor", "PorchDeck", "BackStoop", "MainStair",
                 "BackStair", "PorchSteps", "BackSteps", "BulkheadSteps"}
DECOR_PREFIXES = ("Light_", "Curtains_", "Radiator_", "RoofTrim", "Gutters", "RoofHips", "DormerWindow", "PorchSkirt",
                  "BackStoopRoof", "BackStoopBrackets", "BulkheadHardware")
DECOR_SUFFIXES = ("_Finish", "_Cladding")
# Hiding spots: kind, and the side the player climbs out on (the spot's +Z in Godot).
HIDING = {"CarrieBed": ("bed", "+x"), "CarrieWardrobe": ("closet", "+z"), "CoatCloset": ("closet", "-x"),
          "WalkInCloset": ("closet", "-x")}
YAW = {"+z": 0.0, "+x": 90.0, "-z": 180.0, "-x": -90.0}
# How far in from its open side a spot's origin sits. HidingSpot's eye and exit offsets suit the stock
# ward bed and supply closet, whose fronts are this far from their middles. A closet built into the
# walls is measured from the inside of its door wall, which puts the eye behind the door and the
# player out clear of the wall.
SPOT_DEPTH = {"bed": 0.47, "closet": 0.32}
WALL_CLOSET_DEPTH = 0.29
# The power is out: only these lights still work (mode, energy, range); the rest stay dark.
LIVE_LIGHTS = {"CARRIE'S ROOM": ("flicker", 0.55, 5.5), "KITCHEN": ("dying", 0.5, 6.0)}
WARM = [1.0, 0.82, 0.6]

builder = runpy.run_path(str(ROOT / "tools" / "blender" / "build_carrie_house.py"), run_name="export")
checker = builder["load_module"]("validate")
problems = checker.problems()
if problems:
    raise SystemExit("Carrie's house layout has problems, nothing exported:\n  " + "\n  ".join(problems))
bpy.ops.wm.open_mainfile(filepath=str(builder["SOURCE_PATH"]))
builder["build"]()
layout = builder["load_layout"]()
furniture = builder["load_module"]("furniture")
for obj in list(bpy.data.collections[builder["AIDS"]].all_objects):
    bpy.data.objects.remove(obj, do_unlink=True)

house = bpy.data.collections[builder["COLLECTION"]]
root = bpy.data.objects[builder["ROOT_NAME"]]
FURNITURE = {o[0] for o in layout.objects if o[0] in furniture.PIECES or o[0] == "Dollhouse"}
FURNITURE |= {d[0] for d in furniture.DRESSING}
OPEN_DOORS = {name for name, _hinge, _swing, angle in [*layout.door_leaves.values(), *layout.exterior_doors.values()]
              if angle > 1.0}
PICTURES = {p[0] for p in furniture.PICTURES}


def bare(material) -> str:
    """The builder's material name without its Greybox_/House_ prefix."""
    return material.name.split("_", 1)[1] if material and "_" in material.name else (material.name if material else "")


def part_of(obj) -> str:
    owner = next((c for c in obj.users_collection if c.name.startswith("CH ")), None)
    return owner.name[3:].replace(" ", "") if owner else "House"


def world_mesh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    data = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    data.transform(obj.matrix_world)
    return data


class Group:
    """Faces gathered from several objects into one mesh, keeping UVs and materials."""

    def __init__(self, name: str) -> None:
        self.name, self.mesh, self.materials = name, bmesh.new(), []

    def add(self, data, keep=None) -> None:
        """Append mesh data (world space); keep(polygon) picks which faces come along."""
        remap = []
        for material in data.materials:
            if material not in self.materials:
                self.materials.append(material)
            remap.append(self.materials.index(material))
        piece = bmesh.new()
        piece.from_mesh(data)
        if keep is not None:
            drop = [face for face, polygon in zip(piece.faces, data.polygons) if not keep(polygon)]
            bmesh.ops.delete(piece, geom=drop, context="FACES")
        for face in piece.faces:
            face.material_index = remap[face.material_index] if remap else 0
        temp = bpy.data.meshes.new("temp")
        piece.to_mesh(temp)
        piece.free()
        self.mesh.from_mesh(temp)
        bpy.data.meshes.remove(temp)

    def build(self):
        if not self.mesh.faces:
            self.mesh.free()
            return None
        mesh = bpy.data.meshes.new(self.name)
        self.mesh.to_mesh(mesh)
        self.mesh.free()
        for material in self.materials:
            mesh.materials.append(material)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def is_walkable(data):
    def keep(polygon) -> bool:
        material = data.materials[polygon.material_index] if data.materials else None
        return bare(material) in SURFACES and polygon.normal.z > 0.7
    return keep


groups: dict = {}


def group(name: str) -> Group:
    return groups.setdefault(name, Group(name))


furniture_objects = []
for obj in list(house.all_objects):
    if obj.type != "MESH":
        continue
    name = obj.name.split(".")[0]
    if name in FURNITURE:
        furniture_objects.append(obj)
        continue
    data = world_mesh(obj)
    if name in FLOOR_OBJECTS:
        walkable = is_walkable(data)
        for surface in sorted(set(SURFACES.values())):
            group("Floor_" + surface).add(data, lambda polygon, s=surface: walkable(polygon)
                                          and SURFACES[bare(data.materials[polygon.material_index])] == s)
        group("Structure_" + part_of(obj)).add(data, lambda polygon: not walkable(polygon))
    elif name in OPEN_DOORS or name in PICTURES or name.startswith(DECOR_PREFIXES) or name.endswith(DECOR_SUFFIXES):
        group("Decor_" + part_of(obj)).add(data)
    else:
        group("Structure_" + part_of(obj)).add(data)
    bpy.data.meshes.remove(data)

merged = [g.build() for g in groups.values()]

# Furniture: world-space meshes with the origin at the middle of each piece's base.
to_blender = root.matrix_world
for obj in furniture_objects:
    data = world_mesh(obj)
    corners = [Vector(v.co) for v in data.vertices]
    low = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    high = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    base = Vector(((low.x + high.x) / 2.0, (low.y + high.y) / 2.0, low.z))
    data.transform(Matrix.Translation(-base))
    name = obj.name.split(".")[0]
    bpy.data.objects.remove(obj, do_unlink=True)
    target = bpy.data.objects.new(name, data)
    data.name = name
    target.location = base
    bpy.context.scene.collection.objects.link(target)

for obj in list(house.all_objects):
    bpy.data.objects.remove(obj, do_unlink=True)
for obj in list(bpy.context.scene.objects):
    obj.hide_set(False)
    obj.hide_viewport = False
    obj.hide_render = False

OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLTF_SEPARATE", export_apply=True,
                          use_visible=True, export_image_format="AUTO", export_texture_dir="carrie_house_images")

# Point the images at the project's texture files rather than the exporter's copies.
texture_dir = ROOT / "assets" / "local_licensed" / "carrie_house_textures"
sources = {path.name: path for path in texture_dir.rglob("*") if path.suffix.lower() in (".jpg", ".png")}
gltf = json.loads(OUTPUT.read_text(encoding="utf-8"))
copies = OUTPUT_DIR / "carrie_house_images"
for image in gltf.get("images", []):
    file_name = Path(image["uri"]).name
    source = sources.get(file_name)
    if source is None:
        raise SystemExit(f"no project texture for exported image {file_name}")
    image["uri"] = Path("../../..", source.relative_to(ROOT)).as_posix()
OUTPUT.write_text(json.dumps(gltf, indent=1), encoding="utf-8")
if copies.exists():
    for path in copies.iterdir():
        path.unlink()
    copies.rmdir()

# Markers for Godot, in house-local game coordinates (x along the front, y up, +z out the door).
storey_floor = {"CELLAR": layout.CELLAR, "GROUND": layout.GROUND, "UPPER": layout.UPPER, "ATTIC": layout.ATTIC}
pieces = []
for name, role, y, x0, x1, z0, z1, height in layout.objects:
    if name in FURNITURE:
        pieces.append({"name": name, "role": role, "min": [x0, y, z0], "max": [x1, y + height, z1],
                       "blocks": name not in furniture.PASSABLE})
for name, model, storey, lift, x0, x1, z0, z1, height, facing in furniture.DRESSING:
    y = storey_floor[storey] + lift
    pieces.append({"name": name, "role": "dressing", "min": [x0, y, z0], "max": [x1, y + height, z1],
                   "blocks": name not in furniture.PASSABLE})
floors_by_y = sorted(storey_floor.values())
hiding = []
for name, role, y, x0, x1, z0, z1, height in layout.objects:
    if role == "hide":
        floor = max(f for f in floors_by_y if f <= y + 0.01)
        kind, side = HIDING[name]
        depth = SPOT_DEPTH[kind] if name in FURNITURE else WALL_CLOSET_DEPTH
        x, z = (x0 + x1) / 2.0, (z0 + z1) / 2.0
        if side == "+x":
            x = x1 - depth
        elif side == "-x":
            x = x0 + depth
        elif side == "+z":
            z = z1 - depth
        else:
            z = z0 + depth
        hiding.append({"name": name, "kind": kind, "position": [x, floor, z], "yaw": YAW[side]})
tops = {round(floor, 3): top for floor, _bottom, top in builder["storeys"](layout)}
lights = []
for name, floor, x0, x1, z0, z1 in layout.rooms:
    ceiling = layout.ATTIC + 2.6 if name == "ATTIC" else tops[round(floor, 3)]
    bulb = name in ("CELLAR", "ATTIC")
    mode, energy, reach = LIVE_LIGHTS.get(name, ("off", 0.0, 0.0))
    lights.append({"room": name, "position": [(x0 + x1) / 2.0, ceiling - (0.47 if bulb else 0.42), (z0 + z1) / 2.0],
                   "kind": "bulb" if bulb else "bowl", "mode": mode, "energy": energy, "range": reach, "color": WARM})
front_door = next(o for w in layout.walls if w["id"] == "ExtFront" for o in w["openings"] if o["kind"] == "door")
lights.append({"room": "PORCH", "position": [(front_door["a"] + front_door["b"]) / 2.0, 3.12, 1.0], "kind": "porch",
               "mode": "steady", "energy": 0.35, "range": 7.0, "color": [0.92, 0.68, 0.42]})
doors = [{"name": name, "wall": wall, "start": start, "hinge": hinge, "swing": swing, "open_degrees": angle}
         for (wall, start), (name, hinge, swing, angle) in layout.door_leaves.items()]
# Doorways people walk through: every interior door or cased opening, and the outside doors of
# the ground floor. Open ones get navigation links in Godot, since a door is narrower than the
# navigation mesh can pass.
doorways = []
for w in layout.walls:
    for o in w["openings"]:
        outside_door = w["id"] in layout.exterior_doors and o["kind"] == "door" and o["y0"] >= layout.GROUND - 0.01
        if o["kind"] in ("window", "boarded") or (w["id"].startswith("Ext") and not outside_door):
            continue
        middle = (o["a"] + o["b"]) / 2.0
        centre = [middle, o["y0"], w["fixed"]] if w["axis"] == "x" else [w["fixed"], o["y0"], middle]
        doorways.append({"wall": w["id"], "centre": centre, "normal": [0, 0, 1] if w["axis"] == "x" else [1, 0, 0],
                         "width": o["b"] - o["a"], "open": checker.walked_through(layout, w, o)})
walls = {w["id"]: w for w in layout.walls}
main = next(s for s in layout.stairs if s["id"] == "MainStair")
back = next(s for s in layout.stairs if s["id"] == "BackStair")
back_steps = next(s for s in layout.stairs if s["id"] == "BackSteps")
stoop = next(rect for name, _y, _t, rect, _holes in layout.floors if name == "BackStoop")
front = next(o for o in walls["ExtFront"]["openings"] if o["kind"] == "door")
back_door = next(o for o in walls["ExtBack"]["openings"] if o["kind"] == "door" and o["y0"] >= layout.GROUND - 0.01)
door_x, back_x = (front["a"] + front["b"]) / 2.0, (back_door["a"] + back_door["b"]) / 2.0
chair, tv, desk = (next(p for p in pieces if p["name"] == name) for name in ("Armchair", "TV", "CarrieDesk"))
carrie = next(r for r in layout.rooms if r[0] == "CARRIE'S ROOM")
points = {
    # Front path: the foot of the porch steps, the porch, the doorway and the hall inside it.
    "yard_front": [door_x, layout.GRADE, 4.6],
    "porch": [door_x, layout.GROUND - 0.05, 1.3],
    "front_door": [door_x, layout.GROUND, 0.0],
    "hall": [door_x, layout.GROUND, -1.4],
    # The note pinned beside the open front door, facing the porch.
    "door_note": [front["a"] - 0.32, layout.GROUND + 0.85, 0.15],
    # The Wrapper waits in front of the living-room armchair, facing the TV, sitting back in the chair.
    "wrapper_post": [(chair["min"][0] + chair["max"][0]) / 2.0, layout.GROUND, chair["max"][2] + 0.45],
    "wrapper_seat": [(chair["min"][0] + chair["max"][0]) / 2.0, layout.GROUND, chair["min"][2] + 0.5],
    "tv": [(tv["min"][0] + tv["max"][0]) / 2.0, layout.GROUND, (tv["min"][2] + tv["max"][2]) / 2.0],
    # Upstairs: the voice calls from the middle of Carrie's room; her notebook lies on her desk.
    "voice": [(carrie[2] + carrie[3]) / 2.0, layout.UPPER + 1.2, (carrie[4] + carrie[5]) / 2.0],
    "notebook": [(desk["min"][0] + desk["max"][0]) / 2.0, desk["max"][1] + 0.0225, (desk["min"][2] + desk["max"][2]) / 2.0],
    # Open floor in Carrie's room, between the dollhouse table and the bed.
    "carrie_room": [-3.1, layout.UPPER, -2.6],
    # The stairs: the floor in front of the main stair's foot, the landing between the two tops,
    # and the floor at the back stair's foot.
    "stairs_bottom": [sum(main["x"]) / 2.0, layout.GROUND, main["z"][0] + 0.6],
    "stairs_top": [sum(main["x"]) / 2.0, layout.UPPER, (main["z"][1] + back["z"][1]) / 2.0],
    "back_stair_bottom": [sum(back["x"]) / 2.0, layout.GROUND, back["z"][0] - 0.6],
    # The way out at the back: the kitchen by the back stair's door, the back stoop, the yard.
    "kitchen": [walls["G_StairEnclosure"]["fixed"] - 0.7, layout.GROUND, back["z"][0] - 0.65],
    "back_door": [back_x, layout.GROUND - 0.05, (stoop[2] + stoop[3]) / 2.0],
    "back_yard": [back_x, layout.GRADE, back_steps["z"][1] - 0.75],
}
rooms = [{"name": name, "floor": floor, "min": [x0, z0], "max": [x1, z1]} for name, floor, x0, x1, z0, z1 in layout.rooms]
footprint = {"min": [builder["HOUSE"][0], builder["HOUSE"][2]], "max": [builder["HOUSE"][1], builder["HOUSE"][3]]}
MARKERS.write_text(json.dumps({"footprint": footprint, "floors": storey_floor, "points": points, "furniture": pieces,
                               "hiding": hiding, "lights": lights, "doors": doors, "doorways": doorways, "rooms": rooms},
                              indent=1), encoding="utf-8")
print(f"exported {OUTPUT.name}: {len([m for m in merged if m])} merged meshes, {len(furniture_objects)} furniture nodes, "
      f"{len(gltf.get('images', []))} images; markers: {len(pieces)} furniture, {len(hiding)} hiding, {len(lights)} lights")
