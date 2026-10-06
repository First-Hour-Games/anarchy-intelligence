import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

for m in ['ArrayMesh_11s4a', 'ArrayMesh_4x0ik', 'ArrayMesh_mujqg', '14_rrvih']:
    pattern = r'\[(ext_resource|sub_resource)[^\]]*id="' + m + r'"\](.*?)(?=\n\[|\Z)'
    found = re.search(pattern, text, re.DOTALL)
    if found:
        print(f"=== {m} ===")
        print(found.group(0)[:300])
