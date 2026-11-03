"""Build the downtown beside the hospital in models/source/buildings/Downtown.blend.

Headless: blender --background --python tools/blender/build_downtown.py
Live (Blender MCP): runpy.run_path(<this file>, run_name="live")["build"]()

The layout lives in tools/blender/downtown/plan.py, in the map's world coordinates; generated
textures come from tools/blender/downtown/textures.py. Everything is rebuilt from scratch in the
"Downtown" collection under the "DowntownRoot" empty, which turns +90 degrees about X so children
are authored in game coordinates (x east, y up, z south). Aids that are never exported (a figure
for scale) go in "DowntownAids".

Each building becomes up to three objects:
- <Id>: walls, trim, shopfronts, awnings and signboards;
- <Id>_Glass: every pane, drawn in Godot by shaders/window_interior.gdshader. Its first UV map runs
  0-1 across each pane; the second carries the pane's codes (see glass_codes);
- <Id>_Details: cornice brackets, fire escapes, roof tanks, sign frames and other small parts that
  Godot stops drawing far away.
The street adds Paving (sidewalks, curbs, alleys, lots, the hospital forecourt and crosswalks),
StreetFurniture (meters, newspaper boxes, tree grates, lot fences) and the Signal, whose lenses
SignalAmber and SignalRed blink in Godot. MARKERS gathers what Godot adds itself: collision boxes,
occluders, sign lettering and lights (see prepare_downtown.py).
"""

from math import cos, pi, radians, sin, sqrt
from pathlib import Path

import bpy

PROJECT_ROOT = Path(__file__).resolve().parents[2]
SOURCE_PATH = PROJECT_ROOT / "models" / "source" / "buildings" / "Downtown.blend"
PLAN_DIR = Path(__file__).resolve().parent / "downtown"
GENERATED = PROJECT_ROOT / "models" / "buildings" / "downtown" / "textures"
LICENSED = PROJECT_ROOT / "assets" / "local_licensed"
COLLECTION = "Downtown"
AIDS = "DowntownAids"
ROOT_NAME = "DowntownRoot"

BRICK = LICENSED / "carrie_house_textures" / "brick_wall_02" / "brick_wall_02_diff_1k.jpg"
BRICK_NORMAL = LICENSED / "carrie_house_textures" / "brick_wall_02" / "brick_wall_02_nor_gl_1k.jpg"
PLASTER = LICENSED / "carrie_house_textures" / "painted_plaster_wall" / "painted_plaster_wall_diff_1k.jpg"
PLASTER_NORMAL = LICENSED / "carrie_house_textures" / "painted_plaster_wall" / "painted_plaster_wall_nor_gl_1k.jpg"
CONCRETE = LICENSED / "materials" / "concrete034" / "Concrete034_Color.jpg"
ASPHALT = LICENSED / "street_materials" / "textures" / "asphalt_02_diff_4k.jpg"
# Tiled finishes: colour map, normal map or None, metres per repeat (across, up), roughness, tint.
# The sidewalk and road tints match the map's own sidewalks and roads, which use the same images.
TILED = {
    "BrickRed": (BRICK, BRICK_NORMAL, (1.35, 1.35), 0.85, (1.0, 0.93, 0.90)),
    "BrickBrown": (BRICK, BRICK_NORMAL, (1.35, 1.35), 0.85, (0.72, 0.58, 0.50)),
    "BrickDark": (BRICK, BRICK_NORMAL, (1.35, 1.35), 0.85, (0.52, 0.41, 0.38)),
    "BrickCream": (GENERATED / "brick_painted.png", BRICK_NORMAL, (1.35, 1.35), 0.8, (1.0, 1.0, 1.0)),
    "BrickBuff": (GENERATED / "brick_buff.png", BRICK_NORMAL, (1.35, 1.35), 0.85, (1.0, 1.0, 1.0)),
    "Limestone": (GENERATED / "limestone.png", None, (2.0, 1.8), 0.8, (1.0, 1.0, 1.0)),
    "Stucco": (PLASTER, PLASTER_NORMAL, (2.0, 2.0), 0.9, (0.80, 0.70, 0.68)),
    "Concrete": (CONCRETE, None, (2.0, 2.0), 0.95, (0.83, 0.82, 0.77)),
    "Asphalt": (ASPHALT, None, (3.0, 3.0), 0.95, (0.78, 0.78, 0.78)),
}
WALL_T = 0.4            # front walls, deep enough for the window reveals
RECESS = 0.2            # glass behind the face of the wall
GLOW_STRENGTH = 2.5
SIDEWALK = 0.13         # plan.SIDEWALK_TOP, repeated for the paving helpers
PAVED = 0.08            # alleys, lots and the service lane: the service lane's old height
ROAD_TOP = 0.1

# Room and overlay names for windows (textures.ROOMS and textures.OVERLAYS), weighted.
ROOM_CHOICES = {
    "flat": [("living", 3), ("bedroom", 3), ("kitchen", 2), ("empty", 2), ("living_green", 2), ("bedroom_blue", 2),
             ("storage", 1), ("lit_living", 0.6), ("lit_kitchen", 0.3)],
    "hotel": [("hotel_room", 7), ("empty", 1.5), ("storage", 1), ("lit_living", 0.4)],
    "office": [("office", 6), ("empty", 2), ("storage", 2), ("lit_kitchen", 0.3)],
    "shop": [("shop", 4), ("service", 2), ("vacant_shop", 3)],
    "lobby": [("lobby", 1)],
    "stair": [("hall", 1)],
}
OVERLAY_CHOICES = {
    "flat": [("clear", 3), ("curtains", 2.5), ("curtains_open", 2.5), ("nets", 1.5), ("blinds", 1.5), ("blinds_half", 1),
             ("shade", 1.2), ("boarded", 0.7), ("cracked", 0.6), ("grime", 1)],
    "hotel": [("curtains_red", 3), ("curtains", 2), ("nets", 2), ("shade", 1.5), ("clear", 1), ("boarded", 0.5)],
    "office": [("blinds", 4), ("blinds_half", 2), ("blinds_broken", 1), ("grime", 1.5), ("clear", 1)],
    "shop": [("whitewash", 2.5), ("newspaper", 1.5), ("notice", 1), ("grime", 2), ("dust", 2), ("boarded", 1)],
    "lobby": [("dust", 2), ("grime", 1), ("notice", 0.5)],
    "stair": [("grime", 1), ("dust", 1)],
}
# Frame styles the shader draws: two sashes, one pane, four panes, none (the frame is modelled).
SASH, PANE, FOUR, BARE = 0, 1, 2, 3

_state = {}             # plan, tex (the textures module) and the markers of the current build


def load_module(name: str):
    """A module from tools/blender/downtown, loaded fresh (and without a __pycache__)."""
    import types
    path = PLAN_DIR / f"{name}.py"
    module = types.ModuleType("downtown_" + name)
    module.__file__ = str(path)
    exec(compile(path.read_text(encoding="utf-8"), str(path), "exec"), module.__dict__)
    return module


def hash01(text: str) -> float:
    """A stable number in 0..1 for a name."""
    h = 2166136261
    for ch in text:
        h = ((h ^ ord(ch)) * 16777619) & 0xFFFFFFFF
    return h / 4294967296.0


def pick(choices: list, seed: str) -> str:
    total = sum(weight for _name, weight in choices)
    at = hash01(seed) * total
    for name, weight in choices:
        at -= weight
        if at < 0:
            return name
    return choices[-1][0]


def glass_codes(room: str, overlay: str, style: int) -> tuple:
    """The pane's second UV, as Blender stores it: (room + 16 if lit, 1 - (overlay + 16 * style)).
    glTF flips v on export, so Godot reads (room + 16 if lit, overlay + 16 * style)."""
    tex = _state["tex"]
    lit = 16 if room in tex.LIT_ROOMS else 0
    return float(tex.ROOMS.index(room) + lit), 1.0 - float(tex.OVERLAYS.index(overlay) + 16 * style)


# --- Vectors --------------------------------------------------------------------------------------

def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = sqrt(dot(a, a))
    return (a[0] / length, a[1] / length, a[2] / length) if length > 1e-9 else (0.0, 0.0, 0.0)


def polygon_normal(points):
    total = (0.0, 0.0, 0.0)
    for i in range(1, len(points) - 1):
        c = cross(sub(points[i], points[0]), sub(points[i + 1], points[0]))
        total = (total[0] + c[0], total[1] + c[1], total[2] + c[2])
    return norm(total)


UP = (0.0, 1.0, 0.0)

# --- Materials ------------------------------------------------------------------------------------

_materials = {}


def load_image(path: Path, data: bool = False):
    image = bpy.data.images.get(path.name) or bpy.data.images.load(str(path))
    if bpy.data.filepath:
        image.filepath = bpy.path.relpath(str(path))
    if data:
        for colorspace in ("Non-Color", "Raw", "Data"):
            try:
                image.colorspace_settings.name = colorspace
                break
            except TypeError:
                continue
    return image


def material(name: str) -> bpy.types.Material:
    """Blender material for a key's family: a TILED name, Paint, Glow, Fabric or Glass."""
    if name in _materials:
        return _materials[name]
    result = bpy.data.materials.get("Downtown_" + name) or bpy.data.materials.new("Downtown_" + name)
    result.use_nodes = True
    result.use_backface_culling = True         # exported single-sided: two-sided parts are modelled so
    nodes, links = result.node_tree.nodes, result.node_tree.links
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    output.location, shader.location = (400, 0), (100, 0)
    links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    colour = nodes.new("ShaderNodeTexImage")
    colour.location = (-500, 150)
    if name in TILED:
        path, normal_path, _tile, roughness, tint = TILED[name]
        colour.image = load_image(path)
        if tint != (1.0, 1.0, 1.0):
            mix = nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.location = (-200, 150)
            mix.inputs["Factor"].default_value = 1.0
            mix.inputs[7].default_value = (*tint, 1.0)
            links.new(colour.outputs["Color"], mix.inputs[6])
            links.new(mix.outputs[2], shader.inputs["Base Color"])
        else:
            links.new(colour.outputs["Color"], shader.inputs["Base Color"])
        if normal_path is not None:
            normal = nodes.new("ShaderNodeTexImage")
            bump = nodes.new("ShaderNodeNormalMap")
            normal.location, bump.location = (-700, -250), (-250, -250)
            normal.image = load_image(normal_path, data=True)
            links.new(normal.outputs["Color"], bump.inputs["Color"])
            links.new(bump.outputs["Normal"], shader.inputs["Normal"])
        shader.inputs["Roughness"].default_value = roughness
        result.diffuse_color = (*[c * 0.5 for c in tint], 1.0)
    else:
        image = {"Paint": "palette.png", "Glow": "palette.png", "Fabric": "fabric.png", "Glass": "rooms.png"}[name]
        colour.image = load_image(GENERATED / image)
        if name in ("Paint", "Glow"):
            colour.interpolation = "Closest"
        links.new(colour.outputs["Color"], shader.inputs["Base Color"])
        shader.inputs["Roughness"].default_value = {"Paint": 0.7, "Glow": 0.5, "Fabric": 0.9, "Glass": 0.1}[name]
        if name == "Glow":
            links.new(colour.outputs["Color"], shader.inputs["Emission Color"])
            shader.inputs["Emission Strength"].default_value = GLOW_STRENGTH
        result.diffuse_color = {"Paint": (0.4, 0.4, 0.4, 1), "Glow": (1, 0.8, 0.4, 1), "Fabric": (0.5, 0.2, 0.2, 1),
                                "Glass": (0.1, 0.12, 0.14, 1)}[name]
    nodes.active = colour
    _materials[name] = result
    return result


def family(key: str) -> str:
    return key.split(":", 1)[0]


# --- Gathering faces ------------------------------------------------------------------------------

BOX_FACES = {"-y": (0, 1, 2, 3), "+y": (4, 7, 6, 5), "-z": (0, 4, 5, 1), "+z": (3, 2, 6, 7),
             "-x": (0, 3, 7, 4), "+x": (1, 5, 6, 2)}


class Kit:
    """Faces gathered into one object. Each face has a material key ("BrickRed", "Paint:Tar",
    "Glow:NeonRed", "Fabric:AwningRed", "Glass") and either explicit UVs or planar ones worked out
    from its material when the object is made."""

    def __init__(self, name: str) -> None:
        self.name = name
        self.verts = []
        self.faces = []

    def face(self, points, key: str, uvs=None, uv2=None, facing=None) -> None:
        points = [tuple(p) for p in points]
        if facing is not None and dot(polygon_normal(points), facing) < 0:
            points = points[::-1]
            uvs = uvs[::-1] if uvs else None
            uv2 = uv2[::-1] if uv2 else None
        base = len(self.verts)
        self.verts += points
        self.faces.append((tuple(range(base, base + len(points))), key, uvs, uv2))

    def box(self, lo, hi, key: str, skip=(), keys=None) -> None:
        """An axis-aligned box; skip names faces to leave out ("-x", "+y"...); keys gives faces
        their own materials."""
        (x0, x1), (y0, y1), (z0, z1) = (sorted(pair) for pair in zip(lo, hi))
        if min(x1 - x0, y1 - y0, z1 - z0) < 1e-4:
            return
        v = [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1),
             (x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)]
        for name, index in BOX_FACES.items():
            if name in skip:
                continue
            self.face([v[i] for i in index], (keys or {}).get(name, key))

    def pane(self, points, key: str, outward, uv2=None) -> None:
        """A flat vertical piece with UVs running 0-1 across it, as seen from outside."""
        right = norm(cross(UP, outward))
        across = [dot(p, right) for p in points]
        heights = [p[1] for p in points]
        a0, a1, h0, h1 = min(across), max(across), min(heights), max(heights)
        uvs = [((a - a0) / max(a1 - a0, 1e-6), (h - h0) / max(h1 - h0, 1e-6)) for a, h in zip(across, heights)]
        self.face(points, key, uvs, [uv2] * len(points) if uv2 else None, facing=outward)

    def prism(self, outline, y0: float, y1: float, key: str, top: str | None = None, bottom: bool = False) -> None:
        """An upright prism over an outline of (x, z) points, either winding."""
        n = len(outline)
        area = sum(outline[i][0] * outline[(i + 1) % n][1] - outline[(i + 1) % n][0] * outline[i][1] for i in range(n))
        ring = outline if area > 0 else outline[::-1]       # counter-clockwise in (x, z): outward is (dz, -dx)
        for i in range(n):
            (xa, za), (xb, zb) = ring[i], ring[(i + 1) % n]
            self.face([(xa, y0, za), (xb, y0, zb), (xb, y1, zb), (xa, y1, za)], key, facing=(zb - za, 0.0, -(xb - xa)))
        self.face([(x, y1, z) for x, z in ring], top or key, facing=UP)
        if bottom:
            self.face([(x, y0, z) for x, z in ring], key, facing=(0.0, -1.0, 0.0))

    def cylinder(self, centre, radius: float, y0: float, y1: float, key: str, sides: int = 8,
                 cap: bool = True, radius_top: float | None = None) -> None:
        cx, cz = centre
        rt = radius if radius_top is None else radius_top
        ring = [(cos(2 * pi * i / sides), sin(2 * pi * i / sides)) for i in range(sides)]
        for i in range(sides):
            (ca, sa), (cb, sb) = ring[i], ring[(i + 1) % sides]
            points = [(cx + ca * radius, y0, cz + sa * radius), (cx + cb * radius, y0, cz + sb * radius),
                      (cx + cb * rt, y1, cz + sb * rt), (cx + ca * rt, y1, cz + sa * rt)]
            middle = ((ca + cb) / 2, 0.0, (sa + sb) / 2)
            if rt < 1e-4:
                points = points[:3]
            self.face(points, key, facing=middle)
        if cap and rt > 1e-4:
            self.face([(cx + c * rt, y1, cz + s * rt) for c, s in ring], key, facing=UP)

    def beam(self, a, b, size: float, key: str) -> None:
        """A square bar of side `size` from point a to point b (for stairs, rods and arms)."""
        axis = norm(sub(b, a))
        side = norm(cross(axis, UP)) if abs(axis[1]) < 0.99 else (1.0, 0.0, 0.0)
        lift = norm(cross(side, axis))
        h = size / 2.0
        corners = [(-h, -h), (h, -h), (h, h), (-h, h)]

        def at(p, s, t):
            return (p[0] + side[0] * s + lift[0] * t, p[1] + side[1] * s + lift[1] * t, p[2] + side[2] * s + lift[2] * t)
        ra = [at(a, s, t) for s, t in corners]
        rb = [at(b, s, t) for s, t in corners]
        for i in range(4):
            j = (i + 1) % 4
            mid = (corners[i][0] + corners[j][0], corners[i][1] + corners[j][1])
            out = tuple(side[k] * mid[0] + lift[k] * mid[1] for k in range(3))
            self.face([ra[i], ra[j], rb[j], rb[i]], key, facing=out)
        self.face(ra, key, facing=tuple(-c for c in axis))
        self.face(rb, key, facing=axis)


def planar_uv(point, normal, key: str):
    fam = family(key)
    tex = _state["tex"]
    if fam in ("Paint", "Glow"):
        return tex.palette_uv(key.split(":", 1)[1])
    if fam == "Fabric":
        v0, v1 = tex.fabric_v(key.split(":", 1)[1])
        return 0.0, (v0 + v1) / 2.0
    tile = TILED[fam][2] if fam in TILED else (1.0, 1.0)
    u_axis = cross(UP, normal)
    if sqrt(dot(u_axis, u_axis)) < 1e-4:
        return point[0] / tile[0], -point[2] / tile[1]
    u_axis = norm(u_axis)
    v_axis = cross(normal, u_axis)
    return dot(point, u_axis) / tile[0], dot(point, v_axis) / tile[1]


def make_object(kit: Kit, into: str = COLLECTION):
    """One mesh object from a kit, parented to the root, or None when the kit is empty."""
    if not kit.faces:
        return None
    mesh = bpy.data.meshes.new(kit.name)
    mesh.from_pydata(kit.verts, [], [face[0] for face in kit.faces])
    families = []
    for _indices, key, _uvs, _uv2 in kit.faces:
        if family(key) not in families:
            families.append(family(key))
    for name in families:
        mesh.materials.append(material(name))
    uv = mesh.uv_layers.new(name="UVMap")
    params = mesh.uv_layers.new(name="Params") if any(face[3] for face in kit.faces) else None
    for polygon, (indices, key, uvs, uv2) in zip(mesh.polygons, kit.faces):
        polygon.material_index = families.index(family(key))
        normal = polygon_normal([kit.verts[i] for i in indices])
        for corner, loop_index in enumerate(polygon.loop_indices):
            point = kit.verts[indices[corner]]
            if uvs and family(key) not in ("Paint", "Glow"):
                coords = uvs[corner]
            else:
                coords = planar_uv(point, normal, key)
            uv.data[loop_index].uv = coords
            if params is not None:
                params.data[loop_index].uv = uv2[corner] if uv2 else (0.0, 1.0)
    mesh.update()
    obj = bpy.data.objects.new(kit.name, mesh)
    collection(into).objects.link(obj)
    obj.parent = root()
    return obj


def collection(name: str) -> bpy.types.Collection:
    found = bpy.data.collections.get(name)
    if found is None:
        found = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(found)
    return found


def root() -> bpy.types.Object:
    found = bpy.data.objects.get(ROOT_NAME)
    if found is None:
        found = bpy.data.objects.new(ROOT_NAME, None)
        found.empty_display_type = "ARROWS"
        collection(COLLECTION).objects.link(found)
    found.rotation_euler = (radians(90.0), 0.0, 0.0)
    return found


def clear() -> None:
    for name in (COLLECTION, AIDS):
        found = bpy.data.collections.get(name)
        if found is None:
            continue
        for obj in list(found.all_objects):
            if obj.name == ROOT_NAME:
                continue
            data = obj.data
            bpy.data.objects.remove(obj, do_unlink=True)
            if isinstance(data, bpy.types.Mesh) and data.users == 0:
                bpy.data.meshes.remove(data)


# --- A building's own axes ------------------------------------------------------------------------

class Frame:
    """u along the front from its left end as seen from the street, y up, d back from the front."""

    def __init__(self, row: str, x0: float, x1: float, front: float) -> None:
        self.row, self.x0, self.x1, self.front = row, x0, x1, front
        self.w = x1 - x0
        self.sx = -1.0 if row == "south" else 1.0
        self.sz = 1.0 if row == "south" else -1.0
        self.ox = x1 if row == "south" else x0

    def p(self, u: float, y: float, d: float) -> tuple:
        return self.ox + self.sx * u, y, self.front + self.sz * d

    def out(self) -> tuple:
        """World direction from the front toward the street."""
        return 0.0, 0.0, -self.sz

    def side_out(self, side: str) -> tuple:
        return (-self.sx, 0.0, 0.0) if side == "left" else (self.sx, 0.0, 0.0)

    def world_face(self, local: str) -> str:
        south = self.row == "south"
        return {"front": "-z" if south else "+z", "back": "+z" if south else "-z", "left": "+x" if south else "-x",
                "right": "-x" if south else "+x", "top": "+y", "bottom": "-y"}[local]

    def box(self, kit: Kit, u0, u1, y0, y1, d0, d1, key: str, skip=(), keys=None) -> None:
        a, b = self.p(u0, y0, d0), self.p(u1, y1, d1)
        kit.box((min(a[0], b[0]), y0, min(a[2], b[2])), (max(a[0], b[0]), y1, max(a[2], b[2])), key,
                {self.world_face(s) for s in skip}, {self.world_face(k): v for k, v in (keys or {}).items()})

    def pane(self, kit: Kit, u0, u1, y0, y1, d, key: str, uv2=None) -> None:
        """A pane facing the street at depth d."""
        kit.pane([self.p(u0, y0, d), self.p(u1, y0, d), self.p(u1, y1, d), self.p(u0, y1, d)], key, self.out(), uv2)

    def side_pane(self, kit: Kit, side: str, d0, d1, y0, y1, key: str, uv2=None, proud: float = 0.02) -> None:
        """A pane on a side wall, standing proud of it."""
        u = -proud if side == "left" else self.w + proud
        kit.pane([self.p(u, y0, d0), self.p(u, y0, d1), self.p(u, y1, d1), self.p(u, y1, d0)], key,
                 self.side_out(side), uv2)

    def back_pane(self, kit: Kit, depth: float, u0, u1, y0, y1, key: str, uv2=None, proud: float = 0.02) -> None:
        d = depth + proud
        back = (0.0, 0.0, self.sz)
        kit.pane([self.p(u0, y0, d), self.p(u1, y0, d), self.p(u1, y1, d), self.p(u0, y1, d)], key, back, uv2)


# --- Markers for Godot ----------------------------------------------------------------------------

def markers() -> dict:
    return _state["markers"]


def add_collider(name: str, lo, hi, yaw: float = 0.0) -> None:
    """A collision box in world coordinates: lo and hi are corners before turning by yaw (degrees)
    about the box's middle."""
    lo, hi = [min(a, b) for a, b in zip(lo, hi)], [max(a, b) for a, b in zip(lo, hi)]
    markers()["colliders"].append({"name": name, "centre": [(a + b) / 2 for a, b in zip(lo, hi)],
                                   "size": [b - a for a, b in zip(lo, hi)], "yaw": yaw})


def frame_collider(fr: Frame, name: str, u0, u1, y0, y1, d0, d1) -> None:
    a, b = fr.p(u0, y0, d0), fr.p(u1, y1, d1)
    add_collider(name, a, b)


def add_sign(building: str, text: str, fr: Frame | None, position, facing, height: float, width: float,
             style: str, colour: str = "SignLight", pitch: float = 0.0) -> None:
    """Lettering Godot draws as a Label3D: height is the capital height in metres, width the most it
    may take; facing is the world direction the letters face. style: painted, neon, carved, ghost,
    marquee or raised. Text with line breaks stacks its lines pitch metres apart, centred on position."""
    tex = _state["tex"]
    sign = {"building": building, "text": text, "position": list(position), "facing": list(facing), "height": height,
            "width": width, "style": style, "colour": list(tex.PALETTE[colour])}
    if pitch:
        sign["pitch"] = pitch
    markers()["signs"].append(sign)


def add_light(building: str, position, colour, energy: float, reach: float, group: str = "") -> None:
    markers()["lights"].append({"building": building, "position": list(position), "colour": list(colour),
                                "energy": energy, "range": reach, "group": group})


# --- Facade parts ---------------------------------------------------------------------------------

def wall_with_openings(fr: Frame, kit: Kit, u0, u1, y0, y1, openings, key: str, depth: float = WALL_T) -> None:
    """The front wall from u0 to u1 and y0 to y1, as boxes around rectangular openings
    (ou0, ou1, oy0, oy1). The insides of the openings are the boxes' faces."""
    openings = sorted(openings)
    cursor = u0
    for ou0, ou1, oy0, oy1 in openings:
        fr.box(kit, cursor, ou0, y0, y1, 0.0, depth, key, skip=("back", "top", "bottom"))
        if oy1 < y1:
            fr.box(kit, ou0, ou1, oy1, y1, 0.0, depth, key, skip=("back", "top", "left", "right"))
        if oy0 > y0:
            fr.box(kit, ou0, ou1, y0, oy0, 0.0, depth, key, skip=("back", "bottom", "left", "right"))
        cursor = ou1
    fr.box(kit, cursor, u1, y0, y1, 0.0, depth, key, skip=("back", "top", "bottom"))


def window(fr: Frame, kit: Kit, glass: Kit, u0, u1, y0, y1, seed: str, use: str, style: int = SASH,
           sill: str | None = "Paint:Stone", lintel: str | None = "Paint:Stone", recess: float = RECESS) -> tuple:
    """Glass, sill and lintel for one opening; returns the opening for wall_with_openings."""
    room = pick(ROOM_CHOICES[use], seed + ":room")
    overlay = pick(OVERLAY_CHOICES[use], seed + ":overlay")
    fr.pane(glass, u0, u1, y0, y1, recess, "Glass", glass_codes(room, overlay, style))
    if sill:
        fr.box(kit, u0 - 0.08, u1 + 0.08, y0 - 0.1, y0, -0.07, 0.05, sill, skip=("back",))
    if lintel:
        fr.box(kit, u0 - 0.15, u1 + 0.15, y1, y1 + 0.24, -0.04, 0.05, lintel, skip=("back", "bottom"))
    return u0, u1, y0, y1


def window_row(fr: Frame, kit: Kit, glass: Kit, u0, u1, y0, y1, count: int, width: float, seed: str, use: str,
               style: int = SASH, sill="Paint:Stone", lintel="Paint:Stone") -> list:
    """count windows of `width`, centred in equal bays between u0 and u1, as openings."""
    bay = (u1 - u0) / count
    return [window(fr, kit, glass, u0 + bay * (i + 0.5) - width / 2, u0 + bay * (i + 0.5) + width / 2, y0, y1,
                   f"{seed}:{i}", use, style, sill, lintel) for i in range(count)]


def storey(fr: Frame, kit: Kit, glass: Kit, wall: str, y0, y1, count: int, width: float, height: float,
           sill_above: float, seed: str, use: str, u0: float = 0.0, u1: float | None = None, style: int = SASH,
           trim: str = "Paint:Stone") -> None:
    """One upper storey of the front: windows in equal bays and the wall around them."""
    u1 = fr.w if u1 is None else u1
    openings = window_row(fr, kit, glass, u0, u1, y0 + sill_above, y0 + sill_above + height, count, width, seed,
                          use, style, trim, trim)
    wall_with_openings(fr, kit, u0, u1, y0, y1, openings, wall)


def band(fr: Frame, kit: Kit, y0, y1, key: str, proud: float = 0.06, u0: float = 0.0, u1: float | None = None) -> None:
    u1 = fr.w if u1 is None else u1
    fr.box(kit, u0, u1, y0, y1, -proud, 0.02, key, skip=("back",))


def cornice(fr: Frame, kit: Kit, details: Kit, wall: str, y: float, top: float, colour: str = "Paint:Cornice",
            brackets: bool = True, u0: float = 0.0, u1: float | None = None, depth: float = WALL_T) -> None:
    """Brackets under a projecting cornice, a parapet above it and a coping on top."""
    u1 = fr.w if u1 is None else u1
    if brackets:
        u = u0 + 0.3
        while u < u1 - 0.25:
            fr.box(details, u, u + 0.2, y - 0.42, y, -0.22, 0.0, colour, skip=("back",))
            u += 0.55
    fr.box(kit, u0 - 0.25 if u0 == 0 else u0, u1 + 0.25 if u1 == fr.w else u1, y, y + 0.3, -0.28, depth, colour,
           skip=("back",))
    fr.box(kit, u0, u1, y + 0.3, top - 0.14, 0.0, depth, wall, skip=("back", "bottom"))
    fr.box(kit, u0 - 0.08, u1 + 0.08, top - 0.14, top, -0.08, depth + 0.05, "Paint:Stone", skip=("bottom",))


def mass(fr: Frame, kit: Kit, depth: float, roof: float, parapet: float, wall: str, outline=None) -> None:
    """The body behind the front wall: side and back walls, the flat roof and a low parapet round it."""
    if outline is None:
        corners = [fr.p(0.0, 0.0, WALL_T), fr.p(fr.w, 0.0, WALL_T), fr.p(fr.w, 0.0, depth), fr.p(0.0, 0.0, depth)]
        outline = [(c[0], c[2]) for c in corners]
    kit.prism(outline, 0.0, roof, wall, top="Paint:Tar")
    if parapet > roof:
        t = 0.3
        for u0, u1, d0, d1 in ((0.0, t, WALL_T, depth), (fr.w - t, fr.w, WALL_T, depth), (0.0, fr.w, depth - t, depth)):
            fr.box(kit, u0, u1, roof, parapet, d0, d1, wall, skip=("bottom",), keys={"top": "Paint:RoofEdge"})


def side_windows(fr: Frame, kit: Kit, glass: Kit, side: str, depth: float, floors: list, seed: str, use: str,
                 every: float = 3.4, start: float = 1.6, width: float = 1.0, height: float = 1.7) -> None:
    """Windows on a side wall, standing on its face: floors is a list of sill heights."""
    d = start
    i = 0
    while d + width < depth - 0.8:
        for k, sill in enumerate(floors):
            room = pick(ROOM_CHOICES[use], f"{seed}:{i}:{k}:room")
            overlay = pick(OVERLAY_CHOICES[use], f"{seed}:{i}:{k}:overlay")
            fr.side_pane(glass, side, d, d + width, sill, sill + height, "Glass", glass_codes(room, overlay, SASH))
            u = -0.02 if side == "left" else fr.w + 0.02
            sx = -1.0 if side == "left" else 1.0
            a = fr.p(u, sill - 0.1, d - 0.08)
            b = fr.p(u + sx * 0.08, sill, d + width + 0.08)
            kit.box((min(a[0], b[0]), a[1], min(a[2], b[2])), (max(a[0], b[0]), b[1], max(a[2], b[2])), "Paint:Stone")
            frame_bar = fr.p(u + sx * 0.03, sill + height, d - 0.06)
            frame_end = fr.p(u, sill + height + 0.12, d + width + 0.06)
            kit.box((min(frame_bar[0], frame_end[0]), frame_bar[1], min(frame_bar[2], frame_end[2])),
                    (max(frame_bar[0], frame_end[0]), frame_end[1], max(frame_bar[2], frame_end[2])), "Paint:Stone")
        d += every
        i += 1


def back_windows(fr: Frame, kit: Kit, glass: Kit, depth: float, floors: list, seed: str, use: str, every: float = 4.2,
                 door: bool = True) -> None:
    """A few windows and a back door on the back wall, standing on its face."""
    u = 1.4
    i = 0
    while u + 1.0 < fr.w - 1.0:
        for k, sill in enumerate(floors):
            room = pick(ROOM_CHOICES[use], f"{seed}:b{i}:{k}:room")
            overlay = pick(OVERLAY_CHOICES[use], f"{seed}:b{i}:{k}:overlay")
            fr.back_pane(glass, depth, u, u + 1.0, sill, sill + 1.6, "Glass", glass_codes(room, overlay, SASH))
        u += every
        i += 1
    if door:
        fr.box(kit, fr.w / 2 - 0.55, fr.w / 2 + 0.55, 0.0, 2.15, depth, depth + 0.05, "Paint:DoorGreen", skip=("front",))
        fr.box(kit, fr.w / 2 - 0.75, fr.w / 2 + 0.75, 2.3, 2.42, depth, depth + 0.6, "Paint:Iron", skip=("front",))


def awning(fr: Frame, kit: Kit, u0, u1, fabric: str, high: float = 3.36, low: float = 2.7, reach: float = 1.5) -> None:
    """A sloping fabric awning with a valance, from the wall out over the sidewalk."""
    tex = _state["tex"]
    v0, v1 = tex.fabric_v(fabric)
    period = tex.FABRIC_PERIOD * tex.FABRIC_REPEATS
    key = "Fabric:" + fabric
    top = [fr.p(u0, high, 0.0), fr.p(u1, high, 0.0), fr.p(u1, low, -reach), fr.p(u0, low, -reach)]
    uvs = [(u0 / period, v1), (u1 / period, v1), (u1 / period, v0), (u0 / period, v0)]
    up_out = (fr.out()[0], 1.0, fr.out()[2])
    kit.face(top, key, uvs, facing=up_out)
    kit.face(top[::-1], key, uvs[::-1], facing=(-up_out[0], -1.0, -up_out[2]))
    valance = [fr.p(u0, low - 0.28, -reach), fr.p(u1, low - 0.28, -reach), fr.p(u1, low, -reach), fr.p(u0, low, -reach)]
    vuvs = [(u0 / period, v0), (u1 / period, v0), (u1 / period, v1), (u0 / period, v1)]
    kit.face(valance, key, vuvs, facing=fr.out())
    kit.face(valance[::-1], key, vuvs[::-1], facing=tuple(-c for c in fr.out()))
    for u, side in ((u0, "left"), (u1, "right")):
        tri = [fr.p(u, high, 0.0), fr.p(u, low, -reach), fr.p(u, low - 0.28, -reach)]
        out = fr.side_out(side)
        kit.face(tri, key, [(0.0, v1), (0.1, v0), (0.1, v0)], facing=out)
        kit.face(tri[::-1], key, [(0.1, v0), (0.1, v0), (0.0, v1)], facing=tuple(-c for c in out))


def shopfront(fr: Frame, kit: Kit, glass: Kit, details: Kit, name: str, building: str, u0, u1, sign: str, fabric: str,
              door_right: bool, board: str = "Paint:SignBlack", frame: str = "Paint:FrameDark", wall: str = "",
              door_room: str = "shop", top: float = 4.4) -> None:
    """Pilasters, a kickplate, display glass and a recessed door, a transom, a signboard and an
    awning, between u0 and u1 below `top`."""
    p0, p1 = u0 + 0.35, u1 - 0.35
    fr.box(kit, u0, p0, 0.0, top, 0.0, WALL_T, wall, skip=("back", "bottom", "top"))
    fr.box(kit, p1, u1, 0.0, top, 0.0, WALL_T, wall, skip=("back", "bottom", "top"))
    door = (p1 - 1.45, p1 - 0.15) if door_right else (p0 + 0.15, p0 + 1.45)
    # Kickplate, display panes either side of the door, and a mullion every two metres or so.
    for a, b in ((p0, door[0]), (door[1], p1)):
        if b - a < 0.3:
            continue
        fr.box(kit, a, b, 0.0, 0.55, 0.12, WALL_T, frame, skip=("back", "bottom"))
        room = pick(ROOM_CHOICES["shop"], f"{name}:{a:.1f}:room")
        overlay = pick(OVERLAY_CHOICES["shop"], f"{name}:{a:.1f}:overlay")
        fr.pane(glass, a, b, 0.55, 2.9, 0.26, "Glass", glass_codes(room, overlay, PANE))
        panes = max(1, round((b - a) / 2.1))
        for k in range(panes + 1):
            u = a + (b - a) * k / panes
            fr.box(kit, u - 0.05, u + 0.05, 0.55, 2.95, 0.18, 0.3, frame, skip=("back",))
        fr.box(kit, a, b, 2.9, 2.98, 0.15, 0.3, frame, skip=("back",))
    # The door: a dark leaf with a glazed upper half, set back a little, and a transom over it.
    fr.box(kit, door[0], door[1], 0.0, 2.55, 0.32, WALL_T, "Paint:DoorWood", skip=("back", "bottom"))
    fr.pane(glass, door[0] + 0.18, door[1] - 0.18, 1.15, 2.35, 0.31, "Glass", glass_codes(door_room, "grime", PANE))
    fr.box(kit, door[0] - 0.08, door[0], 0.0, 2.95, 0.12, WALL_T, frame, skip=("back", "bottom"))
    fr.box(kit, door[1], door[1] + 0.08, 0.0, 2.95, 0.12, WALL_T, frame, skip=("back", "bottom"))
    fr.box(kit, door[0], door[1], 2.55, 2.62, 0.2, WALL_T, frame, skip=("back",))
    fr.pane(glass, door[0], door[1], 2.62, 2.9, 0.26, "Glass", glass_codes("hall", "grime", PANE))
    # Transom band over the whole front, the signboard and its hood.
    fr.pane(glass, p0, p1, 2.98, 3.4, 0.26, "Glass", glass_codes("empty", "dust", FOUR))
    fr.box(kit, p0, p1, 3.4, 3.44, 0.15, WALL_T, frame, skip=("back",))
    fr.box(kit, p0, p1, 3.44, 4.2, -0.06, WALL_T, board, skip=("back", "bottom"))
    fr.box(kit, p0 - 0.1, p1 + 0.1, 4.2, top if top > 4.2 else 4.4, -0.16, WALL_T, "Paint:Cornice", skip=("back",))
    middle = fr.p((p0 + p1) / 2, 3.82, -0.075)
    add_sign(building, sign, fr, middle, fr.out(), 0.5, p1 - p0 - 0.6, "painted", "SignCream")
    awning(fr, kit, p0 - 0.05, p1 + 0.05, fabric)
    # Under the sill line the wall shows between the kickplate and the pilasters: fill above the
    # signboard with wall up to the storey line.
    if top > 4.4:
        fr.box(kit, p0, p1, 4.4, top, 0.0, WALL_T, wall, skip=("back", "bottom"))


# --- Buildings ------------------------------------------------------------------------------------

def frame_of(row: str, b: dict) -> Frame:
    plan = _state["plan"]
    return Frame(row, b["x0"], b["x1"], plan.front_z(row, b))


def exposed_sides(row: str, b: dict) -> list:
    """Sides ("left", "right") that face an alley, a lot or the open, not a neighbour's wall."""
    plan = _state["plan"]
    items = dict(plan.rows())[row]
    index = items.index(b)
    west = items[index - 1] if index > 0 else None
    east = items[index + 1] if index + 1 < len(items) else None
    sides = []
    for neighbour, direction in ((west, "west"), (east, "east")):
        open_side = neighbour is None or neighbour["kind"] in ("alley", "lot") or direction in b.get("sides", ())
        if open_side:
            sides.append(local_side(row, direction))
    return sides


def local_side(row: str, direction: str) -> str:
    """The building's own side ("left" or "right", as seen from the street) on a compass side."""
    if row == "south":
        return "left" if direction == "east" else "right"
    return "left" if direction == "west" else "right"


def build_shop(row: str, b: dict) -> None:
    plan = _state["plan"]
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    ground, upper = plan.STOREYS["shop"]
    roof = ground + upper
    top = plan.height(b)
    share = fr.w / len(b["shops"])
    for i, (sign, fabric) in enumerate(b["shops"]):
        shopfront(fr, kit, glass, details, f"{b['id']}{i}", b["id"], share * i, share * (i + 1), sign, fabric,
                  door_right=i % 2 == 0, wall=wall, board=("Paint:SignGreen", "Paint:SignBlack", "Paint:SignMaroon")[i % 3])
    count = max(2, round((fr.w - 1.0) / 3.1))
    storey(fr, kit, glass, wall, ground, roof, count, 1.15, 1.85, 0.75, b["id"] + ":u", "flat")
    cornice(fr, kit, details, wall, roof, top)
    mass(fr, kit, b["depth"], roof, top - 0.4, wall)
    for side in exposed_sides(row, b):
        side_windows(fr, kit, glass, side, b["depth"], [ground + 0.9], b["id"] + side, "flat", every=4.0)
    back_windows(fr, kit, glass, b["depth"], [ground + 0.9], b["id"], "flat")
    if b.get("barber_pole"):
        u = share + 0.18
        centre = fr.p(u, 0.0, -0.32)
        details.cylinder((centre[0], centre[2]), 0.11, 1.6, 2.75, "Fabric:BarberPole", sides=8)
        details.cylinder((centre[0], centre[2]), 0.14, 2.75, 2.92, "Paint:Chrome", sides=8)
        details.cylinder((centre[0], centre[2]), 0.14, 1.45, 1.6, "Paint:Chrome", sides=8)
        bracket = fr.p(u, 2.2, 0.0)
        details.beam(bracket, (centre[0], 2.2, centre[2]), 0.05, "Paint:Iron")
    finish(row, b, fr, kit, glass, details, top)


def build_apartments(row: str, b: dict) -> None:
    plan = _state["plan"]
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    ground, upper = plan.STOREYS["apartments"]
    roof = ground + upper * (b["floors"] - 1)
    top = plan.height(b)
    e0, e1 = fr.w * 0.42, fr.w * 0.58
    (sign_a, fabric_a), (sign_b, fabric_b) = b["shops"]
    shopfront(fr, kit, glass, details, b["id"] + "A", b["id"], 0.0, e0, sign_a, fabric_a, True, wall=wall,
              board="Paint:SignNavy")
    shopfront(fr, kit, glass, details, b["id"] + "B", b["id"], e1, fr.w, sign_b, fabric_b, False, wall=wall,
              board="Paint:SignMaroon")
    # The entry between the shops: a door with a fanlight, a little canopy and the name above.
    c = (e0 + e1) / 2
    wall_with_openings(fr, kit, e0, e1, 0.0, ground, [(c - 0.65, c + 0.65, 0.0, 2.9)], wall)
    fr.box(kit, c - 0.65, c + 0.65, 0.0, 2.5, 0.3, WALL_T, "Paint:DoorWood", skip=("back", "bottom"))
    fr.pane(glass, c - 0.45, c + 0.45, 1.2, 2.3, 0.29, "Glass", glass_codes("hall", "grime", PANE))
    fr.pane(glass, c - 0.65, c + 0.65, 2.5, 2.9, 0.26, "Glass", glass_codes("hall", "dust", FOUR))
    fr.box(kit, c - 1.0, c + 1.0, 3.0, 3.12, -0.9, 0.05, "Paint:Iron", skip=("back",))
    fr.box(kit, c - 1.25, c + 1.25, 3.4, 4.05, -0.05, 0.05, "Paint:SignCream", skip=("back",))
    add_sign(b["id"], b["entry"], fr, fr.p(c, 3.72, -0.06), fr.out(), 0.36, 2.2, "painted", "FrameBlack")
    band(fr, kit, ground - 0.12, ground + 0.12, "Paint:Stone", u0=0.0, u1=fr.w)
    count = round(fr.w / 3.0)
    for k in range(1, b["floors"]):
        y0 = ground + upper * (k - 1)
        storey(fr, kit, glass, wall, y0, y0 + upper, count, 1.15, 1.8, 0.8, f"{b['id']}:f{k}", "flat")
    cornice(fr, kit, details, wall, roof, top)
    mass(fr, kit, b["depth"], roof, top - 0.45, wall)
    fire_escape(fr, details, count, b["escape"], ground, upper, b["floors"])
    if b.get("tank"):
        water_tank(details, fr.p(fr.w * 0.72, roof, b["depth"] * 0.55), roof)
    roof_hut(fr, details, kit, b["depth"], roof, wall)
    for side in exposed_sides(row, b):
        side_windows(fr, kit, glass, side, b["depth"],
                     [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])], b["id"] + side, "flat")
    back_windows(fr, kit, glass, b["depth"], [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])],
                 b["id"], "flat", every=3.0)
    finish(row, b, fr, kit, glass, details, top)


def fire_escape(fr: Frame, details: Kit, bays: int, first: int, ground: float, upper: float, floors: int) -> None:
    """Landings at each upper floor across two bays, stairs between them and a drop ladder."""
    bay = fr.w / bays
    u0, u1 = first * bay + 0.25, (first + 2) * bay - 0.25
    iron = "Paint:Iron"
    for k in range(1, floors):
        y = ground + upper * (k - 1) + 0.55
        fr.box(details, u0, u1, y - 0.08, y, -1.1, 0.0, iron)
        fr.box(details, u0, u1, y + 0.95, y + 1.0, -1.1, -1.06, iron)
        for u in (u0, u1):
            fr.box(details, u - 0.03, u + 0.03, y, y + 1.0, -1.1, -1.04, iron)
        fr.box(details, u0, u0 + 0.04, y + 0.95, y + 1.0, -1.1, 0.0, iron)
        fr.box(details, u1 - 0.04, u1, y + 0.95, y + 1.0, -1.1, 0.0, iron)
        u = u0 + 0.6
        while u < u1 - 0.3:
            fr.box(details, u - 0.015, u + 0.015, y, y + 0.95, -1.08, -1.05, iron)
            u += 0.5
        if k < floors - 1:
            a, b_ = (u0 + 0.5, u1 - 0.9) if k % 2 else (u1 - 0.5, u0 + 0.9)
            details.beam(fr.p(a, y, -0.55), fr.p(b_, y + upper, -0.55), 0.09, iron)
            details.beam(fr.p(a, y + 0.9, -0.95), fr.p(b_, y + upper + 0.9, -0.95), 0.04, iron)
    # The drop ladder hangs drawn up, its foot clear of the awnings below.
    y = ground + 0.55
    for u in (u1 - 0.85, u1 - 0.4):
        fr.box(details, u - 0.02, u + 0.02, 3.6, y, -1.0, -0.96, iron)
    rung = 3.75
    while rung < y - 0.1:
        fr.box(details, u1 - 0.85, u1 - 0.4, rung - 0.015, rung + 0.015, -1.0, -0.97, iron)
        rung += 0.3


def water_tank(details: Kit, base, roof: float) -> None:
    x, _y, z = base
    for dx, dz in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
        details.beam((x + dx, roof, z + dz), (x + dx * 0.85, roof + 1.8, z + dz * 0.85), 0.14, "Paint:Iron")
    details.box((x - 1.2, roof + 1.8, z - 1.2), (x + 1.2, roof + 1.9, z + 1.2), "Paint:Iron")
    details.cylinder((x, z), 1.3, roof + 1.9, roof + 4.3, "Paint:TankWood", sides=10, cap=False)
    for h in (2.3, 3.1, 3.9):
        details.cylinder((x, z), 1.33, roof + h, roof + h + 0.07, "Paint:TankBand", sides=10, cap=False)
    details.cylinder((x, z), 1.45, roof + 4.3, roof + 5.1, "Paint:TankWood", sides=10, radius_top=0.0)


def roof_hut(fr: Frame, details: Kit, kit: Kit, depth: float, roof: float, wall: str) -> None:
    """The stair bulkhead and a couple of vents on a flat roof."""
    u, d = fr.w * 0.3, depth * 0.6
    fr.box(details, u - 1.3, u + 1.3, roof, roof + 2.6, d - 1.6, d + 1.6, wall, keys={"top": "Paint:Tar"})
    fr.box(details, u - 0.5, u + 0.5, roof, roof + 2.1, d - 1.62, d - 1.6, "Paint:DoorGreen")
    for k, du in enumerate((0.2, 0.75)):
        centre = fr.p(fr.w * du, roof, depth * (0.3 + 0.4 * k))
        details.cylinder((centre[0], centre[2]), 0.18, roof, roof + 1.1, "Paint:Steel", sides=6)
        details.cylinder((centre[0], centre[2]), 0.32, roof + 1.1, roof + 1.35, "Paint:Steel", sides=6, radius_top=0.05)


def build_bank(row: str, b: dict) -> None:
    plan = _state["plan"]
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    ground, upper = plan.STOREYS["bank"]
    roof = ground + upper * (b["floors"] - 1)
    top = plan.height(b)
    corner = 3.2
    corner_side = local_side(row, b["corner"])
    # The street front runs from the far end to the cut corner; the side front runs back from it.
    f0, f1 = (corner, fr.w) if corner_side == "left" else (0.0, fr.w - corner)
    bays = 4
    bay = (f1 - f0) / bays
    lower = []
    for i in range(bays):
        c = f0 + bay * (i + 0.5)
        lower.append(window(fr, kit, glass, c - 0.95, c + 0.95, 0.9, 4.4, f"{b['id']}:g{i}", "lobby", FOUR, "Paint:Stone", None))
        fanlight(fr, kit, glass, c, 4.62, 0.95, f"{b['id']}:fan{i}")
    wall_with_openings(fr, kit, f0, f1, 0.0, ground, lower, wall)
    for k in range(1, b["floors"]):
        y0 = ground + upper * (k - 1)
        storey(fr, kit, glass, wall, y0, y0 + upper, bays, 1.2, 1.9, 0.6, f"{b['id']}:f{k}", "office",
               u0=f0, u1=f1, style=FOUR)
    for i in range(bays + 1):
        u = f0 + bay * i
        fr.box(kit, u - 0.35, u + 0.35, ground, roof, -0.12, 0.0, wall, skip=("back", "bottom"))
    band(fr, kit, ground - 0.25, ground, "Paint:Stone", 0.1, f0, f1)
    # Frieze with the carved name, cornice and coping.
    fr.box(kit, f0, f1, roof, roof + 0.75, -0.04, WALL_T, wall, skip=("back", "bottom"))
    add_sign(b["id"], b["sign"], fr, fr.p((f0 + f1) / 2, roof + 0.37, -0.05), fr.out(), 0.42, f1 - f0 - 1.0, "carved",
             "StoneDark")
    fr.box(kit, f0 - (0.35 if f0 == 0 else 0.0), f1 + (0.35 if f1 == fr.w else 0.0), roof + 0.75, roof + 1.05, -0.35,
           WALL_T, "Paint:StoneDark", skip=("back",))
    fr.box(kit, f0, f1, roof + 1.05, top, 0.0, WALL_T, wall, skip=("back", "bottom"), keys={"top": "Paint:RoofEdge"})
    # The cut corner: a slab across it with the door, a window per floor and the clock.
    a = fr.p(f1 if corner_side == "right" else f0, 0.0, 0.0)
    side_u = fr.w if corner_side == "right" else 0.0
    c_pt = fr.p(side_u, 0.0, corner)
    middle = fr.p(fr.w / 2, 0.0, b["depth"] / 2)
    diagonal(kit, glass, details, b, (a[0], a[2]), (c_pt[0], c_pt[2]), (middle[0], middle[2]), top, roof, ground,
             upper, wall)
    # Side front along the Connector road: the same treatment, back from the corner.
    side_front(fr, kit, glass, b, corner_side, corner, b["depth"], ground, upper, roof, top, wall)
    # Body, roof and parapet. The outline stays behind both fronts and the corner.
    t = WALL_T
    if corner_side == "right":
        outline_local = [(0.0, t), (fr.w - corner, t), (fr.w - t, corner), (fr.w - t, b["depth"]), (0.0, b["depth"])]
    else:
        outline_local = [(corner, t), (fr.w, t), (fr.w, b["depth"]), (t, b["depth"]), (t, corner)]
    outline = [(fr.p(u, 0, d)[0], fr.p(u, 0, d)[2]) for u, d in outline_local]
    kit.prism(outline, 0.0, roof, wall, top="Paint:Tar")
    far = 0.0 if corner_side == "right" else fr.w - 0.3
    fr.box(kit, far, far + 0.3, roof, top - 0.3, t, b["depth"], wall, skip=("bottom",), keys={"top": "Paint:RoofEdge"})
    fr.box(kit, 0.0, fr.w, roof, top - 0.3, b["depth"] - 0.3, b["depth"], wall, skip=("bottom",),
           keys={"top": "Paint:RoofEdge"})
    back_windows(fr, kit, glass, b["depth"], [ground + 0.6, ground + upper + 0.6], b["id"], "office", every=3.6)
    finish(row, b, fr, kit, glass, details, top)
    # The cut corner needs its own collision: two boxes, and a turned one along the corner's wall.
    markers()["colliders"] = [c for c in markers()["colliders"] if c["name"] != b["id"]]
    if corner_side == "right":
        frame_collider(fr, b["id"], 0.0, fr.w - corner, 0.0, top, 0.0, b["depth"])
        frame_collider(fr, b["id"] + "Side", fr.w - corner, fr.w, 0.0, top, corner, b["depth"])
    else:
        frame_collider(fr, b["id"], corner, fr.w, 0.0, top, 0.0, b["depth"])
        frame_collider(fr, b["id"] + "Side", 0.0, corner, 0.0, top, corner, b["depth"])
    along = norm((c_pt[0] - a[0], 0.0, c_pt[2] - a[2]))
    inward = norm((middle[0] - (a[0] + c_pt[0]) / 2, 0.0, middle[2] - (a[2] + c_pt[2]) / 2))
    length = sqrt((a[0] - c_pt[0]) ** 2 + (a[2] - c_pt[2]) ** 2)
    centre = [(a[0] + c_pt[0]) / 2 + inward[0] * WALL_T, top / 2, (a[2] + c_pt[2]) / 2 + inward[2] * WALL_T]
    add_collider(b["id"] + "Corner", (centre[0] - length / 2, 0.0, centre[2] - WALL_T),
                 (centre[0] + length / 2, top, centre[2] + WALL_T), yaw_of(along))


def yaw_of(direction) -> float:
    """Degrees about +y, as Godot turns a node, that carry +x onto a horizontal direction."""
    from math import atan2, degrees
    return degrees(atan2(-direction[2], direction[0]))


def fanlight(fr: Frame, kit: Kit, glass: Kit, c: float, spring: float, radius: float, seed: str) -> None:
    """A half-round pane over a window head, framed by a stone arch, standing on the wall."""
    steps = 8
    arc = [(c + radius * cos(pi * i / steps), spring + radius * sin(pi * i / steps)) for i in range(steps + 1)]
    points = [fr.p(u, y, -0.02) for u, y in arc]
    room = pick(ROOM_CHOICES["lobby"], seed)
    glass.pane(points, "Glass", fr.out(), glass_codes(room, "dust", BARE))
    for i in range(steps):
        (ua, ya), (ub, yb) = arc[i], arc[i + 1]
        outer_a = (c + (ua - c) * 1.25, spring + (ya - spring) * 1.25)
        outer_b = (c + (ub - c) * 1.25, spring + (yb - spring) * 1.25)
        ring = [fr.p(ua, ya, -0.05), fr.p(outer_a[0], outer_a[1], -0.05), fr.p(outer_b[0], outer_b[1], -0.05),
                fr.p(ub, yb, -0.05)]
        kit.face(ring, "Paint:Stone", facing=fr.out())
    fr.box(kit, c - 0.17, c + 0.17, spring + radius * 1.05, spring + radius * 1.4, -0.08, 0.0, "Paint:StoneDark",
           skip=("back",))


def diagonal(kit: Kit, glass: Kit, details: Kit, b: dict, a, c, middle, top: float, roof: float, ground: float,
             upper: float, wall: str) -> None:
    """The bank's cut corner from a to c (x, z): a wall slab with the door, windows and the clock.
    middle is a point inside the building, to tell outward from inward."""
    ax, az = a
    cx, cz = c
    along = norm((cx - ax, 0.0, cz - az))
    out = norm((along[2], 0.0, -along[0]))
    if (middle[0] - (ax + cx) / 2) * out[0] + (middle[1] - (az + cz) / 2) * out[2] > 0:
        out = (-out[0], 0.0, -out[2])
    length = sqrt((cx - ax) ** 2 + (cz - az) ** 2)

    def at(s, y, d):
        """s along the corner from a, d inward."""
        return (ax + along[0] * s - out[0] * d, y, az + along[2] * s - out[2] * d)
    # Front face of the slab, with three openings stacked in the middle.
    w0, w1 = length / 2 - 0.8, length / 2 + 0.8
    rows = [(0.0, 3.2), (ground + 0.6, ground + 2.5), (ground + upper + 0.6, ground + upper + 2.5)]
    y_breaks = [0.0, ground, ground + upper, roof, top]
    for y0, y1 in zip(y_breaks, y_breaks[1:]):
        opening = next(((o0, o1) for o0, o1 in rows if y0 <= o0 < y1), None)
        pieces = [(0.0, w0, y0, y1), (w1, length, y0, y1)]
        if opening:
            o0, o1 = opening
            pieces += [(w0, w1, y0, o0), (w0, w1, o1, y1)]
        else:
            pieces += [(w0, w1, y0, y1)]
        for s0, s1, h0, h1 in pieces:
            if s1 - s0 < 1e-3 or h1 - h0 < 1e-3:
                continue
            front = [at(s0, h0, 0.0), at(s1, h0, 0.0), at(s1, h1, 0.0), at(s0, h1, 0.0)]
            kit.face(front, wall, facing=out)
    for o0, o1 in rows:
        for s in (w0, w1):
            side = [at(s, o0, 0.0), at(s, o0, WALL_T), at(s, o1, WALL_T), at(s, o1, 0.0)]
            kit.face(side, wall, facing=along if s == w0 else tuple(-v for v in along))
        kit.face([at(w0, o1, 0.0), at(w1, o1, 0.0), at(w1, o1, WALL_T), at(w0, o1, WALL_T)], wall, facing=(0, -1, 0))
        if o0 > 0:
            kit.face([at(w0, o0, 0.0), at(w0, o0, WALL_T), at(w1, o0, WALL_T), at(w1, o0, 0.0)], wall, facing=UP)
    # The door leaf, glass over it, and windows above. The body behind the corner starts 0.28 m in,
    # so all of these stand in front of that.
    kit.face([at(w0, 0.0, 0.25), at(w1, 0.0, 0.25), at(w1, 2.7, 0.25), at(w0, 2.7, 0.25)], "Paint:DoorWood", facing=out)
    glass.pane([at(w0, 2.7, 0.2), at(w1, 2.7, 0.2), at(w1, 3.2, 0.2), at(w0, 3.2, 0.2)], "Glass", out,
               glass_codes("lobby", "dust", FOUR))
    glass.pane([at(w0 + 0.15, 1.1, 0.24), at(w1 - 0.15, 1.1, 0.24), at(w1 - 0.15, 2.5, 0.24), at(w0 + 0.15, 2.5, 0.24)],
               "Glass", out, glass_codes("lobby", "grime", PANE))
    for o0, o1 in rows[1:]:
        glass.pane([at(w0, o0, RECESS), at(w1, o0, RECESS), at(w1, o1, RECESS), at(w0, o1, RECESS)], "Glass", out,
                   glass_codes(pick(ROOM_CHOICES["office"], f"bankcorner{o0}"), "blinds", FOUR))
    # Cornice and frieze carried round the corner.
    kit.face([at(0.0, roof, -0.04), at(length, roof, -0.04), at(length, roof + 0.75, -0.04), at(0.0, roof + 0.75, -0.04)],
             wall, facing=out)
    kit.face([at(0.0, roof + 0.75, -0.35), at(length, roof + 0.75, -0.35), at(length, roof + 1.05, -0.35),
              at(0.0, roof + 1.05, -0.35)], "Paint:StoneDark", facing=out)
    kit.face([at(0.0, roof + 0.75, -0.35), at(0.0, roof + 0.75, 0.0), at(length, roof + 0.75, 0.0),
              at(length, roof + 0.75, -0.35)], "Paint:StoneDark", facing=(0, -1, 0))
    kit.face([at(0.0, roof + 1.05, -0.35), at(length, roof + 1.05, -0.35), at(length, roof + 1.05, 0.0),
              at(0.0, roof + 1.05, 0.0)], "Paint:StoneDark", facing=UP)
    # The clock on an iron bracket over the door: a case with a lit round face on either side.
    hub = at(length / 2, 4.75, -1.0)
    details.beam(at(length / 2, 4.75, 0.0), at(length / 2, 4.75, -0.7), 0.08, "Paint:Iron")
    details.beam(at(length / 2, 4.75, -0.92), at(length / 2, 4.75, -1.08), 1.25, "Paint:Iron")
    face_points = [(hub[0] + along[0] * 0.55 * cos(2 * pi * i / 12), 4.75 + 0.55 * sin(2 * pi * i / 12),
                    hub[2] + along[2] * 0.55 * cos(2 * pi * i / 12)) for i in range(12)]
    for shift in (0.085, -0.085):
        direction = out if shift < 0 else tuple(-v for v in out)
        ring = [(p[0] - out[0] * shift, p[1], p[2] - out[2] * shift) for p in face_points]
        details.face(ring, "Glow:ClockFace", facing=direction)
        for dx0, dx1, dy0, dy1 in ((-0.02, 0.02, 0.0, 0.42), (0.0, 0.3, -0.02, 0.02)):
            hand = [(hub[0] - out[0] * shift * 1.05 + along[0] * dx, 4.75 + dy, hub[2] - out[2] * shift * 1.05 + along[2] * dx)
                    for dx, dy in ((dx0, dy0), (dx1, dy0), (dx1, dy1), (dx0, dy1))]
            details.face(hand, "Paint:FrameBlack", facing=direction)
    add_light(b["id"], at(length / 2, 3.6, -1.2), _state["tex"].PALETTE["LampWarm"], 0.35, 5.0)


def side_front(fr: Frame, kit: Kit, glass: Kit, b: dict, side: str, start: float, depth: float,
               ground: float, upper: float, roof: float, top: float, wall: str) -> None:
    """The bank's front along the Connector road: windows in bays from the corner back, on a wall
    slab of its own."""
    u_face = fr.w if side == "right" else 0.0
    inward = -1.0 if side == "right" else 1.0
    out = fr.side_out(side)
    bays = 4
    bay = (depth - start - 0.6) / bays

    def at(d, y, inset):
        return fr.p(u_face + inward * inset, y, d)
    for y0, y1 in ((0.0, ground), (ground, ground + upper), (ground + upper, roof), (roof, top)):
        storey_index = 0 if y1 <= ground else (1 if y1 <= ground + upper + 1e-6 else (2 if y1 <= roof + 1e-6 else 3))
        cursor = start
        for i in range(bays):
            c = start + bay * (i + 0.5)
            if storey_index == 0:
                o = (c - 0.85, c + 0.85, 0.9, 4.4)
            elif storey_index in (1, 2):
                base = ground + upper * (storey_index - 1)
                o = (c - 0.6, c + 0.6, base + 0.6, base + 2.5)
            else:
                o = None
            if o is None:
                continue
            d0, d1, h0, h1 = o
            kit.face([at(cursor, y0, 0), at(d0, y0, 0), at(d0, y1, 0), at(cursor, y1, 0)], wall, facing=out)
            kit.face([at(d0, y0, 0), at(d1, y0, 0), at(d1, h0, 0), at(d0, h0, 0)], wall, facing=out)
            kit.face([at(d0, h1, 0), at(d1, h1, 0), at(d1, y1, 0), at(d0, y1, 0)], wall, facing=out)
            along = norm(sub(fr.p(0, 0, 1), fr.p(0, 0, 0)))
            for d, facing_sign in ((d0, 1.0), (d1, -1.0)):
                kit.face([at(d, h0, 0), at(d, h0, WALL_T), at(d, h1, WALL_T), at(d, h1, 0)], wall,
                         facing=tuple(v * facing_sign for v in along))
            kit.face([at(d0, h1, 0), at(d1, h1, 0), at(d1, h1, WALL_T), at(d0, h1, WALL_T)], wall, facing=(0, -1, 0))
            kit.face([at(d0, h0, 0), at(d0, h0, WALL_T), at(d1, h0, WALL_T), at(d1, h0, 0)], wall, facing=UP)
            room = pick(ROOM_CHOICES["lobby" if storey_index == 0 else "office"], f"{b['id']}:side{i}:{storey_index}")
            overlay = pick(OVERLAY_CHOICES["lobby" if storey_index == 0 else "office"], f"{b['id']}:sideo{i}:{storey_index}")
            glass.pane([at(d0, h0, RECESS), at(d1, h0, RECESS), at(d1, h1, RECESS), at(d0, h1, RECESS)], "Glass", out,
                       glass_codes(room, overlay, FOUR))
            sill = [at(d0 - 0.08, h0 - 0.1, -0.07), at(d1 + 0.08, h0, 0.05)]
            kit.box((min(sill[0][0], sill[1][0]), sill[0][1], min(sill[0][2], sill[1][2])),
                    (max(sill[0][0], sill[1][0]), sill[1][1], max(sill[0][2], sill[1][2])), "Paint:Stone")
            if storey_index == 0:
                fanlight_side(fr, kit, glass, side, u_face, (d0 + d1) / 2, 4.62, 0.85, out, f"{b['id']}:sf{i}")
            cursor = d1
        kit.face([at(cursor, y0, 0), at(depth, y0, 0), at(depth, y1, 0), at(cursor, y1, 0)], wall, facing=out)
    # The cornice is carried round from the front.
    cornice_side = [at(start, roof + 0.75, -0.35), at(depth, roof + 0.75, -0.35), at(depth, roof + 1.05, -0.35),
                    at(start, roof + 1.05, -0.35)]
    kit.face(cornice_side, "Paint:StoneDark", facing=out)
    kit.face([at(start, roof + 0.75, -0.35), at(start, roof + 0.75, 0.0), at(depth, roof + 0.75, 0.0),
              at(depth, roof + 0.75, -0.35)], "Paint:StoneDark", facing=(0, -1, 0))
    kit.face([at(start, roof + 1.05, -0.35), at(depth, roof + 1.05, -0.35), at(depth, roof + 1.05, 0.0),
              at(start, roof + 1.05, 0.0)], "Paint:StoneDark", facing=UP)


def fanlight_side(fr: Frame, kit: Kit, glass: Kit, side: str, u_face: float, d: float, spring: float, radius: float,
                  out, seed: str) -> None:
    steps = 8
    offset = 0.02 if side == "right" else -0.02
    arc = [(d + radius * cos(pi * i / steps), spring + radius * sin(pi * i / steps)) for i in range(steps + 1)]
    points = [fr.p(u_face + offset, y, dd) for dd, y in arc]
    glass.pane(points, "Glass", out, glass_codes("lobby", "dust", BARE))
    for i in range(steps):
        (da, ya), (db, yb) = arc[i], arc[i + 1]
        outer = lambda dd, y: (d + (dd - d) * 1.25, spring + (y - spring) * 1.25)
        oa, ob = outer(da, ya), outer(db, yb)
        ring = [fr.p(u_face + offset * 2.5, ya, da), fr.p(u_face + offset * 2.5, oa[1], oa[0]),
                fr.p(u_face + offset * 2.5, ob[1], ob[0]), fr.p(u_face + offset * 2.5, yb, db)]
        kit.face(ring, "Paint:Stone", facing=out)


def build_cinema(row: str, b: dict) -> None:
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    w, c = fr.w, fr.w / 2
    body = 12.5
    # Front wall with the entrance and four tall stair windows; stepped parapet over the middle.
    entrance = (c - 2.6, c + 2.6, 0.0, 2.75)
    tall = [(c + dx - 0.32, c + dx + 0.32, 6.5, 11.4) for dx in (-5.2, -4.0, 4.0, 5.2)]
    for o in tall:
        fr.pane(glass, o[0], o[1], o[2], o[3], RECESS, "Glass", glass_codes("hall", "nets", FOUR))
    wall_with_openings(fr, kit, 0.0, w, 0.0, body, [entrance] + tall, wall)
    fr.box(kit, c - w * 0.37, c + w * 0.37, body, 13.5, 0.0, WALL_T, wall, skip=("back", "bottom"),
           keys={"top": "Paint:Stone"})
    fr.box(kit, c - w * 0.22, c + w * 0.22, 13.5, 14.6, 0.0, WALL_T, wall, skip=("back", "bottom"),
           keys={"top": "Paint:Stone"})
    fr.box(kit, 0.0, w, body - 0.15, body, -0.06, WALL_T, "Paint:Stone", skip=("back", "bottom"))
    u = 0.8
    while u < w - 0.5:
        if not any(o[0] - 0.2 < u < o[1] + 0.2 for o in tall) and abs(u - c) > 0.9:
            fr.box(details, u - 0.06, u + 0.06, 6.2, 12.2, -0.06, 0.0, "Paint:Stone", skip=("back",))
        u += 1.2
    # Doors under the marquee, the ticket booth and the poster cases.
    for i in range(4):
        u0 = c - 2.4 + i * 1.2
        fr.pane(glass, u0, u0 + 1.0, 0.1, 2.5, 0.35, "Glass", glass_codes("lobby", "grime", PANE))
        fr.box(kit, u0 - 0.1, u0, 0.0, 2.75, 0.3, WALL_T, "Paint:FrameDark", skip=("back",))
    fr.box(kit, c + 2.4, c + 2.6, 0.0, 2.75, 0.3, WALL_T, "Paint:FrameDark", skip=("back",))
    fr.box(kit, c - 2.6, c + 2.6, 2.5, 2.75, 0.3, WALL_T, "Paint:FrameDark", skip=("back",))
    # The ticket booth stands in the entrance, out of the sidewalk's clear walk.
    fr.box(kit, c - 0.9, c + 0.9, 0.0, 2.4, -0.35, 0.3, "Paint:FrameRed", keys={"top": "Paint:Cornice"})
    fr.pane(glass, c - 0.65, c + 0.65, 1.1, 2.05, -0.37, "Glass", glass_codes("lit_living", "grime", PANE))
    frame_collider(fr, b["id"] + "Booth", c - 0.9, c + 0.9, 0.0, 2.4, -0.35, 0.0)
    for dx in (-6.6, -4.9, 4.9, 6.6):
        fr.box(kit, c + dx - 0.6, c + dx + 0.6, 0.7, 2.5, -0.08, 0.0, "Paint:Brass", skip=("back",))
        poster = "Glow:PosterA" if dx < 0 else "Glow:PosterB"
        fr.pane(kit, c + dx - 0.48, c + dx + 0.48, 0.82, 2.38, -0.09, poster)
    # Marquee: a lit letter board on three sides, bulbs along its edges, dark underneath.
    m0, m1, my0, my1, reach = c - 6.8, c + 6.8, 3.4, 5.5, 2.8
    fr.box(kit, m0, m1, my0, my1, -reach, 0.0, "Paint:FrameDark", skip=("back",))
    fr.pane(kit, m0 + 0.25, m1 - 0.25, my0 + 0.22, my1 - 0.22, -reach - 0.01, "Glow:MarqueeBoard")
    for side, u in (("left", m0), ("right", m1)):
        pad = -0.01 if side == "left" else 0.01
        pts = [fr.p(u + pad, my0 + 0.22, -reach + 0.25), fr.p(u + pad, my0 + 0.22, -0.25),
               fr.p(u + pad, my1 - 0.22, -0.25), fr.p(u + pad, my1 - 0.22, -reach + 0.25)]
        kit.pane(pts, "Glow:MarqueeBoard", fr.side_out(side))
    for y in (my0 + 0.08, my1 - 0.08):
        fr.box(details, m0 - 0.02, m1 + 0.02, y - 0.05, y + 0.05, -reach - 0.05, -reach + 0.02, "Glow:BulbWarm")
    fr.box(details, m0 + 0.3, m1 - 0.3, my0 - 0.02, my0, -reach + 0.3, -0.3, "Glow:BulbWarm", skip=("top",))
    line1, line2 = b["marquee"]
    add_sign(b["id"], line1, fr, fr.p(c, 4.7, -reach - 0.03), fr.out(), 0.62, 12.0, "marquee", "FrameBlack")
    add_sign(b["id"], line2, fr, fr.p(c, 3.95, -reach - 0.03), fr.out(), 0.42, 12.0, "marquee", "FrameBlack")
    for side, u in (("left", m0), ("right", m1)):
        add_sign(b["id"], b["sign"], fr, fr.p(u + (-0.03 if side == "left" else 0.03), 4.45, -reach / 2),
                 fr.side_out(side), 0.55, 2.0, "marquee", "FrameBlack")
    add_light(b["id"], fr.p(c, 3.1, -2.0), _state["tex"].PALETTE["BulbWarm"], 1.2, 9.0, "marquee")
    # The vertical blade sign, readable up and down the street, outlined in neon.
    s0, s1 = 5.9, 14.0
    fr.box(kit, c - 0.3, c + 0.3, s0, s1, -1.9, -0.1, "Paint:FrameDark")
    for u in (c - 0.31, c + 0.31):
        fr.box(details, u - 0.01, u + 0.01, s0 + 0.15, s1 - 0.15, -1.85, -1.75, "Glow:NeonTeal")
        fr.box(details, u - 0.01, u + 0.01, s1 - 0.25, s1 - 0.15, -1.85, -0.2, "Glow:NeonTeal")
        fr.box(details, u - 0.01, u + 0.01, s0 + 0.15, s0 + 0.25, -1.85, -0.2, "Glow:NeonTeal")
    pitch = 1.25
    middle = s1 - 0.95 - (len(b["sign"]) - 1) * pitch / 2
    for side, u in (("left", c - 0.33), ("right", c + 0.33)):
        add_sign(b["id"], "\n".join(b["sign"]), fr, fr.p(u, middle, -1.0), fr.side_out(side), 0.95, 1.4, "neon",
                 "NeonPink", pitch)
    fr.box(details, c - 0.05, c + 0.05, s1 - 0.6, s1 - 0.5, -1.9, 0.0, "Paint:Iron")
    add_light(b["id"], fr.p(c, 10.0, -2.6), _state["tex"].PALETTE["NeonPink"], 1.4, 10.0, "neon")
    mass(fr, kit, b["depth"], body - 0.5, body - 0.5, wall)
    for side in exposed_sides(row, b):
        side_windows(fr, kit, glass, side, b["depth"], [6.0], b["id"] + side, "stair", every=7.0, start=3.0)
    back_windows(fr, kit, glass, b["depth"], [], b["id"], "stair")
    finish(row, b, fr, kit, glass, details, 14.6)


def build_hotel(row: str, b: dict) -> None:
    plan = _state["plan"]
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    ground, upper = plan.STOREYS["hotel"]
    roof = ground + upper * (b["floors"] - 1)
    top = plan.height(b)
    bays = 7
    bay = fr.w / bays
    c = fr.w / 2
    lobby = []
    for i in range(bays):
        u = bay * (i + 0.5)
        if i == bays // 2:
            lobby.append((u - 0.95, u + 0.95, 0.0, 3.0))
            continue
        lobby.append(window(fr, kit, glass, u - 0.9, u + 0.9, 0.6, 3.6, f"{b['id']}:l{i}", "lobby", FOUR, "Paint:Stone",
                            "Paint:Stone"))
    wall_with_openings(fr, kit, 0.0, fr.w, 0.0, ground, lobby, wall)
    fr.box(kit, c - 0.95, c + 0.95, 0.0, 3.0, 0.32, WALL_T, "Paint:FrameDark", skip=("back", "bottom"))
    for u0 in (c - 0.85, c + 0.05):
        fr.pane(glass, u0, u0 + 0.8, 0.1, 2.75, 0.31, "Glass", glass_codes("lobby", "grime", PANE))
    for k in range(1, b["floors"]):
        y0 = ground + upper * (k - 1)
        storey(fr, kit, glass, wall, y0, y0 + upper, bays, 1.1, 1.8, 0.8, f"{b['id']}:f{k}", "hotel")
        band(fr, kit, y0 - 0.12, y0 + 0.1, "Paint:Stone")
    cornice(fr, kit, details, wall, roof, top, brackets=True)
    mass(fr, kit, b["depth"], roof, top - 0.4, wall)
    # The entrance canopy, hung on rods, with the name along its front.
    fr.box(kit, c - 2.8, c + 2.8, 3.05, 3.5, -3.0, 0.0, "Paint:FrameDark", keys={"bottom": "Paint:Cornice"})
    for u in (c - 2.6, c + 2.6):
        details.beam(fr.p(u, 3.5, -2.9), fr.p(u * 0.0 + (c - 1.2 if u < c else c + 1.2), 5.0, 0.0), 0.04, "Paint:Iron")
    add_sign(b["id"], "HOTEL", fr, fr.p(c, 3.27, -3.02), fr.out(), 0.3, 5.0, "painted", "SignCream")
    fr.box(details, c - 2.6, c + 2.6, 3.03, 3.05, -2.8, -0.2, "Glow:BulbWarm", skip=("top",))
    add_light(b["id"], fr.p(c, 2.7, -1.5), _state["tex"].PALETTE["LampWarm"], 0.6, 6.0)
    # Roof letters on a steel lattice at the front of the roof, clear of the parapet so they read from
    # the sidewalk below; one letter is dead.
    steel = "Paint:Steel"
    l0, l1 = 1.2, fr.w - 1.2
    sign_d, foot = 0.9, top + 0.35
    for u in [l0 + (l1 - l0) * k / 8 for k in range(9)]:
        fr.box(details, u - 0.06, u + 0.06, roof, foot + 3.0, sign_d - 0.06, sign_d + 0.06, steel)
        details.beam(fr.p(u, roof, sign_d + 2.2), fr.p(u, foot + 2.2, sign_d + 0.06), 0.06, steel)
    for y in (foot + 0.25, foot + 2.95):
        fr.box(details, l0, l1, y - 0.05, y + 0.05, sign_d - 0.05, sign_d + 0.05, steel)
    word = b["sign"]
    add_sign(b["id"], word, fr, fr.p(c, foot + 1.6, sign_d - 0.12), fr.out(), 2.0, l1 - l0, "neon", "BulbWarm")
    markers()["signs"][-1]["dead_letter"] = b.get("dead_letter", -1)
    add_light(b["id"], fr.p(c, foot + 1.2, sign_d - 2.5), _state["tex"].PALETTE["BulbWarm"], 1.0, 14.0, "neon")
    # The ghost sign on the side over the corner lot.
    sides = exposed_sides(row, b)
    for side in sides:
        u_face = 0.0 if side == "left" else fr.w
        pad = -0.02 if side == "left" else 0.02
        out = fr.side_out(side)
        panel = [fr.p(u_face + pad, 8.4, 3.0), fr.p(u_face + pad, 8.4, 17.0), fr.p(u_face + pad, 16.2, 17.0),
                 fr.p(u_face + pad, 16.2, 3.0)]
        kit.pane(panel, "Paint:GhostPanel", out)
        line1, line2 = b["ghost"]
        add_sign(b["id"], line1, fr, fr.p(u_face + pad * 2, 13.6, 10.0), out, 1.5, 13.0, "ghost", "SignCream")
        add_sign(b["id"], line2, fr, fr.p(u_face + pad * 2, 10.6, 10.0), out, 0.9, 13.0, "ghost", "SignCream")
        side_windows(fr, kit, glass, side, b["depth"], [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])],
                     b["id"] + side, "hotel", every=3.2, start=17.2)
    back_windows(fr, kit, glass, b["depth"], [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])],
                 b["id"], "hotel", every=3.1)
    finish(row, b, fr, kit, glass, details, top)


def build_civic(row: str, b: dict) -> None:
    plan = _state["plan"]
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    wall = b["wall"]
    post = b["variant"] == "post"
    ground, upper = plan.STOREYS[b["variant"]]
    roof = ground + upper * (b["floors"] - 1)
    top = plan.height(b)
    bays = 5 if post else 6
    bay = fr.w / bays
    c = fr.w / 2
    step = SIDEWALK + 0.51 if post else 0.0      # the post office stands on three steps
    lower = []
    for i in range(bays):
        u = bay * (i + 0.5)
        door = (i == 2) if post else i in (2, 3)
        if door:
            continue
        lower.append(window(fr, kit, glass, u - (0.75 if post else 0.65), u + (0.75 if post else 0.65),
                            step + (0.9 if post else 1.0), step + (3.7 if post else 3.2), f"{b['id']}:g{i}",
                            "lobby" if post else "office", FOUR))
    door_w = 0.9 if post else 1.4
    lower.append((c - door_w, c + door_w, step, step + (3.4 if post else 2.8)))
    wall_with_openings(fr, kit, 0.0, fr.w, 0.0, ground, lower, wall)
    fr.box(kit, c - door_w, c + door_w, step, step + 2.6, 0.32, WALL_T, "Paint:DoorWood", skip=("back", "bottom"))
    for u0 in (c - door_w + 0.15, c + 0.08):
        fr.pane(glass, u0, u0 + door_w - 0.23, step + 1.1, step + 2.4, 0.31, "Glass",
                glass_codes("lobby", "grime", PANE))
    fr.pane(glass, c - door_w, c + door_w, step + 2.6, step + (3.4 if post else 2.8), 0.26, "Glass",
            glass_codes("lobby", "dust", FOUR))
    for k in range(1, b["floors"]):
        y0 = ground + upper * (k - 1)
        storey(fr, kit, glass, wall, y0, y0 + upper, bays, 1.3 if post else 1.2, 2.0 if post else 1.9, 0.9,
               f"{b['id']}:f{k}", "office", style=FOUR)
    if post:
        for i in range(bays + 1):
            u = bay * i
            fr.box(kit, u - 0.3, u + 0.3, step, roof, -0.12, 0.0, wall, skip=("back", "bottom"))
        fr.box(kit, 0.0, fr.w, roof, roof + 0.8, -0.04, WALL_T, wall, skip=("back", "bottom"))
        add_sign(b["id"], b["sign"], fr, fr.p(c, roof + 0.4, -0.05), fr.out(), 0.45, fr.w - 1.5, "carved", "StoneDark")
        fr.box(kit, -0.3, fr.w + 0.3, roof + 0.8, roof + 1.1, -0.3, WALL_T, "Paint:StoneDark", skip=("back",))
        fr.box(kit, 0.0, fr.w, roof + 1.1, top, 0.0, WALL_T, wall, skip=("back", "bottom"), keys={"top": "Paint:RoofEdge"})
        # Lanterns either side of the door, steps and a landing across the front, the roof flag.
        for dx in (-1.55, 1.55):
            fr.box(details, c + dx - 0.18, c + dx + 0.18, step + 2.35, step + 2.85, -0.36, -0.04, "Glow:LampWarm")
            fr.box(details, c + dx - 0.22, c + dx + 0.22, step + 2.85, step + 2.95, -0.4, 0.0, "Paint:Iron")
            add_light(b["id"], fr.p(c + dx, step + 2.6, -0.6), _state["tex"].PALETTE["LampWarm"], 0.45, 5.0)
        setback = b.get("setback", 0.0)
        for k in range(3):
            d0 = -setback + k * 0.35
            fr.box(kit, c - 4.0 + k * 0.1, c + 4.0 - k * 0.1, 0.0, SIDEWALK + 0.17 * (k + 1) - 0.0, d0, 0.0,
                   "Paint:Stone", skip=("back", "bottom"))
            frame_collider(fr, f"{b['id']}Step{k}", c - 4.0 + k * 0.1, c + 4.0 - k * 0.1, 0.0,
                           SIDEWALK + 0.17 * (k + 1), d0, 0.0)
        flag(details, fr.p(c, top, b["depth"] * 0.4), top, 5.2, fr)
    else:
        cornice(fr, kit, details, wall, roof, top, brackets=False)
        # Canopy over the doors, the name in raised letters above it, blue lamps either side.
        fr.box(kit, c - 3.2, c + 3.2, 3.0, 3.38, -1.8, 0.0, "Paint:FrameDark", keys={"bottom": "Paint:Cornice"})
        add_sign(b["id"], b["sign"], fr, fr.p(c, 3.95, -0.08), fr.out(), 0.55, 9.0, "raised", "SignLight")
        for dx in (-2.2, 2.2):
            globe = fr.p(c + dx, 2.6, -0.45)       # above head height
            details.cylinder((globe[0], globe[2]), 0.3, 2.6, 2.75, "Glow:PoliceBlue", sides=8, radius_top=0.3)
            details.cylinder((globe[0], globe[2]), 0.3, 2.75, 3.05, "Glow:PoliceBlue", sides=8, radius_top=0.0)
            details.cylinder((globe[0], globe[2]), 0.0001, 2.3, 2.6, "Glow:PoliceBlue", sides=8, radius_top=0.3, cap=False)
            details.beam(fr.p(c + dx, 2.7, 0.0), (globe[0], 2.7, globe[2]), 0.05, "Paint:Iron")
            add_light(b["id"], (globe[0], 2.7, globe[2]), _state["tex"].PALETTE["PoliceBlue"], 0.5, 4.5)
        pole_base = fr.p(fr.w - 1.2, 5.0, 0.0)
        pole_tip = fr.p(fr.w - 1.2, 7.2, -2.2)
        details.beam(pole_base, pole_tip, 0.07, "Paint:Steel")
        hang = [fr.p(fr.w - 1.2 - 0.02, 7.1, -2.1), fr.p(fr.w - 1.2 - 0.02, 7.1, -0.5),
                fr.p(fr.w - 1.2 - 0.02, 6.0, -0.5), fr.p(fr.w - 1.2 - 0.02, 6.0, -2.1)]
        flag_faces(details, hang, fr.side_out("left"))
    mass(fr, kit, b["depth"], roof, top - 0.35, wall)
    for side in exposed_sides(row, b):
        side_windows(fr, kit, glass, side, b["depth"], [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])]
                     + [1.0], b["id"] + side, "office", every=3.3)
    back_windows(fr, kit, glass, b["depth"], [ground + upper * (k - 1) + 0.9 for k in range(1, b["floors"])], b["id"],
                 "office", every=3.6)
    finish(row, b, fr, kit, glass, details, top)


def flag(details: Kit, base, roof: float, height: float, fr: Frame) -> None:
    x, _y, z = base
    details.cylinder((x, z), 0.05, roof, roof + height, "Paint:Steel", sides=6)
    details.cylinder((x, z), 0.09, roof + height, roof + height + 0.12, "Paint:Brass", sides=6)
    across = norm(sub(fr.p(1, 0, 0), fr.p(0, 0, 0)))
    y1 = roof + height - 0.1
    corners = [(x, y1 - 1.0, z), (x + across[0] * 1.7, y1 - 1.0, z + across[2] * 1.7),
               (x + across[0] * 1.7, y1, z + across[2] * 1.7), (x, y1, z)]
    flag_faces(details, corners, fr.out())


def flag_faces(details: Kit, corners, out) -> None:
    """A flag on both faces: red and white stripes with a blue canton."""
    a, b, c, d = corners

    def lerp(p, q, t):
        return tuple(p[i] + (q[i] - p[i]) * t for i in range(3))
    stripes = 7
    for k in range(stripes):
        t0, t1 = k / stripes, (k + 1) / stripes
        quad = [lerp(a, d, t0), lerp(b, c, t0), lerp(b, c, t1), lerp(a, d, t1)]
        key = "Paint:FrameRed" if k % 2 == 0 else "Paint:LineWhite"
        details.face(quad, key, facing=out)
        details.face(quad[::-1], key, facing=tuple(-v for v in out))
    canton = [lerp(lerp(a, d, 3 / 7), lerp(b, c, 3 / 7), 0.0), lerp(lerp(a, d, 3 / 7), lerp(b, c, 3 / 7), 0.42),
              lerp(d, c, 0.42), d]
    shifted = [tuple(p[i] + out[i] * 0.005 for i in range(3)) for p in canton]
    details.face(shifted, "Paint:SignNavy", facing=out)
    details.face([tuple(p[i] - out[i] * 0.005 for i in range(3)) for p in canton][::-1], "Paint:SignNavy",
                 facing=tuple(-v for v in out))


def build_diner(row: str, b: dict) -> None:
    fr = frame_of(row, b)
    kit, glass, details = Kit(b["id"]), Kit(b["id"] + "_Glass"), Kit(b["id"] + "_Details")
    w, H = fr.w, 4.6
    ribbon = (0.8, w - 3.0, 1.3, 3.6)
    door = (w - 2.6, w - 1.4, 0.0, 2.6)
    wall_with_openings(fr, kit, 0.0, w, 0.0, H, [ribbon, door], "Paint:Enamel")
    panes = round((ribbon[1] - ribbon[0]) / 1.5)
    for k in range(panes):
        u0 = ribbon[0] + (ribbon[1] - ribbon[0]) * k / panes
        u1 = ribbon[0] + (ribbon[1] - ribbon[0]) * (k + 1) / panes
        fr.pane(glass, u0, u1, ribbon[2], ribbon[3], 0.12, "Glass",
                glass_codes("lit_kitchen", "grime" if k % 3 else "clear", PANE))
        fr.box(kit, u0 - 0.04, u0 + 0.04, ribbon[2], ribbon[3], 0.0, 0.14, "Paint:Chrome", skip=("back",))
    fr.box(kit, door[0], door[1], 0.0, 2.6, 0.22, 0.3, "Paint:Chrome", skip=("back", "bottom"))
    fr.pane(glass, door[0] + 0.15, door[1] - 0.15, 0.4, 2.4, 0.2, "Glass", glass_codes("lit_kitchen", "clear", PANE))
    fr.box(kit, door[0] - 0.4, door[1] + 0.4, 2.75, 2.95, -1.0, 0.0, "Paint:Chrome")
    for y0, y1, key in ((0.9, 1.2, "Paint:EnamelRed"), (3.95, 4.3, "Paint:Chrome")):
        band(fr, kit, y0, y1, key, 0.03)
    mass(fr, kit, b["depth"], H, H, "Paint:Enamel")
    for side in ("left", "right"):
        u_face = 0.0 if side == "left" else w
        pad = -0.03 if side == "left" else 0.03
        for y0, y1, key in ((0.9, 1.2, "Paint:EnamelRed"), (3.95, 4.3, "Paint:Chrome")):
            fr.box(kit, min(u_face, u_face + pad), max(u_face, u_face + pad), y0, y1, 0.0, b["depth"], key)
        for k in range(3):
            d0 = 1.5 + k * 2.4
            fr.side_pane(glass, side, d0, d0 + 1.8, 1.3, 3.4, "Glass", glass_codes("lit_kitchen", "grime", PANE))
    # Roof sign on two posts: the name in neon, a star at its left.
    for u in (2.0, w - 2.0):
        fr.box(details, u - 0.08, u + 0.08, H, 7.4, 0.4, 0.56, "Paint:Steel")
    fr.box(kit, 1.5, w - 1.5, 5.0, 7.2, 0.42, 0.6, "Paint:FrameDark")
    for direction, d in ((fr.out(), 0.41), (tuple(-v for v in fr.out()), 0.61)):
        star_centre = fr.p(2.6, 6.1, d)
        points = []
        for i in range(10):
            r = 0.85 if i % 2 == 0 else 0.36
            a = pi / 2 + i * pi / 5
            across = norm(sub(fr.p(1, 0, 0), fr.p(0, 0, 0)))
            points.append((star_centre[0] + across[0] * r * cos(a), star_centre[1] + r * sin(a),
                           star_centre[2] + across[2] * r * cos(a)))
        for i in range(10):
            details.face([star_centre, points[i], points[(i + 1) % 10]], "Glow:StarGold", facing=direction)
    add_sign(b["id"], b["sign"], fr, fr.p(w / 2 + 0.9, 6.35, 0.39), fr.out(), 0.85, w - 5.0, "neon", "NeonRed")
    add_sign(b["id"], "DINER", fr, fr.p(w / 2 + 0.9, 5.45, 0.39), fr.out(), 0.45, 4.0, "neon", "StarGold")
    add_light(b["id"], fr.p(w / 2, 5.5, -2.0), _state["tex"].PALETTE["NeonRed"], 1.0, 9.0, "neon")
    add_light(b["id"], fr.p(w / 2, 2.3, -1.6), _state["tex"].PALETTE["LampWarm"], 0.8, 7.0)
    back_windows(fr, kit, glass, b["depth"], [], b["id"], "flat")
    finish(row, b, fr, kit, glass, details, H)


def finish(row: str, b: dict, fr: Frame, kit: Kit, glass: Kit, details: Kit, top: float) -> None:
    """Make the building's objects and record its collision box and occluder."""
    made = [make_object(kit), make_object(glass), make_object(details)]
    markers()["buildings"].append({"id": b["id"], "kind": b["kind"], "row": row,
                                   "objects": [obj.name for obj in made if obj is not None],
                                   "footprint": list(_state["plan"].footprint(row, b)), "height": top})
    frame_collider(fr, b["id"], 0.0, fr.w, 0.0, top, 0.0, b["depth"])
    inset = 0.5
    a, c = fr.p(inset, 0.0, inset), fr.p(fr.w - inset, top - 0.5, b["depth"] - inset)
    markers()["occluders"].append({"name": b["id"], "centre": [(a[0] + c[0]) / 2, (top - 0.5) / 2, (a[2] + c[2]) / 2],
                                   "size": [abs(c[0] - a[0]), top - 0.5, abs(c[2] - a[2])]})


BUILDERS = {"shop": build_shop, "apartments": build_apartments, "bank": build_bank, "cinema": build_cinema,
            "hotel": build_hotel, "civic": build_civic, "diner": build_diner}


# --- The street -----------------------------------------------------------------------------------

def build_paving() -> None:
    plan = _state["plan"]
    kit = Kit("Paving")
    top = SIDEWALK
    north0, north1 = plan.NORTH_FRONT, plan.CURB_NORTH[0]
    east = plan.CROSSROAD_END
    # Sidewalks, the corners down the Connector road, the forecourts and the hospital's.
    kit.box((plan.CONNECTOR_CURB_EAST + 0.1, 0.0, north0), (east, top, north1), "Concrete", skip=("-y",))
    kit.box((plan.CONNECTOR_CURB_EAST + 0.1, 0.0, plan.CURB_SOUTH[1]), (plan.HOSPITAL[0] - 3.2, top, plan.SOUTH_FRONT),
            "Concrete", skip=("-y",))
    kit.box((plan.CONNECTOR_CURB_EAST + 0.1, 0.0, plan.SOUTH_FRONT), (plan.WEST_EDGE, top, plan.SERVICE_LANE[1]),
            "Concrete", skip=("-y",))
    kit.box((plan.HOSPITAL[0] - 3.2, 0.0, plan.CURB_SOUTH[1]), (plan.HOSPITAL[1], top, plan.HOSPITAL[2]), "Concrete",
            skip=("-y",))
    for row, items in plan.rows():
        for b in items:
            if b.get("setback"):
                x0, x1, z0, z1 = plan.footprint(row, b)
                if row == "north":
                    kit.box((x0, 0.0, z1), (x1, top, plan.NORTH_FRONT), "Concrete", skip=("-y",))
                else:
                    kit.box((x0, 0.0, plan.SOUTH_FRONT), (x1, top, z0), "Concrete", skip=("-y",))
    # The north curb, cut at the lot entrances.
    cuts = sorted(b["entrance"] for b in plan.NORTH_ROW if "entrance" in b)
    cursor = plan.CONNECTOR_CURB_EAST + 0.1
    for a, b_ in cuts + [(east, east)]:
        kit.box((cursor, 0.0, plan.CURB_NORTH[0]), (a, top, plan.CURB_NORTH[1]), "Paint:Kerb", skip=("-y",))
        cursor = b_
    for a, b_ in cuts:
        kit.box((a, 0.0, plan.CURB_NORTH[0]), (b_, ROAD_TOP + 0.015, plan.CURB_NORTH[1]), "Concrete", skip=("-y",))
    # Alleys, lots and the service lane, a little lower than the sidewalks.
    for row, items in plan.rows():
        for b in items:
            if b["kind"] in ("alley", "lot"):
                x0, x1, z0, z1 = plan.footprint(row, b)
                kit.box((x0, 0.0, z0), (x1, PAVED, z1), "Asphalt", skip=("-y",))
    lane = plan.SERVICE_LANE
    kit.box((plan.SERVICE_LANE_X[0], 0.0, lane[0]), (plan.SERVICE_LANE_X[1], PAVED, lane[1]), "Asphalt", skip=("-y",))
    # Parking stalls in the lots.
    for b in plan.NORTH_ROW:
        if b["kind"] != "lot":
            continue
        x0, x1, z0, z1 = plan.footprint("north", b)
        x = x0 + 0.6
        while x < x1 - 0.5:
            kit.box((x - 0.06, PAVED, z0 + 0.4), (x + 0.06, PAVED + 0.004, z0 + 5.6), "Paint:LineWhite", skip=("-y",))
            x += 2.7
    # Crosswalks over the Crossroad's east leg and the Connector road's south leg, with stop bars.
    for i in range(7):
        z = plan.CROSSROAD[0] + 0.55 + i * 1.15
        kit.box((105.0, ROAD_TOP, z), (107.8, ROAD_TOP + 0.006, z + 0.55), "Paint:LineWhite", skip=("-y",))
    for i in range(7):
        x = plan.CONNECTOR_ROAD[0] + 0.55 + i * 1.15
        kit.box((x, ROAD_TOP, 229.6), (x + 0.55, ROAD_TOP + 0.006, 232.4), "Paint:LineWhite", skip=("-y",))
    # The stop bar for westbound traffic, which keeps to the north lane.
    kit.box((108.4, ROAD_TOP, plan.CROSSROAD[0] + 0.2), (108.8, ROAD_TOP + 0.006, 224.9), "Paint:LineWhite", skip=("-y",))
    make_object(kit)
    markers()["paving_top"] = top
    # Collision for the sidewalks at the road's height, not the paving's: a curb as high as the
    # town's roads is one every body in the game already steps up, and props settle on it within a
    # few centimetres of the paving. Alleys, lots and the lane stay on the ground, as the old lane did.
    walks = [(plan.CONNECTOR_CURB_EAST + 0.1, east, north0, plan.CURB_NORTH[1]),
             (plan.CONNECTOR_CURB_EAST + 0.1, plan.HOSPITAL[0] - 3.2, plan.CURB_SOUTH[1], plan.SOUTH_FRONT),
             (plan.CONNECTOR_CURB_EAST + 0.1, plan.WEST_EDGE, plan.SOUTH_FRONT, plan.SERVICE_LANE[1]),
             (plan.HOSPITAL[0] - 3.2, plan.HOSPITAL[1], plan.CURB_SOUTH[1], plan.HOSPITAL[2])]
    for row, items in plan.rows():
        for b in items:
            if b.get("setback"):
                x0, x1, z0, z1 = plan.footprint(row, b)
                walks.append((x0, x1, z1, plan.NORTH_FRONT) if row == "north" else (x0, x1, plan.SOUTH_FRONT, z0))
    for x0, x1, z0, z1 in walks:
        add_collider("Sidewalk", (x0, 0.0, z0), (x1, ROAD_TOP, z1))


def build_street_furniture() -> None:
    """Parking meters, newspaper boxes, tree grates and the lot fences, merged into one object."""
    plan = _state["plan"]
    kit = Kit("StreetFurniture")
    for x, z in plan.METERS:
        kit.cylinder((x, z), 0.045, SIDEWALK, SIDEWALK + 1.05, "Paint:Steel", sides=6)
        kit.box((x - 0.11, SIDEWALK + 1.05, z - 0.08), (x + 0.11, SIDEWALK + 1.38, z + 0.08), "Paint:Meter")
        kit.box((x - 0.08, SIDEWALK + 1.2, z - 0.085), (x + 0.08, SIDEWALK + 1.32, z + 0.085), "Paint:Chrome")
        kit.cylinder((x, z), 0.11, SIDEWALK + 1.38, SIDEWALK + 1.48, "Paint:Meter", sides=6, radius_top=0.05)
        add_collider("Meter", (x - 0.08, 0.0, z - 0.08), (x + 0.08, 1.4, z + 0.08))
    news = ["Paint:NewsBlue", "Paint:NewsRed", "Paint:NewsYellow"]
    for i, (_kind, x, z, yaw) in enumerate(f for f in plan.FURNITURE if f[0] == "newspaper"):
        facing = 1.0 if yaw == 0.0 else -1.0
        kit.box((x - 0.24, SIDEWALK, z - 0.2), (x + 0.24, SIDEWALK + 0.95, z + 0.2), news[i % 3])
        kit.box((x - 0.18, SIDEWALK + 0.55, z + facing * 0.2 - 0.005), (x + 0.18, SIDEWALK + 0.85, z + facing * 0.2 + 0.005),
                "Paint:Chrome")
        add_collider("NewspaperBox", (x - 0.24, 0.0, z - 0.2), (x + 0.24, 0.95, z + 0.2))
    for x, z in plan.TREES:
        kit.box((x - 0.6, SIDEWALK, z - 0.6), (x + 0.6, SIDEWALK + 0.006, z + 0.6), "Paint:Grate", skip=("-y",))
        kit.box((x - 0.35, SIDEWALK, z - 0.35), (x + 0.35, SIDEWALK + 0.008, z + 0.35), "Paint:Soil", skip=("-y",))
    for b in plan.NORTH_ROW:
        if b["kind"] == "lot":
            lot_fence(kit, b)
    make_object(kit)


def lot_fence(kit: Kit, b: dict) -> None:
    """A pipe-rail fence along a lot's sidewalk edge, open at its entrance, and down its west side
    when that faces the Connector road; the sign by the entrance."""
    plan = _state["plan"]
    x0, x1, z0, z1 = plan.footprint("north", b)
    z = z1 - 0.15
    entrance = b["entrance"]
    runs = [((x0 + 0.15, z), (entrance[0], z)), ((entrance[1], z), (x1 - 0.15, z))]
    if b["x0"] <= plan.WEST_EDGE + 1e-6:
        runs.append(((x0 + 0.15, z0 + 0.3), (x0 + 0.15, z)))
    for (ax, az), (bx, bz) in runs:
        length = sqrt((bx - ax) ** 2 + (bz - az) ** 2)
        posts = max(1, round(length / 2.4))
        for k in range(posts + 1):
            t = k / posts
            px, pz = ax + (bx - ax) * t, az + (bz - az) * t
            kit.cylinder((px, pz), 0.04, PAVED, 1.2, "Paint:Steel", sides=6)
        for y in (0.45, 1.15):
            kit.beam((ax, y, az), (bx, y, bz), 0.05, "Paint:Steel")
        add_collider("LotFence", (min(ax, bx) - 0.05, 0.0, min(az, bz) - 0.05), (max(ax, bx) + 0.05, 1.2, max(az, bz) + 0.05))
    sx = entrance[0] - 0.6 if b["sign"] == "PARK" else x0 + 2.7
    if b["sign"] == "PARK":
        kit.cylinder((sx, z - 0.2), 0.05, PAVED, 2.6, "Paint:Steel", sides=6)
        kit.box((sx - 0.45, 2.0, z - 0.25), (sx + 0.45, 2.6, z - 0.15), "Paint:SignNavy")
        add_sign(b["id"], "PARK", None, (sx, 2.3, z - 0.13), (0.0, 0.0, 1.0), 0.32, 0.8, "painted", "SignLight")
    else:
        # The diner's EAT sign on a pole by the sidewalk, in neon on both faces.
        kit.cylinder((sx, z - 0.4), 0.09, PAVED, 6.6, "Paint:Steel", sides=8)
        kit.box((sx - 0.75, 3.4, z - 0.6), (sx + 0.75, 6.6, z - 0.2), "Paint:FrameDark")
        for u in (sx - 0.76, sx + 0.76):
            kit.box((u - 0.01, 3.5, z - 0.62), (u + 0.01, 6.5, z - 0.18), "Glow:NeonRed")
        for facing, dz in (((0.0, 0.0, 1.0), -0.18), ((0.0, 0.0, -1.0), -0.62)):
            add_sign(b["id"], "E\nA\nT", None, (sx, 4.95, z + dz + facing[2] * 0.01), facing, 0.75, 1.2, "neon",
                     "NeonRed", 0.95)
        add_light(b["id"], (sx, 5.0, z + 1.2), _state["tex"].PALETTE["NeonRed"], 0.9, 7.0, "neon")
        add_collider("EatSign", (sx - 0.1, 0.0, z - 0.5), (sx + 0.1, 3.3, z - 0.3))
    for car_index, car in enumerate(b.get("cars", ())):
        cx = x0 + 3.6 + car_index * 5.4
        markers()["cars"].append({"scene": car, "position": [cx, PAVED, z0 + 3.0], "yaw": 180.0 + (car_index * 7.0)})


def build_signal() -> None:
    """A pole on the bank's corner, a mast arm over the intersection and a four-way head on it."""
    plan = _state["plan"]
    kit, amber, red = Kit("Signal"), Kit("SignalAmber"), Kit("SignalRed")
    px, pz = plan.SIGNAL_POLE
    hx, hz = plan.SIGNAL_HEAD
    y = plan.SIGNAL_HEIGHT
    kit.cylinder((px, pz), 0.14, SIDEWALK, y + 0.5, "Paint:Steel", sides=8)
    kit.cylinder((px, pz), 0.25, SIDEWALK, SIDEWALK + 0.4, "Paint:Steel", sides=8)
    kit.beam((px, y + 0.3, pz), (hx, y + 0.3, hz), 0.12, "Paint:Steel")
    kit.beam((px, y - 0.9, pz), ((px + hx) / 2, y + 0.28, (pz + hz) / 2), 0.06, "Paint:Steel")
    kit.beam((hx, y + 0.3, hz), (hx, y + 0.05, hz), 0.05, "Paint:Iron")
    s = 0.22
    kit.box((hx - s, y - 1.0, hz - s), (hx + s, y + 0.05, hz + s), "Paint:SignalYellow")
    for i, lens_y in enumerate((y - 0.18, y - 0.48, y - 0.78)):
        for direction in ((0, 0, 1), (0, 0, -1), (1, 0, 0), (-1, 0, 0)):
            dx, _dy, dz = direction
            cx, cz = hx + dx * (s + 0.005), hz + dz * (s + 0.005)
            corners = []
            for a, bb in ((-0.1, -0.1), (0.1, -0.1), (0.1, 0.1), (-0.1, 0.1)):
                corners.append((cx + a, lens_y + bb, cz) if dx == 0 else (cx, lens_y + bb, cz + a))
            # Flashing amber for the Connector road (the faces looking north and south), flashing red
            # for the Crossroad; the other lenses stay dark.
            main_road = dz != 0
            lit = (i == 1 and main_road) or (i == 0 and not main_road)
            target = (amber if main_road else red) if lit else kit
            key = ("Glow:LensAmber" if main_road else "Glow:LensRed") if lit else "Paint:FrameBlack"
            target.face(corners, key, facing=direction)
            top_edge = [corners[3], corners[2]]
            hood = [top_edge[0], top_edge[1], (top_edge[1][0] + dx * 0.18, top_edge[1][1], top_edge[1][2] + dz * 0.18),
                    (top_edge[0][0] + dx * 0.18, top_edge[0][1], top_edge[0][2] + dz * 0.18)]
            kit.face(hood, "Paint:FrameBlack", facing=(0, 1, 0))
            kit.face(hood[::-1], "Paint:FrameBlack", facing=(0, -1, 0))
    make_object(kit)
    make_object(amber)
    make_object(red)
    add_collider("SignalPole", (px - 0.2, 0.0, pz - 0.2), (px + 0.2, y, pz + 0.2))
    markers()["signal"] = {"head": [hx, y - 0.48, hz], "amber": "SignalAmber", "red": "SignalRed"}


def build_aids() -> None:
    """A 1.8 m figure on the south sidewalk for scale. Never exported."""
    kit = Kit("ScaleFigure")
    kit.box((150.0, SIDEWALK, 232.0), (150.45, SIDEWALK + 1.8, 232.3), "Paint:NeonPink")
    make_object(kit, AIDS)


# --- Build ----------------------------------------------------------------------------------------

def build() -> dict:
    """Rebuild everything; returns the markers for prepare_downtown.py."""
    _materials.clear()
    _state["plan"] = load_module("plan")
    _state["tex"] = load_module("textures")
    _state["markers"] = {"buildings": [], "colliders": [], "occluders": [], "signs": [], "lights": [], "cars": []}
    clear()
    root()
    plan = _state["plan"]
    for row, b in plan.buildings():
        BUILDERS[b["kind"]](row, b)
    build_paving()
    build_street_furniture()
    build_signal()
    build_aids()
    return _state["markers"]


if __name__ == "__main__":
    if bpy.app.background:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE_PATH))
        build()
        bpy.ops.wm.save_mainfile()
