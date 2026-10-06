extends Node3D


func _ready() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh and mesh.find_children("*", "CollisionShape3D", true, false).is_empty():
			mesh.create_trimesh_collision()
