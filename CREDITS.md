# Credits and licences

Everything in the game that someone else made, who made it, and the licence it comes under.
The in-game credits and any licence files shipped with the game should be built from this list.

The export preset ships every resource in the project (`export_filter="all_resources"`), so
assets the scenes no longer use still reach players and still need their credit, or need
removing or excluding from the export.

Status on 2026-10-25: the game has no credits screen and ships no licence texts yet, and some
assets are not cleared for release. See **Before release** at the end.

## Engine and code

| What | By | Licence | Notes |
|---|---|---|---|
| Godot Engine 4.7 | © 2014-present Godot Engine contributors; © 2007-2014 Juan Linietsky, Ariel Manzur | MIT | The licence text, and the notices of the libraries built into Godot (Jolt Physics, FreeType and others), must ship with the game. `Engine.get_license_text()` and `Engine.get_copyright_info()` return them. |
| Dialogue Manager (`addons/dialogue_manager`) | © 2022-present Nathan Hoad and Dialogue Manager contributors | MIT | Ship `addons/dialogue_manager/LICENSE`. |
| Shader Tiler (`third_party/shader-tiler`) | © 2026 Profesor Shader | MIT | Ship `third_party/shader-tiler/LICENSE`. Used for the tutorial sky. |

## Fonts

| Font | By | Licence | Used for |
|---|---|---|---|
| European Teletext Nuevo | Jayvee Enaguas (HarvettFox96) | CC0 1.0 | Menus, inventory, pickups, pause menu, dialogue |
| Jaini Purva | The Jaini Project Authors (Ek Type: Maithili Shingre, Girish Dalvi, Taresh Vohra) | SIL Open Font License 1.1: ship the licence text with the game | Tutorial, health display, inventory, viewmodel |
| Receiptional Receipt | Jayvee D. Enaguas (GrandChaos9000) | CC BY-NC-SA 3.0: **no commercial use** | Dialogue balloons |
| Kuigaf | Yumnacreative / Dhabee Studio | **Unknown**: no licence on file | Gas station signs |
| Helvetica Neue Condensed | © 1990 Adobe Systems; Helvetica is a trademark of Linotype | **Commercial font, no licence on file** | Main menu, intro, starting forest, brochure, pickup screen, downtown signs |

Each font's licence and authorship come from its own name table. `fonts/HelveticaNeueCondensed 2.ttf`
is an unused duplicate.

## 3D models: credit required

**CyberThreat Urban Props 1-3** (`assets/local_licensed/cyberthreat_urban`): 3D Model by Conor
McKenna (CyberThreat/Aphelios), https://cyberthreat.itch.io/retro-3d-style-assets-pack-1-urban-props,
CC BY 4.0. Street furniture across town and downtown.

**Hospital Assets** (`assets/local_licensed/clinic_hospital`): Atomic Realm,
https://atomicrealm.itch.io/hospital-assets. Credit required by the creator; no standalone
redistribution.

From Sketchfab, all CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). The author,
licence and link are embedded in each file.

| Model | Author | Link | In the game |
|---|---|---|---|
| Fallen Tree N.3 (Not scanned) | Danylo Tyupa | https://sketchfab.com/3d-models/fallen-tree-n3-not-scanned-3d8930670b894259af120816c851f448 | Starting forest |
| ps1 style factory building | Burnedout Visuals | https://sketchfab.com/3d-models/ps1-style-factory-building-07086221da5a4335a1f3da4d88fba0bb | Starting forest |
| (PSX) - STOP Sign | Kasugay | https://sketchfab.com/3d-models/psx-stop-sign-22b5c125cbed44cd9503be93904ab977 | Starting forest |
| Low-Poly PSX Style Wooden Interior Doors Pack | vanillao03 | https://sketchfab.com/3d-models/low-poly-psx-style-wooden-interior-doors-pack-02e442c6d4a24df29624808d058f010a | Doors |
| Trash Can | Yury Misiyuk | https://sketchfab.com/3d-models/trash-can-0ad3407cd8104ba58f71885c0e58ca9a | Gas station |
| land rover Freelander | zairiq zairiq 8 | https://sketchfab.com/3d-models/land-rover-freelander-053e35b3c3e54ff8a0d480204d331a59 | Vehicles |
| Ceiling_Lamp_LP | Vitor.GomesPT | https://sketchfab.com/3d-models/ceiling-lamp-lp-97807f860c804446a31f9beed37afa20 | Tutorial |
| Coffin | Daniyal Malik | https://sketchfab.com/3d-models/coffin-232a95f5c4be4411abc1d2f7cc28965f | Tutorial |
| Grandfather Clock | Memorie | https://sketchfab.com/3d-models/grandfather-clock-5c08d95755954e109ab63fbf997b818b | Tutorial |
| Old telephone | Termi1 | https://sketchfab.com/3d-models/old-telephone-5fec9138e8fe4f6aa023a99aa11de159 | Tutorial |
| stairs | RVECH | https://sketchfab.com/3d-models/stairs-6560ab865d0f4374916a15ab538d87fb | Tutorial |
| Table | yryabchenko | https://sketchfab.com/3d-models/table-1132fa2850a24917892733566bd68e74 | Tutorial |
| Hourglass | Inuciian | https://sketchfab.com/3d-models/hourglass-50decbf440da4921907eb852e69a46ca | Unused, still exported |
| Bush Test | Michele.Passerino | https://sketchfab.com/3d-models/bush-test-520dc8e3d01d4ddc8d97c710508f9f8b | Unused, still exported |
| Snowy Car | maregajavier | https://sketchfab.com/3d-models/snowy-car-0186dc3ce18e49b9bae235ca5767b703 | Unused, still exported |

CC BY also asks you to say if you changed a work. Where a model was re-textured or cut down
for the game, add that to its credit.

Not cleared for a commercial release: **Prison Bed** by Mihai,
https://sketchfab.com/3d-models/prison-bed-5b6a3d7a9daf4bca924b834a2cf570ed, CC BY-NC 4.0, used
in the tutorial.

## 3D models: credit optional

| Pack | By | Licence | Source |
|---|---|---|---|
| The Wrapper, The Clawman, The Ridgeback | Codyanka | CC0 | https://codyanka.itch.io/ |
| Abandoned House; Characters PSX (the Watching Bear) | Elbolilloduro | CC0 | https://elbolilloduro.itch.io/ |
| Cars Bundle; Ultimate Monsters (the Watching Yeti) | Quaternius | CC0 | https://quaternius.com/ |
| City Kit Roads, Furniture Kit, Graveyard Kit, Nature Kit, Particle Pack | Kenney (Particle Pack filter templates: Indigo Ray, Craig Nisbet, Zoltan Erdokovy, Heliagon, ThreeDee, Killst4r, Tim2501) | CC0 | https://kenney.nl/ |
| PSX Style Modular Hedges | valsekamerplant | CC0 | https://valsekamerplant.itch.io/psx-style-hedges |
| PSX Med Pack | Retro Assets Library | Game use allowed, credit optional, no standalone redistribution | https://retroassetslibrary.itch.io/psx-med-pack |

## Textures

All CC0.

- **Poly Haven** (https://polyhaven.com): asphalt_02, old_planks_02, cracked_concrete (Upper street);
  winter_leaves (Dimitrios Savva); and for Carrie's house and the downtown, stone_wall, brick_wall_02,
  grey_roof_01, wood_floor_deck, old_wooden_floor_02, old_linoleum_flooring_01, long_white_tiles,
  painted_plaster_wall, painted_concrete, dark_wooden_planks, roof_planks, decrepit_wallpaper, by
  Dimitrios Savva, Dario Barresi, Charlotte Baglioni, Rob Tuytel, Jenelle van Heerden, Sergej
  Majboroda and Amal Kumar. Identified by their file names, with no record of download yet:
  dry_mud_field_001 (`img/materials/dirtRoad`) and wood_floor_worn (`img/materials/woodFloor`).
- **ambientCG** (https://ambientcg.com): Concrete012, Concrete034, WoodSiding009 and Tiles071, all on
  record. Identified by their file names: Road013A, Road015C, Ground037, Snow009A, Tiles012,
  Wallpaper001C, Wallpaper002C, Metal009, Wood035, Bark014, Concrete047A, Rocks025, Plastic013B,
  Tiles141.

The downtown's limestone and painted and buff brick are this project's own work, drawn over
Concrete012 and brick_wall_02. See `models/buildings/downtown/textures/SOURCE.md`.

## Sound

- **Freesound**, CC0, credited voluntarily: *Ghost Monster Scream* by NachtmahrTV, *monster sound
  2.wav* by ZyryTSounds, *growl 2* by balloonhead (death scares).
- **Kenney**, Impact Sounds, CC0 (bottles and hiding-spot doors).

## Original work for this game

The downtown and its generated textures, Carrie's house and its wallpapers, the Corrupted Friend,
and the Blender and Godot tooling in `tools/` were made for this game.

## Before release

**Licences that don't fit a commercial release.** Replace these if the game will be sold or
monetised:

- Receiptional Receipt (CC BY-NC-SA 3.0)
- Prison Bed (CC BY-NC 4.0)

**Licences not on file:**

- Helvetica Neue Condensed is a commercial font. Unless a licence covering embedding in a game has
  been bought, replace it.
- Kuigaf: find where it came from and what its licence allows.

**Placeholder:** Carrie's voice (`sounds/chapters/main/carrie_voice_placeholder.wav`) is Windows
text-to-speech; record a real line.

**Not traced.** For each of these, find the source and licence, then credit it here:

- **Asset packs:** `6twelve`, `house`, `exploration_objects`, `alone_in_the_dusk`,
  `retro_tree_pack`, `trees_v1`, `buildings_pack` (no longer on the map, but still exported).
- **Models:** `models/foliage` (grass), `models/props/gasStation`, `models/trees/DeadTreePack.fbx`,
  `models/interior` (Door2, Roman_Baseboard).
- **Images:**
  - `img/materials/asphalt/CleanAsphalt_*`
  - `img/materials/dirtRoad/RoadsDirt0056_1_350.jpg`: its name follows Textures.com.
  - `img/materials/tutorial/cooperflooring3-300x300.jpg` and `floralwallpaper`
  - `img/textures/road_dirt_road_0027_01_s.jpg`
  - `img/characters`, `img/player`, `img/static`, `img/menu`, `img/pictures`, `img/sky`,
    `img/sprites`, `img/ui`
- **Sounds:** these carry their makers' names in their tags, with no recorded source:
  - `doorBang.mp3`: Alexander Kopeikin
  - `lockedDoor.mp3`: Badlands Sound
  - `suvEngineLoop.mp3`: Soundholder
  - `oldPhoneRinging.mp3`: Ryan Wassil
  - grass footsteps: Fuse Hive
  - gravel footsteps: Andrew Ros Sounds
  - `ui/move.mp3`: Rogue Waves

  Untagged: the concrete, dirt, tile and wood footsteps, `sounds/ambience`, `sounds/player`,
  `sounds/dialogue` and `sounds/ui`.
- **Music:** `dreamStairs.mp3`, `theVisitor.mp3`, `welcomingHike.mp3`, `intro1.wav`,
  `menu.wav`, `tutorial.ogg`.
