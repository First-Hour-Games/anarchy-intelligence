extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Procedural Grass Generator Tests ---")

	# 1. Load starting forest scene to test against real map geometry and landmarks
	var forest_scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	assert(forest_scene != null, "starting_forest.tscn must load")
	var root_node := forest_scene.instantiate() as Node3D
	root.add_child(root_node)

	# 2. Create ProceduralGrassGenerator and attach to scene
	var gen_script := load("res://scenes/environment/procedural_grass_generator.gd") as GDScript
	assert(gen_script != null, "procedural_grass_generator.gd must load")

	var generator := Node3D.new()
	generator.name = "ProceduralGrass"
	generator.set_script(gen_script)

	# Configure generation properties
	generator.set("area_size", Vector2(400.0, 300.0))
	generator.set("area_center_offset", Vector3(-100.0, 0.0, 50.0))
	generator.set("low_grass_count", 600)
	generator.set("tall_grass_count", 150)
	generator.set("exclusion_margin", 2.0)
	generator.set("fallback_ground_y", 0.0)

	root_node.add_child(generator)

	# 3. Test exclusion AABBs discovery
	var aabbs: Array[AABB] = generator.call("get_exclusion_aabbs")
	print("Discovered exclusion AABBs from starting forest: ", aabbs.size())
	assert(aabbs.size() > 0, "Must detect landmark AABBs (visitor center, roads, parking lot)")

	# Verify visitor center is among exclusion AABBs
	var visitor_center := root_node.get_node_or_null("welcomeCenterTextured2") as Node3D
	assert(visitor_center != null, "welcomeCenterTextured2 must exist in starting forest")
	var vc_pos: Vector3 = visitor_center.global_position
	print("Visitor center global position: ", vc_pos)
	assert(generator.call("is_point_excluded", vc_pos), "Visitor center position must be excluded!")

	# Verify road center is among exclusion AABBs
	var road := root_node.get_node_or_null("Streets/MainRoad") as Node3D
	if road:
		var road_pos: Vector3 = road.global_position
		print("Main road global position: ", road_pos)
		assert(generator.call("is_point_excluded", road_pos), "MainRoad position must be excluded!")

	# 4. Generate grass
	var stats: Dictionary = generator.call("generate_grass")
	print("Generation stats: ", stats)
	assert(stats["low_grass_count"] > 0, "Must generate low grass instances")
	assert(stats["tall_grass_count"] > 0, "Must generate tall grass instances")

	var low_node: MultiMeshInstance3D = generator.call("get_low_grass_node")
	var tall_node: MultiMeshInstance3D = generator.call("get_tall_grass_node")
	assert(low_node != null, "LowGrassMultiMesh must be created")
	assert(tall_node != null, "TallGrassMultiMesh must be created")
	assert(low_node.multimesh != null, "Low grass MultiMesh must exist")
	assert(tall_node.multimesh != null, "Tall grass MultiMesh must exist")

	var low_mm: MultiMesh = low_node.multimesh
	var tall_mm: MultiMesh = tall_node.multimesh
	assert(low_mm.instance_count == stats["low_grass_count"], "Low grass instance count must match")
	assert(tall_mm.instance_count == stats["tall_grass_count"], "Tall grass instance count must match")

	# 5. Verify no grass spawned inside any exclusion AABBs
	var low_buf: PackedFloat32Array = low_mm.buffer
	var low_violators := 0
	for i in range(low_mm.instance_count):
		var base := i * 12
		var local_orig := Vector3(low_buf[base + 3], low_buf[base + 7], low_buf[base + 11])
		var gpos: Vector3 = low_node.global_transform * local_orig
		for box in aabbs:
			var pad: float = 0.0 # Strict check inside actual box
			if gpos.x >= (box.position.x - pad) and gpos.x <= (box.end.x + pad) and \
			   gpos.z >= (box.position.z - pad) and gpos.z <= (box.end.z + pad) and \
			   gpos.y >= (box.position.y - 2.0) and gpos.y <= (box.end.y + 2.0):
				low_violators += 1

	print("Low grass instances inside exclusion zones: ", low_violators)
	assert(low_violators == 0, "No low grass should spawn inside exclusion zones!")

	var tall_buf: PackedFloat32Array = tall_mm.buffer
	var tall_violators := 0
	for i in range(tall_mm.instance_count):
		var base := i * 12
		var local_orig := Vector3(tall_buf[base + 3], tall_buf[base + 7], tall_buf[base + 11])
		var gpos: Vector3 = tall_node.global_transform * local_orig
		for box in aabbs:
			var pad: float = 0.0
			if gpos.x >= (box.position.x - pad) and gpos.x <= (box.end.x + pad) and \
			   gpos.z >= (box.position.z - pad) and gpos.z <= (box.end.z + pad) and \
			   gpos.y >= (box.position.y - 2.0) and gpos.y <= (box.end.y + 2.0):
				tall_violators += 1

	print("Tall grass instances inside exclusion zones: ", tall_violators)
	assert(tall_violators == 0, "No tall grass should spawn inside exclusion zones!")

	# 6. Verify custom_aabb and visibility_range_end (prevents culling when camera enters visitor center)
	print("Low grass custom_aabb: ", low_node.custom_aabb)
	print("Tall grass custom_aabb: ", tall_node.custom_aabb)
	assert(low_node.custom_aabb.size.length_squared() > 100.0, "Low grass custom_aabb must enclose the spawn area")
	assert(tall_node.custom_aabb.size.length_squared() > 100.0, "Tall grass custom_aabb must enclose the spawn area")
	assert(low_node.visibility_range_end == 0.0, "visibility_range_end must be 0.0 (disabled) to avoid culling across map")
	assert(tall_node.visibility_range_end == 0.0, "visibility_range_end must be 0.0 (disabled) to avoid culling across map")

	if low_mm.instance_count > 0:
		var s := Vector3(low_buf[0], low_buf[4], low_buf[8]).length()
		print("Low grass sample scale: ", s)
		assert(s >= 2.9 and s <= 5.1, "Low grass scale should be between 3.0 and 5.0")

	if tall_mm.instance_count > 0:
		var s := Vector3(tall_buf[0], tall_buf[4], tall_buf[8]).length()
		print("Tall grass sample scale: ", s)
		assert(s >= 2.1 and s <= 2.7, "Tall grass scale should be between 2.2 and 2.6")

	# 7. Test clear_grass
	generator.call("clear_grass")
	assert(low_mm.instance_count == 0, "Low grass instance count must be 0 after clear")
	assert(tall_mm.instance_count == 0, "Tall grass instance count must be 0 after clear")
	assert(low_node.custom_aabb == AABB(), "Low grass custom_aabb must be reset after clear")
	print("PASS: Clear grass works correctly")

	generator.queue_free()

	# 8. Test standalone procedural_grass.tscn scene loading and generation
	var pgrass_scene := load("res://scenes/environment/procedural_grass.tscn") as PackedScene
	assert(pgrass_scene != null, "procedural_grass.tscn must load")
	var pgrass := pgrass_scene.instantiate() as Node3D
	assert(pgrass != null, "procedural_grass.tscn must instantiate")
	root_node.add_child(pgrass)

	pgrass.set("low_grass_count", 300)
	pgrass.set("tall_grass_count", 80)
	var scene_stats: Dictionary = pgrass.call("generate_grass")
	assert(scene_stats["low_grass_count"] == 300, "Must generate 300 low grass from scene")
	assert(scene_stats["tall_grass_count"] == 80, "Must generate 80 tall grass from scene")
	print("PASS: Standalone procedural_grass.tscn successfully instantiated and generated!")

	root_node.queue_free()
	print("--- ALL PROCEDURAL GRASS GENERATOR TESTS PASSED! ---")
	quit(0)
