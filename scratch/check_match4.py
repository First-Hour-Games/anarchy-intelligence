import sys
sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/match4_TreePlacement4.bin", "rb") as f:
    data = f.read()

print("File size:", len(data))

for keyword in [b'TreePlacement4', b'TreePlacement5', b'treeMulti8', b'treeMulti9', b'MultiMesh_y0hyv', b'MultiMesh_s25nh', b'MultiMesh_4x0ik', b'MultiMesh_2mla1', b'barricade']:
    idx = 0
    found = 0
    while True:
        idx = data.find(keyword, idx)
        if idx == -1:
            break
        found += 1
        start = max(0, idx - 200)
        end = min(len(data), idx + 300)
        print(f"Keyword {keyword.decode()} match #{found} at offset {idx}:")
        print(data[start:end].decode('utf-8', errors='replace'))
        print("-" * 50)
        idx += len(keyword)
