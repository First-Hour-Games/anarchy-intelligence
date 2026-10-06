extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1


func pack_transform_3d(t: Transform3D, buf: PackedFloat32Array) -> void:
	buf.append(t.basis.x.x); buf.append(t.basis.y.x); buf.append(t.basis.z.x); buf.append(t.origin.x)
	buf.append(t.basis.x.y); buf.append(t.basis.y.y); buf.append(t.basis.z.y); buf.append(t.origin.y)
	buf.append(t.basis.x.z); buf.append(t.basis.y.z); buf.append(t.basis.z.z); buf.append(t.origin.z)


func get_instance_pos(mm: MultiMesh, idx: int) -> Vector3:
	var buf := mm.buffer
	var base := idx * 12
	return Vector3(buf[base + 3], buf[base + 7], buf[base + 11])


func _init() -> void:
	print("--- Running Tree Exclusion Zone Smoke Test ---")
	call_deferred("_run")


func _run() -> void:
	var zone_scene: PackedScene = load("res://scenes/zones/tree_exclusion_zone.tscn")
	check(zone_scene != null, "tree_exclusion_zone.tscn loaded successfully")
	if zone_scene == null:
		quit(1)
		return

	var zone: TreeExclusionZone3D = zone_scene.instantiate() as TreeExclusionZone3D
	root.add_child(zone)
	await process_frame

	# 1. Properties and Bounds
	print("--- Test 1: Properties and Local AABB ---")
	check(zone.size == Vector3(15.0, 10.0, 15.0), "Default size is (15, 10, 15)")
	check(zone.margin == 0.5, "Default margin is 0.5")
	check(zone.filter_trees_only, "Default filter_trees_only is true")
	check(zone.auto_prune_on_ready, "Default auto_prune_on_ready is true")

	var local_aabb := zone.get_local_aabb()
	check(local_aabb.size == zone.size, "Local AABB size matches zone.size")
	check(local_aabb.position == -zone.size * 0.5, "Local AABB is centered at origin")

	# 2. Point Inside / Outside (OBB)
	print("--- Test 2: Point Inside / Outside (OBB) ---")
	zone.global_position = Vector3(10.0, 0.0, 10.0)
	check(zone.is_point_inside(Vector3(10.0, 0.0, 10.0)), "Center point is inside")
	check(zone.is_point_inside(Vector3(15.0, 2.0, 15.0)), "Interior point is inside")
	check(not zone.is_point_inside(Vector3(50.0, 0.0, 50.0)), "Distant point is outside")

	# Test margin padding
	# Half-extent X is 7.5. At global X = 10 + 7.5 + 0.2 = 17.7 (0.2 beyond half extent)
	# With margin = 0.5, 17.7 is within margin.
	check(zone.is_point_inside(Vector3(17.7, 0.0, 10.0)), "Point inside margin padding is detected")
	zone.margin = 0.1
	check(not zone.is_point_inside(Vector3(17.7, 0.0, 10.0)), "Point outside reduced margin is rejected")
	zone.margin = 0.5

	# 3. Rotation OBB Testing
	print("--- Test 3: Rotated Zone (OBB) ---")
	zone.global_position = Vector3.ZERO
	zone.size = Vector3(10.0, 10.0, 2.0) # Thin along Z
	zone.margin = 0.0
	zone.rotation.y = deg_to_rad(45.0)

	# Along local Z (which is rotated 45 deg, world vector (1, 0, 1) normalized * distance)
	var local_along_z := zone.to_global(Vector3(0.0, 0.0, 0.8)) # length 0.8 < half-size 1.0
	check(zone.is_point_inside(local_along_z), "Local interior along rotated axis is inside")

	var local_outside_z := zone.to_global(Vector3(0.0, 0.0, 2.5)) # length 2.5 > half-size 1.0
	check(not zone.is_point_inside(local_outside_z), "Local exterior along rotated axis is outside")

	# Reset zone
	zone.rotation = Vector3.ZERO
	zone.global_position = Vector3.ZERO
	zone.size = Vector3(10.0, 10.0, 10.0)
	zone.margin = 0.5

	# 4. MultiMesh Pruning
	print("--- Test 4: Tree MultiMesh Pruning ---")
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "treeMulti_Test"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D

	# Setup 5 instances
	# 0: (0, 0, 0) -> INSIDE
	# 1: (2, 1, 2) -> INSIDE
	# 2: (100, 0, 100) -> OUTSIDE
	# 3: (-50, 0, 0) -> OUTSIDE
	# 4: (0, 80, 0) -> OUTSIDE
	var positions: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.0),
		Vector3(2.0, 1.0, 2.0),
		Vector3(100.0, 0.0, 100.0),
		Vector3(-50.0, 0.0, 0.0),
		Vector3(0.0, 80.0, 0.0)
	]
	var buf := PackedFloat32Array()
	for p in positions:
		pack_transform_3d(Transform3D(Basis(), p), buf)

	mm.instance_count = positions.size()
	mm.buffer = buf
	mmi.multimesh = mm
	root.add_child(mmi)
	await process_frame

	var result: Dictionary = zone.prune_trees(root)
	check(result.get("total_instances_removed", 0) == 2, "Pruned exactly 2 tree instances inside zone")
	check(result.get("modified_nodes", 0) == 1, "Modified 1 MultiMesh node")
	check(mm.instance_count == 3, "Remaining instance_count on MultiMesh is 3")

	# Verify remaining instance positions are the outside ones
	var remaining_p0 := get_instance_pos(mm, 0)
	var remaining_p1 := get_instance_pos(mm, 1)
	var remaining_p2 := get_instance_pos(mm, 2)
	check(remaining_p0.is_equal_approx(Vector3(100.0, 0.0, 100.0)), "Remaining instance 0 is (100, 0, 100)")
	check(remaining_p1.is_equal_approx(Vector3(-50.0, 0.0, 0.0)), "Remaining instance 1 is (-50, 0, 0)")
	check(remaining_p2.is_equal_approx(Vector3(0.0, 80.0, 0.0)), "Remaining instance 2 is (0, 80, 0)")

	# 5. Tree Name Filtering
	print("--- Test 5: Name Filtering (filter_trees_only) ---")
	var grass_mmi := MultiMeshInstance3D.new()
	grass_mmi.name = "grassMulti_Test"
	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	var grass_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)), grass_buf)
	pack_transform_3d(Transform3D(Basis(), Vector3(1.0, 0.0, 1.0)), grass_buf)
	grass_mm.instance_count = 2
	grass_mm.buffer = grass_buf
	grass_mmi.multimesh = grass_mm
	root.add_child(grass_mmi)
	await process_frame

	zone.filter_trees_only = true
	var res_filter := zone.prune_trees(root)
	check(grass_mm.instance_count == 2, "Grass MultiMesh ignored when filter_trees_only is true")

	zone.filter_trees_only = false
	var res_all := zone.prune_trees(root)
	check(grass_mm.instance_count == 0, "Grass MultiMesh pruned when filter_trees_only is false")

	# 6. Group Management and exclude_grass
	print("--- Test 6: Group Management and exclude_grass ---")
	check(zone.is_in_group(&"tree_exclusion_zone"), "Zone is in group tree_exclusion_zone")
	check(not zone.is_in_group(&"building_exclusion"), "Zone is initially not in building_exclusion")
	check(not zone.is_in_group(&"foliage_exclusion"), "Zone is initially not in foliage_exclusion")

	zone.exclude_grass = true
	check(zone.is_in_group(&"building_exclusion"), "Zone joined building_exclusion when exclude_grass = true")
	check(zone.is_in_group(&"foliage_exclusion"), "Zone joined foliage_exclusion when exclude_grass = true")

	zone.exclude_grass = false
	check(not zone.is_in_group(&"building_exclusion"), "Zone left building_exclusion when exclude_grass = false")
	check(not zone.is_in_group(&"foliage_exclusion"), "Zone left foliage_exclusion when exclude_grass = false")

	# 7. Integration with MultiMeshExclusionFilter
	print("--- Test 7: MultiMeshExclusionFilter Integration ---")
	var filter_node := MultiMeshExclusionFilter.new()
	filter_node.name = "treeMulti_FilterTest"
	var filter_mm := MultiMesh.new()
	filter_mm.transform_format = MultiMesh.TRANSFORM_3D
	var fbuf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)), fbuf) # INSIDE zone
	pack_transform_3d(Transform3D(Basis(), Vector3(200.0, 0.0, 200.0)), fbuf) # OUTSIDE zone
	pack_transform_3d(Transform3D(Basis(), Vector3(300.0, 0.0, 300.0)), fbuf) # OUTSIDE zone
	filter_mm.instance_count = 3
	filter_mm.buffer = fbuf
	filter_node.multimesh = filter_mm
	filter_node.auto_prune_on_ready = false
	filter_node.prune_tree_collisions = false
	filter_node.prune_downward_facing = false
	root.add_child(filter_node)
	await process_frame

	var filter_removed := filter_node.prune_instances()
	check(filter_removed == 1, "MultiMeshExclusionFilter pruned 1 instance falling inside TreeExclusionZone3D")
	check(filter_mm.instance_count == 2, "MultiMeshExclusionFilter instance_count is now 2")

	# 8. Editor Preview
	print("--- Test 8: Editor Preview ---")
	zone.show_in_game_debug = true
	check(is_instance_valid(zone._editor_mesh_instance), "Preview MeshInstance3D created when debug preview is enabled")
	check(zone._editor_mesh_instance.mesh is BoxMesh, "Preview uses BoxMesh")
	var bm := zone._editor_mesh_instance.mesh as BoxMesh
	check(bm.size == zone.size, "Preview BoxMesh size matches zone.size")

	# 9. Auto Prune on Ready
	print("--- Test 9: Auto Prune On Ready ---")
	var auto_tree := MultiMeshInstance3D.new()
	auto_tree.name = "treeMulti_AutoTest"
	var auto_mm := MultiMesh.new()
	auto_mm.transform_format = MultiMesh.TRANSFORM_3D
	var auto_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(500.0, 0.0, 500.0)), auto_buf) # INSIDE auto_zone
	pack_transform_3d(Transform3D(Basis(), Vector3(900.0, 0.0, 900.0)), auto_buf) # OUTSIDE auto_zone
	auto_mm.instance_count = 2
	auto_mm.buffer = auto_buf
	auto_tree.multimesh = auto_mm
	root.add_child(auto_tree)

	var auto_zone: TreeExclusionZone3D = zone_scene.instantiate() as TreeExclusionZone3D
	auto_zone.name = "AutoZone"
	auto_zone.position = Vector3(500.0, 0.0, 500.0)
	auto_zone.auto_prune_on_ready = true
	root.add_child(auto_zone)
	await process_frame

	check(auto_mm.instance_count == 1, "auto_prune_on_ready pruned 1 instance upon entering tree")
	var auto_rem_pos := get_instance_pos(auto_mm, 0)
	check(auto_rem_pos.is_equal_approx(Vector3(900.0, 0.0, 900.0)), "Remaining instance is the outside instance")

	# Cleanup test nodes
	zone.queue_free()
	mmi.queue_free()
	grass_mmi.queue_free()
	filter_node.queue_free()
	auto_tree.queue_free()
	auto_zone.queue_free()
	await process_frame

	print("--- Tree Exclusion Zone Smoke Test Complete ---")
	if failures == 0:
		print("ALL PASS")
	else:
		print("FAILED with %d errors" % failures)

	quit(failures)
