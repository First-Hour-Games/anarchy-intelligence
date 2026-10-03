extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Testing MultiMeshExclusionFilter & Auto-Pruning ---")
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var root_node := scene.instantiate()

	var foliage := root_node.get_node_or_null("Foliage")
	var grass_node := foliage.get_node_or_null("lowGrassMulti") as MultiMeshInstance3D
	var visitor_center := root_node.get_node_or_null("welcomeCenterTextured2") as Node3D

	if not grass_node:
		printerr("FAIL: lowGrassMulti node not found!")
		quit(1)
		return

	if not visitor_center:
		printerr("FAIL: welcomeCenterTextured2 node not found!")
		quit(1)
		return

	print("Initial packed grass instance count: ", grass_node.multimesh.instance_count)
	if grass_node.multimesh.instance_count != 1000:
		printerr("FAIL: Expected 1000 initial grass instances in packed scene, got: ", grass_node.multimesh.instance_count)
		quit(1)
		return

	# Adding to tree triggers _ready() and auto_prune_on_ready
	root.add_child(root_node)

	print("Grass instance count after entering tree (_ready auto-prune): ", grass_node.multimesh.instance_count)
	var pruned_on_ready := 1000 - grass_node.multimesh.instance_count
	print("Instances automatically pruned on ready: ", pruned_on_ready)

	if pruned_on_ready <= 0:
		printerr("FAIL: Grass was not automatically pruned on ready!")
		quit(1)
		return

	# Now verify that no instances remain inside the visitor center AABB
	var aabbs: Array[AABB] = grass_node.call("get_exclusion_aabbs")
	print("Found exclusion AABBs: ", aabbs.size())
	for i in range(aabbs.size()):
		print("  AABB [", i, "]: position=", aabbs[i].position, " size=", aabbs[i].size, " end=", aabbs[i].end)

	var buf: PackedFloat32Array = grass_node.multimesh.buffer
	var remaining_count := grass_node.multimesh.instance_count
	var any_inside := 0
	for i in range(remaining_count):
		var base := i * 12
		var local_orig := Vector3(buf[base + 3], buf[base + 7], buf[base + 11])
		var gpos: Vector3 = grass_node.global_transform * local_orig
		for box in aabbs:
			if grass_node.call("_is_point_inside_aabb", gpos, box, 0.0):
				any_inside += 1

	print("Grass instances still inside visitor center: ", any_inside)
	if any_inside > 0:
		printerr("FAIL: ", any_inside, " grass instances still inside visitor center!")
		quit(1)
		return

	# Test calling prune_instances() again (should prune 0 now that it's clean)
	var second_prune: int = grass_node.call("prune_instances")
	print("Second prune removed: ", second_prune)
	if second_prune != 0:
		printerr("FAIL: Second prune should remove 0 instances, removed: ", second_prune)
		quit(1)
		return

	root_node.queue_free()
	print("ALL MULTIMESH EXCLUSION CHECKS PASSED!")
	quit(0)
