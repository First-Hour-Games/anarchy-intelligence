# Carrie's house

A 1920s American foursquare, built entirely by script into
`models/source/buildings/CarrieHouse.blend`. Don't edit the generated objects by hand: change
these files and rebuild.

| File | What it holds |
|---|---|
| `layout.py` | The design: walls with their doors and windows, which doors stand open, floors, stairs, rooms, and the gameplay objects (role, footprint, height). |
| `furniture.py` | Furniture models for those objects, extra dressing (chairs, rugs, lamps, toilet, dress form, doll), pictures, which rooms get curtains, and which pieces the player can walk through (`PASSABLE`). |
| `validate.py` | Checks the layout leaves room for the player and monsters (see below). Runs without Blender. |
| `wallpapers.py` | Draws and ages the five room wallpapers into `assets/local_licensed/carrie_house_textures/generated/`. |
| `../build_carrie_house.py` | The builder: grey-box shell, exterior and interior finishes, furniture, the dollhouse, editing aids. |

## Rebuild

Headless, which saves the .blend:

    blender --background --python tools/blender/build_carrie_house.py

In a live Blender with the .blend open (Blender MCP), then save:

    runpy.run_path("tools/blender/build_carrie_house.py", run_name="live")["build"]()

`build(stages)` takes any of `structure`, `exterior`, `interior`, `objects` and `aids`. For
example, `["structure", "objects", "aids"]` gives the flat grey-box. Remake the wallpapers
with `blender --background --python tools/blender/carrie_house/wallpapers.py`.

## How it fits together

- Game coordinates: x along the front, y up, +z out of the front door. The exterior walls'
  centre lines are x -5..5 and z -10..0. `HouseRoot` turns them into Blender's axes.
- Rooms take their finishes from `ROOM_FINISH` in the builder: wallpaper, floor, ceiling and
  wainscot. Walls and floor slabs split where rooms meet, so each face gets the finish of the
  room it faces. Unnamed space (closets, stairwells) takes the storey default.
- Furniture keeps the layout object's name (`TV`, `Radio`, `CarrieBed`, `Dollhouse`...) so the
  game can find it. Hide markers with nothing to model (`CoatCloset`, `WalkInCloset`) move to
  `CarrieHouseAids`.
- The `Dollhouse` is this house rebuilt at 1:16, with its back wall left open and its
  furniture inside, merged into one object on Carrie's play table. A tiny wrapped figure sits in
  its armchair, where the Wrapper sits in the real house when Thomas arrives.
- Which doors stand open is `door_leaves` and `exterior_doors` in `layout.py`. A door at
  0 degrees is shut and solid. For the opening chapter, only the route the story uses is open:
  - the hall, living room, dining room and kitchen;
  - both stairs, the landing and Carrie's room.

  The cellar stair and the attic ladder are left out of `stairs` until a chapter opens those.
- Textures are CC0; see `assets/local_licensed/carrie_house_textures/SOURCE.md`.

## Export to the game

    blender --background --python tools/blender/prepare_carrie_house.py

The export script rebuilds the house in memory without saving the .blend. It writes
`models/buildings/carrie_house/carrie_house.gltf`, its `.bin` and `carrie_house_markers.json`.
- The mesh is merged by collision role. `Floor_*` holds the walkable tops, named by footstep
  surface. `Structure_*` holds walls, roof and closed doors. `Decor_*` gets no collision. Each
  piece of furniture stays its own node.
- The glTF points at the textures in `assets/local_licensed/carrie_house_textures/` instead of
  copying them.
- The markers file holds furniture boxes, hiding spots, the lights that still work, doorways,
  rooms and the named story points. Its tables (`HIDING`, `SPOT_DEPTH`, `LIVE_LIGHTS`) are at the
  top of the export script.

Hiding furniture has to let the player see out. A hidden player's eye is 0.26 m up under a bed
and 0.1 m behind a wardrobe's doors (`scenes/interaction/hiding_spot.gd`). So the beds stay open
below 0.3 m, and the wardrobe's doors stand 5 cm apart (`WARDROBE_GAP`).

`scenes/environment/carrie_house.tscn` turns the export into the playable house. See "Carrie's
house" in `scenes/chapters/main/OPENING_PLAYTHROUGH.md`.

## Room for the game's bodies

The player is 0.7 m across and the monsters 0.8 m, so the open part of the house is laid out
for them rather than as a real house would be. Check it with:

    python tools/blender/carrie_house/validate.py

The export runs the same check and stops on any problem. The rules:
- **Doorways:** every open doorway is at least 1.0 m wide, with nothing that blocks in front of
  it. Navigation links carry enemies through, since doorways are narrower than the navigation
  mesh can pass.
- **Stairs:** 1.2 m of clear floor beyond both ends of the main and back stairs. That means no
  wall, no blocking furniture and no hole in the floor there. The main stair's bottom newel
  stands on its first tread, so it stays out of that space.
- **Routes:** on each floor, every open doorway and stair end connects to the others with about
  1.1 m of clearance. The enemies' navigation mesh closes any gap much narrower than that, so
  furniture keeps at least that much room between pieces.
- **Pictures:** they hang on solid wall, not across an opening.

After an export, check the house in `scenes/chapters/playground/carrie_house_test.tscn` and with
two tests:
- `tests/carrie_house_smoke.gd` checks collision, hiding spots, doors and routes;
- `tests/carrie_house_routes_smoke.gd` walks the player through every open route.
