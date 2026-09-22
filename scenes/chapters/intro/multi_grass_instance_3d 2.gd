extends MultiMeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var rotation_angle = deg_to_rad(90.0)
	var rotated_basis = Basis().rotated(Vector3.UP, rotation_angle)

	for i in range(multimesh.instance_count):
		var current_transform = multimesh.get_instance_transform(i)
		var new_transform = Transform3D(rotated_basis, current_transform.origin)

		multimesh.set_instance_transform(i, new_transform)




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:

	pass
