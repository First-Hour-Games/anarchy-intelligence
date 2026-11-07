"""The ten walkers: the alt route's rooftop Ridgebacks (scenes/monsters/the_ridgeback/ridgeback_faller.tscn),
each a different mutation of the creator's body, built by tools/blender/build_ridgeback_walkers.py.

The Ridgeback is a gaunt, skull-headed thing, its neck a bare spine and its ribs open. Every walker keeps
that body and its rig, so all the clips play on it (the leap, the fall, the splat, the legless crawl), and
grows one thing more out of it: bone blades down its back, talons to its knees, a stretched and broken
neck, a second skull, a hump of broken ribs, a jaw hanging to its chest, a crown of horns, quills, a brute's
bulk, a patient's gown. Added parts are skinned to the bone they grow from, so they move with it, and the
legless cut and the fallen legs are made from the whole walker the same way as the original's.

Everything here is in the rig's rest space, in Blender axes: the body faces -Y, its left is +X, up is +Z,
the floor is z = 0.
"""

import math
import random

import bmesh
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

UP = Vector((0.0, 0.0, 1.0))
BACK = Vector((0.0, 1.0, 0.0))
FRONT = Vector((0.0, -1.0, 0.0))
LEFT = Vector((1.0, 0.0, 0.0))
# The skull's eyes (scenes/monsters/the_ridgeback/ridgeback_faller_visual.gd draws a glow in each).
EYES = (Vector((0.044, -0.13, 2.025)), Vector((-0.044, -0.13, 2.025)))
# The neck bone, from the top of the back to the skull.
NECK_BASE = Vector((0.0, 0.138, 1.66))
NECK_TOP = Vector((0.0, 0.048, 1.90))
SKULL_CENTRE = Vector((0.0, -0.045, 2.0))


def material(name: str, colour: tuple, roughness: float = 0.5, metallic: float = 0.0, emission: tuple = None,
             strength: float = 0.0):
    import bpy

    found = bpy.data.materials.get(name)
    if found is not None:
        return found
    made = bpy.data.materials.new(name)
    made.use_nodes = True
    shader = next(node for node in made.node_tree.nodes if node.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*colour, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    if emission is not None:
        shader.inputs["Emission Color"].default_value = (*emission, 1.0)
        shader.inputs["Emission Strength"].default_value = strength
    made.diffuse_color = (*colour, 1.0)
    made.use_backface_culling = False
    return made


def frame(tangent: Vector) -> tuple:
    """Two unit vectors square to `tangent` and to each other."""
    reference = UP if abs(tangent.dot(UP)) < 0.9 else BACK
    normal = tangent.cross(reference).normalized()
    return normal, tangent.cross(normal).normalized()


class Body:
    """The creator's mesh being grown into a walker: its bmesh, its skin weights, and what the walker adds."""

    def __init__(self, obj, rng: random.Random, gore):
        self.obj = obj
        self.rng = rng
        self.gore = gore
        self.bm = bmesh.new()
        self.bm.from_mesh(obj.data)
        self.bm.verts.ensure_lookup_table()
        self.bm.faces.ensure_lookup_table()
        self.deform = self.bm.verts.layers.deform.verify()
        self.uv = self.bm.loops.layers.uv.active
        self.group = {g.name: g.index for g in obj.vertex_groups}
        self.bone_of = {g.index: g.name for g in obj.vertex_groups}
        self.bm.normal_update()
        self.body_verts = list(self.bm.verts)
        self.body_faces = list(self.bm.faces)
        # The skull's eyes; a walker that moves the head moves them, and a second head adds its own.
        self.eyes = [dict(bone="head", at=eye.copy(), second=False) for eye in EYES]
        self.tree = None
        self.refresh()
        neck = [loop[self.uv].uv.copy() for face in self.body_faces
                if all(self.share(v, {"neck"}) >= 0.5 for v in face.verts) for loop in face.loops]
        self.neck_uv = (Vector((min(u.x for u in neck), min(u.y for u in neck))),
                        Vector((max(u.x for u in neck), max(u.y for u in neck))))

    # ---- Reading the body ----
    def share(self, vertex, names: set) -> float:
        weights = vertex[self.deform]
        total = sum(weights.values())
        if total <= 0.0:
            return 0.0
        return sum(w for g, w in weights.items() if self.bone_of.get(g) in names) / total

    def dominant(self, vertex) -> str:
        weights = vertex[self.deform]
        if not weights:
            return "chest"
        return self.bone_of[max(weights.items(), key=lambda kv: kv[1])[0]]

    def weights_of(self, vertex) -> dict:
        return {self.bone_of[g]: w for g, w in vertex[self.deform].items()}

    def refresh(self) -> None:
        """Normals and the ray tree of the body as it is now (the walker's own parts not included)."""
        self.bm.normal_update()
        faces = [f for f in self.body_faces if f.is_valid]
        verts = [v.co.copy() for v in self.bm.verts]
        index = {v: i for i, v in enumerate(self.bm.verts)}
        self.tree = BVHTree.FromPolygons(verts, [[index[v] for v in f.verts] for f in faces])
        self._tree_faces = faces

    def hit(self, origin: Vector, direction: Vector, reach: float = 3.0):
        """Where a ray meets the body: (point, normal, bone of the nearest corner), or None."""
        point, normal, index, _ = self.tree.ray_cast(origin, direction.normalized(), reach)
        if point is None:
            return None
        face = self._tree_faces[index]
        corner = min(face.verts, key=lambda v: (v.co - point).length)
        if normal.dot(direction) > 0.0:
            normal = -normal
        return point, normal, self.dominant(corner)

    # ---- Adding to it ----
    def slot(self, made) -> int:
        materials = self.obj.data.materials
        for index, existing in enumerate(materials):
            if existing == made:
                return index
        materials.append(made)
        return len(materials) - 1

    def vert(self, co: Vector, weights: dict):
        vertex = self.bm.verts.new(co)
        for bone, weight in weights.items():
            vertex[self.deform][self.group[bone]] = weight
        return vertex

    def face(self, verts: list, slot: int, uvs: list = None):
        try:
            made = self.bm.faces.new(verts)
        except ValueError:
            return None
        made.material_index = slot
        for index, loop in enumerate(made.loops):
            loop[self.uv].uv = uvs[index] if uvs else (0.5, 0.5)
        made.smooth = False
        return made

    def tube(self, points: list, radii: list, weights, made, sides: int = 5, flat: float = 1.0,
             width: Vector = None, skin_uv: bool = False) -> list:
        """A tapered tube along `points`; a radius of 0 at the end makes a point. `weights` is one dict for
        the whole tube or one per point. `flat` squashes it across `width` (a blade, a tongue)."""
        slot = self.slot(made)
        rings = []
        normal = None
        for index, point in enumerate(points):
            ahead = points[min(index + 1, len(points) - 1)] - points[max(index - 1, 0)]
            tangent = ahead.normalized()
            if width is not None:
                normal = (width - tangent * width.dot(tangent)).normalized()
            elif normal is None:
                normal = frame(tangent)[0]
            else:
                normal = (normal - tangent * normal.dot(tangent)).normalized()
            binormal = tangent.cross(normal).normalized()
            weight = weights[index] if isinstance(weights, list) else weights
            if radii[index] <= 1e-5:
                rings.append([self.vert(point, weight)])
                continue
            ring = []
            for side in range(sides):
                angle = 2.0 * math.pi * side / sides
                offset = normal * math.cos(angle) * radii[index] + binormal * math.sin(angle) * radii[index] * flat
                ring.append(self.vert(point + offset, weight))
            rings.append(ring)
        low, high = self.neck_uv
        for index in range(len(rings) - 1):
            a, b = rings[index], rings[index + 1]
            v0 = index / (len(rings) - 1)
            v1 = (index + 1) / (len(rings) - 1)
            for side in range(sides):
                u0 = side / sides
                u1 = (side + 1) / sides
                uvs = None
                if skin_uv:
                    uvs = [low.lerp(high, 0.0) + Vector(((high.x - low.x) * u, (high.y - low.y) * v))
                           for u, v in ((u0, v0), (u1, v0), (u1, v1), (u0, v1))]
                if len(b) == 1:
                    self.face([a[side], a[(side + 1) % sides], b[0]], slot, uvs[:3] if uvs else None)
                else:
                    self.face([a[side], a[(side + 1) % sides], b[(side + 1) % sides], b[side]], slot, uvs)
        return rings

    def spike(self, root: Vector, direction: Vector, length: float, radius: float, weights, made,
              sides: int = 4, segments: int = 3, bend: float = 0.0, axis: Vector = None, flat: float = 1.0,
              width: Vector = None, sink: float = 0.025, taper: float = 1.0) -> list:
        """A horn, blade or quill: a tapered spike from `root` along `direction`, `sink` deep in the body,
        curving `bend` degrees about `axis` over its length."""
        heading = direction.normalized()
        point = root - heading * sink
        points = [point.copy()]
        step = (length + sink) / segments
        turn = Quaternion(axis.normalized(), math.radians(bend) / segments) if bend and axis is not None else None
        for _ in range(segments):
            if turn is not None:
                heading = turn @ heading
            point = point + heading * step
            points.append(point.copy())
        radii = [radius * (1.0 - index / segments) ** taper for index in range(segments + 1)]
        radii[-1] = 0.0
        if isinstance(weights, str):
            weights = {weights: 1.0}
        return self.tube(points, radii, weights, made, sides=sides, flat=flat, width=width)

    def ring(self, centre: Vector, axis: Vector, radius: float, thickness: float, weights: dict, made,
             segments: int = 10, sides: int = 5) -> None:
        """A torus round `axis` (a band, a noose)."""
        slot = self.slot(made)
        axis = axis.normalized()
        a, b = frame(axis)
        rings = []
        for index in range(segments):
            angle = 2.0 * math.pi * index / segments
            out = a * math.cos(angle) + b * math.sin(angle)
            centre_point = centre + out * radius
            rings.append([self.vert(centre_point + (out * math.cos(2.0 * math.pi * s / sides)
                                                    + axis * math.sin(2.0 * math.pi * s / sides)) * thickness, weights)
                          for s in range(sides)])
        for index in range(segments):
            this, after = rings[index], rings[(index + 1) % segments]
            for s in range(sides):
                self.face([this[s], this[(s + 1) % sides], after[(s + 1) % sides], after[s]], slot)

    def strip(self, top: Vector, down: Vector, across: Vector, width: float, length: float, weights, made,
              rows: int = 3, sway: float = 0.0) -> None:
        """A hanging rag: a flat strip from `top`, `width` wide along `across`, falling along `down`."""
        slot = self.slot(made)
        across = across.normalized()
        edges = []
        for row in range(rows + 1):
            t = row / rows
            centre = top + down.normalized() * length * t + across * math.sin(t * 2.5) * sway
            narrow = width * (1.0 - 0.35 * t)
            weight = weights[row] if isinstance(weights, list) else weights
            edges.append((self.vert(centre - across * narrow / 2.0, weight), self.vert(centre + across * narrow / 2.0, weight)))
        for row in range(rows):
            (a, b), (c, d) = edges[row], edges[row + 1]
            self.face([a, b, d, c], slot)

    def copy_faces(self, faces: list, transform: Matrix, weights, offset: float = 0.0) -> dict:
        """The faces again, moved by `transform` (and `offset` out along the normals), skinned by `weights`
        (a dict, or a function of the original vertex). Returns the original vertex -> its copy."""
        copies = {}
        for face in faces:
            for vertex in face.verts:
                if vertex not in copies:
                    co = transform @ (vertex.co + vertex.normal * offset)
                    copies[vertex] = self.vert(co, weights(vertex) if callable(weights) else weights)
        for face in faces:
            uvs = [loop[self.uv].uv.copy() for loop in face.loops]
            self.face([copies[v] for v in face.verts], face.material_index, uvs)
        return copies

    def move_head(self, lift: Vector, turn: Quaternion, stretch: bool) -> None:
        """Moves the skull by `lift` and turns it by `turn` about the top of its neck, the neck following
        along its length (stretching to reach if `stretch`), and the eyes with the skull."""
        axis = NECK_TOP - NECK_BASE
        length = axis.length
        axis.normalize()
        pivot = NECK_TOP + lift
        for vertex in self.body_verts:
            head = self.share(vertex, {"head"})
            neck = self.share(vertex, {"neck"})
            if head + neck < 0.05 or vertex.co.z < NECK_BASE.z - 0.02:
                continue
            along = min(max((vertex.co - NECK_BASE).dot(axis) / length, 0.0), 1.0)
            reach = max(head, along * along if stretch else along * along * neck)
            moved = vertex.co + lift * reach
            turned = pivot + turn @ (moved - pivot)
            vertex.co = moved.lerp(turned, head)
        for eye in self.eyes:
            if eye["bone"] == "head":
                eye["at"] = pivot + turn @ (eye["at"] + lift - pivot)

    def finish(self) -> None:
        self.bm.normal_update()
        self.bm.to_mesh(self.obj.data)
        self.obj.data.update()
        self.bm.free()


# ---- The walkers ---------------------------------------------------------------------------------------
def bone_white(name="Walker_Bone"):
    return material(name, (0.74, 0.68, 0.55), 0.45)


def spine(body: Body) -> None:
    """Blades of bone along its spine, from the hips up the neck, tallest between the shoulders: a jagged
    fin along the roofline."""
    blade = bone_white()
    count = 15
    for index in range(count):
        t = index / (count - 1)
        z = 1.02 + t * 0.66
        found = body.hit(Vector((0.0, 0.9, z)), FRONT)
        if found is None:
            continue
        point, normal, bone = found
        length = (0.09 + 0.38 * math.sin(math.pi * min(1.0, t * 1.08)) ** 1.6) * body.rng.uniform(0.88, 1.12)
        heading = (normal * 0.8 + UP * 0.5 + BACK * 0.2).normalized()
        body.spike(point, heading, length, 0.05, bone, blade, sides=4, segments=3, bend=-28.0, axis=LEFT,
                   flat=0.28, width=UP, sink=0.03)
    for z in (1.70, 1.75, 1.80, 1.85):
        found = body.hit(Vector((0.0, 0.9, z)), FRONT)
        if found is not None:
            point, normal, bone = found
            body.spike(point, (normal + UP * 0.6).normalized(), body.rng.uniform(0.05, 0.08), 0.018, bone, blade,
                       sides=4, segments=2, flat=0.4, width=UP, sink=0.012)


def reacher(body: Body) -> None:
    """Hands grown into talons longer than its forearms, curled under, and spurs at the elbows: hanging, its
    arms reach past its knees."""
    claw = material("Walker_Claw", (0.13, 0.11, 0.09), 0.3)
    for side in (1.0, -1.0):
        hand = "hand_l" if side > 0 else "hand_r"
        for finger in range(4):
            spread = finger - 1.5
            root = Vector((side * 1.05, 0.124 + spread * 0.024, 1.637 - abs(spread) * 0.004))
            heading = Vector((side, spread * 0.14, -0.15)).normalized()
            length = (0.36, 0.44, 0.42, 0.34)[finger] * body.rng.uniform(0.94, 1.06)
            body.spike(root, heading, length, 0.0135, hand, claw, sides=4, segments=4, bend=38.0,
                       axis=Vector((0.0, side, 0.0)), sink=0.05, taper=0.8)
        body.spike(Vector((side * 0.98, 0.09, 1.63)), Vector((side * 0.45, -0.8, -0.35)), 0.2, 0.012, hand, claw,
                   sides=4, segments=3, bend=30.0, axis=Vector((0.0, side, 0.0)), sink=0.04)
        elbow = body.hit(Vector((side * 0.55, 0.9, 1.645)), FRONT)
        if elbow is not None:
            point, normal, bone = elbow
            body.spike(point, (normal + Vector((side * 0.5, 0.0, 0.2))).normalized(), 0.15, 0.022, "forearm_l" if side > 0 else "forearm_r",
                       claw, sides=4, segments=2, sink=0.02)


def hanged(body: Body) -> None:
    """A neck stretched half as long again and broken, the skull lolling to one side, and the noose still on
    it, the cut rope hanging down its back."""
    axis = (NECK_TOP - NECK_BASE).normalized()
    length = (NECK_TOP - NECK_BASE).length
    lift = axis * length * 0.6
    lolls = Quaternion(FRONT, math.radians(40.0)) @ Quaternion(LEFT, math.radians(16.0))
    body.move_head(lift, lolls, stretch=True)
    rope = material("Walker_Rope", (0.42, 0.34, 0.2), 0.95)
    # The noose round the stretched neck, below the skull.
    along = 0.78
    centre = NECK_BASE + axis * length * 1.6 * along
    neck = [v.co for v in body.body_verts if body.share(v, {"neck"}) >= 0.5
            and abs((v.co - centre).dot(axis)) < 0.04]
    reach = max(((co - centre) - axis * (co - centre).dot(axis)).length for co in neck) if neck else 0.03
    body.ring(centre, axis, reach + 0.012, 0.012, {"neck": 0.6, "head": 0.4}, rope, segments=10, sides=5)
    knot = centre + BACK * (reach + 0.02) + LEFT * 0.02
    points = [knot]
    weights = [{"neck": 1.0}]
    for z, bone in ((1.78, "chest"), (1.58, "chest"), (1.38, "spine_02"), (1.2, "spine_01")):
        found = body.hit(Vector((0.03, 0.9, z)), FRONT)
        if found is not None:
            points.append(found[0] + found[1] * 0.026)
            weights.append({bone: 1.0})
    body.tube(points, [0.017] + [0.014] * (len(points) - 2) + [0.006], weights, rope, sides=5)


def twin(body: Body) -> None:
    """A second skull grown out of its left shoulder on a stalk of raw neck, leaning away and looking
    outward with its own eyes."""
    skin = body.obj.data.materials[0]
    faces = [f for f in body.body_faces if all(body.share(v, {"head"}) >= 0.5 for v in f.verts)]
    base = Vector((0.0, 0.0, 1.9))
    place = Vector((0.2, 0.06, 1.81))
    turn = Quaternion(UP, math.radians(30.0)) @ Quaternion(BACK, math.radians(38.0))
    transform = Matrix.Translation(place) @ turn.to_matrix().to_4x4() @ Matrix.Scale(0.96, 4) @ Matrix.Translation(-base)
    weights = {"clavicle_l": 0.7, "chest": 0.3}
    body.copy_faces(faces, transform, weights)
    stalk = [Vector((0.1, 0.085, 1.665)), Vector((0.14, 0.08, 1.72)), Vector((0.18, 0.07, 1.77)),
             place + Vector((-0.01, 0.0, 0.025))]
    body.tube(stalk, [0.036, 0.032, 0.03, 0.027], weights, skin, sides=6, skin_uv=True)
    for eye in EYES:
        body.eyes.append(dict(bone="clavicle_l", at=transform @ eye, second=True))


def hunch(body: Body) -> None:
    """Bent double under a hump of its own back, the skull sunk forward between its shoulders, ribs broken
    out through the hump; burnt black, still smouldering in the cracks."""
    for vertex in body.body_verts:
        if not (1.12 < vertex.co.z < 1.9) or vertex.normal.y < 0.05:
            continue
        reach = (vertex.co.x / 0.18) ** 2 + ((vertex.co.z - 1.56) / 0.21) ** 2
        weight = math.exp(-reach) * min(1.0, (vertex.normal.y - 0.05) / 0.4)
        vertex.co += (vertex.normal * 0.5 + Vector((0.0, 0.6, 0.32))).normalized() * 0.22 * weight
    body.move_head(Vector((0.0, -0.07, -0.11)), Quaternion(LEFT, math.radians(-12.0)), stretch=False)
    body.refresh()
    rib = material("Walker_Charred", (0.4, 0.33, 0.25), 0.6)
    for x, z in ((-0.07, 1.64), (0.07, 1.64), (-0.13, 1.54), (0.13, 1.54), (-0.17, 1.44), (0.17, 1.44)):
        found = body.hit(Vector((x, 1.0, z)), FRONT)
        if found is None:
            continue
        point, normal, bone = found
        out = Vector((math.copysign(1.0, x), 0.0, 0.0))
        heading = (normal + UP * 0.45 + out * 0.35).normalized()
        body.spike(point, heading, body.rng.uniform(0.2, 0.3), 0.024, bone, rib, sides=4, segments=4,
                   bend=55.0, axis=heading.cross(out).normalized() if heading.cross(out).length > 0.1 else LEFT,
                   flat=0.45, width=UP, sink=0.03)
    ember = material("Walker_Ember", (0.16, 0.03, 0.01), 0.6, emission=(1.0, 0.2, 0.03), strength=1.2)
    slot = body.slot(ember)
    torso = [f for f in body.body_faces if body.dominant(f.verts[0]) in
             ("chest", "spine_02", "spine_01", "hips", "upperarm_l", "upperarm_r", "thigh_l", "thigh_r", "clavicle_l", "clavicle_r")]
    for face in body.rng.sample(torso, min(16, len(torso))):
        face.material_index = slot


def gaper(body: Body) -> None:
    """Its jaw unhinged and hanging to its chest, the mouth stretched raw between, and its tongue out."""
    hinge = Vector((0.0, -0.03, 1.945))
    drop = Quaternion(LEFT, math.radians(38.0))
    jaw = {v for v in body.body_verts if body.share(v, {"head"}) >= 0.5 and v.co.z < 1.945 and v.co.y < -0.035}
    for vertex in jaw:
        vertex.co = hinge + drop @ (vertex.co - hinge) + Vector((0.0, -0.01, -0.12))
    mouth = body.slot(body.gore)
    for face in body.body_faces:
        inside = sum(1 for v in face.verts if v in jaw)
        if 0 < inside < len(face.verts):
            face.material_index = mouth
    tongue = [Vector((0.0, -0.06, 1.9)), Vector((0.0, -0.13, 1.83)), Vector((0.004, -0.17, 1.71)),
              Vector((0.012, -0.17, 1.58)), Vector((0.022, -0.145, 1.46)), Vector((0.03, -0.12, 1.38))]
    body.tube(tongue, [0.028, 0.032, 0.03, 0.024, 0.016, 0.0], {"head": 1.0}, body.gore, sides=6, flat=0.45,
              width=LEFT)


def crowned(body: Body) -> None:
    """A crown of horns grown out of the skull, sweeping back: antlers against the sky."""
    horn = material("Walker_Horn", (0.72, 0.66, 0.54), 0.5)
    for yaw, rise, length in ((0.0, 52.0, 0.36), (38.0, 42.0, 0.32), (-38.0, 42.0, 0.32), (78.0, 30.0, 0.27),
                              (-78.0, 30.0, 0.27), (118.0, 22.0, 0.17), (-118.0, 22.0, 0.17), (0.0, 80.0, 0.2)):
        a, b = math.radians(yaw), math.radians(rise)
        out = Vector((math.sin(a) * math.cos(b), math.cos(a) * math.cos(b), math.sin(b)))
        found = body.hit(SKULL_CENTRE + out * 0.4, -out)
        if found is None:
            continue
        point, normal, _ = found
        heading = (out + UP * 0.35).normalized()
        sweep = heading.cross(UP)
        sweep = sweep.normalized() if sweep.length > 0.1 else LEFT
        body.spike(point, heading, length * body.rng.uniform(0.92, 1.08), 0.026, "head", horn, sides=5,
                   segments=4, bend=-40.0, axis=sweep, sink=0.02, taper=1.1)


def quill(body: Body) -> None:
    """Quills of bone all over its back, shoulders and arms, bristling backward."""
    spine_bones = ("chest", "spine_02", "spine_01", "clavicle_l", "clavicle_r", "neck")
    arm_bones = ("upperarm_l", "upperarm_r", "forearm_l", "forearm_r")
    faces = [f for f in body.body_faces if body.dominant(f.verts[0]) in spine_bones + arm_bones
             and f.normal.y > -0.15 and f.calc_center_median().z > 1.15]
    areas = [f.calc_area() for f in faces]
    quill_mat = material("Walker_Quill", (0.66, 0.6, 0.5), 0.45)
    for _ in range(90):
        face = body.rng.choices(faces, weights=areas)[0]
        corners = [v.co for v in face.verts[:3]]
        a, b = body.rng.random(), body.rng.random()
        if a + b > 1.0:
            a, b = 1.0 - a, 1.0 - b
        point = corners[0] + (corners[1] - corners[0]) * a + (corners[2] - corners[0]) * b
        bone = body.dominant(min(face.verts, key=lambda v: (v.co - point).length))
        jitter = Vector((body.rng.uniform(-0.3, 0.3), body.rng.uniform(-0.2, 0.3), body.rng.uniform(-0.2, 0.3)))
        heading = (face.normal + BACK * 0.45 + UP * 0.25 + jitter).normalized()
        longest = 0.34 if bone in spine_bones else 0.2
        body.spike(point, heading, body.rng.uniform(0.09, longest), body.rng.uniform(0.006, 0.011), bone, quill_mat,
                   sides=3, segments=1, sink=0.015)


def brute(body: Body) -> None:
    """Bigger and heavier all over (the game also draws it a third larger), the small skull sunk on its
    bulk, with spurs of bone on its shoulders."""
    swell = {"chest": 0.04, "spine_02": 0.04, "spine_01": 0.038, "hips": 0.034, "clavicle_l": 0.034,
             "clavicle_r": 0.034, "upperarm_l": 0.032, "upperarm_r": 0.032, "forearm_l": 0.026, "forearm_r": 0.026,
             "hand_l": 0.012, "hand_r": 0.012, "thigh_l": 0.032, "thigh_r": 0.032, "calf_l": 0.022,
             "calf_r": 0.022, "foot_l": 0.006, "foot_r": 0.006, "neck": 0.012, "toe_l": 0.004, "toe_r": 0.004}
    moves = []
    for vertex in body.body_verts:
        if vertex.normal.length < 0.5:
            continue
        weights = body.weights_of(vertex)
        total = sum(weights.values()) or 1.0
        amount = sum(w * swell.get(bone, 0.0) for bone, w in weights.items()) / total
        moves.append((vertex, vertex.normal * amount))
    for vertex, offset in moves:
        vertex.co += offset
    body.refresh()
    spur = bone_white()
    for side in (1.0, -1.0):
        for k, (x, z) in enumerate(((0.16, 1.73), (0.26, 1.72), (0.36, 1.7))):
            found = body.hit(Vector((side * x, 0.12, 2.4)), Vector((0.0, 0.0, -1.0)))
            if found is None:
                continue
            point, normal, bone = found
            heading = (normal + UP * 0.3 + BACK * 0.35 + Vector((side * 0.2, 0.0, 0.0))).normalized()
            body.spike(point, heading, (0.2, 0.16, 0.12)[k], 0.03, bone, spur, sides=4, segments=3, bend=-25.0,
                       axis=LEFT, sink=0.03)


def patient(body: Body) -> None:
    """One of the hospital's: still in its gown, open down the back and hanging off it in rags, its ID band
    on one wrist and an IV line taped to the other arm."""
    gown = material("Walker_Gown", (0.56, 0.68, 0.66), 0.92)
    stained = material("Walker_GownBlood", (0.3, 0.06, 0.05), 0.7)
    covered = {"hips", "spine_01", "spine_02", "chest", "clavicle_l", "clavicle_r"}
    faces = []
    for face in body.body_faces:
        centre = face.calc_center_median()
        bones = {body.dominant(v) for v in face.verts}
        sleeve = bones <= {"upperarm_l", "upperarm_r", "clavicle_l", "clavicle_r"} and abs(centre.x) < 0.36
        if not (bones <= covered or sleeve):
            continue
        if centre.y > 0.07 and abs(centre.x) < 0.05 and centre.z > 1.0:
            continue   # open down the back
        faces.append(face)
    copies = body.copy_faces(faces, Matrix.Identity(4), body.weights_of, offset=0.016)
    gown_slot = body.slot(gown)
    blood_slot = body.slot(stained)
    made = {f for v in copies.values() for f in v.link_faces}
    for face in made:
        front = face.calc_center_median().y < -0.02
        face.material_index = blood_slot if front and body.rng.random() < 0.18 else gown_slot
    # The skirt of it, torn into rags hanging from the hips.
    for k in range(9):
        angle = math.radians(-160.0 + k * 40.0 + body.rng.uniform(-8.0, 8.0))
        out = Vector((math.sin(angle), -math.cos(angle) * 0.9, 0.0))
        top = Vector((0.0, 0.08, 1.02)) + Vector((math.sin(angle) * 0.14, -math.cos(angle) * 0.11, 0.0))
        body.strip(top, Vector((out.x * 0.12, out.y * 0.12, -1.0)), Vector((math.cos(angle), math.sin(angle), 0.0)),
                   body.rng.uniform(0.07, 0.11), body.rng.uniform(0.22, 0.4), {"hips": 1.0},
                   stained if k % 4 == 1 else gown, rows=3, sway=0.015)
    band = material("Walker_Band", (0.9, 0.9, 0.85), 0.6)
    wrist = Vector((-0.83, 0.124, 1.639))
    near = [v.co for v in body.body_verts if body.share(v, {"forearm_r", "hand_r"}) >= 0.5 and abs(v.co.x - wrist.x) < 0.03]
    reach = max(((co - wrist) - LEFT * (co - wrist).dot(LEFT)).length for co in near) if near else 0.035
    body.ring(wrist, LEFT, reach + 0.006, 0.007, {"forearm_r": 1.0}, band, segments=10, sides=4)
    line = material("Walker_IVLine", (0.82, 0.86, 0.84), 0.25)
    found = body.hit(Vector((0.7, -0.6, 1.64)), BACK)
    if found is not None:
        point, normal, _ = found
        lift = normal * 0.012
        body.tube([point + lift, point + lift + Vector((-0.08, 0.0, 0.004)), point + lift + Vector((-0.17, 0.004, 0.0)),
                   point + lift + Vector((-0.2, -0.02, -0.06)), point + lift + Vector((-0.18, -0.03, -0.17))],
                  [0.006, 0.006, 0.006, 0.006, 0.005], {"forearm_l": 1.0}, line, sides=4)
        tape = body.slot(band)
        corners = [point + normal * 0.006 + LEFT * dx + UP * dz for dx, dz in ((-0.02, -0.015), (0.02, -0.015), (0.02, 0.015), (-0.02, 0.015))]
        body.face([body.vert(c, {"forearm_l": 1.0}) for c in corners], tape)


# Name, what to call it, its skin, its eyes' glow (and a second head's), how much bigger the game draws it,
# its voice's pitch, and what grows on it.
WALKERS = [
    dict(name="spine", title="The Spine", skin="pale", eyes=(0.72, 0.86, 1.0), scale=1.0, pitch=1.0, build=spine),
    dict(name="reacher", title="The Reacher", skin="dirt", eyes=(1.0, 0.66, 0.26), scale=1.06, pitch=0.94, build=reacher),
    dict(name="hanged", title="The Hanged", skin="frost", eyes=(0.66, 0.94, 1.0), scale=1.0, pitch=1.06, build=hanged),
    dict(name="twin", title="The Twin", skin="flesh", eyes=(1.0, 0.84, 0.42), second=(1.0, 0.22, 0.12), scale=1.0,
         pitch=1.1, build=twin),
    dict(name="hunch", title="The Hunch", skin="burnt", eyes=(1.0, 0.42, 0.1), scale=0.97, pitch=0.86, build=hunch),
    dict(name="gaper", title="The Gaper", skin="pale", eyes=(1.0, 0.3, 0.18), scale=1.0, pitch=1.14, build=gaper),
    dict(name="crowned", title="The Crowned", skin="tar", eyes=(0.86, 0.74, 1.0), scale=1.03, pitch=0.92, build=crowned),
    dict(name="quill", title="The Quill", skin="rot", eyes=(0.74, 1.0, 0.32), scale=0.96, pitch=1.16, build=quill),
    dict(name="brute", title="The Brute", skin="blood", eyes=(1.0, 0.18, 0.08), scale=1.32, pitch=0.76, build=brute),
    dict(name="patient", title="The Patient", skin="flesh", eyes=(1.0, 0.92, 0.6), scale=0.95, pitch=1.1, build=patient),
]
