"""Export user-supplied kits as reusable, meter-scale Godot props.

Run with Blender --background --disable-autoexec --python this_file --
    <interior.blend> <flashlight.blend> <output_directory>
Source files are read without running embedded scripts and are never saved.
"""
import bpy
import json
import sys
from pathlib import Path
from mathutils import Matrix, Vector

interior_source, flashlight_source, output_arg = sys.argv[sys.argv.index('--') + 1:]
output = Path(output_arg)
output.mkdir(parents=True, exist_ok=True)
names = [
    'Counter_Straight_L96in', 'Counter_Straight_L72in', 'Counter_Raised_L72in',
    'Gondola_2Side_L72in_H48in', 'Gondola_Wall_L72in_H72in',
    'Island_Cooler_L72in', 'Ice_Merchandiser_2Door_W72in',
    'Prop_Chip_Bag', 'Prop_Juice_Bottle', 'Prop_Snack_Box',
    'Prop_Soda_Can', 'Prop_Water_Bottle',
]

def transparent(mat, alpha):
    bsdf = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Alpha'].default_value = alpha
    bsdf.inputs['Transmission Weight'].default_value = 0
    mat.surface_render_method = 'DITHERED'

def export(path):
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format='GLB', use_selection=True,
        export_animations=False, export_cameras=False, export_lights=False,
        export_apply=True, export_yup=True, export_materials='EXPORT',
    )

bpy.ops.wm.open_mainfile(filepath=interior_source, load_ui=False, use_scripts=False)
for mat in bpy.data.materials:
    if mat.name in ['GasStn_Glass', 'GasStn_BottleClear']:
        transparent(mat, 0.16 if mat.name == 'GasStn_Glass' else 0.3)
manifest = {}
for name in names:
    bpy.ops.object.select_all(action='DESELECT')
    original = bpy.data.objects[name]
    obj = original.copy()
    obj.data = original.data.copy()
    bpy.context.collection.objects.link(obj)
    corners = [original.matrix_world @ Vector(point) for point in original.bound_box]
    lower = Vector(tuple(min(point[i] for point in corners) for i in range(3)))
    upper = Vector(tuple(max(point[i] for point in corners) for i in range(3)))
    origin = Vector(((lower.x + upper.x) / 2, (lower.y + upper.y) / 2, lower.z))
    obj.data.transform(Matrix.Translation(-origin) @ original.matrix_world)
    obj.matrix_world = Matrix.Identity(4)
    obj.name = name + '_Export'
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    obj.data.update()
    levels = set()
    for polygon in obj.data.polygons:
        material = obj.data.materials[polygon.material_index]
        if material and material.name == 'GasStn_ShelfBlack' and polygon.normal.z > 0.9 and polygon.area > 0.01:
            levels.add(round(sum(obj.data.vertices[i].co.z for i in polygon.vertices) / len(polygon.vertices), 4))
    size = upper - lower
    manifest[name] = {'size': [size.x, size.z, size.y], 'shelf_levels': sorted(levels)}
    export(output / (name + '.glb'))
    bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.wm.open_mainfile(filepath=flashlight_source, load_ui=False, use_scripts=False)
missing = [image.name for image in bpy.data.images if image.source == 'FILE' and not image.packed_file and not Path(bpy.path.abspath(image.filepath)).is_file()]
if missing:
    # The supplied blend references an absent Flashlight_Textures directory.
    # Rebuild its anodized finish while preserving the body, lens, and LED geometry.
    material = bpy.data.materials['FL_Body_Baked']
    bsdf = next(node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    for key in ['Base Color', 'Metallic', 'Roughness', 'Normal']:
        for link in list(bsdf.inputs[key].links):
            material.node_tree.links.remove(link)
    bsdf.inputs['Base Color'].default_value = (0.028, 0.032, 0.035, 1)
    bsdf.inputs['Metallic'].default_value = 0.8
    bsdf.inputs['Roughness'].default_value = 0.28
    for node in list(material.node_tree.nodes):
        if node.type in ['TEX_IMAGE', 'NORMAL_MAP']:
            material.node_tree.nodes.remove(node)
    print('Restored anodized flashlight finish; absent external maps:', missing)
transparent(bpy.data.materials['FL_Lens'], 0.16)
bpy.ops.object.select_all(action='DESELECT')
forward = Matrix.Rotation(-1.5707963267948966, 4, 'X')
for obj in bpy.data.objects:
    if obj.type == 'MESH' and obj.name.startswith('Flashlight_'):
        obj.data = obj.data.copy()
        obj.data.transform(forward @ obj.matrix_world)
        obj.matrix_world = Matrix.Identity(4)
        obj.select_set(True)
export(output / 'Flashlight_Game.glb')
manifest['Flashlight_Game'] = {'forward': '-Z', 'length_m': 0.234, 'missing_source_maps': missing}
(output / 'asset_dimensions.json').write_text(json.dumps(manifest, indent=2))
print('Exported gas-station props and flashlight to', output)
