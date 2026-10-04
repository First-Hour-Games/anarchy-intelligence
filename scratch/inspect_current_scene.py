import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

sub_res = re.findall(r'\[sub_resource type="([^"]+)" id="([^"]+)"\]', text)
print("=== SubResources in starting_forest.tscn ===")
for t, i in sub_res:
    if 'MultiMesh' in t or 'Mesh' in t:
        print(f'{t} id={i}')

print("\n=== Foliage children ===")
in_foliage = False
for line in text.splitlines():
    if '[node name="Foliage"' in line:
        in_foliage = True
    elif in_foliage and line.startswith('[node '):
        if 'parent="Foliage"' not in line:
            break
        print(line)

print("\n=== Scene Nodes around Sketchfab / Barricade ===")
for line in text.splitlines():
    if any(k in line for k in ['Sketchfab', 'barricade', 'InteractableBlock', 'toyotaCrownModel']):
        print(line)
