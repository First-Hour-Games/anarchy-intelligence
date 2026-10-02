# Opening playthrough

Start from the main menu to play the existing intro followed by this chapter, or
run `scenes/chapters/main/map.tscn` to review it directly. Thomas starts
outside the supplied welcome center, carrying its tourist map. The opening uses
subtitle narration; new story lines have no recorded voice audio yet.

Escape > Main Menu returns to the menu. Continue Game resumes the saved chapter
directly; it does not replay the intro. New playthroughs still use the intro.

1. Follow the map to the gas station and examine the flashlight.
2. Follow the west road to Carrie's corner house. Examine her notebook just inside
   the open doorway. Carrie has left for the hospital because people said it was safe.
3. Reach the hospital entrance. Search the reception registration book.
4. Search staff records for the evacuation notice. These two hospital clues can be
   read in either order. The notice confirms Carrie escaped and links the mysterious
   voices to the failed refuge. The next destination remains a later story decision.

The hospital replaces the clinic in the main map, reusing its floor shader,
medical equipment, beds, cabinets, supplies and chairs. Only the ground floor is
playable. Original Blender files are preserved under `models/source/buildings/`,
which Godot ignores; exported GLBs live under `models/buildings/`. Rebuild both
exports with Blender's background Python runner and
`tools/blender/inspect_story_buildings.py`. The hospital export clips a ground-floor
entrance and internal exterior surfaces; the Godot scene supplies the furnished rooms.

## Encounters

- Ridgeback: appears farther along the route after collecting the flashlight.
  It follows throughout town, including around corners, and turns toward its movement.
  Its beam and nearby working lights make it retreat toward darker ground.
- Wrapper: advances when it is outside the player's view near Carrie's house.
  Watching it stops its advance. It can follow throughout town and now
  moves slightly faster.
- Clawman: hears uncrouched movement within 12 meters and sees players within
  7 meters. Crouching reduces noise; partitions break sight. It remembers a detected
  position briefly and remains in the hospital territory.

Clawman uses the model's idle, chase, alert and attack animations. It stays active
while exploring the hospital after reading the clues. Both new encounters can damage the player at
close range. Reading documents freezes player movement and suspends these enemies.
The existing extra Ridgebacks and friend prototype are disabled for this opening.

## Controls and progress

E opens the full field inventory; R examines; M opens the map; J opens collected
notes and the objective; F toggles the owned flashlight directly; Ctrl crouches.
Scroll-wheel and numbered-slot equipment switching are removed. Inventory pauses
the world; E or Esc closes it. Close documents with their button, J or Esc.
Interaction and journal keys use Input Map actions.

Stamina capacity is doubled to 200, with an unlabeled meter. Footsteps use the original
recordings again. Escape pauses gameplay with Resume, Main Menu, Quit and saved
Master, Music, Effects and Footsteps volume sliders. Subtitle narration still has no
recorded voice. Objectives use a compact
brass pin and short text. The hospital has a continuous interior shell and props
scaled by measured height, including 22 cm medicine bottles.

Progress and the flashlight save automatically at major discoveries. Getting caught
uses the latest checkpoint without discarding clues. Reopening the chapter resumes
the saved progress. Use **J → Restart opening chapter** to replay from the beginning.
The save is `user://opening_story_v1.json`, separate from other game data.

## Validation

`tests/opening_story_smoke.gd` exercises progression, clue ordering, reading safety,
checkpoints, doorway collision, notebook interaction, hospital navigation and cover,
and both new enemy rules. It disables persistence and does not alter the player's save.
`tests/opening_story_preview.gd` captures four engine-rendered review views with
editor lighting and the inventory; the CRT is hidden for inspection. Ordinary
gameplay retains the CRT. `tests/gameplay_refinement_smoke.gd` checks inventory,
stamina, surface selection, hospital furnishings, Clawman clips and light repulsion.
`tests/menu_entry_alignment_smoke.gd` verifies returning to the menu and moving
after Continue, Wrapper entering the corner house, and prop support heights.
Navigation parses ground, road and building collision geometry in one map coordinate frame; doorway links
join the brick houses' entrances. Enemies advance waypoints horizontally while
physics handles floor height. Civic props settle onto their supporting surface;
AC units and their pads are removed. Hospital cabinets stack, shelves have uprights, and bottles
and clue books rest on their shelves and desks. Ground vertex displacement is
disabled to match the flat collider; texture and normal-map detail remain.

All three chapter enemies share `scenes/shared/entity_route.gd`. Brick-house routes
use front-door approaches and a main-stair transition with landing turns. Enemies
retain those transitions while crossing them, then update the route to the player's
new position. The route retries after stalled progress. Floor projection queries
above foot height to avoid selecting a lower stair fragment at a landing.
Step climbing accepts supported capsule-edge contacts and cancels accumulated
fall velocity after climbing a tread. `tests/entity_building_routes_smoke.gd`
checks a player deep inside the house, the actual stairs and the upper floor.
Navigation uses 0.2 m horizontal cells, 0.125 m vertical cells, and the enemies'
0.4 m capsule radius so the upstairs hallway stays connected. Geometry and bake
settings determine the cached navmesh signature; changes invalidate the cache
automatically. The cache is `user://town_navigation_v4.res` and does not affect
story progress.
