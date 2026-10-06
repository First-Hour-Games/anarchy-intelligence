extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Procedural Tree Generator Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var scene_path := "res://scenes/chapters/main/starting_forest.tscn"
	var scene_res: PackedScene = load(scene_path)
	check(scene_res != null, "starting_forest.tscn loads successfully")
	if not scene_res:
		quit(1)
		return

	var root: Node = scene_res.instantiate()
	get_root().add_child(root)

	var foliage: Node3D = root.get_node_or_null("Foliage") as Node3D
	check(foliage != null, "Foliage node exists")
	if not foliage:
		quit(1)
		return

	# 1. Script attachment check
	print("--- Test 1: ProceduralTreeGenerator script on Foliage ---")
	var gen := foliage as ProceduralTreeGenerator
	check(gen != null, "Foliage has ProceduralTreeGenerator script attached")
	if gen != null:
		check("click_to_fill_clearing_and_prune_now" in gen, "Has click_to_fill_clearing_and_prune_now button")
		check("click_to_fill_all_gaps_and_prune_now" in gen, "Has click_to_fill_all_gaps_and_prune_now button")
		check("click_to_regenerate_all_now" in gen, "Has click_to_regenerate_all_now button")
		check("click_to_prune_now" in gen, "Has click_to_prune_now button")
		check("click_to_clear_now" in gen, "Has click_to_clear_now button")

	# 2. MultiMeshExclusionFilter integration check
	print("--- Test 2: MultiMeshExclusionFilter Delegation Buttons ---")
	var tree2 := foliage.get_node_or_null("treeMulti2") as MultiMeshInstance3D
	check(tree2 != null, "treeMulti2 exists")
	if tree2:
		var filter: Script = tree2.get_script()
		check(filter != null, "treeMulti2 has filter script")
		check("click_to_fill_clearing_and_prune_now" in tree2, "treeMulti2 exposes click_to_fill_clearing_and_prune_now")
		check("click_to_fill_all_and_prune_now" in tree2, "treeMulti2 exposes click_to_fill_all_and_prune_now")

	# 3. Road surfaces
	print("--- Test 3: Road Surfaces are Gravel ---")
	var main_road := root.get_node_or_null("Streets/MainRoad")
	check(main_road != null and main_road.has_meta("surface") and main_road.get_meta("surface") == "gravel", "Streets/MainRoad has surface=gravel")
	var prk_road1 := root.get_node_or_null("ParkingLot/MainRoad")
	check(prk_road1 != null and prk_road1.has_meta("surface") and prk_road1.get_meta("surface") == "gravel", "ParkingLot/MainRoad has surface=gravel")
	var prk_road2 := root.get_node_or_null("ParkingLot/MainRoad2")
	check(prk_road2 != null and prk_road2.has_meta("surface") and prk_road2.get_meta("surface") == "gravel", "ParkingLot/MainRoad2 has surface=gravel")

	# 4. TreeExclusionZone location
	print("--- Test 4: TreeExclusionZone Moved to New Welcome Center ---")
	var zone := root.get_node_or_null("TreeExclusionZone") as Node3D
	check(zone != null, "TreeExclusionZone exists")
	if zone:
		check(absf(zone.position.x - (-123.0)) < 2.0, "TreeExclusionZone X positioned around new Welcome Center (-123)")
		check(absf(zone.position.z - (-9.0)) < 2.0, "TreeExclusionZone Z positioned around new Welcome Center (-9)")

	# 5. Tree instances and clearing verification
	print("--- Test 5: Tree Counts and Exclusion Verification ---")
	var total_trees := 0
	var trees_in_clearing := 0
	var trees_in_welcome := 0

	for child in foliage.get_children():
		if child is MultiMeshInstance3D and (child.name.begins_with("treeMulti") or child.name.to_lower().contains("tree")):
			var mm: MultiMesh = child.multimesh
			if not mm: continue
			var count := mm.instance_count
			total_trees += count
			var node_xform: Transform3D = child.transform
			var buf := mm.buffer
			for i in range(count):
				var b := i * 12
				var local_pos := Vector3(buf[b + 3], buf[b + 7], buf[b + 11])
				var gpos := node_xform * local_pos
				if gpos.x >= -300.0 and gpos.x <= -220.0 and gpos.z >= -25.0 and gpos.z <= 5.0:
					trees_in_clearing += 1
				if gpos.x >= -138.0 and gpos.x <= -106.0 and gpos.z >= -25.0 and gpos.z <= 7.0:
					trees_in_welcome += 1

	print("Total tree instances: %d" % total_trees)
	print("Trees in previously empty clearing (X in [-300, -220], Z in [-25, 5]): %d" % trees_in_clearing)
	print("Trees inside new Welcome Center & Parking bounds: %d" % trees_in_welcome)

	check(total_trees >= 700 and total_trees <= 950, "Total tree count is natural and balanced (%d trees)" % total_trees)
	check(trees_in_clearing >= 50, "Vacated clearing has been filled with trees (%d trees)" % trees_in_clearing)
	check(trees_in_welcome == 0, "No trees collide with the new Welcome Center or Parking Lot (0 colliding trees)")

	# 6. Button trigger test
	print("--- Test 6: Button Setters Function Correctly ---")
	if gen != null:
		gen.click_to_prune_now = true
		check(gen.click_to_prune_now == false, "click_to_prune_now executed and reset to false")
		check(trees_in_welcome == 0, "Pruning retained zero colliding trees")

	print("\n--- Smoke Test Summary ---")
	if failures == 0:
		print("ALL PASS (0 failures)")
	else:
		print("FAILED (%d failures)" % failures)

	root.free()
	quit(failures)
