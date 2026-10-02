import bpy, json, runpy
from mathutils import Vector
from pathlib import Path

root = Path(__file__).resolve().parents[2]
output = {}
for filename, slug in [('Hospital_V1.blend', 'hospital'), ('welcomeCenterV2.blend', 'welcome_center')]:
    bpy.ops.wm.open_mainfile(filepath=str(root / 'models/source/buildings' / filename))
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    output[slug] = [{'name': o.name, 'min': list(map(float, [min((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for i in range(3)])), 'max': list(map(float, [max((o.matrix_world @ Vector(c))[i] for c in o.bound_box) for i in range(3)]))} for o in meshes]
    dest = root / 'models' / 'buildings' / slug
    dest.mkdir(parents=True, exist_ok=True)
    if slug == 'welcome_center':
        for obj in meshes:
            if obj.name == 'Ground_Grid' or obj.name.startswith(('LightPost_', 'Fence_', 'Yard_')):
                obj.hide_set(True)
            elif obj.name.startswith('BigBear_Statue_'):
                obj.location.x -= 42
                obj.location.y -= 9
    bpy.ops.export_scene.gltf(filepath=str(dest / (slug + '.glb')), export_format='GLB', export_apply=True, use_visible=True)
(root / 'tools' / 'blender' / 'story_building_bounds.json').write_text(json.dumps(output, indent=2))
runpy.run_path(str(root / 'tools/blender/prepare_story_hospital.py'), run_name='__main__')
