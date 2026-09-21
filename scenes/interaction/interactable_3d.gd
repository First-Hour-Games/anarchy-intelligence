class_name Interactable3D extends Node3D

signal interacted(interactor: Node3D)

@export_range(0.5, 10.0, 0.1) var interaction_distance: float = 3.0
@export var visual_target_path: NodePath = NodePath("..")
@export_multiline var interaction_message: String = "Interacted with an object."


func _ready() -> void:
	add_to_group(&"interactable")


func can_interact(interactor: Node3D) -> bool:
	return interactor.global_position.distance_to(get_prompt_world_position()) <= interaction_distance


func interact(interactor: Node3D) -> void:
	interacted.emit(interactor)
	print(interaction_message)


func get_prompt_world_position() -> Vector3:
	var visual_target := get_node_or_null(visual_target_path) as Node3D
	if not is_instance_valid(visual_target):
		return global_position

	var mesh_instances: Array[MeshInstance3D] = []
	if visual_target is MeshInstance3D:
		mesh_instances.append(visual_target as MeshInstance3D)
	for child in visual_target.find_children("*", "MeshInstance3D", true, false):
		mesh_instances.append(child as MeshInstance3D)

	var has_bounds := false
	var bounds_min := Vector3.ZERO
	var bounds_max := Vector3.ZERO
	for mesh_instance in mesh_instances:
		if not is_instance_valid(mesh_instance) or mesh_instance.mesh == null:
			continue
		var aabb := mesh_instance.get_aabb()
		for x_index in 2:
			for y_index in 2:
				for z_index in 2:
					var corner := aabb.position + Vector3(
						aabb.size.x * x_index,
						aabb.size.y * y_index,
						aabb.size.z * z_index
					)
					var world_corner := mesh_instance.global_transform * corner
					if not has_bounds:
						bounds_min = world_corner
						bounds_max = world_corner
						has_bounds = true
					else:
						bounds_min = Vector3(
							minf(bounds_min.x, world_corner.x),
							minf(bounds_min.y, world_corner.y),
							minf(bounds_min.z, world_corner.z)
						)
						bounds_max = Vector3(
							maxf(bounds_max.x, world_corner.x),
							maxf(bounds_max.y, world_corner.y),
							maxf(bounds_max.z, world_corner.z)
						)

	return (bounds_min + bounds_max) * 0.5 if has_bounds else visual_target.global_position
