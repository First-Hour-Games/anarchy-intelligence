# Downtown Cicely

The street beside the hospital: eleven buildings facing each other across the Crossroad, east of
the Connector road, built entirely by script into `models/source/buildings/Downtown.blend` and
exported to `models/buildings/downtown/downtown.gltf`. Don't edit the generated objects by hand:
change these files and rebuild.

| File | What it holds |
|---|---|
| `plan.py` | The layout, in the map's own coordinates: each row's buildings, alleys and lots with their sizes, walls, signs and awnings; the sidewalks; the street furniture; the signal; the cars at the curbs. Sign words live here. |
| `validate.py` | Checks the plan leaves room for the player and monsters (see below). Runs without Blender. |
| `textures.py` | Paints the generated textures into `models/buildings/downtown/textures/`: the rooms seen through the windows, what hangs behind the glass, the flat-colour palette, awning stripes, limestone, painted and buff brick. |
| `../build_downtown.py` | The builder: the building types, sidewalks and curbs, meters, newspaper boxes, tree grates, lot fences and the signal. |
| `../prepare_downtown.py` | The export: the .gltf and `downtown_markers.json`. |
| `../../import/downtown_post_import.gd` | Runs when Godot imports the .gltf and adds collision, occluders, lettering, lights, the window shader and draw distances. |

## Rebuild

    python -I tools/blender/downtown/validate.py
    blender --background --python tools/blender/prepare_downtown.py
    godot --headless --path . --import

The export rebuilds the downtown from scratch, so it doesn't need the .blend saved first. To see
it in a live Blender (Blender MCP), open `Downtown.blend` and run
`runpy.run_path("tools/blender/build_downtown.py", run_name="live")["build"]()`. Remake the
textures with `blender --background --python tools/blender/downtown/textures.py`.

## The building types

- **Main Street shop** (`shop`): two storeys, one or two shopfronts with recessed doors, sign
  boards and striped awnings. Hardware, Variety, Bakery and Barber.
- **Apartments over shops** (`apartments`): three or four storeys over two shops and the
  apartment entry, a fire escape across two bays, a roof hut, and a water tank on The Alder.
- **Corner bank** (`bank`): limestone, a cut corner on the intersection with the door and a
  lit clock, arched fanlights over the tall ground-floor windows, a second front along the
  Connector road.
- **Cinema** (`cinema`): a stepped parapet, a vertical neon AURORA sign, a lit marquee with a
  letter board, poster cases and a ticket booth.
- **Hotel** (`hotel`): five storeys, roof letters on a steel frame with one dead letter, an
  entrance canopy and a painted ghost sign over the corner lot.
- **Civic building** (`civic`): the post office (limestone, steps, lanterns, a roof flag) and
  the police station (buff brick, canopy, blue lamps, a flag on an angled pole).
- **Diner** (`diner`): one storey of enamel and chrome, lit windows, a roof sign with a star,
  and a neon EAT sign at its lot.

## How it fits together

- Coordinates are the map's: x east, y up, z south. `DowntownRoot` turns them into Blender's
  axes. Each building is authored in its own frame (u along the front from its left end as seen
  from the street, y up, d back from the front); `Frame` maps that to the map.
- Each building exports as `<Id>` (walls, trim, shopfronts), `<Id>_Glass` (every pane) and
  `<Id>_Details` (brackets, fire escapes, tanks, sign frames). Godot stops drawing the details
  past 90 m. Every building uses the same few materials: its wall finish, `Paint` (flat colours
  from one palette texture), `Glow` (the palette, lit), `Fabric` for awnings, and the glass.
- Windows are panes with a room behind them, drawn by `shaders/window_interior.gdshader`. The
  pane's second UV carries which room, what hangs behind the glass (curtains, blinds, boards,
  whitewash) and the sash pattern, picked per window from the weighted lists in the builder.
  Lit rooms glow at night.
- Lettering is not modelled: the markers carry each sign's words, place, size and style
  (painted, carved, raised, neon, marquee, ghost) and the import adds them as Label3D in the
  project's condensed face. Neon signs flicker with their lights (`neon_lettering.gd`). The
  traffic signal's lenses flash (`blinking_signal.gd`).
- Collision is boxes from the markers: one per building (the bank's cut corner gets a turned
  one), the post office steps, the cinema's ticket booth, poles, meters, fences, and the
  sidewalks at the road's height so every body steps up them as it steps onto a road. One box
  occluder per building lets the street wall hide what stands behind it; occlusion culling is on
  in the project settings.
- `scenes/environment/civic_finishing.gd` places the street furniture listed in the markers
  (lamps, benches, bins, mailbox, phone boxes, hydrants, signs, dumpsters, trees, dead cars).
  The neighborhood decorator keeps the corner house's lot dressing out of the downtown, and the
  Crossroad's north sidewalk east of the Connector road is the downtown's, not
  `remaining_street_connections.gd`'s.

## Room for the game's bodies

`validate.py` holds the plan to the game's sizes (the player's capsule has a 0.35 m radius,
monsters 0.4 m, and the navigation mesh needs about 1.2 m to pass):

- each row runs west to east without overlaps, inside its band between the streets, and clear of
  the hospital and the corner house;
- alleys are at least 3 m wide, and the south alleys keep the walk lines at x 139, 169 and 201
  a capsule's width clear on both sides;
- sidewalks are at least 4 m wide; furniture stands in the strip by the curb, out of the clear
  walk, off the lot entrances and apart from each other; the hospital's path stays clear.

`tests/downtown_smoke.gd` checks the result in the map: the buildings are solid, glazed,
lettered and occluding, the walks, alleys, lane and hospital path are clear and on the
navigation mesh, and the street stays within its drawing budget.

## Textures

The brick of Carrie's house (Poly Haven, CC0) is used as it is for the red, brown and dark
brick, and repainted for the cream and buff. Limestone is drawn over ambientCG's Concrete012,
the sidewalks use the map's Concrete034 and the alleys and lots the map's asphalt. Everything
in `models/buildings/downtown/textures/` is generated by `textures.py`; see `SOURCE.md` there.
