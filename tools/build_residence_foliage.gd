extends SceneTree

## Rebuilds the residence's baked foliage using the starting forest tree palette.
## Run with the normal renderer so MultiMesh transforms are retained when saving.
func _init() -> void:
	call_deferred("_build")

func _build() -> void:
	var residence: Node3D = load("res://scenes/chapters/main/residence_area.tscn").instantiate()
	var forest: Node3D = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	var existing := residence.get_node_or_null("Foliage")
	if existing:
		residence.remove_child(existing)
		existing.free()
	var foliage := ProceduralTreeGenerator.new()
	foliage.name = "Foliage"
	residence.add_child(foliage)
	foliage.scatter_strength = 0.95
	foliage.placement_density = 0.65
	foliage.grid_step = 9.0
	foliage.min_tree_distance = 6.0
	foliage.ground_y = -0.001
	foliage.random_seed = 261026
	foliage.road_exclusion_margin = 5.0
	foliage.exclusion_margin = 5.0
	foliage.tree_scale_multiplier = 1.2
	foliage.custom_placement_nodes.append(NodePath("TreePlacement"))
	foliage.exclusion_nodes.append(NodePath("../ResidentialStreet/RoadSurface/Turnaround"))
	# Keep the clearing action scoped to this map instead of the forest welcome center.
	foliage.clearing_x_range = Vector2(-340, 340)
	foliage.clearing_z_range = Vector2(-60, 420)
	var placement := MeshInstance3D.new()
	placement.name = "TreePlacement"
	placement.mesh = BoxMesh.new()
	placement.mesh.size = Vector3(680, 2, 480)
	placement.position = Vector3(0, 0, 180)
	placement.visible = false
	foliage.add_child(placement)
	placement.owner = foliage
	for source in forest.get_node("Foliage").get_children():
		if source is MultiMeshInstance3D and source.name.to_lower().contains("tree"):
			var trees := MultiMeshInstance3D.new()
			trees.name = source.name
			trees.multimesh = MultiMesh.new()
			trees.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			trees.multimesh.mesh = source.multimesh.mesh
			foliage.add_child(trees)
			trees.owner = foliage
	var result := foliage.regenerate_all_trees()
	var count := 0
	var exclusions := foliage.get_all_exclusion_aabbs()
	for trees in foliage._collect_tree_multimeshes():
		count += trees.multimesh.instance_count
		for i in trees.multimesh.instance_count:
			var point := trees.multimesh.get_instance_transform(i).origin
			assert(absf(point.y - foliage.ground_y) < 0.01, "Tree ground height")
			assert(absf(point.x) <= 340 and point.z >= -60 and point.z <= 420, "Tree placement bounds")
			for box in exclusions:
				assert(not box.has_point(point), "Tree overlaps road exclusion")
	assert(count > 0, "No trees generated")
	var packed := PackedScene.new()
	assert(packed.pack(foliage) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/environment/residence_foliage.tscn") == OK)
	var saved: Node3D = ResourceLoader.load("res://scenes/environment/residence_foliage.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	var saved_count := 0
	for trees in saved.get_children():
		if trees is MultiMeshInstance3D:
			saved_count += trees.multimesh.instance_count
			for i in trees.multimesh.instance_count:
				assert(trees.multimesh.get_instance_transform(i).is_equal_approx(foliage.get_node(NodePath(trees.name)).multimesh.get_instance_transform(i)), "Saved transform differs")
	assert(saved_count == count, "Saved instance count differs")
	saved.free()
	print("Residence foliage saved: %d trees, %d road exclusions. %s" % [count, exclusions.size(), result])
	residence.free()
	forest.free()
	quit()
