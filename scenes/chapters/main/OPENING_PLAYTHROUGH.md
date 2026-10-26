# Opening playthrough

Start from the main menu to play the existing intro followed by this chapter, or
run `scenes/chapters/main/map.tscn` to review it directly. Thomas starts
outside the supplied welcome center, carrying its tourist map. The opening uses
subtitle narration; new story lines have no recorded voice audio yet.

Escape > Main Menu returns to the menu. Continue Game resumes the saved chapter
directly; it does not replay the intro. New playthroughs still use the intro.

1. Follow the map to the gas station and examine the flashlight.
2. Follow the west road to Carrie's house at its end. "It's already inside":
   - A note pinned beside the open front door says her notebook is upstairs, on her desk.
   - Through the opening into the living room, the Wrapper sits in an armchair facing the dead
     TV. Once Thomas has seen it there, it moves whenever he isn't looking, so reaching the stairs
     means turning his back on it.
   - Upstairs, Carrie's voice calls him into her room, which is empty. The voice is a
     text-to-speech placeholder for now (`sounds/chapters/main/SOURCE.md`).
   - Her notebook says she left for the hospital because people said it was safe. The last page
	 warns: "If you hear me calling, it isn't me."
   - When he comes out, the Wrapper is waiting at the foot of the main stair. He takes the back
     stair down through the kitchen and out the back door, or hides until it drifts back to its
     chair.
3. Reach the hospital entrance. Search the reception registration book.
4. Search staff records for the evacuation notice. These two hospital clues can be
   read in either order. The notice confirms Carrie escaped and links the mysterious
   voices to the failed refuge. The next destination remains a later story decision.

The hospital replaces the clinic in the main map. Only the ground floor is playable.
Original Blender files are preserved under `models/source/buildings/`, which Godot
ignores; exported GLBs live under `models/buildings/`.

The hospital's furnished ground floor is modelled in Blender, in `Hospital_V2.blend`:
- `tools/blender/build_hospital_interior.py` builds it from the layout data in
  `tools/blender/hospital_layout/`.
- The equipment comes from `tools/blender/hospital_dressing/`.
- `tools/blender/prepare_story_hospital.py` re-exports `models/buildings/hospital/hospital.glb`
  and `hospital_markers.json`. Run it with Blender's background Python runner.
- `tools/blender/inspect_story_buildings.py` re-exports the welcome center and finishes by
  running the hospital export.
- `scenes/environment/story_building.gd` reads the markers file. It places the hiding spots,
  bottles, medical-pack props (with box collision when they stand on the floor) and lights.
  The story reads the three hospital documents' positions from the same file.

Check layout or equipment changes with `tools/blender/hospital_layout/validate.py` before
exporting. The navigation mesh rebuilds itself when the geometry changes.

## Carrie's house

Carrie's house (`Buildings/ResidentialLots/CarrieHouse`) is a 1920s foursquare with a
cellar, two floors and an attic, built by script in `CarrieHouse.blend`. See
`tools/blender/carrie_house/README.md` for the model.
- **Open for this chapter:** the hall, living room, dining room and kitchen, both stairs, the
  landing and Carrie's room.
- **Shut for this chapter:** the parents' room, bathroom, boarded sewing room, cellar and attic.
- **Sized for the game's bodies.** The player is 0.7 m across and the monsters 0.8 m:
  - open doorways are at least 1.0 m wide;
  - there is 1.2 m of clear floor at both ends of each stair;
  - nothing stands in front of a door or a stair.

  `tools/blender/carrie_house/validate.py` checks this, and the export stops on any problem.
- `tools/blender/prepare_carrie_house.py` exports `models/buildings/carrie_house/carrie_house.gltf`
  and `carrie_house_markers.json`. The glTF uses the textures in
  `assets/local_licensed/carrie_house_textures/` in place, rather than copies.
- `scenes/environment/carrie_house.gd` makes it playable:
  - Floors and structure get collision. Floors carry their footstep surface: wood, tile in the
    kitchen and bath, concrete in the cellar.
  - Furniture gets box collision.
  - Carrie's bed, her wardrobe, the coat closet and the walk-in closet become hiding spots
	(`HidingSpot.builtin_model` off).
	- From under the bed and through the gap in the wardrobe doors, the hidden player sees the
	  room and can hold the Wrapper by watching it, as in the hospital.
	- The coat closet and the walk-in closet are blind: their doors stay shut.
  - The power is out. Only the porch light, a flickering bulb in Carrie's room and a dying one in
	the kitchen work.
- The house opens the map's ground over its cellar. It splits the `GroundCollision` box and
  sets `cutout_rect` on the ground shader.
- Navigation and enemy routes:
  - Navigation links cross every open doorway, since doors are narrower than the navmesh can pass.
  - Enemies take route gates through the front door and up and down the main stair.
- The story asks the house for named places (`point()` and `local_point()`):
  - the door note, the notebook, the porch checkpoint and the front-door objective;
  - the Wrapper's armchair and where it stands in front of it;
  - the foot of the main stair, where it waits after the notebook;
  - the middle of Carrie's room, where her voice calls from.
- `scenes/monsters/seated_pose.gd` bends the Wrapper's legs to sit it in the chair. It only
  moves while unwatched, so nobody sees it get up.
- `scenes/chapters/playground/carrie_house_test.tscn` sets the house on its own ground for
  walking around it. Two tests use it:
  - `tests/carrie_house_smoke.gd` checks the house there;
  - `tests/carrie_house_routes_smoke.gd` walks the player along every open route.
- To work on one part of the chapter without playing up to it, select the map's `OpeningStory`
  node and set **Editor Start** in the Inspector, then press F6 (Run Current Scene):
  - **Fresh start:** no progress, at the welcome center.
  - **Carrie's house:** on the porch with the flashlight, at the notebook step.
  - **Hospital:** inside the entrance.

  It only works in runs started with the editor's play buttons; exported games, tests and tools
  that load the map ignore it. Such a run ignores the save and never writes it, and a corner label
  says so. Set it back to **Saved progress** before committing; `tests/editor_start_smoke.gd`
  covers it.
- During a run, press backtick (`) and choose **Carrie's house** to replay the house the same way.
  - Thomas starts on the porch with the flashlight.
  - The story goes back to finding the notebook, with the house's lines unsaid and the Wrapper
	back in its chair, so the house plays again.
  - Saving stops for that session, so the jump never sets real progress back.

## Encounters

- Ridgeback: appears farther along the route after collecting the flashlight.
  It follows throughout town, including around corners, and turns toward its movement.
  Its beam and nearby working lights make it retreat toward darker ground.
- Wrapper: sits in Carrie's living-room armchair until Thomas has seen it there, or goes
  upstairs without looking.
  - It then advances whenever it is outside his view, and watching it stops its advance.
  - After the notebook it waits at the foot of the main stair, and from then on it can follow
	throughout town.
  - A player who hides is lost to it, and it drifts back to its post.
- Clawman: hears uncrouched movement within 12 meters and sees players within
  7 meters. Crouching reduces noise; partitions break sight. It remembers a detected
  position briefly and remains in the hospital territory.

Clawman counterplay (hospital):

- **Hiding spots:** five staff lockers (three in staff records, two in linen and
  changing), a supply closet in procedure room 1, and two ward beds. Press E to climb in and E
  to leave. While hidden the player can look around a little, toggle the
  flashlight (F) and recover stamina, but cannot move, throw, or open the
  inventory. A hidden player is invisible and silent to the Clawman, unless it
  could see the player at the moment they climbed in (within 7 m, or 10 m while
  it is already hunting). Then it walks to a point 1.25 m beyond the spot's exit,
  pulls the player out, and the grab deals 35 damage. A Clawman that only heard
  the player still walks to where it last heard them, sniffs around, and then
  returns to its post, so waiting it out is safe. The Wrapper can still be held
  in place by watching it through the vents or the door gap.
- **Bottles:** five empty bottles lie around the ground floor (stores shelf, office
  desk, linen shelf, nurse counter, lounge counter); carry up to three.
  A bottle is only offered when the player can see it and has room for it.
  G (Input Map action `throw_item`), or USE in the inventory, throws one. It
  shatters on first impact. A Clawman within 16 m of the impact, with the impact
  within 28 m of its post (territory plus 6 m), goes to investigate for 7 seconds,
  even if the thrower stands outside its territory. Glass that breaks while a
  note is open is remembered and investigated once the note closes. Being seen
  or heard afterwards re-targets it on the player, so the lure only works if the
  player stays quiet. A Clawman tracking a hidden player ignores bottles.
- The Clawman's post is in the east corridor, in front of the moonlit end window.
  Between the close-set ward beds, its pull-out point moves in from 1.25 m toward
  0.8 m beyond the exit, until it lands on the navigation mesh.
- The cot dormitory and the medical stores sit beyond its territory, behind the narrow
  aisle between the cot rows. Navigation does not cross that aisle, so those rooms stay
  calm.
- For quick testing in debug builds, press backtick (`) and choose **Hospital
  entrance**. It loads `map.tscn` if needed (keeping saved progress), places
  the player in the lobby facing toward the corridor, and gives the flashlight
  if missing. That spot is inside the hospital trigger, so the story
  immediately advances to the hospital stage (and saves, as in normal play),
  which activates the Clawman.
- The medical stores log explains both rules. The locker, closet and ward bed come
  from `tools/blender/build_hospital_hiding_props.py`; impact sounds are Kenney CC0
  (`sounds/props/impacts/SOURCE.md`). `tests/hiding_and_distraction_smoke.gd`
  covers the rules in isolation; `tests/hospital_hiding_map_smoke.gd` checks
  placement, clear exits, navigation reachability, and both behaviors in the
  real map.

Clawman uses the model's idle, chase, alert and attack animations. It stays active
while exploring the hospital after reading the clues. Both new encounters can damage the player at
close range. Reading documents freezes player movement and suspends these enemies.
The existing extra Ridgebacks and friend prototype are disabled for this opening.

## Controls and progress

E opens the full field inventory; R examines; M opens the map; J opens collected
notes and the objective; F toggles the owned flashlight directly; Ctrl crouches;
G throws a carried bottle.
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
after Continue, Wrapper entering Carrie's house, and prop support heights.
Navigation parses ground, road and building collision geometry in one map coordinate frame;
doorway links join the brick house's entrance and Carrie's open doorways. Enemies advance waypoints horizontally while
physics handles floor height. Civic props settle onto their supporting surface;
AC units and their pads are removed. Hospital cabinets stack, shelves have uprights, and bottles
and clue books rest on their shelves and desks. Ground vertex displacement is
disabled to match the flat collider; texture and normal-map detail remain.

All three chapter enemies share `scenes/shared/entity_route.gd`. Building routes (the brick
house and Carrie's house) use front-door approaches and stair transitions. Enemies
retain those transitions while crossing them, then update the route to the player's
new position. The route retries after stalled progress. Floor projection queries
above foot height to avoid selecting a lower stair fragment at a landing.
Step climbing accepts supported capsule-edge contacts and cancels accumulated
fall velocity after climbing a tread. `tests/entity_building_routes_smoke.gd`
checks the Wrapper following a player deep into Carrie's house, and finding its own way from
the hall up the main stair to her bedroom.
Navigation uses 0.2 m horizontal cells, 0.125 m vertical cells, and the enemies'
0.4 m capsule radius. Gaps much under 1.2 m vanish from the navigation mesh, so the house
keeps that much room between furniture, and links cross its narrower doorways. Geometry and bake
settings determine the cached navmesh signature; changes invalidate the cache
automatically. The cache is `user://town_navigation_v4.res` and does not affect
story progress.
