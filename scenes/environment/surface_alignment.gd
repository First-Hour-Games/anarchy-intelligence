extends RefCounted

static func world_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	var meshes: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for child: Node in meshes:
		var mesh := child as MeshInstance3D
		if not mesh.is_visible_in_tree():
			continue
		var part := mesh.global_transform * mesh.get_aabb()
		bounds = part if first else bounds.merge(part)
		first = false
	return bounds

static func settle(node: Node3D, max_drop: float = 2.0) -> bool:
	var bounds := world_bounds(node)
	if bounds.size.is_zero_approx():
		return false
	var foot := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	var ray := PhysicsRayQueryParameters3D.create(foot + Vector3.UP * 0.15, foot - Vector3.UP * max_drop)
	var exclusions: Array[RID] = []
	for child: Node in node.find_children("*", "CollisionObject3D", true, false):
		exclusions.append((child as CollisionObject3D).get_rid())
	if node is CollisionObject3D:
		exclusions.append((node as CollisionObject3D).get_rid())
	ray.exclude = exclusions
	var hit := node.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		return false
	node.global_position.y += (hit.position as Vector3).y - foot.y
	return true
