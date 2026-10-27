# Neighborhood lots

Each GLB contains one complete lot from `scenes/chapters/main/hood.Final.glb`,
including its house, garage, yard/lawn, fences, site, and mailbox details.
Materials and component mesh names are preserved. Roads, shared backdrop ground,
and standalone source props are excluded.

Godot applies textures through `tools/import/hoodfinal_textures.gd`, adapted from
the supplied `hoodfinalTEXTURES.gd`. All twelve `.glb.import` files and the full
neighborhood's import settings reference it. The importer uses triplanar mapping,
the supplied material-prefix rules and tile sizes, and preserves authored tints.
It reuses matching project textures as fallbacks. Add a custom map set under
`res://textures/<folder>/` to override a fallback, then reimport the affected GLBs.
Folder names and the fallback paths are listed in the import script.

These texture assignments are Godot import settings, not images embedded into
the GLB binaries. Keep the `.import` settings, importer, and referenced texture
assets together when moving these lots to another Godot project.

The importer also places a warm OmniLight at every modeled `Lamp_Glow` bulb on
the porch and garage. These use `scenes/environment/house_exterior_light.tscn`:
energy 2, range 7 m, attenuation 2, shadows, and subtle fog illumination. Lights
fade over 45-60 m and shadows fade over 25-40 m. They inherit each lot's position
and rotation and unload with its geometry. Edit the shared light scene and
reimport the GLBs to update every lot; enable Editable Children on a placed lot
to adjust an individual light's native Inspector properties.

Drag a GLB into a Godot 3D scene to place it independently. Each lot uses its
authored curb-center origin at ground level. The original neighborhood offset
and rotation are removed so every lot starts in the same orientation, with the
yard extending along local negative Z. Child transforms and geometry retain
their original dimensions and alignment.

The import pass adds native StaticBody3D bodies with BoxShape3D collision for
the closed house and garage shells, foundations, porch steps, fence runs, and
walkable lawn ground. Fences are merged into runs while preserving entrances;
the lawn uses a few rotated slabs following its street-to-backyard slope to
within approximately 1 cm. The models represent closed exterior buildings, so
the house and garage shells are solid. Roof trim, individual fence boards,
lamps, gutters, and mailbox numbers do not create extra collision shapes.
Collision is generated once at import, follows lot placement, and unloads with
the lot. The same rules apply to the original full-neighborhood GLB.

The original GLB and existing neighborhood scenes remain unchanged.

To regenerate all 12 assets from the source, run from the repository root:

```powershell
python tools/export_neighborhood_lots.py
```
