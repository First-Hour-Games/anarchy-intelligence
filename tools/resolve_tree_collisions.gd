@tool
extends SceneTree

## Standalone script to resolve all tree collisions, upside-down orientations, and exclusions in starting_forest.tscn.
## Prioritizes 'treeMulti9' over other MultiMeshes.

const SCENE_PATH := "res://scenes/chapters/main/starting_forest.tscn"
const DEFAULT_MIN_DISTANCE := 2.5 # meters


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Running Foliage Pruning (Orientation, Collisions, Exclusions) ===")
	var packed := load(SCENE_PATH) as PackedScene
	if not packed:
		printerr("Failed to load scene: ", SCENE_PATH)
		quit(1)
		return

	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var foliage := scene.get_node_or_null("Foliage")
	if not foliage:
		printerr("No Foliage node found in scene!")
		quit(1)
		return

	# Collect all tree MultiMeshInstance3D nodes
	var tree_nodes: Array[MultiMeshInstance3D] = []
	for child in foliage.get_children():
		if child is MultiMeshInstance3D and child.multimesh:
			if child.name.begins_with("treeMulti") or child.name.to_lower().contains("tree"):
				tree_nodes.append(child)

	# Priority helper: treeMulti9 gets -1 (highest priority)
	var get_prio = func(node_name: String) -> int:
		if node_name == "treeMulti9":
			return -1
		var regex := RegEx.new()
		regex.compile("(\\d+)")
		var m := regex.search(node_name)
		if m:
			var val := m.get_string().to_int()
			return val if val > 0 else 1
		return 1

	# Sort with treeMulti9 first, then ascending priority
	tree_nodes.sort_custom(func(a: MultiMeshInstance3D, b: MultiMeshInstance3D) -> bool:
		var pa: int = get_prio.call(a.name)
		var pb: int = get_prio.call(b.name)
		if pa != pb:
			return pa < pb
		return a.name < b.name
	)

	# Helper to find model up vector in mesh space
	var get_mesh_up = func(m: Mesh) -> Vector3:
		if not m: return Vector3.UP
		var aabb := m.get_aabb()
		if aabb.size.z > aabb.size.y and aabb.size.z > aabb.size.x:
			return Vector3(0, 0, -1) if aabb.position.z < 0.0 else Vector3(0, 0, 1)
		else:
			return Vector3(0, 1, 0) if aabb.end.y > abs(aabb.position.y) else Vector3(0, -1, 0)

	# Collect building exclusion AABBs from lowGrassMulti or landmarks
	var grass_node := foliage.get_node_or_null("lowGrassMulti") as MultiMeshInstance3D
	var aabbs: Array[AABB] = []
	if grass_node and grass_node.has_method("get_exclusion_aabbs"):
		aabbs = grass_node.get_exclusion_aabbs()
	print("Found %d building exclusion AABBs" % aabbs.size())

	var default_exclusion_paths: Array[NodePath] = [
		NodePath("../../welcomeCenterTextured2"),
		NodePath("../../ParkingLot")
	]

	var accepted_positions: Array[Vector3] = []
	var min_dist_sq := DEFAULT_MIN_DISTANCE * DEFAULT_MIN_DISTANCE
	var total_initial := 0
	var total_kept := 0
	var total_removed := 0
	var total_upside_down := 0

	for node in tree_nodes:
		if node.get("exclusion_nodes") != null and (node.get("exclusion_nodes") as Array).is_empty():
			node.set("exclusion_nodes", default_exclusion_paths)

		var mm := node.multimesh
		var buf := mm.buffer
		if buf.is_empty() or mm.instance_count == 0:
			continue

		var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
		var stride: int = 12 if is_3d else 8
		if mm.use_colors: stride += 4
		if mm.use_custom_data: stride += 4

		var count: int = mm.instance_count
		total_initial += count

		var model_up: Vector3 = get_mesh_up.call(mm.mesh)
		var node_xform := node.global_transform
		var new_buf := PackedFloat32Array()
		var node_kept := 0
		var node_removed := 0
		var node_upside_down := 0

		for i in range(count):
			var base := i * stride
			var is_rejected := false

			# 1. Orientation check (reject upside-down / downward pointing trees)
			if is_3d:
				var local_dir := Vector3(
					buf[base + 0] * model_up.x + buf[base + 1] * model_up.y + buf[base + 2] * model_up.z,
					buf[base + 4] * model_up.x + buf[base + 5] * model_up.y + buf[base + 6] * model_up.z,
					buf[base + 8] * model_up.x + buf[base + 9] * model_up.y + buf[base + 10] * model_up.z
				)
				var world_dir := node_xform.basis * local_dir
				if world_dir.y < -0.05:
					is_rejected = true
					node_upside_down += 1

			var local_pos := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
			var gpos := node.to_global(local_pos)

			# 2. AABB exclusion check
			if not is_rejected and not aabbs.is_empty():
				for box in aabbs:
					if gpos.x >= (box.position.x - 0.5) and gpos.x <= (box.end.x + 0.5) and \
					   gpos.z >= (box.position.z - 0.5) and gpos.z <= (box.end.z + 0.5) and \
					   gpos.y >= (box.position.y - 1.0) and gpos.y <= (box.end.y + 1.0):
						is_rejected = true
						break

			# 3. Collision check (XZ plane distance) against already accepted trees
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

		print("[%s] Initial: %d | Kept: %d | Removed: %d (Upside-down: %d)" % [
			node.name, count, node_kept, node_removed, node_upside_down
		])
		total_kept += node_kept
		total_removed += node_removed
		total_upside_down += node_upside_down

		# Apply updated buffer
		mm.instance_count = node_kept
		mm.buffer = new_buf

	print("\n=== Summary ===")
	print("Total initial trees:     %d" % total_initial)
	print("Total kept:              %d" % total_kept)
	print("Total removed:           %d" % total_removed)
	print("Total upside-down trees: %d" % total_upside_down)

	# Save updated scene
	var packed_updated := PackedScene.new()
	var pack_err := packed_updated.pack(scene)
	if pack_err == OK:
		var save_err := ResourceSaver.save(packed_updated, SCENE_PATH)
		if save_err == OK:
			print("Successfully saved updated starting_forest.tscn!")
		else:
			printerr("Failed to save scene, error code: ", save_err)
	else:
		printerr("Failed to pack scene, error code: ", pack_err)

	scene.queue_free()
	quit(0)
