import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

nodes = re.findall(r'(\[node name="[^"]*tree[^"]*"[^\]]*\])', text, re.IGNORECASE)
for n in nodes:
    print(n)
