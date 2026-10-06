extends SceneTree
## Run with the normal renderer; Godot's headless dummy renderer does not retain MultiMesh transforms.

const Generator = preload("res://scenes/environment/procedural_tree_generator.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failures += 1

func _init() -> void:
	var gen = Generator.new()
	gen.auto_detect_landmarks = false
	gen.fallback_area_size = Vector2(24, 24)
	gen.fallback_area_offset = Vector3.ZERO
	gen.grid_step = 6.0
	gen.scatter_strength = 0.0
	gen.tree_scale_ranges.clear()
	gen.tree_scale_ranges["treeMulti2"] = Vector2(3, 2)
	gen.tree_scale_multiplier = 2.0
	gen.yaw_range_degrees = Vector2(90, 90)
	var node := MultiMeshInstance3D.new()
	node.name = "treeMulti2"
	node.transform = Transform3D(Basis(Vector3.UP, 0.4).scaled(Vector3.ONE * 1.5), Vector3(2, 1, 3))
	node.multimesh = MultiMesh.new()
	node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 5, 1)
	mesh.get_mesh_arrays()
	node.multimesh.mesh = mesh
	gen.add_child(node)
	gen.regenerate_all_trees()
	check(node.multimesh.instance_count == 16, "Full density populates all grid cells")
	var first := node.multimesh.buffer.duplicate()
	for i in range(node.multimesh.instance_count):
		var world: Transform3D = node.transform * node.multimesh.get_instance_transform(i)
		check(world.basis.x.length() >= 3.999 and world.basis.x.length() <= 6.001, "Reversed scale endpoints normalized and multiplier applied")
		# Centered BoxMesh is classified as Y-down by the mesh orientation heuristic.
		check(world.basis.x.normalized().distance_to(Vector3(0, 0, 1)) < 0.0001, "Yaw uses world vertical axis after mesh up correction")
		check((world.basis * gen.get_mesh_up_vector(mesh)).normalized().distance_to(Vector3.UP) < 0.0001, "Mesh remains upright")
		check(is_equal_approx(world.origin.y, gen.ground_y), "Ground height preserved under transformed parent")
	gen.regenerate_all_trees()
	check(first == node.multimesh.buffer, "Same seed reproduces generation")
	var origin := node.multimesh.get_instance_transform(0).origin
	gen.tree_scale_ranges.clear()
	gen.tree_scale_ranges["treemulti2"] = Vector2(1, 1)
	gen.randomize_existing_tree_variation()
	check(node.multimesh.get_instance_transform(0).origin == origin, "Variation preserves existing positions")
	check(is_equal_approx((node.transform.basis * node.multimesh.get_instance_transform(0).basis).x.length(), 2.0), "Variation updates existing scale")
	gen.scatter_strength = 1.0
	gen.regenerate_all_trees()
	check(node.multimesh.get_instance_transform(0).origin != origin, "Scatter changes positions")
	gen.placement_density = 0.0
	gen.regenerate_all_trees()
	check(node.multimesh.instance_count == 0, "Zero density generates no trees")
	gen.free()
	print("Tree variation tests: %d failures" % failures)
	quit(failures)
