extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var helper := ProceduralTreeGenerator.new()
	var turnaround := CSGCylinder3D.new()
	turnaround.radius = 14.0
	turnaround.height = 0.4
	turnaround.position = Vector3(-97, -0.1, 135)
	var bounds := helper._calculate_node_world_aabb(turnaround)
	assert(bounds.position.is_equal_approx(Vector3(-111, -0.3, 121)))
	assert(bounds.size.is_equal_approx(Vector3(28, 0.4, 28)), "Unbaked circular road must have exclusion bounds")
	print("PASS: circular road has accurate bounds before entering the scene tree")
	turnaround.free()
	helper.free()

	var stream := root.get_node("WorldStreaming")
	var forest := Node3D.new()
	forest.scene_file_path = stream.FOREST
	var foliage := Node3D.new()
	foliage.name = "Foliage"
	forest.add_child(foliage)
	var trees := MultiMeshInstance3D.new()
	trees.name = "treeMulti"
	foliage.add_child(trees)
	var original := MultiMesh.new()
	original.transform_format = MultiMesh.TRANSFORM_3D
	original.mesh = BoxMesh.new()
	original.instance_count = 2
	original.set_instance_transform(0, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(0, 0, 50)))
	original.set_instance_transform(1, Transform3D(Basis(Vector3.RIGHT, PI), Vector3(20, 0, 50)))
	trees.multimesh = original
	var residence := Node3D.new()
	var roads := Node3D.new()
	roads.name = "ResidentialStreet"
	residence.add_child(roads)
	var road := CSGBox3D.new()
	road.name = "MainRoad"
	road.size = Vector3(10, 0.4, 10)
	road.position.z = 50
	roads.add_child(road)
	stream._cache_road_bounds(residence)
	residence.free()
	stream._partition_trees(forest)
	assert(trees.multimesh.instance_count == 1, "A tree must respect roads authored in the other section")
	assert(trees.multimesh.get_instance_transform(0).origin.is_equal_approx(Vector3(20, 0, 50)))
	assert(original.instance_count == 2, "Cached scene resources must remain unchanged")
	print("PASS: foreign road exclusions survive duplicate removal and preserve cached foliage")
	forest.free()
	stream._reset()
	quit()
