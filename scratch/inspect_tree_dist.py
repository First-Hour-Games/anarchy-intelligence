import re, struct

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# Parse multimesh buffers
mm_blocks = re.findall(r'\[sub_resource type="MultiMesh" id="([^"]+)"\](.*?)(?=\n\[sub_resource|\n\[node|\Z)', text, re.DOTALL)
all_trees = []
for mm_id, block in mm_blocks:
    buf_m = re.search(r'buffer = PackedFloat32Array\((.*?)\)', block, re.DOTALL)
    if not buf_m: continue
    floats = [float(x.strip()) for x in buf_m.group(1).split(',') if x.strip()]
    count = len(floats) // 12
    for i in range(count):
        base = i * 12
        x = floats[base + 3]
        y = floats[base + 7]
        z = floats[base + 11]
        all_trees.append((x, y, z, mm_id))

print(f"Total trees across all MultiMeshes: {len(all_trees)}")
xs = [t[0] for t in all_trees]
zs = [t[2] for t in all_trees]
print(f"X range: {min(xs):.1f} to {max(xs):.1f}")
print(f"Z range: {min(zs):.1f} to {max(zs):.1f}")

# Check density in bins along X:
for x_bin in range(-350, 350, 50):
    bin_trees = [t for t in all_trees if x_bin <= t[0] < x_bin + 50]
    print(f"X in [{x_bin:4d}, {x_bin+50:4d}): {len(bin_trees)} trees")
