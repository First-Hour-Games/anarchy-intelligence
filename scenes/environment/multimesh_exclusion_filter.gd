@tool
extends MultiMeshInstance3D
class_name MultiMeshExclusionFilter

## Automatically deletes MultiMesh instances that fall inside specified building bounds or exclusion zones,
## removes upside-down instances, and resolves overlapping tree collisions across MultiMeshes
## (with priority given to treeMulti9).

@export_group("Exclusion Zones")
## Nodes whose bounding boxes (AABBs) will be used to exclude foliage (e.g. Visitor Center, houses, roads).
## If left empty, automatically searches sibling MultiMeshes or scene landmarks (welcomeCenter, ParkingLot).
@export var exclusion_nodes: Array[NodePath] = []

## Additional manual bounding boxes (in global coordinates) to exclude instances from.
@export var manual_exclusion_boxes: Array[AABB] = []

## Extra padding/margin around the exclusion bounds (in meters).
@export var margin: float = 0.5

## If true, automatically prunes instances when entering the scene tree at game start.
@export var auto_prune_on_ready: bool = true

@export_group("Tree Collision Deduplication")
## If true, pruning will also delete tree instances that collide with higher-priority trees or self-clashes.
@export var prune_tree_collisions: bool = true

## Minimum distance (in meters) between tree instances before they are considered colliding.
@export_range(0.5, 10.0, 0.1) var min_tree_distance: float = 2.5

## Name of the MultiMesh node that should have top priority (e.g. "treeMulti9").
@export var top_priority_node_name: String = "treeMulti9"

@export_group("Orientation Filter")
## If true, removes instances whose scale is inverted or whose Up vector points straight downward.
@export var prune_downward_facing: bool = true

@export_group("Editor Actions")
## Click this checkbox in the Godot Inspector to trigger pruning (AABB exclusion, downward orientation, and tree collisions) immediately on this node.
@export var click_to_prune_now: bool = false:
	set(val):
		if val:
			var removed := prune_instances()
			print("[MultiMeshExclusionFilter] Pruned %d instances from %s" % [removed, name])
			click_to_prune_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to resolve all tree collisions across ALL sibling tree MultiMeshes (prioritizing treeMulti9).
@export var click_to_resolve_all_tree_clashes_now: bool = false:
	set(val):
		if val:
			resolve_all_tree_clashes()
			click_to_resolve_all_tree_clashes_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to prune ALL foliage under parent (AABBs + downward + all tree clashes).
@export var click_to_prune_all_foliage_now: bool = false:
	set(val):
		if val:
			prune_all_foliage()
			click_to_prune_all_foliage_now = false
			notify_property_list_changed()


func _ready() -> void:
	if not Engine.is_editor_hint() and auto_prune_on_ready:
		prune_instances()


## Checks if this node is considered a tree MultiMesh.
func is_tree_node() -> bool:
	var lname := name.to_lower()
	return lname.contains("tree") or lname.begins_with("treemulti")


## Returns a numerical priority for tree collision deduplication.
## Lower number = higher priority (retained first).
## top_priority_node_name (e.g. treeMulti9) always gets -1 (highest priority).
func get_tree_priority(node_name: String) -> int:
	var priority_name := top_priority_node_name.strip_edges()
	if not priority_name.is_empty() and node_name == priority_name:
		return -1

	# Extract number from name if any (e.g. treeMulti -> 1, treeMulti2 -> 2, ..., treeMulti10 -> 10)
	var regex := RegEx.new()
	regex.compile("(\\d+)")
	var m := regex.search(node_name)
	if m:
		var val := m.get_string().to_int()
		return val if val > 0 else 1
	return 1


## Collects all active exclusion AABBs in global coordinates.
## If exclusion_nodes is empty, automatically falls back to sibling MultiMeshes or scene landmarks.
func get_exclusion_aabbs() -> Array[AABB]:
	var aabbs: Array[AABB] = []

	for box in manual_exclusion_boxes:
		aabbs.append(box)

	var targets: Array[Node3D] = []

	# 1. Configured exclusion_nodes
	for node_path in exclusion_nodes:
		var target := get_node_or_null(node_path) as Node3D
		if target and not targets.has(target):
			targets.append(target)

	# 2. Sibling fallback: if exclusion_nodes is empty, inherit from sibling MultiMeshExclusionFilter
	if targets.is_empty():
		var p := get_parent()
		if p:
			for sibling in p.get_children():
				if sibling != self and sibling is MultiMeshInstance3D:
					var sib_nodes = sibling.get("exclusion_nodes")
					if sib_nodes is Array and not sib_nodes.is_empty():
						for spath in sib_nodes:
							var target := sibling.get_node_or_null(spath) as Node3D
							if target and not targets.has(target):
								targets.append(target)
						if not targets.is_empty():
							break

	# 3. Scene landmark search if still empty (welcome center, parking lot)
	if targets.is_empty():
		var root_cand: Node = self
		while root_cand.get_parent() != null and root_cand.get_parent() != (get_tree().get_root() if is_inside_tree() else null):
			root_cand = root_cand.get_parent()
		_find_landmarks_in_node(root_cand, targets)

	# 4. Group "building_exclusion"
	if is_inside_tree():
		var group_nodes := get_tree().get_nodes_in_group(&"building_exclusion")
		for gnode in group_nodes:
			if gnode is Node3D and not targets.has(gnode):
				targets.append(gnode as Node3D)

	# Collect AABBs from all discovered targets
	for target in targets:
		for box in _collect_target_aabbs(target):
			if box.size.length_squared() > 0.01:
				aabbs.append(box)

	return aabbs


func _find_landmarks_in_node(node: Node, results: Array[Node3D]) -> void:
	if not is_instance_valid(node):
		return
	var lname := node.name.to_lower()
	if lname.contains("welcomecenter") or lname.contains("visitorcenter") or lname.contains("parkinglot"):
		if node is Node3D and not results.has(node):
			results.append(node as Node3D)
	for child in node.get_children():
		_find_landmarks_in_node(child, results)


## Prunes all instances falling inside any exclusion AABB, facing downward,
## or (for tree MultiMeshes) colliding with higher priority trees or self-clashes.
## Calculates the model up vector in local mesh space based on the mesh's AABB extents.
func get_mesh_up_vector(m: Mesh = null) -> Vector3:
	var target_mesh: Mesh = m if m else (multimesh.mesh if multimesh else null)
	if not target_mesh:
		return Vector3.UP
	var aabb := target_mesh.get_aabb()
	# Check whether Y or Z has the greatest height extent
	if aabb.size.z > aabb.size.y and aabb.size.z > aabb.size.x:
		return Vector3(0, 0, -1) if aabb.position.z < 0.0 else Vector3(0, 0, 1)
	else:
		return Vector3(0, 1, 0) if aabb.end.y > abs(aabb.position.y) else Vector3(0, -1, 0)


## Prunes all instances falling inside any exclusion AABB, facing downward,
## or (for tree MultiMeshes) colliding with higher priority trees or self-clashes.
## Returns number of removed instances.
func prune_instances() -> int:
	var mm := multimesh
	if not mm or mm.instance_count == 0:
		return 0

	var aabbs := get_exclusion_aabbs()
	var check_tree_clashes: bool = prune_tree_collisions and is_tree_node()

	if aabbs.is_empty() and not prune_downward_facing and not check_tree_clashes:
		return 0

	var buf: PackedFloat32Array = mm.buffer
	if buf.is_empty():
		return 0

	var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
	var stride: int = 12 if is_3d else 8
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4

	var count: int = mm.instance_count
	if buf.size() < count * stride:
		return 0

	var model_up := get_mesh_up_vector()

	# If checking tree clashes, gather positions from all higher-priority sibling tree MultiMeshes
	var prior_tree_positions: Array[Vector3] = []
	var min_dist_sq := min_tree_distance * min_tree_distance
	if check_tree_clashes:
		var my_prio := get_tree_priority(name)
		var p := get_parent()
		if p:
			for sibling in p.get_children():
				if sibling != self and sibling is MultiMeshInstance3D and sibling.multimesh:
					var sib_name: String = sibling.name
					var sib_lname := sib_name.to_lower()
					if sib_lname.contains("tree") or sib_lname.begins_with("treemulti"):
						var sib_prio := get_tree_priority(sib_name)
						if sib_prio < my_prio:
							var s_mm: MultiMesh = sibling.multimesh
							var s_buf: PackedFloat32Array = s_mm.buffer
							var s_is_3d: bool = (s_mm.transform_format == MultiMesh.TRANSFORM_3D)
							var s_stride: int = 12 if s_is_3d else 8
							if s_mm.use_colors: s_stride += 4
							if s_mm.use_custom_data: s_stride += 4
							for si in range(s_mm.instance_count):
								var s_base := si * s_stride
								var s_local := Vector3(s_buf[s_base + 3], s_buf[s_base + 7], s_buf[s_base + 11]) if s_is_3d else Vector3(s_buf[s_base + 2], s_buf[s_base + 5], 0.0)
								prior_tree_positions.append(sibling.to_global(s_local))

	var xform := global_transform
	var new_buf := PackedFloat32Array()
	var removed_count := 0
	var kept_count := 0
	var accepted_in_self: Array[Vector3] = []

	for i in range(count):
		var base := i * stride
		var is_rejected := false

		# 1. Orientation check (rejects instances pointing upside-down / downwards)
		if prune_downward_facing and is_3d:
			var local_dir := Vector3(
				buf[base + 0] * model_up.x + buf[base + 1] * model_up.y + buf[base + 2] * model_up.z,
				buf[base + 4] * model_up.x + buf[base + 5] * model_up.y + buf[base + 6] * model_up.z,
				buf[base + 8] * model_up.x + buf[base + 9] * model_up.y + buf[base + 10] * model_up.z
			)
			var world_dir := xform.basis * local_dir
			if world_dir.y < -0.05:
				is_rejected = true

		var local_orig := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
		var gpos := xform * local_orig

		# 2. AABB exclusion check
		if not is_rejected and not aabbs.is_empty():
			for box in aabbs:
				if _is_point_inside_aabb(gpos, box, margin):
					is_rejected = true
					break

		# 3. Tree collision check (XZ plane distance)
		if not is_rejected and check_tree_clashes:
			# Check against higher-priority trees
			for ppos in prior_tree_positions:
				var dx: float = gpos.x - ppos.x
				var dz: float = gpos.z - ppos.z
				if (dx * dx + dz * dz) < min_dist_sq:
					is_rejected = true
					break

			# Check against already accepted trees in self (self-clashes)
			if not is_rejected:
				for spos in accepted_in_self:
					var dx: float = gpos.x - spos.x
					var dz: float = gpos.z - spos.z
					if (dx * dx + dz * dz) < min_dist_sq:
						is_rejected = true
						break

		if is_rejected:
			removed_count += 1
		else:
			kept_count += 1
			if check_tree_clashes:
				accepted_in_self.append(gpos)
			for s in range(stride):
				new_buf.append(buf[base + s])

	if removed_count > 0:
		mm.instance_count = kept_count
		mm.buffer = new_buf
		mm.emit_changed()

	return removed_count


## Scans all sibling tree MultiMeshes, prioritizing top_priority_node_name (e.g. treeMulti9),
## and deletes any tree instances that are closer than min_tree_distance to an existing tree.
func resolve_all_tree_clashes(target_parent: Node = null) -> Dictionary:
	var p: Node = target_parent if is_instance_valid(target_parent) else get_parent()
	if not is_instance_valid(p):
		printerr("[MultiMeshExclusionFilter] Cannot resolve clashes: no parent node found!")
		return {}

	var tree_nodes: Array[MultiMeshInstance3D] = []
	for child in p.get_children():
		if child is MultiMeshInstance3D and child.multimesh:
			if child.name.begins_with("treeMulti") or child.name.to_lower().contains("tree"):
				tree_nodes.append(child)

	if tree_nodes.is_empty():
		print("[MultiMeshExclusionFilter] No tree MultiMesh nodes found under: ", p.name)
		return {}

	# Sort with top_priority_node_name first, then ascending priority
	tree_nodes.sort_custom(func(a: MultiMeshInstance3D, b: MultiMeshInstance3D) -> bool:
		var pa := get_tree_priority(a.name)
		var pb := get_tree_priority(b.name)
		if pa != pb:
			return pa < pb
		return a.name < b.name
	)

	var accepted_positions: Array[Vector3] = []
	var results: Dictionary = {}
	var min_dist_sq := min_tree_distance * min_tree_distance
	var total_initial := 0
	var total_kept := 0
	var total_removed := 0

	for node in tree_nodes:
		var mm := node.multimesh
		var buf := mm.buffer
		if buf.is_empty() or mm.instance_count == 0:
			continue

		var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
		var stride: int = 12 if is_3d else 8
		if mm.use_colors:
			stride += 4
		if mm.use_custom_data:
			stride += 4

		var count: int = mm.instance_count
		total_initial += count

		var model_up := get_mesh_up_vector(mm.mesh)
		var node_xform := node.global_transform
		var new_buf := PackedFloat32Array()
		var node_kept := 0
		var node_removed := 0

		for i in range(count):
			var base := i * stride
			var is_rejected := false

			# 1. Orientation check (reject upside-down instances)
			if is_3d:
				var local_dir := Vector3(
					buf[base + 0] * model_up.x + buf[base + 1] * model_up.y + buf[base + 2] * model_up.z,
					buf[base + 4] * model_up.x + buf[base + 5] * model_up.y + buf[base + 6] * model_up.z,
					buf[base + 8] * model_up.x + buf[base + 9] * model_up.y + buf[base + 10] * model_up.z
				)
				var world_dir := node_xform.basis * local_dir
				if world_dir.y < -0.05:
					is_rejected = true

			var local_pos := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
			var gpos := node.to_global(local_pos)

			# 2. Check collision with already accepted trees (horizontal XZ distance)
			if not is_rejected:
				for existing in accepted_positions:
					var dx: float = gpos.x - existing.x
					var dz: float = gpos.z - existing.z
					if (dx * dx + dz * dz) < min_dist_sq:
						is_rejected = true
						break

			if is_rejected:
				node_removed += 1
			else:
				node_kept += 1
				accepted_positions.append(gpos)
				for s in range(stride):
					new_buf.append(buf[base + s])

		if node_removed > 0:
			mm.instance_count = node_kept
			mm.buffer = new_buf
			mm.emit_changed()

		results[node.name] = { "kept": node_kept, "removed": node_removed, "initial": count }
		total_kept += node_kept
		total_removed += node_removed
		print("[Tree Clash Resolver] %s: kept %d, removed %d clashing trees" % [node.name, node_kept, node_removed])

	print("[Tree Clash Resolver] Done! Total kept: %d, Total clashing trees removed: %d" % [total_kept, total_removed])
	return results


## Prunes building AABBs and downward facing instances for all MultiMeshes,
## and then resolves all tree collisions across all sibling tree MultiMeshes.
func prune_all_foliage(target_parent: Node = null) -> Dictionary:
	var p: Node = target_parent if is_instance_valid(target_parent) else get_parent()
	if not is_instance_valid(p):
		printerr("[MultiMeshExclusionFilter] Cannot prune all foliage: no parent node found!")
		return {}

	# 1. Prune AABB & downward on each child
	for child in p.get_children():
		if child is MultiMeshInstance3D and child.get_script() != null:
			if child.has_method("prune_instances"):
				# Disable tree clashes temporarily so we do AABB/downward first
				var orig_clashes: bool = child.get("prune_tree_collisions")
				child.set("prune_tree_collisions", false)
				child.call("prune_instances")
				child.set("prune_tree_collisions", orig_clashes)

	# 2. Resolve tree clashes across all trees with top_priority_node_name first
	return resolve_all_tree_clashes(p)


func _is_point_inside_aabb(pt: Vector3, box: AABB, pad: float) -> bool:
	return pt.x >= (box.position.x - pad) and pt.x <= (box.end.x + pad) and \
		   pt.z >= (box.position.z - pad) and pt.z <= (box.end.z + pad) and \
		   pt.y >= (box.position.y - 1.0) and pt.y <= (box.end.y + 1.0)


func _collect_target_aabbs(target: Node3D) -> Array[AABB]:
	var result: Array[AABB] = []
	var target_shape_aabb := _get_node_local_aabb(target)
	if target_shape_aabb.size.length_squared() <= 0.001 and target.scene_file_path.is_empty() and target.get_child_count() > 0:
		var has_child_shape := false
		for child in target.get_children():
			if child is Node3D:
				var child_box := _calculate_node_aabb(child as Node3D)
				if child_box.size.length_squared() > 0.01:
					result.append(child_box)
					has_child_shape = true
		if has_child_shape:
			return result

	var box := _calculate_node_aabb(target)
	if box.size.length_squared() > 0.01:
		result.append(box)
	return result


func _calculate_node_aabb(node: Node3D) -> AABB:
	var local_aabb := _get_node_local_aabb(node)
	if local_aabb.size.length_squared() <= 0.001:
		return AABB()
	return node.global_transform * local_aabb


func _get_node_local_aabb(node: Node3D) -> AABB:
	if node is MeshInstance3D and node.mesh:
		return node.mesh.get_aabb()
	if node is CollisionShape3D and node.shape:
		return _shape_to_aabb(node.shape)
	if node is CSGShape3D:
		return _csg_to_aabb(node)

	var combined := AABB()
	var has_bounds := false
	for child in node.get_children():
		if child is Node3D:
			var child_box := _calculate_node_aabb(child as Node3D)
			if child_box.size.length_squared() > 0.01:
				if not has_bounds:
					combined = child_box
					has_bounds = true
				else:
					combined = combined.merge(child_box)
	return combined


func _shape_to_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size * 0.5, shape.size)
	if shape is SphereShape3D:
		var r: float = shape.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	if shape is CylinderShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is CapsuleShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is ConvexPolygonShape3D:
		return _points_to_aabb(shape.points)
	if shape is ConcavePolygonShape3D:
		return _points_to_aabb(shape.get_faces())
	return AABB()


func _points_to_aabb(pts: PackedVector3Array) -> AABB:
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		aabb = aabb.expand(pts[i])
	return aabb


func _csg_to_aabb(csg: CSGShape3D) -> AABB:
	if csg is CSGBox3D:
		return AABB(-csg.size * 0.5, csg.size)
	if csg is CSGSphere3D:
		var r: float = csg.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	if csg is CSGCylinder3D:
		var r: float = csg.radius
		var h: float = csg.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	var meshes := csg.get_meshes()
	if meshes.size() > 1 and meshes[1] is Mesh:
		return (meshes[1] as Mesh).get_aabb()
	return AABB()
