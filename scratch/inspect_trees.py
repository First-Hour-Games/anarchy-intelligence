import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

nodes = re.findall(r'\[node name="(treeMulti\d*)"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.DOTALL)
for name, body in nodes:
    mm_match = re.search(r'multimesh = SubResource\("([^"]+)"\)', body)
    mm_id = mm_match.group(1) if mm_match else 'None'
    mm_sub = re.search(r'\[sub_resource type="MultiMesh" id="' + mm_id + r'"\](.*?)(?=\n\[sub_resource|\n\[node|\Z)', text, re.DOTALL)
    if mm_sub:
        mesh_m = re.search(r'mesh = (SubResource|ExtResource)\("([^"]+)"\)', mm_sub.group(1))
        count_m = re.search(r'instance_count = (\d+)', mm_sub.group(1))
        mesh_ref = f"{mesh_m.group(1)}:{mesh_m.group(2)}" if mesh_m else 'None'
        count = count_m.group(1) if count_m else '0'
        print(f'{name:12} mm={mm_id:18} mesh={mesh_ref:25} count={count}')
    else:
        print(f'{name:12} mm={mm_id:18} (subresource not found)')
