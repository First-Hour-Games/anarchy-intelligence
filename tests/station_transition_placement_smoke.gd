extends SceneTree

var checked := 0

func _initialize() -> void:
	run.call_deferred()

func world_transform(node: Node3D) -> Transform3D:
	var result := node.transform
	var parent := node.get_parent()
	while parent is Node3D:
		result = parent.transform * result
		parent = parent.get_parent()
	return result

func compare_layout(source: Node, destination: Node) -> void:
	assert(source.get_class() == destination.get_class(), "Prop type differs: " + str(source.name))
	if source is Node3D:
		assert(world_transform(source).is_equal_approx(world_transform(destination)),
			"Prop transform differs: " + str(source.name))
		checked += 1
	if source is MeshInstance3D and source.mesh != null:
		assert(destination.mesh != null and source.mesh.get_aabb().is_equal_approx(destination.mesh.get_aabb()),
			"Prop geometry differs: " + str(source.name))
	if source is CollisionShape3D:
		assert(source.disabled == destination.disabled, "Prop collision state differs: " + str(source.name))
		assert(source.shape.get_class() == destination.shape.get_class())
		if source.shape is BoxShape3D:
			assert(source.shape.size.is_equal_approx(destination.shape.size))
	assert(source.get_child_count() == destination.get_child_count(), "Prop children differ: " + str(source.name))
	for child in source.get_children():
		var other := destination.get_node_or_null(NodePath(child.name))
		assert(other != null, "Missing prop: " + str(child.name))
		compare_layout(child, other)

func run() -> void:
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as Node3D
	var residence := load("res://scenes/chapters/main/residence_area.tscn").instantiate() as Node3D
	var yard := residence.get_node("GasStationYard")
	for prop in yard.get_children():
		var source := forest.get_node_or_null(NodePath(prop.name))
		assert(source != null, "Yard prop no longer exists in Starting Forest: " + str(prop.name))
		compare_layout(source, prop)
	for path in ["GasStation", "StationApproach"]:
		compare_layout(forest.get_node(path), residence.get_node(path))
	for index in range(20, 44):
		assert(yard.has_node("Fence%d" % index), "Missing warehouse perimeter fence")
	var roadside := forest.get_node("ResidenceRoadsideCars")
	assert(roadside.get_child_count() == 10, "Missing Residence approach cars")
	assert(roadside.find_children("*", "CollisionObject3D", true, false).is_empty(), "Forest preview cars must have no physics bodies")
	assert(roadside.find_children("*", "CollisionShape3D", true, false).is_empty(), "Forest preview cars must have no collision shapes")
	for car: Node3D in roadside.get_children():
		var source := residence.get_node(NodePath(car.name)) as Node3D
		assert(world_transform(source).is_equal_approx(world_transform(car)), "Roadside car placement differs: " + str(car.name))
		var meshes := source.find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty())
		assert(meshes.size() == car.find_children("*", "MeshInstance3D", true, false).size())
		for mesh: MeshInstance3D in meshes:
			var preview := car.get_node(source.get_path_to(mesh)) as MeshInstance3D
			assert(world_transform(mesh).is_equal_approx(world_transform(preview)), "Roadside car mesh placement differs")
			assert(mesh.mesh == preview.mesh, "Roadside car model differs")
		assert(not source.find_children("*", "CollisionObject3D", true, false).is_empty(), "Residence cars retain collision")
	print("PASS: all 10 Residence approach cars match in Starting Forest with zero collision bodies or shapes")
	forest.free()
	residence.free()
	print("PASS: %d shared prop transforms, geometry and collision states match Starting Forest" % checked)
	quit()
