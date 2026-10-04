import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

pattern = re.compile(r'\[sub_resource type="MultiMesh" id="([^"]+)"\]\s*transform_format = (\d+)\s*instance_count = (\d+)\s*mesh = SubResource\("([^"]+)"\)')
for m in pattern.finditer(text):
    print(m.groups())
