import os
import random
from PIL import Image, ImageDraw, ImageFont

os.makedirs("img/items", exist_ok=True)
width, height = 480, 680
img = Image.new("RGBA", (width, height), (232, 226, 212, 255))
draw = ImageDraw.Draw(img)

# Paper texture noise & border
random.seed(42)
for x in range(width):
    for y in range(0, height, 4):
        noise = random.randint(-8, 8)
        c = max(0, min(255, 232 + noise))
        draw.point((x, y), fill=(c, c - 6, c - 18, 255))

# Outer vintage border
border_color = (48, 54, 46, 255)
gold_accent = (168, 138, 72, 255)
draw.rectangle([14, 14, width - 14, height - 14], outline=border_color, width=3)
draw.rectangle([20, 20, width - 20, height - 20], outline=gold_accent, width=1)
draw.rectangle([24, 24, width - 24, height - 24], outline=border_color, width=1)

# Header banner
draw.rectangle([34, 40, width - 34, 120], fill=(42, 58, 50, 255))
draw.rectangle([36, 42, width - 36, 118], outline=gold_accent, width=1)

draw.text((width // 2, 60), "CICELY", fill=(240, 235, 215, 255), anchor="mm")
draw.text((width // 2, 85), "SOUTH DAKOTA", fill=(200, 175, 110, 255), anchor="mm")
draw.text((width // 2, 103), "EST. 1894", fill=(180, 195, 185, 255), anchor="mm")

# Subhead
draw.text((width // 2, 145), "OFFICIAL VISITOR MAP", fill=border_color, anchor="mm")
draw.line([60, 160, width - 60, 160], fill=gold_accent, width=2)
draw.text((width // 2, 175), "LAKE & TIMBER DISTRICT", fill=(90, 85, 75, 255), anchor="mm")

# Map Graphic Illustration Box
map_box = [44, 200, width - 44, 490]
draw.rectangle(map_box, fill=(245, 242, 232, 255), outline=border_color, width=2)

# Grid lines inside map box
for gx in range(map_box[0] + 30, map_box[2], 40):
    draw.line([gx, map_box[1], gx, map_box[3]], fill=(215, 210, 198, 255), width=1)
for gy in range(map_box[1] + 30, map_box[3], 40):
    draw.line([map_box[0], gy, map_box[2], gy], fill=(215, 210, 198, 255), width=1)

# Winding River
river_pts = [(70, 200), (95, 240), (120, 290), (190, 340), (280, 360), (380, 380), (410, 420), (400, 490)]
for i in range(len(river_pts) - 1):
    draw.line([river_pts[i], river_pts[i+1]], fill=(120, 150, 165, 255), width=6)

# Main Roads
road_color = (130, 100, 70, 255)
draw.line([44, 310, width - 44, 310], fill=road_color, width=4)
draw.line([220, 200, 220, 490], fill=road_color, width=4)
draw.line([120, 200, 340, 490], fill=road_color, width=3)

# Compass Rose
cx, cy = map_box[2] - 50, map_box[1] + 50
draw.line([cx - 25, cy, cx + 25, cy], fill=border_color, width=2)
draw.line([cx, cy - 25, cx, cy + 25], fill=border_color, width=2)
draw.polygon([(cx, cy - 25), (cx + 5, cy), (cx, cy - 5)], fill=(180, 40, 40, 255))
draw.polygon([(cx, cy - 25), (cx - 5, cy), (cx, cy - 5)], fill=border_color)
draw.text((cx, cy - 32), "N", fill=border_color, anchor="mm")

# Small town stamps & icons
draw.rectangle([210, 300, 230, 320], fill=(180, 60, 50, 255), outline=border_color, width=1)
draw.text((220, 332), "TOWN CENTER", fill=border_color, anchor="mm")

draw.rectangle([110, 240, 126, 256], fill=(50, 90, 140, 255), outline=border_color, width=1)
draw.text((118, 266), "VISITOR CTR", fill=border_color, anchor="mm")

draw.text((width // 2, 475), "- NOT FOR RESALE -", fill=(140, 135, 125, 255), anchor="mm")

# Bottom section
draw.line([60, 520, width - 60, 520], fill=gold_accent, width=2)
draw.text((width // 2, 545), "KEEP OUR FORESTS CLEAN", fill=border_color, anchor="mm")
draw.text((width // 2, 575), "DEPARTMENT OF TOURISM & PARKS", fill=(90, 85, 75, 255), anchor="mm")
draw.text((width // 2, 600), "SOUTH DAKOTA DIVISION", fill=(120, 115, 105, 255), anchor="mm")
draw.rectangle([width // 2 - 80, 622, width // 2 + 80, 646], outline=border_color, width=1)
draw.text((width // 2, 634), "FREE COPY", fill=(160, 60, 50, 255), anchor="mm")

img.save("img/items/brochure_map_placeholder.png")
print("SUCCESS: Saved img/items/brochure_map_placeholder.png")
