extends Node3D
## The alt route's shed, dressed and lit. Everything in it is drawn on the layer the inside of its walls is
## (see tools/build_shed_meshes.gd), so the lights outside that leave the inside out leave its things out
## too, and the lamp over the bench lights only that layer: its light would otherwise come out through the
## walls, which have no thickness to stop it. The side door is drawn with the outside, since it is seen
## from both.

const INSIDE_LAYER := 1 << 11

# Before the children enter the tree, so they meet the lights already on their layer.
func _enter_tree() -> void:
	var door := get_node("ShedDoor") as Node3D
	for geometry: GeometryInstance3D in find_children("*", "GeometryInstance3D", true, false):
		if not door.is_ancestor_of(geometry):
			geometry.layers = INSIDE_LAYER
