import re

scene_path = "scenes/chapters/main/starting_forest.tscn"
with open(scene_path, "r", encoding="utf-8") as f:
    content = f.read()

# 1. Update ExtResources
# Check if 38_y0hyv already exists
if 'id="38_y0hyv"' not in content:
    old_ext = '[ext_resource type="Script" path="res://scenes/environment/multimesh_exclusion_filter.gd" id="38_filter"]'
    new_ext = (
        '[ext_resource type="PackedScene" uid="uid://brtc72hgbpgst" path="res://models/barricade/barricade.glb" id="38_y0hyv"]\n'
        '[ext_resource type="Script" uid="uid://c5hpefsm7ib4s" path="res://scenes/environment/multimesh_exclusion_filter.gd" id="39_filter"]'
    )
    if old_ext in content:
        content = content.replace(old_ext, new_ext)
    else:
        # fallback search
        content = re.sub(
            r'\[ext_resource type="Script"[^\]]*multimesh_exclusion_filter\.gd"[^\]]*\]',
            new_ext,
            content
        )

# 2. Update lowGrassMulti script reference from 38_filter to 39_filter
content = content.replace('script = ExtResource("38_filter")', 'script = ExtResource("39_filter")')

# 3. Update Sketchfab_Scene transform and insert barricades
old_sketchfab_block = re.search(
    r'(\[node name="Sketchfab_Scene" parent="\." unique_id=712065991 instance=ExtResource\("37_tf0i6"\)\]\s*\n'
    r'transform = Transform3D\([^\n]+\)\s*\n)',
    content
)

new_props_block = (
    '[node name="Sketchfab_Scene" parent="." unique_id=712065991 instance=ExtResource("37_tf0i6")]\n'
    'transform = Transform3D(7.923378, 0, -1.1045743, 0, 8, 0, 1.1045743, 0, 7.923378, -250.02612, 0.6998224, 10.553262)\n\n'
    '[node name="barricade" parent="." unique_id=1877188457 instance=ExtResource("38_y0hyv")]\n'
    'transform = Transform3D(0.04924303, 0, 0.56285, 0, 0.565, 0, -0.56285, 0, 0.04924303, -253.15143, 0.16756046, 7.873889)\n\n'
    '[node name="barricade2" parent="." unique_id=1471984963 instance=ExtResource("38_y0hyv")]\n'
    'transform = Transform3D(-0.00948317, 0, 0.56492054, 0, 0.565, 0, -0.56492054, 0, -0.00948317, -253.54268, 0.16756046, 10.443843)\n\n'
    '[node name="barricade3" parent="." unique_id=94753405 instance=ExtResource("38_y0hyv")]\n'
    'transform = Transform3D(-0.054549642, 0, 0.5623606, 0, 0.56500006, 0, -0.5623606, 0, -0.054549642, -253.13837, 0.16756046, 13.239731)\n\n'
)

if old_sketchfab_block:
    content = content[:old_sketchfab_block.start()] + new_props_block + content[old_sketchfab_block.end():]
    print("Replaced Sketchfab_Scene block with updated transform and 3 barricades.")
else:
    print("WARNING: Could not find exact Sketchfab_Scene block!")

with open(scene_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Saved updated starting_forest.tscn successfully.")
