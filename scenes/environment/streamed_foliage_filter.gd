extends RefCounted
## One exclusion/spacing pass over all loaded sections, including nested grass batches.
var sources: Dictionary = {}
var last_stats: Dictionary = {}

func forget(generator: Node) -> void:
	for node in generator.find_children("*", "MultiMeshInstance3D", true, false):
		sources.erase(node.get_instance_id())

func apply(sections: Array, forest_path: String, seam_z: float, roads: Array[AABB], obstacles: Array[AABB], zones: Array[Dictionary], avoid_canopy_overlap: bool = true, preserve_authored_spacing: bool = false) -> Dictionary:
	var started := Time.get_ticks_msec()
	var entries: Array[Dictionary] = []
	var live_ids: Dictionary = {}
	var cell_size := 1.0
	var helper := ProceduralTreeGenerator.new()
	for section: Node3D in sections:
		var foliage := section.get_node_or_null("Foliage")
		if foliage == null:
			continue
		var spacing: float = foliage.min_tree_distance if foliage is ProceduralTreeGenerator else 3.3
		cell_size = maxf(cell_size, spacing)
		for node in foliage.find_children("*", "MultiMeshInstance3D", true, false):
			var current: MultiMesh = node.multimesh
			if current == null or current.mesh == null or current.transform_format != MultiMesh.TRANSFORM_3D:
				continue
			var id: int = node.get_instance_id()
			live_ids[id] = true
			if not sources.has(id) or sources[id].output != current:
				sources[id] = {"input": current.duplicate(), "output": current}
			var is_tree: bool = node.name.to_lower().contains("tree")
			if is_tree and avoid_canopy_overlap:
				var source: MultiMesh = sources[id].input
				var node_world := helper._get_node_global_xform(node)
				for i in source.instance_count:
					var world := node_world * source.get_instance_transform(i)
					var bounds: AABB = world * source.mesh.get_aabb()
					var reach := maxf(maxf(absf(bounds.position.x - world.origin.x), absf(bounds.end.x - world.origin.x)), maxf(absf(bounds.position.z - world.origin.z), absf(bounds.end.z - world.origin.z)))
					cell_size = maxf(cell_size, reach * 2.0)
			entries.append({"node": node, "section": section, "tree": is_tree, "spacing": spacing,
				"world": helper._get_node_global_xform(node), "id": id,
				"priority": helper._get_tree_priority(node.name) if is_tree else 10000})
	for id in sources.keys():
		if not live_ids.has(id):
			sources.erase(id)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.priority != b.priority:
			return a.priority < b.priority
		return str(a.section.scene_file_path) + str(a.section.get_path_to(a.node)) < str(b.section.scene_file_path) + str(b.section.get_path_to(b.node)))
	var grid: Dictionary = {}
	var stats := {"batches": entries.size(), "initial": 0, "kept": 0, "seam": 0, "obstacles": 0, "spacing": 0, "orientation": 0}
	for entry in entries:
		var original: MultiMesh = sources[entry.id].input
		var mesh_bounds := original.mesh.get_aabb()
		var model_up := helper.get_mesh_up_vector(original.mesh)
		var indices: Array[int] = []
		for i in original.instance_count:
			stats.initial += 1
			var local := original.get_instance_transform(i)
			var world: Transform3D = entry.world * local
			var forest: bool = entry.section.scene_file_path == forest_path
			if (forest and world.origin.z >= seam_z) or (not forest and world.origin.z < seam_z):
				stats.seam += 1
				continue
			if entry.tree and (world.basis * model_up).y < -0.05:
				stats.orientation += 1
				continue
			var bounds: AABB = world * mesh_bounds
			if overlaps_obstacles(bounds, entry.tree, roads, obstacles, zones):
				stats.obstacles += 1
				continue
			if entry.tree:
				var cell := Vector2i(floori(world.origin.x / cell_size), floori(world.origin.z / cell_size))
				var clash := false
				for dx in range(-1, 2):
					for dz in range(-1, 2):
						for prior: Dictionary in grid.get(cell + Vector2i(dx, dz), []):
							# Authored neighbors belong to the scene's density design. Only
							# resolve new conflicts introduced by loading another section.
							if preserve_authored_spacing and prior.section == entry.section:
								continue
							var distance: float = maxf(entry.spacing, prior.spacing)
							var offset: Vector3 = world.origin - prior.point
							if Vector2(offset.x, offset.z).length_squared() < distance * distance or (avoid_canopy_overlap and bounds.grow(0.15).intersects(prior.bounds)):
								clash = true
				if clash:
					stats.spacing += 1
					continue
				if not grid.has(cell):
					grid[cell] = []
				grid[cell].append({"point": world.origin, "spacing": entry.spacing, "bounds": bounds, "section": entry.section})
			indices.append(i)
			stats.kept += 1
		var filtered: MultiMesh = original.duplicate()
		filtered.instance_count = indices.size()
		var visible_count := 0
		for i in indices.size():
			var source_index := indices[i]
			if original.visible_instance_count < 0 or source_index < original.visible_instance_count:
				visible_count += 1
			filtered.set_instance_transform(i, original.get_instance_transform(source_index))
			if original.use_colors:
				filtered.set_instance_color(i, original.get_instance_color(source_index))
			if original.use_custom_data:
				filtered.set_instance_custom_data(i, original.get_instance_custom_data(source_index))
		filtered.visible_instance_count = -1 if original.visible_instance_count < 0 else visible_count
		entry.node.multimesh = filtered
		sources[entry.id].output = filtered
	helper.free()
	stats["elapsed_ms"] = Time.get_ticks_msec() - started
	last_stats = stats
	return stats

func overlaps_obstacles(bounds: AABB, is_tree: bool, roads: Array[AABB], obstacles: Array[AABB], zones: Array[Dictionary]) -> bool:
	# Project the full mesh footprint onto the road, including branches and grass blades.
	var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(0.15)
	for road in roads:
		if footprint.intersects(Rect2(Vector2(road.position.x, road.position.z), Vector2(road.size.x, road.size.z))):
			return true
	for obstacle in obstacles:
		if bounds.grow(0.15).intersects(obstacle):
			return true
	for zone in zones:
		if not is_tree and not zone.grass:
			continue
		# Transform the mesh bounds into the authored zone's coordinate system.
		var local: AABB = zone.inverse * bounds
		if local.intersects(zone.bounds):
			return true
	return false
