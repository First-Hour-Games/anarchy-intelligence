import bpy
from pathlib import Path

root = Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(root / 'models/source/buildings/Hospital_V1.blend'))

def clip(poly, axis, limit, greater):
    result = []
    for index, current in enumerate(poly):
        previous = poly[index - 1]
        current_in = current[axis] >= limit if greater else current[axis] <= limit
        previous_in = previous[axis] >= limit if greater else previous[axis] <= limit
        if current_in != previous_in:
            weight = (limit - previous[axis]) / (current[axis] - previous[axis])
            result.append(previous.lerp(current, weight))
        if current_in:
            result.append(current)
    return result

def subtract(poly, low, high):
    outside = []
    remainder = poly
    for axis in range(3):
        for limit, greater in [(low[axis], True), (high[axis], False)]:
            if len(remainder) < 3:
                return outside
            piece = clip(remainder, axis, limit, not greater)
            if len(piece) >= 3:
                outside.append(piece)
            remainder = clip(remainder, axis, limit, greater)
    return outside

# Clip surfaces without Boolean caps on the source's overlapping joined cubes.
# The Godot adapter supplies the ground floor and room partitions.
cuts = [((-19.6, -1, -0.05), (-14.4, 1, 5.2)), ((-33.5, 0.5, 0.15), (29.5, 15.5, 5.65))]
for obj in list(bpy.context.scene.objects):
    if obj.type != 'MESH' or obj.name == 'RC_concrete':
        continue
    original = obj.data
    original.calc_loop_triangles()
    verts, faces, materials = [], [], []
    inverse = obj.matrix_world.inverted()
    for triangle in original.loop_triangles:
        fragments = [[obj.matrix_world @ original.vertices[index].co for index in triangle.vertices]]
        for low, high in cuts:
            fragments = [part for fragment in fragments for part in subtract(fragment, low, high)]
        for fragment in fragments:
            start = len(verts)
            verts.extend([inverse @ point for point in fragment])
            faces.append(tuple(range(start, len(verts))))
            materials.append(triangle.material_index)
    mesh = bpy.data.meshes.new(original.name + '_playable')
    mesh.from_pydata(verts, [], faces)
    for material in original.materials:
        mesh.materials.append(material)
    for polygon, material_index in zip(mesh.polygons, materials):
        polygon.material_index = material_index
    mesh.update()
    obj.data = mesh
bpy.ops.export_scene.gltf(filepath=str(root / 'models/buildings/hospital/hospital.glb'), export_format='GLB', export_apply=True, use_visible=True)
