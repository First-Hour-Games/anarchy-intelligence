@tool
extends Node
## Applies reflective sheeting to one imported mesh surface, preserving the GLB.

@export_node_path("MeshInstance3D") var mesh_path: NodePath
@export_range(0, 32) var surface_index := 0
@export var sign_material: ShaderMaterial:
	set(value):
		sign_material = value
		if is_node_ready():
			_apply_material()


func _ready() -> void:
	_apply_material()


func _apply_material() -> void:
	var mesh_instance := get_node_or_null(mesh_path) as MeshInstance3D
	if mesh_instance == null or mesh_instance.mesh == null or sign_material == null:
		return
	if surface_index < mesh_instance.mesh.get_surface_count():
		mesh_instance.set_surface_override_material(surface_index, sign_material)
