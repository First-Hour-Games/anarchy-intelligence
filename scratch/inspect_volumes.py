import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

boxes = re.findall(r'\[node name="(TreePlacement\d*)"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.DOTALL)
for name, body in boxes:
    xform = re.search(r'transform = Transform3D\((.*?)\)', body)
    mesh_id = re.search(r'mesh = SubResource\("([^"]+)"\)', body)
    size_str = ""
    if mesh_id:
        sub = re.search(r'\[sub_resource type="BoxMesh" id="' + mesh_id.group(1) + r'"\](.*?)(?=\n\[sub_resource|\n\[node|\Z)', text, re.DOTALL)
        if sub:
            sm = re.search(r'size = Vector3\((.*?)\)', sub.group(1))
            if sm:
                size_str = sm.group(1)
    print(f"{name:16} xform={xform.group(1) if xform else 'default':40} box_size={size_str}")
