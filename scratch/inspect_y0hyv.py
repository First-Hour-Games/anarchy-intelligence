import sys
sys.stdout.reconfigure(encoding='utf-8')

with open("scratch/matches/MultiMesh_y0hyv_0_0x2e3dd85bb41.bin", "rb") as f:
    data = f.read()

print("File size:", len(data))
print("Repr:")
print(repr(data[:500]))
print("\nDecoded strings (printable):")
cur = []
for b in data:
    if 32 <= b <= 126 or b in (10, 13, 9):
        cur.append(chr(b))
    else:
        if len(cur) >= 4:
            print("".join(cur))
        cur = []
if len(cur) >= 4:
    print("".join(cur))
