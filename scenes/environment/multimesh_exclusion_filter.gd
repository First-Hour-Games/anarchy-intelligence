@tool
extends MultiMeshInstance3D
class_name MultiMeshExclusionFilter

## Automatically deletes MultiMesh instances that fall inside specified building bounds or exclusion zones.

@export_group("Exclusion Zones")
## Nodes whose bounding boxes (AABBs) will be used to exclude foliage (e.g. Visitor Center, houses, roads).
@export var exclusion_nodes: Array[NodePath] = []

## Additional manual bounding boxes (in global coordinates) to exclude instances from.
@export var manual_exclusion_boxes: Array[AABB] = []

## Extra padding/margin around the exclusion bounds (in meters).
@export var margin: float = 0.2

## If true, automatically prunes instances when entering the scene tree at game start.
@export var auto_prune_on_ready: bool = true

@export_group("Editor Actions")
## Click this checkbox in the Godot Inspector to trigger pruning immediately in the editor.
@export var click_to_prune_now: bool = false:
	set(val):
		if val:
			var removed := prune_instances()
			print("[MultiMeshExclusionFilter] Pruned ", removed, " instances from ", name)


func _ready() -> void:
	if not Engine.is_editor_hint() and auto_prune_on_ready:
		prune_instances()


## Collects all active exclusion AABBs in global coordinates.
func get_exclusion_aabbs() -> Array[AABB]:
	var aabbs: Array[AABB] = []

	for box in manual_exclusion_boxes:
		aabbs.append(box)

	for node_path in exclusion_nodes:
		var target := get_node_or_null(node_path) as Node3D
		if target:
			var box := _calculate_node_aabb(target)
			if box.size.length_squared() > 0.01:
				aabbs.append(box)

	# Also check any nodes in the scene tagged with group "building_exclusion"
	var group_nodes := get_tree().get_nodes_in_group(&"building_exclusion")
	for gnode in group_nodes:
		if gnode is Node3D and not exclusion_nodes.has(get_path_to(gnode)):
			var box := _calculate_node_aabb(gnode as Node3D)
			if box.size.length_squared() > 0.01:
				aabbs.append(box)

	return aabbs


## Prunes all instances falling inside any exclusion AABB. Returns number of removed instances.
func prune_instances() -> int:
	var mm := multimesh
	if not mm or mm.instance_count == 0:
		return 0

	var aabbs := get_exclusion_aabbs()
	if aabbs.is_empty():
		return 0

	var buf: PackedFloat32Array = mm.buffer
	if buf.is_empty():
		return 0

	var is_3d := (mm.transform_format == MultiMesh.TRANSFORM_3D)
	var stride := 12 if is_3d else 8
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4

	var count := mm.instance_count
	if buf.size() < count * stride:
		return 0

	var xform := global_transform
	var new_buf := PackedFloat32Array()
	var removed_count := 0
	var kept_count := 0

	for i in range(count):
		var base := i * stride
		var local_orig := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
		var gpos := xform * local_orig

		var is_inside := false
		for box in aabbs:
			if _is_point_inside_aabb(gpos, box, margin):
				is_inside = true
				break

		if is_inside:
			removed_count += 1
		else:
			kept_count += 1
			for s in range(stride):
				new_buf.append(buf[base + s])

	if removed_count > 0:
		mm.instance_count = kept_count
		mm.buffer = new_buf

	return removed_count


func _is_point_inside_aabb(pt: Vector3, box: AABB, pad: float) -> bool:
	return pt.x >= (box.position.x - pad) and pt.x <= (box.end.x + pad) and \
	       pt.z >= (box.position.z - pad) and pt.z <= (box.end.z + pad) and \
	       pt.y >= (box.position.y - 1.0) and pt.y <= (box.end.y + 1.0)


func _calculate_node_aabb(root_3d: Node3D) -> AABB:
	var min_pt := Vector3(INF, INF, INF)
	var max_pt := Vector3(-INF, -INF, -INF)
	var found_any := false

	var stack: Array[Node] = [root_3d]
	while not stack.is_empty():
		var curr := stack.pop_back() as Node
		if curr is MeshInstance3D:
			var aabb: AABB = (curr as MeshInstance3D).get_aabb()
			var curr_xform: Transform3D = curr.global_transform
			for corner_idx in range(8):
				var corner := aabb.get_endpoint(corner_idx)
				var global_corner := curr_xform * corner
				min_pt.x = min(min_pt.x, global_corner.x)
				min_pt.y = min(min_pt.y, global_corner.y)
				min_pt.z = min(min_pt.z, global_corner.z)
				max_pt.x = max(max_pt.x, global_corner.x)
				max_pt.y = max(max_pt.y, global_corner.y)
				max_pt.z = max(max_pt.z, global_corner.z)
			found_any = true
		for child in curr.get_children():
			stack.push_back(child)

	if found_any:
		return AABB(min_pt, max_pt - min_pt)
	return AABB()
