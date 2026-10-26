class_name PropSizing extends RefCounted

## Uniformly scales an imported model so its mesh bounds reach target_height,
## then offsets it so the footprint is centered on its parent. The model rests
## on its parent's origin, or is centered on it when center_vertical is true.
## The node must already be inside the scene tree.
static func fit_height(prop: Node3D, target_height: float, center_vertical: bool = false) -> void:
	var bounds := AABB()
	var found := false
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var relative := prop.global_transform.affine_inverse() * instance.global_transform
		var mesh_bounds := relative * instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if found else mesh_bounds
		found = true
	if not found or bounds.size.y <= 0.001:
		return
	var scale_factor := target_height / bounds.size.y
	prop.scale = Vector3.ONE * scale_factor
	var anchor_y := bounds.get_center().y if center_vertical else bounds.position.y
	prop.position -= Vector3(bounds.get_center().x, anchor_y, bounds.get_center().z) * scale_factor
	prop.set_meta("target_height", target_height)
