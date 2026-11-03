# Carrie's house textures

CC0 (public domain) textures for Carrie's house, downloaded Oct 24, 2026 at 1K JPG
resolution (colour and OpenGL normal maps only):

| Folder | Asset | Source | Credits | Used for |
|---|---|---|---|---|
| `WoodSiding009` | Wood Siding 009 | https://ambientcg.com/view?id=WoodSiding009 | ambientCG | Siding |
| `stone_wall` | Stone Wall | https://polyhaven.com/a/stone_wall | Dario Barresi, Charlotte Baglioni | Foundation, cellar walls |
| `brick_wall_02` | Brick Wall 02 | https://polyhaven.com/a/brick_wall_02 | Dimitrios Savva | Chimney, porch piers, fireplace |
| `grey_roof_01` | Grey Roof 01 | https://polyhaven.com/a/grey_roof_01 | Rob Tuytel | Roof shingles |
| `wood_floor_deck` | Wood Floor Deck | https://polyhaven.com/a/wood_floor_deck | Dimitrios Savva | Porch floor and steps |
| `old_wooden_floor_02` | Old Wooden Floor 02 | https://polyhaven.com/a/old_wooden_floor_02 | Charlotte Baglioni, Jenelle van Heerden | Hardwood floors, stair treads |
| `old_linoleum_flooring_01` | Old Linoleum Flooring 01 | https://polyhaven.com/a/old_linoleum_flooring_01 | Charlotte Baglioni | Kitchen floor |
| `long_white_tiles` | Long White Tiles | https://polyhaven.com/a/long_white_tiles | Jenelle van Heerden, Sergej Majboroda | Kitchen and bath tile wainscot |
| `Tiles071` | Tiles 071 | https://ambientcg.com/view?id=Tiles071 | ambientCG | Bath hex floor |
| `painted_plaster_wall` | Painted Plaster Wall | https://polyhaven.com/a/painted_plaster_wall | Amal Kumar | Ceilings, kitchen and bath walls |
| `painted_concrete` | Painted Concrete | https://polyhaven.com/a/painted_concrete | Dario Barresi, Dimitrios Savva | Cellar floor |
| `dark_wooden_planks` | Dark Wooden Planks | https://polyhaven.com/a/dark_wooden_planks | Amal Kumar | Attic floor |
| `roof_planks` | Roof Planks | https://polyhaven.com/a/roof_planks | Rob Tuytel | Attic roof boards, cellar ceiling |
| `decrepit_wallpaper` | Decrepit Wallpaper | https://polyhaven.com/a/decrepit_wallpaper | Rob Tuytel | Sewing room walls; ageing and normal map for the generated wallpapers |

Licence: CC0 1.0 Universal (https://creativecommons.org/publicdomain/zero/1.0/). Credit
is not required, but it is listed here.

`generated/` holds the room wallpapers (ogee, floral, stripe, medallion, diamond). They are
drawn by `tools/blender/carrie_house/wallpapers.py` and aged with `decrepit_wallpaper`, so
they are this project's own work on a CC0 base. Run that script again to remake them.

`tools/blender/build_carrie_house.py` uses these as Blender sources. The exported
`models/buildings/carrie_house/carrie_house.gltf` points at these same files, so Godot imports
them from here (VRAM-compressed with mipmaps; the normal maps are imported as normal maps).
