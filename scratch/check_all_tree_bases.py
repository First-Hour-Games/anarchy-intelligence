import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

nodes = re.findall(r'\[node name="(treeMulti\d*)"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.DOTALL)
for name, body in nodes:
    mm_match = re.search(r'multimesh = SubResource\("([^"]+)"\)', body)
    if not mm_match: continue
    mm_id = mm_match.group(1)
    mm_sub = re.search(r'\[sub_resource type="MultiMesh" id="' + mm_id + r'"\](.*?)(?=\n\[sub_resource|\n\[node|\Z)', text, re.DOTALL)
    if not mm_sub: continue
    buf_m = re.search(r'buffer = PackedFloat32Array\((.*?)\)', mm_sub.group(1), re.DOTALL)
    if not buf_m: continue
    floats = [float(x.strip()) for x in buf_m.group(1).split(',')[:12]]
    print(f"=== {name} ({mm_id}) ===")
    print(f"  row0: {floats[0]:.2f}, {floats[1]:.2f}, {floats[2]:.2f} | X: {floats[3]:.1f}")
    print(f"  row1: {floats[4]:.2f}, {floats[5]:.2f}, {floats[6]:.2f} | Y: {floats[7]:.1f}")
    print(f"  row2: {floats[8]:.2f}, {floats[9]:.2f}, {floats[10]:.2f} | Z: {floats[11]:.1f}")
