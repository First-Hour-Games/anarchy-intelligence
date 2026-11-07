Drag `power_line_array.tscn` into a level and select its root node.

- **Pole Count** changes the number of poles, including zero to clear the row.
- **Spacing** sets the distance between bases in meters.
- **Variant** repeats one of the nine poles, or cycles through all nine.
- **Pole Scale** changes pole size without changing spacing.
- **Pole Rotation Degrees** turns each pole without turning the row.

The row extends along local +X from the node's origin. Move and rotate the
PowerLineArray node to position and aim the entire row. Inspector changes preview
automatically in the editor and the same layout is generated during gameplay.
Generated previews are not saved as extra scene nodes. These are visual poles;
the source pack has no connecting wires or collision geometry.

Individual `power_line_01.glb` through `power_line_09.glb` assets can also be placed
separately. Their pivots sit at the pole base. Regenerate them after changing the
original pack with `python tools/extract_power_line_variants.py`.
