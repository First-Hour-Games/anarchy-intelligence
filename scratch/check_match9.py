import sys
sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/match9_MultiMesh_y0hyv.bin", "rb") as f:
    data = f.read()

print("File size:", len(data))

idx = 0
while True:
    idx = data.find(b'MultiMesh', idx)
    if idx == -1:
        break
    start = max(0, idx - 100)
    end = min(len(data), idx + 300)
    print(f"Match at {idx}:")
    print(data[start:end].decode('utf-8', errors='replace'))
    print("=" * 40)
    idx += 9
