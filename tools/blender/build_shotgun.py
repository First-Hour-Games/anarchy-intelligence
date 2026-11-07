"""Build the double-barrelled shotgun of the alt route: models/props/weapons/shotgun/shotgun.glb.

A low-poly side-by-side 12 gauge in the same PSX style as the pipe: few faces, small textures drawn
here (worn gunmetal and walnut, 128 pixels, sampled nearest-pixel), no bevels, built bulkier than a
real one. The part sizes come from tools/blender/fps_arms/shotgun_layout.py, which the first-person
clips that hold it share.

The GLB holds one root, Shotgun, whose origin is the middle of the stock's wrist, where the right fist
closes. Under it: Body (the action, stock, triggers and top lever), Barrels (both barrels and the
fore-end, its own object with its origin on the hinge pin, so the game can swing it down to open the
breech), and empty markers for the two muzzles, the fore-end grip and the breech, which sit under
Barrels and swing with it, with ChamberShells, the two shells in the chambers. The barrels point
along -Z in Godot. shell_pair.glb beside it holds two more shells, for the left hand to carry while
reloading.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_shotgun.py
"""

import math
import sys
import tempfile
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector

PROJECT_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent / "fps_arms"))

import shotgun_layout as layout  # noqa: E402

OUT_DIR = PROJECT_ROOT / "models" / "props" / "weapons" / "shotgun"
GLB_PATH = OUT_DIR / "shotgun.glb"
SHELLS_PATH = OUT_DIR / "shell_pair.glb"
TEXTURE_SIZE = 128
TEXEL_REPEAT = 0.3          # metres of surface one texture spans
SEGMENTS = 10               # round parts are ten-sided


# --- Textures ------------------------------------------------------------------------------------

def noise(rng: np.random.Generator, cells: int) -> np.ndarray:
    """Smooth value noise that tiles, TEXTURE_SIZE square, 0 to 1."""
    grid = rng.random((cells + 1, cells + 1))
    grid[-1, :] = grid[0, :]
    grid[:, -1] = grid[:, 0]
    steps = np.arange(TEXTURE_SIZE) * cells / TEXTURE_SIZE
    index = steps.astype(int)
    blend = steps - index
    blend = blend * blend * (3.0 - 2.0 * blend)
    rows = grid[index] * (1.0 - blend)[:, None] + grid[index + 1] * blend[:, None]
    return rows[:, index] * (1.0 - blend)[None, :] + rows[:, index + 1] * blend[None, :]


def fractal(rng: np.random.Generator) -> np.ndarray:
    octaves = ((4, 0.5), (8, 0.25), (16, 0.15), (32, 0.1))
    return sum(noise(rng, cells) * weight for cells, weight in octaves) / sum(weight for _, weight in octaves)


def scratch(image: np.ndarray, rng: np.random.Generator, count: int, colour, along: float = None) -> None:
    for _ in range(count):
        x, y = rng.integers(0, TEXTURE_SIZE, 2)
        angle = along + rng.normal(0.0, 0.15) if along is not None else rng.random() * math.pi
        for step in range(int(rng.integers(3, 14))):
            px = int(x + math.cos(angle) * step) % TEXTURE_SIZE
            py = int(y + math.sin(angle) * step) % TEXTURE_SIZE
            image[py, px] = np.maximum(image[py, px], np.array(colour) * (0.8 + 0.2 * rng.random()))


def metal_texture(rng: np.random.Generator) -> np.ndarray:
    mottle = fractal(rng)
    image = np.array([0.30, 0.31, 0.33])[None, None, :] * (0.7 + 0.6 * mottle[..., None])
    image[..., 2] += 0.025 * noise(rng, 6)                     # uneven bluing
    rust = fractal(rng) + 0.25 * rng.random((TEXTURE_SIZE, TEXTURE_SIZE))
    spots = rust > np.quantile(rust, 0.93)
    image[spots] = image[spots] * 0.35 + np.array([0.33, 0.15, 0.07]) * 0.65
    scratch(image, rng, 30, (0.50, 0.50, 0.52))
    image *= (0.78 + 0.22 * noise(rng, 3))[..., None]           # grime
    return np.clip(image, 0.0, 1.0)


def wood_texture(rng: np.random.Generator) -> np.ndarray:
    rows = np.mgrid[0:TEXTURE_SIZE, 0:TEXTURE_SIZE][0] / TEXTURE_SIZE
    warp = fractal(rng)
    grain = np.sin((rows * 9.0 + warp * 2.5) * 2.0 * math.pi)  # stripes that run along U, the length
    fine = noise(rng, 64)
    light = np.array([0.52, 0.31, 0.17])
    dark = np.array([0.26, 0.14, 0.07])
    mix = np.clip(0.55 + 0.3 * grain + 0.25 * (fine - 0.5), 0.0, 1.0)
    image = dark[None, None, :] * (1.0 - mix[..., None]) + light[None, None, :] * mix[..., None]
    scratch(image, rng, 25, (0.45, 0.30, 0.18), along=0.0)
    image *= (0.72 + 0.28 * noise(rng, 3))[..., None]
    return np.clip(image, 0.0, 1.0)


def save_texture(name: str, pixels: np.ndarray, folder: Path) -> bpy.types.Image:
    """Writes the texture outside the project: the GLB carries it, and Godot extracts it on import."""
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    rgba = np.concatenate([pixels, np.ones((TEXTURE_SIZE, TEXTURE_SIZE, 1))], axis=2)
    image.pixels = rgba[::-1].ravel()                          # Blender stores rows bottom-up
    image.filepath_raw = str(folder / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    return image


def material(name: str, image: bpy.types.Image = None, colour=(0.05, 0.05, 0.05), metallic: float = 0.0,
             roughness: float = 0.8) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    shader = next(node for node in nodes if node.type == "BSDF_PRINCIPLED")
    if image is not None:
        texture = nodes.new("ShaderNodeTexImage")
        texture.image = image
        texture.interpolation = "Closest"
        mat.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    else:
        shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return mat


# --- Geometry ------------------------------------------------------------------------------------

class Part:
    """One mesh object built from boxes and lofted rings, each piece with its own material slot."""

    def __init__(self, name: str):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new()

    def _face(self, verts, material_index: int):
        face = self.bm.faces.new(verts)
        face.material_index = material_index
        return face

    def box(self, low, high, material_index: int = 0) -> None:
        verts = [self.bm.verts.new((x, y, z)) for x in (low[0], high[0]) for y in (low[1], high[1])
                 for z in (low[2], high[2])]
        for a, b, c, d in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            self._face((verts[a], verts[b], verts[c], verts[d]), material_index)

    def rings(self, rings, material_index: int = 0, caps: bool = True) -> None:
        """Joins rings of points that run along +Y; each ring goes round counter-clockwise in X-Z."""
        loops = [[self.bm.verts.new(point) for point in ring] for ring in rings]
        count = len(loops[0])
        for near, far in zip(loops, loops[1:]):
            for k in range(count):
                j = (k + 1) % count
                self._face((near[k], far[k], far[j], near[j]), material_index)
        if caps:
            self._face(loops[0], material_index)
            self._face(list(reversed(loops[-1])), material_index)

    def loft(self, rings, material_index: int = 0, caps: bool = True) -> None:
        """Rings along +Y, each (y, centre x, centre z, half width, half height), ten-sided."""
        self.rings([[(cx + rx * math.cos(2.0 * math.pi * k / SEGMENTS), y, cz + rz * math.sin(2.0 * math.pi * k / SEGMENTS))
                     for k in range(SEGMENTS)] for y, cx, cz, rx, rz in rings], material_index, caps)

    def prism(self, profile, start: float, end: float, material_index: int = 0) -> None:
        """A cross-section of (x, z) points, counter-clockwise, run straight from y start to y end."""
        self.rings([[(x, y, z) for x, z in profile] for y in (start, end)], material_index)

    def finish(self, materials, parent: bpy.types.Object, origin: Vector = Vector()) -> bpy.types.Object:
        # Each face takes the texture flat along its main axis: along the length on the sides, so
        # the wood grain follows the stock.
        for face in self.bm.faces:
            axis = max(range(3), key=lambda i: abs(face.normal[i]))
            u_axis, v_axis = {0: (1, 2), 1: (0, 2), 2: (1, 0)}[axis]
            for loop in face.loops:
                point = loop.vert.co
                loop[self.uv].uv = (point[u_axis] / TEXEL_REPEAT, point[v_axis] / TEXEL_REPEAT)
        for vert in self.bm.verts:
            vert.co -= origin
        mesh = bpy.data.meshes.new(self.name)
        self.bm.normal_update()
        self.bm.to_mesh(mesh)
        self.bm.free()
        for mat in materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(self.name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj.parent = parent
        obj.location = origin
        return obj


def build_body(metal: int, wood: int, rubber: int) -> Part:
    body = Part("Body")
    low, high = layout.ACTION
    # The action: flat sides, the corners cut off, the breech face at its front.
    w, b, t = high[0], low[2], high[2]
    body.prism([(-w + 0.004, b), (w - 0.004, b), (w, b + 0.014), (w, t - 0.014), (w - 0.009, t), (-w + 0.009, t),
                (-w, t - 0.014), (-w, b + 0.014)], low[1], high[1], metal)
    body.box((-0.006, 0.040, t), (0.014, 0.078, t + 0.008), metal)                   # top lever
    body.box((-0.018, 0.030, -0.030), (0.018, 0.120, b + 0.001), metal)               # trigger plate
    body.box((-0.006, 0.020, -0.058), (0.006, 0.096, -0.050), metal)                  # trigger guard
    body.box((-0.006, 0.088, -0.058), (0.006, 0.096, -0.029), metal)
    body.box((-0.006, 0.020, -0.056), (0.006, 0.028, -0.029), metal)
    for y in (0.046, 0.066):                                                          # two triggers
        body.box((-0.0028, y, -0.047), (0.0028, y + 0.008, -0.029), metal)
    # Wrist and stock: from the action's back down to the butt.
    half_width, half_height = layout.WRIST
    body.loft([
        (0.035, 0.0, 0.012, 0.027, 0.036),
        (0.0, 0.0, 0.0, half_width, half_height),
        (-0.05, 0.0, -0.012, 0.026, 0.030),
        (-0.10, 0.0, -0.028, 0.028, 0.046),
        (-0.22, 0.0, -0.044, 0.030, 0.066),
        (-0.34, 0.0, -0.054, 0.030, 0.080),
    ], wood)
    body.loft([(-0.34, 0.0, -0.054, 0.030, 0.080), (layout.BUTT.y, 0.0, -0.054, 0.030, 0.080)], rubber)
    return body


def build_barrels(metal: int, wood: int, bore: int) -> Part:
    """Both barrels, the ribs between them and the fore-end under them: everything that swings open."""
    barrels = Part("Barrels")
    start, end, radius = layout.BARREL
    for side in (-1.0, 1.0):
        barrels.loft([(start, side * layout.BARREL_X, layout.BORE_Z, radius, radius),
                      (end, side * layout.BARREL_X, layout.BORE_Z, radius, radius)], metal)
        # The bore, a dark core standing just proud of both ends: two holes at the muzzles, and two
        # chambers when the breech is open.
        barrels.loft([(start - 0.0008, side * layout.BARREL_X, layout.BORE_Z, radius * 0.62, radius * 0.62),
                      (end + 0.0008, side * layout.BARREL_X, layout.BORE_Z, radius * 0.62, radius * 0.62)], bore)
    top, bottom = layout.BORE_Z + radius, layout.BORE_Z - radius
    barrels.box((-0.006, start, layout.BORE_Z), (0.006, end, top + 0.002), metal)               # top rib
    barrels.box((-0.006, start, bottom - 0.002), (0.006, end - 0.02, layout.BORE_Z), metal)      # under rib
    barrels.box((-layout.BARREL_X - radius, start, layout.HINGE.z - 0.008), (layout.BARREL_X + radius, start + 0.05, bottom + 0.004),
                metal)                                                                           # lump on the hinge
    barrels.box((-0.003, end - 0.008, top + 0.002), (0.003, end - 0.002, top + 0.008), metal)    # bead
    near, far, centre, half_width, half_height = layout.FORE_END
    barrels.loft([
        (near, 0.0, centre + 0.004, half_width - 0.008, half_height - 0.006),
        (near + 0.02, 0.0, centre, half_width, half_height),
        (far - 0.04, 0.0, centre, half_width, half_height),
        (far, 0.0, centre + 0.006, half_width - 0.012, half_height - 0.008),
    ], wood)
    return barrels


def build_shell_pair(name: str, shell: int, brass: int) -> Part:
    """Two shells side by side, as far apart as the barrels, pointing along +Y; the origin is between
    their rims."""
    pair = Part(name)
    for side in (-1.0, 1.0):
        x = side * layout.BARREL_X
        pair.loft([(0.0, x, 0.0, layout.SHELL_RIM, layout.SHELL_RIM), (0.002, x, 0.0, layout.SHELL_RIM, layout.SHELL_RIM),
                   (0.002, x, 0.0, layout.SHELL_RADIUS + 0.0004, layout.SHELL_RADIUS + 0.0004),
                   (layout.SHELL_HEAD, x, 0.0, layout.SHELL_RADIUS + 0.0004, layout.SHELL_RADIUS + 0.0004)], brass)
        pair.loft([(layout.SHELL_HEAD, x, 0.0, layout.SHELL_RADIUS, layout.SHELL_RADIUS),
                   (layout.SHELL_LENGTH - 0.004, x, 0.0, layout.SHELL_RADIUS, layout.SHELL_RADIUS),
                   (layout.SHELL_LENGTH, x, 0.0, layout.SHELL_RADIUS * 0.75, layout.SHELL_RADIUS * 0.75)], shell)
    return pair


def marker(name: str, position: Vector, parent: bpy.types.Object) -> None:
    empty = bpy.data.objects.new(name, None)
    empty.empty_display_size = 0.02
    bpy.context.scene.collection.objects.link(empty)
    empty.parent = parent
    empty.location = position


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(870)
    textures = Path(tempfile.mkdtemp(prefix="shotgun_textures_"))
    metal = material("ShotgunMetal", save_texture("shotgun_metal", metal_texture(rng), textures), metallic=0.25,
                     roughness=0.72)
    wood = material("ShotgunWood", save_texture("shotgun_wood", wood_texture(rng), textures), roughness=0.75)
    rubber = material("ShotgunRubber", colour=(0.035, 0.035, 0.035), roughness=0.95)
    shell = material("ShotgunShell", colour=(0.55, 0.05, 0.04), roughness=0.6)
    brass = material("ShotgunBrass", colour=(0.62, 0.45, 0.18), metallic=0.6, roughness=0.45)
    root = bpy.data.objects.new("Shotgun", None)
    bpy.context.scene.collection.objects.link(root)
    build_body(0, 1, 2).finish([metal, wood, rubber], root)
    barrels = build_barrels(0, 1, 2).finish([metal, wood, rubber], root, layout.HINGE)
    for name, position in (("MuzzleLeft", layout.MUZZLES[0]), ("MuzzleRight", layout.MUZZLES[1]),
                           ("ForeEndGrip", layout.FORE_END_GRIP), ("Breech", layout.BREECH)):
        marker(name, position - layout.HINGE, barrels)
    # The shells in the chambers, their rims at the breech; out of sight inside the barrels when closed.
    loaded = build_shell_pair("ChamberShells", 0, 1).finish([shell, brass], barrels)
    loaded.location = layout.BREECH - layout.HINGE
    export(GLB_PATH, [obj for obj in bpy.context.scene.objects])
    # Two more for the left hand to carry while reloading.
    carried = build_shell_pair("ShellPair", 0, 1).finish([shell, brass], None)
    export(SHELLS_PATH, [carried])
    faces = sum(len(obj.data.polygons) for obj in bpy.context.scene.objects if obj.type == "MESH")
    print("SHOTGUN", GLB_PATH, "and", SHELLS_PATH.name, "faces", faces)


def export(path: Path, objects) -> None:
    for obj in bpy.context.scene.objects:
        obj.select_set(obj in objects)
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=True, export_cameras=False, export_lights=False, export_animations=False)


if __name__ == "__main__":
    main()
