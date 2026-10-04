with open('scratch/memory_dump_chunks.txt', 'rb') as f:
    data = f.read()

parts = data.split(b'================ TARGET:')
for i, part in enumerate(parts):
    if b'[node name="barricade"' in part:
        print(f"=== Match {i} ===")
        print(part.decode('utf-8', errors='replace'))
