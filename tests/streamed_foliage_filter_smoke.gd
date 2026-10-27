extends SceneTree

const Filter = preload("res://scenes/environment/streamed_foliage_filter.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error(message)

func section(path: String) -> Node3D:
	var node := Node3D.new()
	node.scene_file_path = path
	var foliage := Node3D.new()
	foliage.name = "Foliage"
	node.add_child(foliage)
	return node

func batch(parent: Node, node_name: String, points: Array[Vector3], size: Vector3 = Vector3.ONE) -> MultiMeshInstance3D:
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var mesh := BoxMesh.new()
	mesh.size = size
	mm.mesh = mesh
	mm.instance_count = points.size()
	for i in points.size():
		# Symmetric BoxMesh's model-up heuristic is -Y.
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.RIGHT, PI), points[i]))
		mm.set_instance_color(i, Color(0.2 + i * 0.1, 0.4, 0.6, 1))
		mm.set_instance_custom_data(i, Color(0.1, i * 0.2, 0.3, 1))
	node.multimesh = mm
	parent.add_child(node)
	return node

func run() -> void:
	var forest_path: String = root.get_node("WorldStreaming").FOREST
	var forest := section(forest_path)
	var residence := section("res://scenes/chapters/main/residence_area.tscn")
	var nested := Node3D.new()
	nested.name = "GrassGenerator"
	nested.position = Vector3(100, 0, 50)
	nested.rotation.y = PI * 0.5
	forest.get_node("Foliage").add_child(nested)
	var grass := batch(nested, "LowGrassMultiMesh", [Vector3.ZERO, Vector3(0, 0, 10)])
	var original_grass := grass.multimesh
	var kept_color := original_grass.get_instance_color(1)
	var kept_data := original_grass.get_instance_custom_data(1)
	var canopy := batch(forest.get_node("Foliage"), "treeMulti2", [Vector3(9, 0, 50)], Vector3(4, 4, 4))
	var first := batch(forest.get_node("Foliage"), "treeMulti9", [Vector3(40, 0, 68)], Vector3(8, 8, 8))
	var second := batch(residence.get_node("Foliage"), "treeMulti3", [Vector3(40, 0, 73)], Vector3(8, 8, 8))
	var building := batch(forest.get_node("Foliage"), "BushMulti", [Vector3(20, 0, 50)])
	var zone_grass := batch(forest.get_node("Foliage"), "TallGrassMultiMesh", [Vector3(60, 0, 50)])
	var roads: Array[AABB] = [AABB(Vector3(0, -1, 45), Vector3(8, 2, 10)), AABB(Vector3(99, -1, 49), Vector3(2, 2, 2))]
	var obstacles: Array[AABB] = [AABB(Vector3(19, -1, 49), Vector3(2, 2, 2))]
	var zone_world := Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(60, 0, 50))
	var zones: Array[Dictionary] = [{"inverse": zone_world.affine_inverse(), "bounds": AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4)), "grass": true}]
	var filter = Filter.new()
	var stats: Dictionary = filter.apply([forest, residence], forest_path, 69.0, roads, obstacles, zones)
	check(canopy.multimesh.instance_count == 0, "branches are excluded when the trunk is outside the road")
	check(grass.multimesh.instance_count == 1, "nested rotated grass uses world-space exclusion bounds")
	check(grass.multimesh.use_colors and grass.multimesh.get_instance_color(0).is_equal_approx(kept_color), "instance colors survive compaction")
	check(grass.multimesh.use_custom_data and grass.multimesh.get_instance_custom_data(0).is_equal_approx(kept_data), "custom shader data survives compaction")
	check(original_grass.instance_count == 2, "cached source MultiMeshes stay unchanged")
	check(first.multimesh.instance_count == 1 and second.multimesh.instance_count == 0, "tree priority and canopy clearance apply across scene boundary")
	check(building.multimesh.instance_count == 0 and zone_grass.multimesh.instance_count == 0, "all foliage respects building and rotated grass-exclusion volumes")
	var repeated: Dictionary = filter.apply([forest, residence], forest_path, 69.0, roads, obstacles, zones)
	check(repeated.kept == stats.kept, "repeated streaming checks do not progressively delete foliage")
	filter.apply([forest, residence], forest_path, 69.0, [], [], [])
	check(grass.multimesh.instance_count == 2 and canopy.multimesh.instance_count == 1, "removing exclusions restores source instances")
	# A generator may repopulate its existing MultiMesh rather than allocate a new resource.
	grass.multimesh.instance_count = 2
	grass.multimesh.set_instance_transform(0, Transform3D(Basis.IDENTITY, Vector3.ZERO))
	grass.multimesh.set_instance_transform(1, Transform3D(Basis.IDENTITY, Vector3(0, 0, 15)))
	filter.forget(nested)
	filter.apply([forest, residence], forest_path, 69.0, roads, obstacles, zones)
	check(grass.multimesh.instance_count == 1, "regenerated nested foliage is checked again")
	var dense_forest := section(forest_path)
	var dense_residence := section("res://scenes/chapters/main/residence_area.tscn")
	var authored := batch(dense_forest.get_node("Foliage"), "treeMulti9", [Vector3(0, 0, 65), Vector3(3, 0, 65), Vector3(20, 0, 65)], Vector3(8, 8, 8))
	var seam_neighbor := batch(dense_residence.get_node("Foliage"), "treeMulti3", [Vector3(3, 0, 72)], Vector3(8, 8, 8))
	var dense_roads: Array[AABB] = [AABB(Vector3(18, -1, 60), Vector3(4, 2, 10))]
	var density_filter = Filter.new()
	density_filter.apply([dense_forest, dense_residence], forest_path, 69.0, dense_roads, [], [], true, true)
	check(authored.multimesh.instance_count == 2, "authored close neighbors survive while road-overlapping trees are removed")
	check(seam_neighbor.multimesh.instance_count == 0, "preserving authored density still removes cross-section canopy conflicts")
	density_filter.apply([dense_forest, dense_residence], forest_path, 69.0, dense_roads, [], [], true, true)
	check(authored.multimesh.instance_count == 2, "repeated reconciliation preserves authored density")
	density_filter.apply([dense_forest, dense_residence], forest_path, 69.0, dense_roads, [], [], true, false)
	check(authored.multimesh.instance_count == 1, "strict within-section spacing remains available")
	dense_forest.free()
	dense_residence.free()
	forest.free()
	residence.free()
	print("Streamed foliage filter: %d failures" % failures)
	quit(1 if failures else 0)
