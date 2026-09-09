@tool
extends Node3D

## Hides broad set-dressing meshes from imported environment packs while keeping
## the useful building and prop meshes intact.
@export var hidden_child_names: PackedStringArray = []:
	set(value):
		hidden_child_names = value
		if is_inside_tree():
			call_deferred("_apply_visibility")


func _ready() -> void:
	_apply_visibility()


func _apply_visibility() -> void:
	for child_name in hidden_child_names:
		var child := get_node_or_null(NodePath(child_name)) as Node3D
		if child:
			child.visible = false
