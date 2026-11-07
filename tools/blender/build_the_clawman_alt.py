"""Build the alt route's Clawman: the creator's Clawman grown worse.

blender --background --factory-startup --disable-autoexec --python tools/blender/build_the_clawman_alt.py

Opens the creator's Monster_PSX_TPose.blend (never saved) and, in its T-pose rest:
- lengthens the bone blades of both hands;
- grows five more arms out of it, copies of its own, each on a chain of new bones: a pair rising out of its
  shoulder blades (MantisArm), a pair out of its ribs (RibArm) and a long one out of the middle of its back
  that drags (DragArm). The creator's clips never move them; Godot does (clawman_alt_visual.gd);
- splits its head down the face's midline onto two new bones, JawL and JawR, hinged at the back of the skull,
  so the halves swing open like a book. Each half's cut is hollowed into a wet bowl of meat: a band of skull
  along the top and back, gums along the face with crooked teeth rooted behind the lips (shut, none of it
  shows), strands of tissue between the halves that stretch as they part, and torn ones hanging. An eye sits
  sunk in each half where the creator painted it. Below, a throat closes the neck, and a tongue on a chain of
  bones (Tongue1-6) lies inside the shut head until it lashes out.
The new parts use materials of their own: "Meat" (a striated flesh texture this script paints), "Gum",
"Slime", "Bone" (teeth and skull), "Throat", "Eye" and "Iris". It exports
models/enemies/the_clawman/TheClawman_alt.glb with the creator's five clips.
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

PROJECT_ROOT = Path(__file__).resolve().parents[2]
VENDOR = PROJECT_ROOT / "models" / "source" / "the_clawman" / "vendor"
SOURCE = VENDOR / "Monster_PSX_TPose.blend"
SKIN = VENDOR / "monster_psx_256.png"
OUT_DIR = PROJECT_ROOT / "models" / "enemies" / "the_clawman"
GLB = OUT_DIR / "TheClawman_alt.glb"
MEAT_TEXTURE = OUT_DIR / "textures" / "clawman_alt_meat.png"

MESH, RIG = "Monster_PSX", "Monster_Rig"
ARM_BONES = ("upper_arm", "forearm", "claw", "claw_02")
# The blades (claw, claw_02) grow this much longer along the arm.
BLADE_STRETCH = 1.45
# Each extra arm: name, side it is copied from, the bone it grows out of, where its shoulder sits (rest pose,
# metres; the creature faces -Y), which way its upper arm points, which way it bends (its bones' local Z, so a
# turn about local X folds it that way), and its size against the arm it copies.
EXTRA_ARMS = [
    ("MantisArmL", "L", "spine_03", (0.085, 0.075, 1.41), (0.38, 0.3, 0.87), (0.0, -1.0, 0.2), 1.1),
    ("MantisArmR", "R", "spine_03", (-0.085, 0.075, 1.41), (-0.38, 0.3, 0.87), (0.0, -1.0, 0.2), 1.1),
    ("RibArmL", "L", "spine_02", (0.12, -0.005, 1.2), (0.75, -0.5, -0.43), (0.0, 0.0, -1.0), 0.85),
    ("RibArmR", "R", "spine_02", (-0.12, -0.005, 1.2), (-0.75, -0.5, -0.43), (0.0, 0.0, -1.0), 0.85),
    ("DragArm", "R", "spine_02", (-0.02, 0.09, 1.25), (-0.15, 0.55, -0.82), (0.0, 1.0, 0.0), 1.35),
]
# The creator modelled the face 1.5 cm off x = 0 (its nose tip is at x = 0.0149, and the head mirrors best about
# x = 0.0125-0.015), so the split runs down the face's own midline, not the rig's.
MID = 0.015
# Each half turns about a vertical hinge near the back of the skull.
HINGE = (MID, 0.075, 1.6)
HINGE_TOP = (MID, 0.075, 1.8)
# Each half's cut is hollowed into a bowl this deep at most, and never deeper than 65% of the half's own width.
DEPTH = 0.05
# The bowl's rings, as fractions of the way in from the cut's rim to its middle. The first band (to GUM_IN) is
# gum along the face and skull along the top and back; the gums reach in to GUM_DEEP.
RINGS = (0.035, 0.07, 0.12, 0.17, 0.25, 0.35, 0.46, 0.58, 0.7, 0.82, 0.92)
GUM_IN, GUM_DEEP = 0.07, 0.17
# Ridges across the bowl, like a palate's: their height and spacing (metres).
RIDGE, RIDGE_SPACING = 0.0032, 0.024
# Gums and teeth line the face's part of the cut (in front of MOUTH_FRONT), from the chin up to the brow.
MOUTH_TOP = 1.735
MOUTH_FRONT = -0.09
TEETH_PER_SIDE = 22
# The creator's painted eyes: this far either side of MID, at this height. Each eyeball sits this far behind the
# skin, so only a wet cap of it shows.
EYE_SPREAD = 0.0295
EYE_Z = 1.692
EYE_RADIUS = 0.0105
EYE_SINK = 0.0082
# Where each eye looks (degrees: out, down): one of them wanders.
EYE_LOOK = {"L": (-3.0, 4.0), "R": (13.0, -5.0)}
# Strands of tissue across the split (y, z): stretched between the halves when it opens.
STRANDS = [(-0.05, 1.715), (-0.015, 1.672), (0.025, 1.742)]
# The neck is closed by a throat at this height, a funnel down into the dark.
THROAT_Z = 1.552
TONGUE_BONES = 6
# Lying inside the shut head, from the throat up behind the lips; Godot draws it out by moving each segment
# along its bone.
TONGUE_FROM = (MID, 0.0, 1.55)
TONGUE_TO = (MID, -0.08, 1.61)


def frame(x_axis: Vector, z_hint: Vector) -> Matrix:
    """A rotation whose X axis is x_axis and whose Z axis is as near z_hint as stays square to it."""
    x = x_axis.normalized()
    z = (z_hint - x * z_hint.dot(x)).normalized()
    y = z.cross(x)
    return Matrix((x, y, z)).transposed()


def value_noise(rng, size: int, cells: int) -> np.ndarray:
    """Smooth tiling noise in 0..1 on a size x size grid, from a cells x cells lattice."""
    grid = rng.random((cells, cells))
    x = np.arange(size) * cells / size
    i0 = np.floor(x).astype(int)
    f = x - i0
    f = f * f * (3.0 - 2.0 * f)
    i1 = (i0 + 1) % cells
    i0 = i0 % cells
    top = grid[i0][:, i0] * (1.0 - f)[None, :] + grid[i0][:, i1] * f[None, :]
    bottom = grid[i1][:, i0] * (1.0 - f)[None, :] + grid[i1][:, i1] * f[None, :]
    return top * (1.0 - f)[:, None] + bottom * f[:, None]


def fractal(rng, size: int, octaves=(4, 8, 16, 32, 64)) -> np.ndarray:
    total, amplitude, norm = 0.0, 1.0, 0.0
    for cells in octaves:
        total = total + value_noise(rng, size, cells) * amplitude
        norm += amplitude
        amplitude *= 0.55
    return total / norm


def paint_meat(path: Path, size: int = 256) -> None:
    """Raw, wet muscle: dark red fibres bent by the noise, pale fascia and thin fat in streaks, dark creases
    and a few veins. It tiles."""
    rng = np.random.default_rng(31)
    v = np.linspace(0.0, 1.0, size, endpoint=False)
    vv = np.meshgrid(v, v)[1]
    warp = fractal(rng, size, (2, 4, 8)) - 0.5
    fibre = 0.5 + 0.5 * np.sin((vv + warp * 0.18) * math.tau * 23.0 + fractal(rng, size, (8, 16, 32)) * 5.0)
    fibre = fibre ** 1.6
    tone = fractal(rng, size)
    deep = np.array([0.2, 0.012, 0.02])
    raw = np.array([0.5, 0.05, 0.055])
    colour = deep[None, None, :] * (1.0 - tone[..., None]) + raw[None, None, :] * tone[..., None]
    colour = colour * (0.72 + 0.4 * fibre[..., None])

    def ridges(octaves) -> np.ndarray:
        return 1.0 - np.abs(2.0 * fractal(rng, size, octaves) - 1.0)

    fascia = np.clip((ridges((3, 6, 12)) - 0.93) / 0.06, 0.0, 1.0)[..., None]
    colour = colour * (1.0 - fascia * 0.35) + np.array([0.55, 0.2, 0.2]) * fascia * 0.35
    fat = np.clip((ridges((4, 8, 16, 32)) - 0.972) / 0.02, 0.0, 1.0)[..., None]
    colour = colour * (1.0 - fat * 0.5) + np.array([0.66, 0.5, 0.34]) * fat * 0.5
    vein = np.clip((ridges((2, 5, 10, 20)) - 0.965) / 0.02, 0.0, 1.0)[..., None]
    colour = colour * (1.0 - vein * 0.7) + np.array([0.18, 0.02, 0.07]) * vein * 0.7
    crease = np.clip((0.28 - fractal(rng, size, (6, 12, 24))) / 0.12, 0.0, 1.0)[..., None]
    colour = colour * (1.0 - crease * 0.55)
    pixels = np.concatenate([colour, np.ones((size, size, 1))], axis=-1).astype(np.float32)
    image = bpy.data.images.new("clawman_alt_meat", size, size)
    image.pixels = pixels[::-1].ravel()
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()


def plain(name: str, colour: tuple, roughness: float) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = colour
    shader.inputs["Roughness"].default_value = roughness
    material.diffuse_color = colour
    return material


def materials(mesh: bpy.types.Object) -> dict:
    """The creator's skin, with its image found again, and the new parts' materials, by name -> slot index."""
    skin = mesh.data.materials[0]
    for node in skin.node_tree.nodes:
        if node.type == "TEX_IMAGE":
            node.image = bpy.data.images.load(str(SKIN), check_existing=True)
    paint_meat(MEAT_TEXTURE)
    meat = bpy.data.materials.new("Meat")
    meat.use_nodes = True
    shader = next(n for n in meat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    texture = meat.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = bpy.data.images.load(str(MEAT_TEXTURE), check_existing=True)
    meat.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    shader.inputs["Roughness"].default_value = 0.18
    meat.use_backface_culling = False
    new = [meat,
           plain("Gum", (0.4, 0.085, 0.08, 1.0), 0.2),
           plain("Slime", (0.6, 0.36, 0.31, 1.0), 0.06),
           plain("Bone", (0.6, 0.52, 0.36, 1.0), 0.32),
           plain("Throat", (0.06, 0.006, 0.006, 1.0), 0.15),
           plain("Eye", (0.6, 0.47, 0.36, 1.0), 0.04),
           plain("Iris", (0.34, 0.33, 0.25, 1.0), 0.04)]
    for material in new:
        mesh.data.materials.append(material)
    names = [m.name for m in mesh.data.materials]
    return {m.name: names.index(m.name) for m in new}


def group_index(mesh: bpy.types.Object, name: str) -> int:
    group = mesh.vertex_groups.get(name) or mesh.vertex_groups.new(name=name)
    return group.index


def dominant(vertex, deform, names: list) -> str:
    weights = vertex[deform]
    if not weights:
        return ""
    return names[max(weights.items(), key=lambda item: item[1])[0]]


def set_weights(vertex, deform, weights: dict) -> None:
    vertex[deform].clear()
    total = sum(weights.values()) or 1.0
    for group, weight in weights.items():
        vertex[deform][group] = weight / total


class Builder:
    """Adds faces to the bmesh with a material, shading, weights and UVs."""

    def __init__(self, bm, deform, uv, mats: dict):
        self.bm, self.deform, self.uv, self.mats = bm, deform, uv, mats
        self.part, self.made = "", []

    def vert(self, co: Vector, weights: dict):
        vertex = self.bm.verts.new(co)
        set_weights(vertex, self.deform, weights)
        self.made.append((vertex, self.part))
        return vertex

    def face(self, corners, material: str, smooth: bool = True, uv=None, facing: Vector = None, uvs: dict = None):
        """uv maps a position to its UV; uvs gives each corner's UV by vertex."""
        try:
            face = self.bm.faces.new(corners)
        except ValueError:
            return None
        face.material_index = self.mats[material]
        face.smooth = smooth
        if facing is not None:
            face.normal_update()
            if face.normal.dot(facing) < 0.0:
                face.normal_flip()
        for loop in face.loops:
            if uvs is not None:
                loop[self.uv].uv = uvs.get(loop.vert, (0.0, 0.0))
            else:
                loop[self.uv].uv = uv(loop.vert.co) if uv else (0.0, 0.0)
        return face

    def tube(self, points: list, radii: list, weights: list, material: str, sides: int = 6, flat: float = 1.0,
             tip: bool = True):
        """A tube along points (each ring weighted as given), closed with a point at the end."""
        rings = []
        for index, (point, radius, weight) in enumerate(zip(points, radii, weights)):
            ahead = points[min(index + 1, len(points) - 1)] - points[max(index - 1, 0)]
            ahead.normalize()
            side = ahead.cross(Vector((0.0, 0.0, 1.0)))
            if side.length < 1e-4:
                side = ahead.cross(Vector((0.0, 1.0, 0.0)))
            side.normalize()
            up = side.cross(ahead).normalized()
            ring = []
            for k in range(sides):
                angle = k / sides * math.tau
                ring.append(self.vert(point + side * math.cos(angle) * radius + up * math.sin(angle) * radius * flat,
                                      weight))
            rings.append(ring)
        span = max(len(rings) - 1, 1)
        for index, (first, second) in enumerate(zip(rings, rings[1:])):
            for k in range(sides):
                n = (k + 1) % sides
                uvs = {first[k]: (k / sides, index / span), first[n]: ((k + 1) / sides, index / span),
                       second[n]: ((k + 1) / sides, (index + 1) / span), second[k]: (k / sides, (index + 1) / span)}
                self.face((first[k], first[n], second[n], second[k]), material, uvs=uvs)
        if tip:
            end = points[-1] + (points[-1] - points[-2]).normalized() * radii[-1] * 1.5
            point = self.vert(end, weights[-1])
            for k in range(sides):
                self.face((rings[-1][k], rings[-1][(k + 1) % sides], point), material)
        return rings


def stretch_blades(rig: bpy.types.Object, bm, deform, names: list) -> None:
    """The blades lengthen outward from the wrist."""
    for side, sign in (("L", 1.0), ("R", -1.0)):
        wrist = rig.data.bones["claw." + side].head_local
        blade = {"claw." + side, "claw_02." + side}
        for vertex in bm.verts:
            if dominant(vertex, deform, names) in blade:
                offset = vertex.co - wrist
                vertex.co = wrist + Vector((offset.x * BLADE_STRETCH, offset.y * BLADE_STRETCH, offset.z))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for side in ("L", "R"):
        wrist = rig.data.edit_bones["claw." + side].head.copy()
        for name in ("claw." + side, "claw_02." + side):
            bone = rig.data.edit_bones[name]
            for end in ("head", "tail"):
                point = getattr(bone, end)
                offset = point - wrist
                setattr(bone, end, wrist + Vector((offset.x * BLADE_STRETCH, offset.y * BLADE_STRETCH, offset.z)))
    bpy.ops.object.mode_set(mode="OBJECT")


def grow_arms(mesh: bpy.types.Object, rig: bpy.types.Object, bm, deform, names: list) -> None:
    """Copies of its own arms, each moved, turned and sized onto a new chain of bones."""
    edit_chains = {}
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for name, side, parent, root, direction, bend, scale in EXTRA_ARMS:
        sign = 1.0 if side == "L" else -1.0
        source = [bone + "." + side for bone in ARM_BONES]
        shoulder = bones[source[0]].head.copy()
        turn = frame(Vector(direction), Vector(bend)) @ frame(Vector((sign, 0, 0)), Vector((0, 0, 1))).inverted()
        place = Matrix.Translation(Vector(root)) @ turn.to_4x4() @ Matrix.Scale(scale, 4) @ Matrix.Translation(-shoulder)
        chain = []
        previous = bones[parent]
        for index, bone_name in enumerate(source):
            original = bones[bone_name]
            bone = bones.new("%s%d" % (name, index + 1))
            bone.head = place @ original.head
            bone.tail = place @ original.tail
            bone.align_roll(Vector(bend))
            bone.parent = previous
            bone.use_connect = index > 0
            bone.use_deform = True
            previous = bone
            chain.append(bone.name)
        edit_chains[name] = (place, source, chain)
    bpy.ops.object.mode_set(mode="OBJECT")
    for name, (place, source, chain) in edit_chains.items():
        remap = {mesh.vertex_groups[s].index: group_index(mesh, c) for s, c in zip(source, chain)}
        names = [g.name for g in mesh.vertex_groups]
        picked = [v for v in bm.verts if dominant(v, deform, names) in source]
        faces = list({f for v in picked for f in v.link_faces if all(dominant(u, deform, names) in source for u in f.verts)})
        copied = bmesh.ops.duplicate(bm, geom=faces)
        new_verts = [g for g in copied["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.transform(bm, matrix=place, verts=new_verts)
        for vertex in new_verts:
            weights = {}
            for group, weight in vertex[deform].items():
                if group in remap:
                    weights[remap[group]] = weights.get(remap[group], 0.0) + weight
            set_weights(vertex, deform, weights or {remap[mesh.vertex_groups[source[0]].index]: 1.0})


def add_head_bones(rig: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for name, x in (("JawL", 0.002), ("JawR", -0.002)):
        bone = bones.new(name)
        bone.head = Vector(HINGE) + Vector((x, 0, 0))
        bone.tail = Vector(HINGE_TOP) + Vector((x, 0, 0))
        bone.align_roll(Vector((0, -1, 0)))
        bone.parent = bones["head"]
        bone.use_deform = True
    previous = bones["head"]
    start, end = Vector(TONGUE_FROM), Vector(TONGUE_TO)
    for index in range(TONGUE_BONES):
        bone = bones.new("Tongue%d" % (index + 1))
        bone.head = start.lerp(end, index / TONGUE_BONES)
        bone.tail = start.lerp(end, (index + 1) / TONGUE_BONES)
        bone.align_roll(Vector((0, 0, 1)))
        bone.parent = previous
        bone.use_connect = index > 0
        bone.use_deform = True
        previous = bone
    bpy.ops.object.mode_set(mode="OBJECT")


def room(tree: BVHTree, y: float, z: float, sign: float) -> float:
    """How far the creator's skin is from the midline toward one side at (y, z); 0 outside the head."""
    hit = tree.ray_cast(Vector((MID, y, z)), Vector((sign, 0.0, 0.0)), 0.2)
    return (hit[0].x - MID) * sign if hit[0] is not None else 0.0


PROBES = (Vector((0.0, 0.0, 1.0)), Vector((0.0, -1.0, 0.0)), Vector((0.57, 0.57, -0.59)))


def crossings(tree: BVHTree, point: Vector, direction: Vector) -> int:
    count, origin = 0, point.copy()
    for _ in range(64):
        hit = tree.ray_cast(origin, direction)
        if hit[0] is None:
            break
        count += 1
        origin = hit[0] + direction * 1e-5
    return count


def inside(tree: BVHTree, point: Vector, margin: float) -> bool:
    """Whether a point is inside the creator's skin by at least margin. Its normals do not all face out (it is
    drawn double-sided), so this counts how often rays from the point cross the skin."""
    if sum(crossings(tree, point, d) % 2 for d in PROBES) < 2:
        return False
    nearest = tree.find_nearest(point)
    return nearest[0] is not None and nearest[3] >= margin


def lump(y: float, z: float) -> float:
    """Smooth bumps for the meat, so the bowl is not a clean scoop."""
    return 0.0035 * math.sin(y * 95.0 + 1.3) * math.sin(z * 80.0 + 0.4) + 0.0018 * math.sin(y * 210.0 + z * 160.0)


def blend(first: dict, second: dict, f: float) -> dict:
    """Weights part way from one set to another."""
    weights = {}
    for group, weight in first.items():
        weights[group] = weights.get(group, 0.0) + weight * (1.0 - f)
    for group, weight in second.items():
        weights[group] = weights.get(group, 0.0) + weight * f
    return weights


def walk(edges: list) -> list:
    """The vertices of a chain of edges, in order from one end."""
    links = {}
    for edge in edges:
        a, b = edge.verts
        links.setdefault(a, []).append(b)
        links.setdefault(b, []).append(a)
    ends = [v for v, near in links.items() if len(near) == 1]
    current = ends[0] if ends else next(iter(links))
    order, seen = [current], {current}
    while True:
        ahead = [v for v in links[current] if v not in seen]
        if not ahead:
            return order
        current = ahead[0]
        order.append(current)
        seen.add(current)


def close_half(build: Builder, tree: BVHTree, side: str, sign: float, jaw: int, rng: random.Random) -> dict:
    """Hollows one half's cut into a bowl of meat with skull, gums and teeth along its rim, and sets its eye."""
    bm = build.bm
    rim = [e for e in bm.edges if e.is_boundary and all(abs(v.co.x - MID) < 0.001 for v in e.verts)
           and (e.link_faces[0].calc_center_median().x - MID) * sign > 0.0]
    chain = walk(rim)
    skin_weights = {v: dict(v[build.deform].items()) for v in chain}
    # The cut ends at the neck, front and back; a chord inside the neck between its ends closes the bowl's floor.
    first, last = chain[0], chain[-1]
    steps = max(2, int((first.co - last.co).length / 0.012))
    chord = []
    for i in range(1, steps):
        f = i / steps
        co = last.co.lerp(first.co, f)
        co.x = MID + sign * 0.0008
        weights = blend(skin_weights[last], skin_weights[first], f)
        vertex = build.vert(co, weights)
        skin_weights[vertex] = weights
        chord.append(vertex)
    outline = chain + chord
    middle = sum((v.co for v in outline), Vector()) / len(outline)

    def bowl(y: float, z: float, t: float) -> Vector:
        depth = min(DEPTH * (1.0 - (1.0 - t) ** 2), 0.65 * room(tree, y, z, sign))
        depth += lump(y, z) * min(1.0, t * 3.0)
        depth += RIDGE * math.sin(math.pi * min(t, 1.0)) * math.sin(z * math.tau / RIDGE_SPACING + 0.7)
        return Vector((MID + sign * max(depth, 0.0005), y, z))

    # Each ring point moves part like the skin at its rim and part like the jaw, all jaw at the middle, so the
    # bowl stays on the skin where the head meets the neck.
    rings = {}
    for vertex in outline:
        points = [(0.0, vertex)]
        for t in RINGS:
            y = vertex.co.y + (middle.y - vertex.co.y) * t
            z = vertex.co.z + (middle.z - vertex.co.z) * t
            points.append((t, build.vert(bowl(y, z, t), blend(skin_weights[vertex], {jaw: 1.0}, t))))
        rings[vertex] = points
    hollow = build.vert(bowl(middle.y, middle.z, 1.0), {jaw: 1.0})
    facing = Vector((-sign, 0.0, 0.0))
    cut_uv = lambda co: (co.y * 5.0 + co.z * 2.0, co.z * 5.0 - co.y * 2.0)
    real = set(chain)

    def is_mouth(a, b) -> bool:
        return a in real and b in real and all(v.co.z < MOUTH_TOP and v.co.y < MOUTH_FRONT for v in (a, b))

    for index in range(len(outline)):
        a, b = outline[index], outline[(index + 1) % len(outline)]
        mouth = is_mouth(a, b)
        skull = a in real and b in real and not mouth and min(a.co.z, b.co.z) > 1.64
        for k in range(len(RINGS)):
            t = rings[a][k + 1][0]
            if t <= GUM_IN:
                material = "Gum" if mouth or not (a in real and b in real) else ("Bone" if skull else "Meat")
            elif t <= GUM_DEEP:
                material = "Gum" if mouth or not (a in real and b in real) else "Meat"
            else:
                material = "Meat"
            build.face((rings[a][k][1], rings[b][k][1], rings[b][k + 1][1], rings[a][k + 1][1]), material,
                       smooth=material != "Bone", uv=cut_uv, facing=facing)
        build.face((rings[a][-1][1], rings[b][-1][1], hollow), "Throat", uv=cut_uv, facing=facing)

    def ring_point(vertex, t: float) -> Vector:
        points = rings[vertex]
        for (t0, v0), (t1, v1) in zip(points, points[1:]):
            if t0 <= t <= t1:
                return v0.co.lerp(v1.co, (t - t0) / max(t1 - t0, 1e-6))
        return points[-1][1].co.copy()

    teeth_line = [v for v in chain if v.co.z < MOUTH_TOP and v.co.y < MOUTH_FRONT]
    chain = teeth_line
    # Teeth, in two staggered rows rooted in the gums behind the lips, pointing across the split and raked back
    # toward the throat; never long enough to come out through the other half's skin when the head is shut.
    lengths = [0.0]
    for a, b in zip(chain, chain[1:]):
        lengths.append(lengths[-1] + (b.co - a.co).length)
    hidden_teeth = [0]
    for index in range(TEETH_PER_SIDE if len(chain) > 1 else 0):
        if rng.random() < 0.1:
            continue                                     # one gone
        row = index % 2
        along = (index + 0.5 + rng.uniform(-0.3, 0.3)) / TEETH_PER_SIDE * lengths[-1]
        j = max(i for i in range(len(chain) - 1) if lengths[i] <= along) if along > 0 else 0
        j = min(j, len(chain) - 2)
        f = (along - lengths[j]) / max(lengths[j + 1] - lengths[j], 1e-6)
        depth = GUM_IN + (GUM_DEEP - GUM_IN) * (0.35 + 0.45 * row)
        root = ring_point(chain[j], depth).lerp(ring_point(chain[j + 1], depth), f)
        aim = Vector((-sign, rng.uniform(0.15, 0.55), rng.uniform(-0.45, 0.15))).normalized()
        length = rng.uniform(0.009, 0.017) * (1.55 if rng.random() < 0.18 else 1.0) * (0.75 if row else 1.0)
        if root.z > 1.7:
            length *= 0.7
        hit = tree.ray_cast(root, aim, 0.1)
        if hit[0] is not None:
            length = min(length, hit[3] - 0.004)
        thin = rng.uniform(0.24, 0.32)
        curl = rng.uniform(0.05, 0.2)
        while length >= 0.005:
            width = length * thin
            bend = Vector((0.0, 0.0, -1.0)) * length * curl
            points = [root - aim * 0.003, root + aim * length * 0.45 + bend * 0.4, root + aim * length + bend]
            across = aim.cross(Vector((0.0, 0.0, 1.0))).normalized()
            up = across.cross(aim).normalized()
            hull = [points[2]] + [points[0] + (across * dx + up * dz) * width for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            hull += [points[1] + (across * dx + up * dz) * width * 0.62 for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if all(inside(tree, point, 0.0015) for point in hull):
                break
            length *= 0.8
        if length < 0.005:
            hidden_teeth[0] += 1
            continue
        last = build.tube(points[:2], [width, width * 0.62], [{jaw: 1.0}] * 2, "Bone", sides=5, tip=False)[-1]
        tip = build.vert(points[2], {jaw: 1.0})
        for k in range(5):
            build.face((last[k], last[(k + 1) % 5], tip), "Bone", smooth=False)

    # The eye: an eyeball sunk behind the skin where the creator painted it, so only a wet cap shows, a milky iris
    # and a pinpoint pupil, looking a little off.
    x = MID + sign * EYE_SPREAD
    surface = tree.ray_cast(Vector((x, -0.5, EYE_Z)), Vector((0.0, 1.0, 0.0)), 1.0)[0]
    centre = Vector((x, surface.y + EYE_SINK, EYE_Z))
    out, down = EYE_LOOK[side]
    look = Matrix.Translation(centre) @ Matrix.Rotation(math.radians(out * sign), 4, "Z") \
        @ Matrix.Rotation(math.radians(-down), 4, "X")
    for material, radii, forward in (("Eye", (1.0, 1.0, 1.0), 0.0), ("Iris", (0.48, 0.16, 0.48), 0.92),
                                     ("Throat", (0.17, 0.1, 0.17), 1.03)):
        ball = bmesh.ops.create_uvsphere(build.bm, u_segments=12, v_segments=8, radius=EYE_RADIUS,
                                         matrix=look @ Matrix.Translation(Vector((0, -EYE_RADIUS * forward, 0)))
                                         @ Matrix.Diagonal(Vector(radii + (1.0,))))
        for vertex in ball["verts"]:
            set_weights(vertex, build.deform, {jaw: 1.0})
        for face in {f for v in ball["verts"] for f in v.link_faces}:
            face.material_index = build.mats[material]
            face.smooth = True
            for loop in face.loops:
                loop[build.uv].uv = (0.0, 0.0)
    return {"rim": len(rim), "outline": len(outline), "teeth_line": len(chain), "dropped_teeth": hidden_teeth[0],
            "eye": tuple(round(c, 4) for c in centre)}


def grow_strands(build: Builder, jaw: dict, rng: random.Random) -> int:
    """Strands of tissue between the halves' bowls, and torn ones hanging from one half."""
    cut = BVHTree.FromBMesh(build.bm)
    made = 0
    for index, (y, z) in enumerate(STRANDS):
        ends = []
        for sign in (1.0, -1.0):
            hit = cut.ray_cast(Vector((MID + sign * 1e-4, y, z)), Vector((sign, 0.0, 0.0)), 0.1)
            ends.append(hit[0])
        if None in ends:
            continue
        left, right = ends[0] + Vector((0.002, 0, 0)), ends[1] - Vector((0.002, 0, 0))
        radius = rng.uniform(0.0014, 0.0024)
        sag = rng.uniform(0.018, 0.032)
        points, radii, weights = [], [], []
        for k in range(9):
            s = k / 8
            points.append(left.lerp(right, s) - Vector((0.0, 0.0, sag * math.sin(math.pi * s))))
            drip = 0.9 * math.exp(-((s - 0.5) / 0.08) ** 2)
            radii.append(radius * (0.45 + 1.4 * (2.0 * s - 1.0) ** 4 + drip))
            weights.append({jaw["L"]: 1.0 - s, jaw["R"]: s})
        build.tube(points, radii, weights, "Slime" if index % 2 else "Gum", tip=False)
        made += 1
    return made


def cap_throat(build: Builder, tree: BVHTree, skin: list, jaws: set, head: int) -> None:
    """Closes the neck under the split: a ring of meat just inside the skin, then a dark funnel down."""
    near = KDTree(len(skin))
    for index, vertex in enumerate(skin):
        near.insert(vertex.co, index)
    near.balance()

    def like_skin(point: Vector) -> dict:
        weights = {}
        for _, index, _ in near.find_n(point, 3):
            for group, weight in skin[index][build.deform].items():
                group = head if group in jaws else group
                weights[group] = weights.get(group, 0.0) + weight
        return weights

    centre = Vector((MID, 0.0, THROAT_Z))
    outer = []
    for k in range(14):
        angle = k / 14 * math.tau
        direction = Vector((math.cos(angle), math.sin(angle), 0.0))
        hit = tree.ray_cast(centre, direction, 0.2)
        reach = (hit[3] if hit[0] is not None else 0.03) * 0.9
        point = centre + direction * reach
        outer.append(build.vert(point, like_skin(point)))
    inner = []
    for vertex in outer:
        point = centre + (vertex.co - centre) * 0.42 + Vector((0.0, 0.0, -0.03))
        inner.append(build.vert(point, like_skin(point)))
    point = centre + Vector((0.0, 0.004, -0.1))
    bottom = build.vert(point, like_skin(point))
    up = Vector((0.0, 0.0, 1.0))
    flat_uv = lambda co: (co.x * 6.0, co.y * 6.0)
    for k in range(14):
        n = (k + 1) % 14
        build.face((outer[k], outer[n], inner[n], inner[k]), "Meat", uv=flat_uv, facing=up)
        build.face((inner[k], inner[n], bottom), "Throat", facing=up)


def grow_tongue(build: Builder, tongue: list) -> None:
    """A long, flat, wet tongue along its chain of bones, from the throat up behind the lips."""
    start, end = Vector(TONGUE_FROM), Vector(TONGUE_TO)
    points, radii, weights = [], [], []
    for index in range(TONGUE_BONES + 1):
        t = index / TONGUE_BONES
        points.append(start.lerp(end, t))
        radii.append(0.015 * (1.0 - 0.6 * t) + 0.003)
        if index == 0:
            weights.append({tongue[0]: 1.0})
        elif index == TONGUE_BONES:
            weights.append({tongue[-1]: 1.0})
        else:
            weights.append({tongue[index - 1]: 0.5, tongue[index]: 0.5})
    build.tube(points, radii, weights, "Meat", sides=8, flat=0.42)


def split_head(mesh: bpy.types.Object, rig: bpy.types.Object, bm, deform, names: list, mats: dict) -> dict:
    """Splits the head down the face's midline onto JawL and JawR and fills the cut with the mouth."""
    rng = random.Random(7)
    uv = bm.loops.layers.uv.verify()
    build = Builder(bm, deform, uv, mats)
    tree = BVHTree.FromBMesh(bm)            # the creator's head, whole: everything new keeps inside its skin
    add_head_bones(rig)
    jaw = {"L": group_index(mesh, "JawL"), "R": group_index(mesh, "JawR")}
    head_group = mesh.vertex_groups["head"].index
    tongue = [group_index(mesh, "Tongue%d" % (i + 1)) for i in range(TONGUE_BONES)]

    head_faces = [f for f in bm.faces if all(dominant(v, deform, names) == "head" for v in f.verts)]
    geom = list({e for f in head_faces for e in f.edges}) + head_faces + list({v for f in head_faces for v in f.verts})
    cut = bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(MID, 0, 0), plane_no=(1, 0, 0), dist=0.0005)
    cut_edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    bmesh.ops.split_edges(bm, edges=cut_edges)
    bm.verts.ensure_lookup_table()
    # Each half's head weight goes to its jaw; its weights on the neck stay, so the base of the skull holds.
    for vertex in bm.verts:
        weights = dict(vertex[deform].items())
        if head_group not in weights:
            continue
        face_side = [f.calc_center_median().x - MID for f in vertex.link_faces]
        side = "L" if (sum(face_side) / max(len(face_side), 1)) > 0.0 else "R"
        weights[jaw[side]] = weights.pop(head_group)
        set_weights(vertex, deform, weights)
    skin = list(bm.verts)
    report = {}
    for side, sign in (("L", 1.0), ("R", -1.0)):
        build.part = "half" + side
        report[side] = close_half(build, tree, side, sign, jaw[side], rng)
    build.part = "strands"
    report["strands"] = grow_strands(build, jaw, rng)
    build.part = "throat"
    cap_throat(build, tree, skin, set(jaw.values()), head_group)
    build.part = "tongue"
    grow_tongue(build, tongue)
    leaks = {}
    for vertex, part in build.made:
        if inside(tree, vertex.co, 0.0):
            continue
        distance = tree.find_nearest(vertex.co)[3]
        if distance < 0.0005:
            continue                                     # on the skin: the rim, where the cut meets it
        count, worst, where = leaks.get(part, (0, 0.0, None))
        if distance > worst:
            worst, where = distance, tuple(round(c, 3) for c in vertex.co)
        leaks[part] = (count + 1, round(worst, 4), where)
    report["outside_skin"] = leaks
    return report


def export(mesh: bpy.types.Object, rig: bpy.types.Object) -> None:
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    mesh.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    settings = {
        "filepath": str(GLB), "export_format": "GLB", "use_selection": True, "export_yup": True,
        "export_apply": False, "export_materials": "EXPORT", "export_animations": True,
        "export_animation_mode": "ACTIONS", "export_force_sampling": True, "export_anim_slide_to_zero": True,
        "export_skins": True, "export_def_bones": True, "export_cameras": False, "export_lights": False,
    }
    available = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(**{key: value for key, value in settings.items() if key in available})


def build() -> tuple:
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE), load_ui=False, use_scripts=False)
    for obj in list(bpy.data.objects):
        if obj.name not in (MESH, RIG):
            bpy.data.objects.remove(obj, do_unlink=True)
    mesh, rig = bpy.data.objects[MESH], bpy.data.objects[RIG]
    rig.animation_data_create()
    rig.animation_data.action = None
    mats = materials(mesh)
    names = [g.name for g in mesh.vertex_groups]
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    deform = bm.verts.layers.deform.verify()
    stretch_blades(rig, bm, deform, names)
    grow_arms(mesh, rig, bm, deform, names)
    names = [g.name for g in mesh.vertex_groups]
    report = split_head(mesh, rig, bm, deform, names, mats)
    print("HEAD %s" % report)
    bm.normal_update()
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    return mesh, rig


if __name__ == "__main__":
    mesh, rig = build()
    export(mesh, rig)
    print("GLB=%s" % GLB)
    print("BONES=%d" % len(rig.data.bones))
