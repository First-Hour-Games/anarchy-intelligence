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


func _init() -> void:
	print("--- Running In-Editor View Prune Smoke Test (Trees & Foliage) ---")
	call_deferred("_run")


func _run() -> void:
	# -------------------------------------------------------------------------
	# 1. TreeExclusionZone3D Editor Properties & Foliage Pruning
	# -------------------------------------------------------------------------
	print("\n--- Test 1: TreeExclusionZone3D Editor & Foliage Capabilities ---")
	var zone := TreeExclusionZone3D.new()
	zone.size = Vector3(20.0, 20.0, 20.0)
	zone.margin = 0.5
	zone.filter_trees_only = true
	zone.auto_prune_on_ready = false

	check("auto_prune_in_editor" in zone, "TreeExclusionZone3D has auto_prune_in_editor property")
	check("click_to_prune_trees_and_foliage_now" in zone, "TreeExclusionZone3D has click_to_prune_trees_and_foliage_now button")
	check("click_to_prune_foliage_now" in zone, "TreeExclusionZone3D has click_to_prune_foliage_now button")
	check("click_to_prune_all_zones_foliage" in zone, "TreeExclusionZone3D has click_to_prune_all_zones_foliage button")
	check(zone.has_method(&"prune_trees_and_foliage"), "TreeExclusionZone3D has prune_trees_and_foliage method")
	check(zone.has_method(&"prune_foliage_only"), "TreeExclusionZone3D has prune_foliage_only method")

	root.add_child(zone)
	await process_frame

	# Create a tree MultiMesh and a foliage/grass MultiMesh
	var tree_mmi := MultiMeshInstance3D.new()
	tree_mmi.name = "treeMulti_Test"
	var tree_mm := MultiMesh.new()
	tree_mm.transform_format = MultiMesh.TRANSFORM_3D
	var tree_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)), tree_buf)      # inside zone
	pack_transform_3d(Transform3D(Basis(), Vector3(100.0, 0.0, 0.0)), tree_buf)    # outside zone
	tree_mm.instance_count = 2
	tree_mm.buffer = tree_buf
	tree_mmi.multimesh = tree_mm
	root.add_child(tree_mmi)

	var grass_mmi := MultiMeshInstance3D.new()
	grass_mmi.name = "foliage_grassMulti"
	var grass_mm := MultiMesh.new()
	grass_mm.transform_format = MultiMesh.TRANSFORM_3D
	var grass_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(1.0, 0.0, 1.0)), grass_buf)      # inside zone
	pack_transform_3d(Transform3D(Basis(), Vector3(200.0, 0.0, 0.0)), grass_buf)    # outside zone
	grass_mm.instance_count = 2
	grass_mm.buffer = grass_buf
	grass_mmi.multimesh = grass_mm
	root.add_child(grass_mmi)
	await process_frame

	# prune_trees() with filter_trees_only=true leaves grass alone
	zone.filter_trees_only = true
	var tree_res := zone.prune_trees(root)
	check(tree_mm.instance_count == 1, "prune_trees() pruned tree instance inside zone (remaining: 1)")
	check(grass_mm.instance_count == 2, "prune_trees() preserved foliage/grass (remaining: 2)")

	# prune_trees_and_foliage() prunes grass as well
	var both_res := zone.prune_trees_and_foliage(root)
	check(grass_mm.instance_count == 1, "prune_trees_and_foliage() pruned foliage/grass inside zone (remaining: 1)")
	check(tree_mm.instance_count == 1, "prune_trees_and_foliage() retained already pruned tree count (1)")

	# -------------------------------------------------------------------------
	# 2. ProceduralTreeGenerator Editor Properties & Foliage Pruning
	# -------------------------------------------------------------------------
	print("\n--- Test 2: ProceduralTreeGenerator Editor & Foliage Capabilities ---")
	var gen := ProceduralTreeGenerator.new()
	gen.name = "Foliage_TestGen"
	check("auto_prune_in_editor" in gen, "ProceduralTreeGenerator has auto_prune_in_editor property")
	check("prune_foliage_as_well" in gen, "ProceduralTreeGenerator has prune_foliage_as_well property")
	check("click_to_prune_trees_and_foliage_now" in gen, "ProceduralTreeGenerator has click_to_prune_trees_and_foliage_now button")
	check("click_to_prune_all_foliage_now" in gen, "ProceduralTreeGenerator has click_to_prune_all_foliage_now button")
	check(gen.has_method(&"prune_all_trees_and_foliage"), "ProceduralTreeGenerator has prune_all_trees_and_foliage method")
	check(gen.has_method(&"prune_all_foliage"), "ProceduralTreeGenerator has prune_all_foliage method")

	# Add a manual exclusion box
	gen.manual_exclusion_boxes.append(AABB(Vector3(-10.0, -10.0, -10.0), Vector3(20.0, 20.0, 20.0)))
	root.add_child(gen)

	# Add tree child and foliage child under gen
	var g_tree := MultiMeshInstance3D.new()
	g_tree.name = "treeMulti1"
	var gt_mm := MultiMesh.new()
	gt_mm.transform_format = MultiMesh.TRANSFORM_3D
	var gt_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)), gt_buf)     # inside box
	pack_transform_3d(Transform3D(Basis(), Vector3(50.0, 0.0, 50.0)), gt_buf)   # outside box
	gt_mm.instance_count = 2
	gt_mm.buffer = gt_buf
	g_tree.multimesh = gt_mm
	gen.add_child(g_tree)

	var g_foliage := MultiMeshInstance3D.new()
	g_foliage.name = "bush_fern"
	var gf_mm := MultiMesh.new()
	gf_mm.transform_format = MultiMesh.TRANSFORM_3D
	var gf_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(2.0, 0.0, 2.0)), gf_buf)     # inside box
	pack_transform_3d(Transform3D(Basis(), Vector3(60.0, 0.0, 60.0)), gf_buf)   # outside box
	gf_mm.instance_count = 2
	gf_mm.buffer = gf_buf
	g_foliage.multimesh = gf_mm
	gen.add_child(g_foliage)
	await process_frame

	var combined_stats := gen.prune_all_trees_and_foliage()
	check(gt_mm.instance_count == 1, "ProceduralTreeGenerator pruned tree inside exclusion box (remaining: 1)")
	check(gf_mm.instance_count == 1, "ProceduralTreeGenerator pruned foliage inside exclusion box (remaining: 1)")
	check(combined_stats.get("total_pruned", 0) == 2, "Combined stats reported 2 total pruned instances")

	# -------------------------------------------------------------------------
	# 3. ProceduralGrassGenerator In-Editor Prune Capability
	# -------------------------------------------------------------------------
	print("\n--- Test 3: ProceduralGrassGenerator In-Editor Pruning ---")
	var grass_packed := load("res://scenes/environment/procedural_grass.tscn") as PackedScene
	var grass_gen := grass_packed.instantiate()
	grass_gen.set("generate_on_ready", false)
	check("auto_prune_in_editor" in grass_gen, "ProceduralGrassGenerator has auto_prune_in_editor property")
	check("click_to_prune_now" in grass_gen, "ProceduralGrassGenerator has click_to_prune_now button")
	check(grass_gen.has_method(&"prune_instances"), "ProceduralGrassGenerator has prune_instances method")

	(grass_gen.get("manual_exclusion_boxes") as Array).append(AABB(Vector3(-10.0, -10.0, -10.0), Vector3(20.0, 20.0, 20.0)))
	root.add_child(grass_gen)

	var low_grass_node: MultiMeshInstance3D = grass_gen.get_node("LowGrassMultiMesh") as MultiMeshInstance3D
	var lg_mm := MultiMesh.new()
	lg_mm.transform_format = MultiMesh.TRANSFORM_3D
	var lg_buf := PackedFloat32Array()
	pack_transform_3d(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)), lg_buf)     # inside box
	pack_transform_3d(Transform3D(Basis(), Vector3(80.0, 0.0, 80.0)), lg_buf)   # outside box
	lg_mm.instance_count = 2
	lg_mm.buffer = lg_buf
	low_grass_node.multimesh = lg_mm
	await process_frame

	var grass_pruned: int = grass_gen.call(&"prune_instances")
	check(grass_pruned == 1, "ProceduralGrassGenerator.prune_instances() pruned 1 instance inside box")
	check(lg_mm.instance_count == 1, "LowGrassMultiMesh instance_count reduced to 1")

	# -------------------------------------------------------------------------
	# 4. MultiMeshExclusionFilter Editor Property
	# -------------------------------------------------------------------------
	print("\n--- Test 4: MultiMeshExclusionFilter In-Editor Capabilities ---")
	var filter_node := MultiMeshExclusionFilter.new()
	check("auto_prune_in_editor" in filter_node, "MultiMeshExclusionFilter has auto_prune_in_editor property")
	check(filter_node.has_method(&"prune_all_foliage"), "MultiMeshExclusionFilter has prune_all_foliage method")

	print("\n--- Summary ---")
	if failures == 0:
		print("ALL PASS (0 failures)")
	else:
		print("FAILED (%d failures)" % failures)

	# Clean up
	zone.queue_free()
	tree_mmi.queue_free()
	grass_mmi.queue_free()
	gen.queue_free()
	grass_gen.queue_free()
	filter_node.queue_free()
	quit(failures)
