"""Build the alt route's shed props: models/props/shed/workbench.glb, work_lamp.glb and gate_padlock.glb.

Low-poly pieces in the same PSX style as the shotgun, with its small drawn textures (tools/blender/build_shotgun.py):
- the workbench the shotgun lies on: a worn plank top on steel legs with a shelf under it, a pegboard of tools
  behind it and a vise at one end. Its origin is on the floor under the middle of its front edge; it is 2 m
  long along X and its back, with the pegboard, is toward -Z in Godot, against the wall.
- the work lamp that lights it: an enamel shade over a bare bulb on a cord up to the shed's roof. Its origin is the
  bulb, for the light; the cord runs LAMP_CORD metres up.
- the padlock and chain that keep the yard gate shut in the alt route: a heavy padlock, "Padlock", whose shackle
  goes through the two front links of a loop of chain, "Chain", that wraps round the gate's end bar and the
  post beside it. Both origins are the padlock's shackle, where the loop is closed, so the game can drop them
  apart when the lock is shot. The loop runs along X (the gate's width) and the padlock hangs toward the yard,
  +Z in Godot.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_shed_props.py
"""

import math
import sys
import tempfile
from pathlib import Path

import bpy
import numpy as np
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_shotgun import (TEXTURE_SIZE, Part, export, fractal, material, metal_texture, noise,  # noqa: E402
                           save_texture, scratch, wood_texture)

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = PROJECT_ROOT / "models" / "props" / "shed"
# Blender is Z-up; the export turns +Z into Godot's +Y and -Y into Godot's +Z.
BENCH_LENGTH, BENCH_DEPTH, BENCH_HEIGHT = 2.0, 0.75, 0.92
CHAIN_LOOP = (0.24, 0.09)     # the loop's length along the gate and its width across it, outside the links
CHAIN_LINKS = 14
LAMP_CORD = 4.15            # from the bulb, hung over the bench, up to the shed's roof ridge


# --- Textures ------------------------------------------------------------------------------------

def plank_texture(rng: np.random.Generator) -> np.ndarray:
    """A bench top worn grey-brown, stained and nicked."""
    image = wood_texture(rng) * np.array([0.82, 0.86, 0.9])[None, None, :] + 0.04
    stains = fractal(rng) > 0.62
    image[stains] *= 0.55
    scratch(image, rng, 40, (0.55, 0.48, 0.40))
    return np.clip(image, 0.0, 1.0)


def pegboard_texture(rng: np.random.Generator) -> np.ndarray:
    """Brown hardboard with rows of holes."""
    image = np.array([0.40, 0.30, 0.20])[None, None, :] * (0.8 + 0.4 * noise(rng, 16)[..., None])
    step = TEXTURE_SIZE // 8
    for row in range(step // 2, TEXTURE_SIZE, step):
        for column in range(step // 2, TEXTURE_SIZE, step):
            image[row - 1:row + 2, column - 1:column + 2] = (0.07, 0.05, 0.04)
    image *= (0.75 + 0.25 * noise(rng, 3))[..., None]
    return np.clip(image, 0.0, 1.0)


def enamel_texture(rng: np.random.Generator, colour) -> np.ndarray:
    """Chipped enamel paint over dark steel."""
    image = np.array(colour)[None, None, :] * (0.85 + 0.3 * noise(rng, 8)[..., None])
    chips = fractal(rng) + 0.3 * rng.random((TEXTURE_SIZE, TEXTURE_SIZE))
    image[chips > np.quantile(chips, 0.9)] = (0.18, 0.17, 0.16)
    image *= (0.75 + 0.25 * noise(rng, 3))[..., None]
    return np.clip(image, 0.0, 1.0)


# --- The workbench -------------------------------------------------------------------------------

def build_workbench(top: int, steel: int, board: int, tool: int, handle: int) -> Part:
    bench = Part("Workbench")
    half, depth, height = BENCH_LENGTH / 2.0, BENCH_DEPTH, BENCH_HEIGHT
    # Blender: front edge at y = 0, back toward +Y (Godot -Z), floor at z = 0.
    bench.box((-half, 0.0, height - 0.06), (half, depth, height), top)
    for x in (-half + 0.05, half - 0.11):
        for y in (0.05, depth - 0.11):
            bench.box((x, y, 0.0), (x + 0.06, y + 0.06, height - 0.06), steel)
    for y in (0.05, depth - 0.08):
        bench.box((-half + 0.05, y, height - 0.14), (half - 0.05, y + 0.03, height - 0.08), steel)
    bench.box((-half + 0.06, 0.07, 0.16), (half - 0.06, depth - 0.07, 0.19), top)
    # The pegboard on two uprights behind the bench, and the tools hung on it. It stands on the top, so no
    # gap under it shows the wall behind.
    for x in (-half + 0.02, half - 0.06):
        bench.box((x, depth - 0.04, height), (x + 0.04, depth, height + 1.0), steel)
    bench.box((-half, depth - 0.05, height), (half, depth - 0.03, height + 0.98), board)
    face = depth - 0.05
    # A hammer: its handle and head.
    bench.box((-0.72, face - 0.025, height + 0.30), (-0.69, face, height + 0.62), handle)
    bench.box((-0.78, face - 0.03, height + 0.62), (-0.62, face, height + 0.67), tool)
    # A wrench, a hand saw's blade and handle, and a screwdriver.
    bench.box((-0.46, face - 0.015, height + 0.32), (-0.43, face, height + 0.72), tool)
    bench.box((-0.48, face - 0.015, height + 0.72), (-0.41, face, height + 0.77), tool)
    bench.box((-0.20, face - 0.01, height + 0.40), (0.30, face, height + 0.62), tool)
    bench.box((0.30, face - 0.03, height + 0.42), (0.42, face, height + 0.62), handle)
    bench.box((0.58, face - 0.02, height + 0.45), (0.61, face, height + 0.62), tool)
    bench.box((0.575, face - 0.03, height + 0.62), (0.615, face, height + 0.75), handle)
    # A vise on the right end, and a couple of cans on the left.
    bench.box((half - 0.36, 0.02, height), (half - 0.16, 0.20, height + 0.10), steel)
    bench.box((half - 0.34, -0.06, height + 0.02), (half - 0.18, 0.02, height + 0.10), steel)
    bench.box((half - 0.27, -0.14, height + 0.05), (half - 0.25, -0.02, height + 0.07), tool)
    for x, radius, tall in ((-0.86, 0.05, 0.14), (-0.72, 0.04, 0.10)):
        _rings_z(bench, [[(x + radius * math.cos(2.0 * math.pi * k / 8), 0.35 + radius * math.sin(2.0 * math.pi * k / 8), z)
                          for k in range(8)] for z in (height, height + tall)], tool, caps=True)
    return bench


# --- The work lamp -------------------------------------------------------------------------------

def build_lamp(shade: int, inside: int, bulb: int, cord: int) -> Part:
    lamp = Part("WorkLamp")
    # Along Z with the bulb at the origin: the shade's rim below the bulb, its top round the socket.
    rings = [(0.12, 0.035), (0.09, 0.06), (0.03, 0.14), (-0.06, 0.19)]
    _rings_z(lamp, [[(r * math.cos(2.0 * math.pi * k / 10), r * math.sin(2.0 * math.pi * k / 10), z) for k in range(10)]
                    for z, r in rings], shade)
    _rings_z(lamp, [[(r * 0.94 * math.cos(2.0 * math.pi * k / 10), r * 0.94 * math.sin(2.0 * math.pi * k / 10), z - 0.004)
                     for k in range(10)] for z, r in rings], inside)
    bulb_rings = [(-0.05, 0.012), (-0.035, 0.035), (0.0, 0.04), (0.03, 0.03), (0.05, 0.016)]
    _rings_z(lamp, [[(r * math.cos(2.0 * math.pi * k / 8), r * math.sin(2.0 * math.pi * k / 8), z) for k in range(8)]
                    for z, r in bulb_rings], bulb, caps=True)
    lamp.box((-0.02, -0.02, 0.04), (0.02, 0.02, 0.12), cord)
    lamp.box((-0.006, -0.006, 0.12), (0.006, 0.006, LAMP_CORD), cord)
    lamp.box((-0.05, -0.05, LAMP_CORD), (0.05, 0.05, LAMP_CORD + 0.03), cord)
    return lamp


def _rings_z(part: Part, rings, material_index: int, caps: bool = False) -> None:
    """Rings of points stacked along Z instead of Y."""
    loops = [[part.bm.verts.new(point) for point in ring] for ring in rings]
    count = len(loops[0])
    for near, far in zip(loops, loops[1:]):
        for k in range(count):
            j = (k + 1) % count
            part._face((near[k], near[j], far[j], far[k]), material_index)
    if caps:
        part._face(list(reversed(loops[0])), material_index)
        part._face(loops[-1], material_index)


# --- The padlock and chain -----------------------------------------------------------------------

def build_padlock(body: int, shackle: int, dark: int) -> Part:
    lock = Part("Padlock")
    # The body hangs from the shackle, which closes at the origin: Blender -Y is toward the yard (Godot +Z).
    w, t, top, bottom = 0.05, 0.02, -0.035, -0.115
    profile = [(-w + 0.008, bottom), (w - 0.008, bottom), (w, bottom + 0.012), (w, top), (-w, top),
               (-w, bottom + 0.012)]
    lock.rings([[(x, y, z) for x, z in profile] for y in (-t, t)], body)
    lock.box((-0.006, -t - 0.002, bottom + 0.025), (0.006, -t, bottom + 0.045), dark)     # the keyhole
    # The shackle: a hardened steel U from the body up through the chain's front links.
    segments = 7
    radius, rod = 0.028, 0.0065
    for k in range(segments):
        a0, a1 = math.pi * k / segments, math.pi * (k + 1) / segments
        x0, z0 = radius * math.cos(a0), radius * math.sin(a0) - 0.005
        x1, z1 = radius * math.cos(a1), radius * math.sin(a1) - 0.005
        lock.box((min(x0, x1) - rod, -rod, min(z0, z1) - rod), (max(x0, x1) + rod, rod, max(z0, z1) + rod), shackle)
    for x in (-radius, radius):
        lock.box((x - rod, -rod, top), (x + rod, rod, -0.005), shackle)
    return lock


def build_chain(steel: int) -> Part:
    chain = Part("Chain")
    length, width = CHAIN_LOOP
    # The loop's path: a rounded rectangle round the end bar and the post, in Blender X-Y, its front (toward
    # the yard, -Y) closed by the padlock at the origin.
    corners = []
    straight = length - width
    for k in range(CHAIN_LINKS):
        s = (k + 0.5) / CHAIN_LINKS
        angle = 2.0 * math.pi * s - math.pi / 2.0
        corners.append(Vector((math.cos(angle) * (straight / 2.0 + width / 2.0), math.sin(angle) * width / 2.0 + width / 2.0, 0.0)))
    for k, centre in enumerate(corners):
        ahead = corners[(k + 1) % CHAIN_LINKS] - corners[k - 1]
        ahead.normalize()
        side = Vector((0.0, 0.0, 1.0)) if k % 2 else ahead.cross(Vector((0.0, 0.0, 1.0)))
        _link(chain, centre, ahead, side.normalized(), steel)
    return chain


def _link(part: Part, centre: Vector, ahead: Vector, side: Vector, material_index: int) -> None:
    """One oval link as four thin bars, its long side along `ahead`, its open face across `side`."""
    half_length, half_width, wire = 0.022, 0.011, 0.004
    frame = Matrix((ahead, side, ahead.cross(side))).transposed()
    for along, across, size in ((0.0, half_width, (half_length, wire)), (0.0, -half_width, (half_length, wire)),
                                (half_length, 0.0, (wire, half_width)), (-half_length, 0.0, (wire, half_width))):
        corners = [centre + frame @ Vector((along + sx * size[0], across + sy * size[1], sz * wire))
                   for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]
        verts = [part.bm.verts.new(p) for p in corners]
        for a, b, c, d in ((0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)):
            part._face((verts[a], verts[b], verts[c], verts[d]), material_index)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(311)
    textures = Path(tempfile.mkdtemp(prefix="shed_textures_"))
    plank = material("BenchPlank", save_texture("bench_plank", plank_texture(rng), textures), roughness=0.85)
    steel = material("BenchSteel", save_texture("bench_steel", metal_texture(rng), textures), metallic=0.3,
                     roughness=0.7)
    board = material("Pegboard", save_texture("pegboard", pegboard_texture(rng), textures), roughness=0.9)
    tool = material("ToolSteel", colour=(0.28, 0.28, 0.3), metallic=0.5, roughness=0.55)
    handle = material("ToolHandle", colour=(0.45, 0.12, 0.06), roughness=0.7)
    build_workbench(0, 1, 2, 3, 4).finish([plank, steel, board, tool, handle], None)
    export(OUT_DIR / "workbench.glb", [obj for obj in bpy.context.scene.objects])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    shade = material("LampShade", save_texture("lamp_shade", enamel_texture(rng, (0.13, 0.24, 0.17)), textures),
                     metallic=0.2, roughness=0.6)
    inside = material("LampShadeInside", colour=(0.75, 0.73, 0.66), roughness=0.5)
    for thin in (shade, inside):
        thin.use_backface_culling = False            # a shell with no thickness, seen from both sides
    bulb = material("LampBulb", colour=(1.0, 0.86, 0.6), roughness=0.3)
    shader = next(node for node in bulb.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Emission Color"].default_value = (1.0, 0.82, 0.55, 1.0)
    shader.inputs["Emission Strength"].default_value = 3.0
    cord = material("LampCord", colour=(0.03, 0.03, 0.03), roughness=0.9)
    build_lamp(0, 1, 2, 3).finish([shade, inside, bulb, cord], None)
    export(OUT_DIR / "work_lamp.glb", [obj for obj in bpy.context.scene.objects])

    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = material("PadlockBody", save_texture("padlock_body", metal_texture(rng) * 1.25, textures), metallic=0.55,
                    roughness=0.5)
    hardened = material("PadlockShackle", colour=(0.55, 0.56, 0.58), metallic=0.8, roughness=0.35)
    dark = material("PadlockKeyhole", colour=(0.02, 0.02, 0.02), roughness=0.9)
    chain_steel = material("ChainSteel", colour=(0.42, 0.42, 0.44), metallic=0.7, roughness=0.5)
    root = bpy.data.objects.new("GatePadlock", None)
    bpy.context.scene.collection.objects.link(root)
    build_padlock(0, 1, 2).finish([body, hardened, dark], root)
    build_chain(0).finish([chain_steel], root)
    export(OUT_DIR / "gate_padlock.glb", [obj for obj in bpy.context.scene.objects])
    print("SHED PROPS", OUT_DIR)


if __name__ == "__main__":
    main()
