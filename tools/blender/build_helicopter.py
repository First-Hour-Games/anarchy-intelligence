"""Build the rescue helicopter waiting on the alt hospital's roof (models/props/helicopter/helicopter.glb).

blender --background --factory-startup --disable-autoexec --python tools/blender/build_helicopter.py

A light twin-skid rescue helicopter in the game's low-poly style: white with a red stripe and RESCUE on the
tail boom, its right-hand sliding door open, a pilot at the controls. Game coordinates (metres): y up, the nose
toward -z (Godot's forward), the origin on the ground under the rotor mast. Nodes:
  Body        everything that does not move;
  MainRotor   hub and four blades, its origin on the mast (Godot spins it about its y);
  TailRotor   two blades, its origin on its hub (spun about its x);
  BoardPoint  where you stand to climb in, outside the open door;
  PassengerSeat  where you sit, looking out of the open door.
Nothing is saved to a .blend.
"""

import math
from pathlib import Path

import bmesh
import bpy

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "models" / "props" / "helicopter" / "helicopter.glb"

PALETTE = {
    "HeliWhite": ((0.86, 0.86, 0.83), 0.1, 0.45),
    "HeliRed": ((0.72, 0.06, 0.05), 0.1, 0.45),
    "HeliGlass": ((0.04, 0.06, 0.08), 0.0, 0.05),
    "Rotor": ((0.12, 0.12, 0.12), 0.3, 0.5),
    "Steel": ((0.45, 0.46, 0.46), 0.8, 0.4),
    "Seat": ((0.12, 0.16, 0.24), 0.0, 0.8),
    "Cabin": ((0.30, 0.31, 0.32), 0.2, 0.7),
    "FlightSuit": ((0.22, 0.27, 0.18), 0.0, 0.85),
    "Helmet": ((0.85, 0.84, 0.80), 0.1, 0.35),
    "Visor": ((0.05, 0.05, 0.06), 0.6, 0.1),
    "Beacon": ((1.0, 0.1, 0.06), 0.0, 0.4),
    "NavGreen": ((0.1, 1.0, 0.3), 0.0, 0.4),
    "Landing": ((1.0, 0.97, 0.85), 0.0, 0.3),
    "Lettering": ((0.95, 0.95, 0.93), 0.0, 0.5),
}
EMISSION = {"Beacon": 4.0, "NavGreen": 3.0, "Landing": 4.0}
ALPHA = {"HeliGlass": 0.55}


def g2b(p) -> tuple:
    """Game (x, y, z) to Blender (x, -z, y)."""
    return (p[0], -p[2], p[1])


def material(name: str):
    existing = bpy.data.materials.get(name)
    if existing:
        return existing
    color, metallic, roughness = PALETTE[name]
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    mat.diffuse_color = (*color, 1.0)
    if name in ALPHA:
        shader.inputs["Alpha"].default_value = ALPHA[name]
        mat.surface_render_method = "BLENDED"
    if name in EMISSION:
        shader.inputs["Emission Color"].default_value = (*color, 1.0)
        shader.inputs["Emission Strength"].default_value = EMISSION[name]
    return mat


class Part:
    """Faces in game coordinates, relative to an origin, gathered into one object."""

    def __init__(self, name: str, origin=(0.0, 0.0, 0.0)) -> None:
        self.name, self.origin = name, origin
        self.verts, self.faces, self.mats, self.names = [], [], [], []

    def _mat(self, name: str) -> int:
        if name not in self.names:
            self.names.append(name)
        return self.names.index(name)

    def hexa(self, corners: list, mat: str) -> "Part":
        """Eight corners: the -z end (x0y0, x1y0, x1y1, x0y1), then the +z end in the same order."""
        base = len(self.verts)
        self.verts += [tuple(c[i] - self.origin[i] for i in range(3)) for c in corners]
        index = self._mat(mat)
        for face in [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]:
            self.faces.append(tuple(base + i for i in face))
            self.mats.append(index)
        return self

    def box(self, low, high, mat: str) -> "Part":
        x0, y0, z0 = low
        x1, y1, z1 = high
        return self.hexa([(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
                          (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], mat)

    def section(self, z0: float, a: tuple, z1: float, b: tuple, mat: str) -> "Part":
        """A tapering box from section a = (half width, y bottom, y top) at z0 to section b at z1."""
        return self.hexa([(-a[0], a[1], z0), (a[0], a[1], z0), (a[0], a[2], z0), (-a[0], a[2], z0),
                          (-b[0], b[1], z1), (b[0], b[1], z1), (b[0], b[2], z1), (-b[0], b[2], z1)], mat)

    def tube(self, a: tuple, b: tuple, radius: float, mat: str, segments: int = 8) -> "Part":
        """A cylinder from point a to point b."""
        ax, ay, az = a
        bx, by, bz = b
        dx, dy, dz = bx - ax, by - ay, bz - az
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        ux, uy, uz = dx / length, dy / length, dz / length
        # Two axes square to the tube.
        px, py, pz = (0.0, 1.0, 0.0) if abs(uy) < 0.9 else (1.0, 0.0, 0.0)
        vx, vy, vz = uy * pz - uz * py, uz * px - ux * pz, ux * py - uy * px
        n = math.sqrt(vx * vx + vy * vy + vz * vz)
        vx, vy, vz = vx / n, vy / n, vz / n
        wx, wy, wz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
        base = len(self.verts)
        for end in (a, b):
            for k in range(segments):
                angle = 2 * math.pi * k / segments
                c, s = math.cos(angle) * radius, math.sin(angle) * radius
                p = (end[0] + vx * c + wx * s, end[1] + vy * c + wy * s, end[2] + vz * c + wz * s)
                self.verts.append(tuple(p[i] - self.origin[i] for i in range(3)))
        index = self._mat(mat)
        for k in range(segments):
            j = (k + 1) % segments
            self.faces.append((base + k, base + j, base + segments + j, base + segments + k))
            self.mats.append(index)
        self.faces.append(tuple(base + k for k in reversed(range(segments))))
        self.mats.append(index)
        self.faces.append(tuple(base + segments + k for k in range(segments)))
        self.mats.append(index)
        return self

    def build(self):
        mesh = bpy.data.meshes.new(self.name)
        mesh.from_pydata([g2b(v) for v in self.verts], [], self.faces)
        for name in self.names:
            mesh.materials.append(material(name))
        for polygon, index in zip(mesh.polygons, self.mats):
            polygon.material_index = index
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        obj = bpy.data.objects.new(self.name, mesh)
        obj.location = g2b(self.origin)
        bpy.context.scene.collection.objects.link(obj)
        return obj


def text(name: str, words: str, at: tuple, yaw: float, size: float, mat: str):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = words
    curve.size = size
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.extrude = 0.004
    curve.materials.append(material(mat))
    obj = bpy.data.objects.new(name, curve)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = g2b(at)
    # Text lies in Blender's XY plane facing +Z: stand it up (facing game +z), then turn it about game y.
    obj.rotation_euler = (math.radians(90.0), 0.0, math.radians(yaw))
    return obj


def empty(name: str, at: tuple, facing: tuple):
    """A marker whose forward (Godot's -z) points along the game direction `facing` (x, z)."""
    obj = bpy.data.objects.new(name, None)
    obj.location = g2b(at)
    # A Blender object's +y becomes the glTF node's -z; turned by phi about Blender z, +y points along game
    # (-sin phi, 0, -cos phi).
    phi = math.atan2(-facing[0], -facing[1])
    obj.rotation_euler = (0.0, 0.0, phi)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    body = Part("Body")
    # Cabin: floor, roof, the left wall with windows, the right wall round the open door, the back wall.
    body.box((-0.86, 0.5, -1.4), (0.86, 0.62, 1.8), "HeliWhite")           # belly and floor
    body.box((-0.86, 1.98, -1.4), (0.86, 2.08, 1.8), "HeliWhite")          # roof
    body.box((-0.86, 0.62, 1.7), (0.86, 1.98, 1.8), "HeliWhite")           # back wall
    body.box((-0.86, 0.62, -1.4), (-0.78, 1.98, 1.7), "HeliWhite")         # left wall
    body.box((-0.87, 1.15, -0.9), (-0.86, 1.75, 1.3), "HeliGlass")         # its windows
    body.box((0.78, 0.62, -1.4), (0.86, 1.98, -0.25), "HeliWhite")         # right wall ahead of the door
    body.box((0.78, 0.62, 1.45), (0.86, 1.98, 1.7), "HeliWhite")           # and behind it
    body.box((0.78, 1.9, -0.25), (0.86, 1.98, 1.45), "HeliWhite")          # over the doorway
    body.box((0.86, 0.66, 1.5), (0.92, 1.92, 3.0), "HeliWhite")            # the sliding door, slid back
    body.box((0.92, 1.2, 1.7), (0.925, 1.7, 2.8), "HeliGlass")
    for side in (-1.0, 1.0):                                               # the red stripe
        body.box((side * 0.865 - 0.004, 0.95, -1.4), (side * 0.865 + 0.004, 1.08, 1.8), "HeliRed")
    # The nose: tapering forward of the cabin, glazed above.
    body.section(-2.75, (0.42, 0.75, 1.35), -1.4, (0.86, 0.55, 2.05), "HeliWhite")
    body.section(-2.55, (0.40, 1.25, 1.62), -1.42, (0.84, 1.3, 2.02), "HeliGlass")
    body.box((-0.75, 0.62, -1.42), (0.75, 1.28, -1.38), "Cabin")           # instrument bulkhead
    # Engine cowling and the mast.
    body.section(-0.7, (0.4, 2.05, 2.45), 1.9, (0.55, 2.05, 2.65), "HeliWhite")
    body.tube((0.0, 2.6, 0.2), (0.0, 2.92, 0.2), 0.1, "Steel")
    # Tail boom, fins and the stabiliser, with RESCUE along it.
    body.section(1.8, (0.45, 1.2, 1.95), 7.2, (0.16, 1.62, 1.88), "HeliWhite")
    body.section(6.55, (0.05, 1.6, 2.2), 7.45, (0.05, 1.7, 3.05), "HeliWhite")
    body.box((-1.15, 1.62, 5.75), (1.15, 1.68, 6.25), "HeliWhite")
    for side in (-1.0, 1.0):
        body.box((side * 1.15 - 0.06, 1.55, 5.85), (side * 1.15 + 0.06, 1.85, 6.2), "HeliRed")
    body.section(1.8, (0.455, 1.5, 1.6), 5.0, (0.3, 1.66, 1.74), "HeliRed")    # the stripe along the boom
    # Skids on their cross tubes.
    for side in (-1.0, 1.0):
        x = side * 1.05
        body.tube((x, 0.08, -1.7), (x, 0.08, 2.3), 0.05, "Steel")
        body.tube((x, 0.08, -1.7), (x, 0.32, -2.1), 0.05, "Steel")
        for z in (-0.7, 1.25):
            body.tube((x, 0.08, z), (side * 0.6, 0.55, z), 0.045, "Steel")
    # Inside: two benches facing each other, and the pilot in the right-hand seat.
    body.box((-0.75, 0.62, -1.3), (0.75, 1.05, -0.85), "Seat")
    body.box((-0.75, 1.05, -1.38), (0.75, 1.55, -1.28), "Seat")
    body.box((-0.75, 0.62, 1.0), (0.75, 1.05, 1.55), "Seat")
    body.box((-0.75, 1.05, 1.55), (0.75, 1.6, 1.65), "Seat")
    body.box((0.12, 0.62, -2.3), (0.62, 1.0, -1.75), "Seat")                # pilot's seat
    body.box((0.17, 1.0, -1.85), (0.57, 1.55, -1.6), "FlightSuit")          # torso
    body.box((0.2, 0.62, -2.3), (0.54, 1.0, -1.85), "FlightSuit")           # legs
    body.tube((0.37, 1.72, -1.78), (0.37, 1.9, -1.78), 0.15, "Helmet", segments=10)
    body.box((0.25, 1.68, -1.95), (0.49, 1.8, -1.9), "Visor")
    # Lights: a beacon on the fin and one under the belly, nav lights on the stabiliser tips, the landing light.
    body.box((-0.07, 3.05, 7.25), (0.07, 3.15, 7.4), "Beacon")
    body.box((-0.08, 0.45, 0.4), (0.08, 0.5, 0.6), "Beacon")
    body.box((-1.24, 1.6, 5.9), (-1.18, 1.7, 6.1), "Beacon")
    body.box((1.18, 1.6, 5.9), (1.24, 1.7, 6.1), "NavGreen")
    body.box((-0.12, 0.62, -2.5), (0.12, 0.7, -2.3), "Landing")
    body.build()
    # The boom is 0.353 m wide each side of centre at z = 3.6 and narrows 3.07 degrees a side: the lettering
    # lies on it, turned with it.
    for side in (-1.0, 1.0):
        text(f"Rescue{int(side > 0)}", "RESCUE", (side * 0.359, 1.63, 3.6), side * 86.9, 0.28, "Lettering")
    rotor = Part("MainRotor", origin=(0.0, 2.92, 0.2))
    rotor.tube((0.0, 2.9, 0.2), (0.0, 3.06, 0.2), 0.24, "Rotor", segments=10)
    for angle in (0.0, 90.0, 180.0, 270.0):
        r = math.radians(angle)
        cx, cz = math.cos(r), math.sin(r)
        tip = 5.3
        corners = []
        for along, across in ((0.25, -0.14), (tip, -0.14), (tip, 0.14), (0.25, 0.14)):
            corners.append((along * cx - across * cz, 2.97, 0.2 + along * cz + across * cx))
        rotor.hexa([(c[0], c[1], c[2]) for c in corners] + [(c[0], c[1] + 0.04, c[2]) for c in corners], "Rotor")
    rotor.build()
    tail = Part("TailRotor", origin=(-0.13, 2.45, 7.05))
    tail.tube((-0.05, 2.45, 7.05), (-0.2, 2.45, 7.05), 0.08, "Rotor")
    for sign in (-1.0, 1.0):
        tail.box((-0.17, 2.45 - 0.06, 7.05 + sign * 0.08), (-0.14, 2.45 + 0.06, 7.05 + sign * 0.85), "Rotor")
    tail.build()
    # You board from outside the open door (its right, +x), and ride on the back bench looking out of it.
    empty("BoardPoint", (2.0, 0.0, 0.6), (-1.0, 0.0))
    empty("PassengerSeat", (0.35, 1.08, 1.2), (1.0, 0.0))
    GLB.parent.mkdir(parents=True, exist_ok=True)
    for obj in bpy.data.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(GLB), export_format="GLB", export_apply=True, use_selection=True,
                              export_yup=True, export_materials="EXPORT", export_animations=False)
    print("HELICOPTER", GLB, [o.name for o in bpy.data.objects])


if __name__ == "__main__":
    build()
