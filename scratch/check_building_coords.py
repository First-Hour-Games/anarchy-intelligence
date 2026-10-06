import re

with open('scenes/chapters/main/starting_forest.tscn', 'r', encoding='utf-8') as f:
    text = f.read()

# Check welcomeCenterTextured2 position:
# transform: X=-117.88, Y=0.1, Z=-8.34
# ParkingLot: transform X=153, Y=0, Z=0. But wait! What are ParkingLot children positions?
# Let's inspect ParkingLot in the file:
pl_match = re.search(r'\[node name="ParkingLot"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.DOTALL)
if pl_match:
    print("ParkingLot node:")
    print(pl_match.group(0))

wc_match = re.search(r'\[node name="welcomeCenterTextured2"[^\]]*\](.*?)(?=\n\[node|\Z)', text, re.DOTALL)
if wc_match:
    print("welcomeCenterTextured2 node:")
    print(wc_match.group(0)[:300])
