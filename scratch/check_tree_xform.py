import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# Grab the first treeMulti2 multimesh
mm_match = re.search(r'\[sub_resource type="MultiMesh" id="MultiMesh_b0uvm"\].*?buffer = PackedFloat32Array\((.*?)\)', text, re.DOTALL)
if mm_match:
    floats = [float(x.strip()) for x in mm_match.group(1).split(',')[:24]]
    for inst in [0, 1]:
        b = inst * 12
        print(f"Inst {inst}:")
        print(f"  row 0: {floats[b+0]:.3f}, {floats[b+1]:.3f}, {floats[b+2]:.3f} | X: {floats[b+3]:.3f}")
        print(f"  row 1: {floats[b+4]:.3f}, {floats[b+5]:.3f}, {floats[b+6]:.3f} | Y: {floats[b+7]:.3f}")
        print(f"  row 2: {floats[b+8]:.3f}, {floats[b+9]:.3f}, {floats[b+10]:.3f} | Z: {floats[b+11]:.3f}")
