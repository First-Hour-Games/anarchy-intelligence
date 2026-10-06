extends RefCounted

const TreeAnchor = preload("res://scenes/atmosphere/apparition_tree_anchor.gd")

static func sections(parts: Array[Dictionary], ground_y: float, bounds: AABB) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	# Measure the visible boundary at coat, shoulder, and hat heights.
	for height: float in [0.65, 1.20, 1.80, 2.40]:
		var plane_y := clampf(ground_y + height, bounds.position.y + 0.001, bounds.end.y - 0.001)
		var points := PackedVector3Array()
		for part: Dictionary in parts:
			var faces: PackedVector3Array = part["faces"]
			var transform: Transform3D = part["transform"]
			for index in range(0, faces.size(), 3):
				var vertices: Array[Vector3] = [transform * faces[index], transform * faces[index + 1], transform * faces[index + 2]]
				for edge in 3:
					var start := vertices[edge]
					var end := vertices[(edge + 1) % 3]
					if (start.y < plane_y and end.y >= plane_y) or (end.y < plane_y and start.y >= plane_y):
						points.append(start.lerp(end, (plane_y - start.y) / (end.y - start.y)))
		if points.size() < 2:
			return []
		result.append(points)
	return result

static func from_mesh(mesh: Mesh, transform: Transform3D, source: Node3D) -> Dictionary:
	var bounds: AABB = transform * mesh.get_aabb()
	if bounds.size.y < 0.5 or maxf(bounds.size.x, bounds.size.z) < 0.15:
		return {}
	return {"source": source, "mesh": mesh, "local_bounds": mesh.get_aabb(), "transform": transform, "bounds": bounds, "name": str(source.name), "close_cover": is_close_cover(source)}

static func is_close_cover(source: Node) -> bool:
	var path := str(source.get_path()).to_lower()
	return "sign" in path or "board" in path or "mapstand" in path

static func refresh(cover: Dictionary, solid_cache: Dictionary) -> bool:
	var source := cover["source"] as Node3D
	if not is_instance_valid(source) or not source.is_visible_in_tree():
		return false
	var mesh: Mesh = cover["mesh"]
	if source is MeshInstance3D:
		var visual := source as MeshInstance3D
		mesh = visual.mesh
		var material := visual.material_override as BaseMaterial3D
		if mesh == null or (material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			return false
	var transform := source.global_transform
	if cover.has("local_transform"):
		transform *= cover["local_transform"] as Transform3D
	if source is CSGShape3D:
		var meshes := (source as CSGShape3D).get_meshes()
		if meshes.size() != 2:
			return false
		mesh = meshes[1] as Mesh
		transform *= meshes[0] as Transform3D
	var local_bounds := mesh.get_aabb()
	var resized: bool = cover.get("local_bounds", local_bounds) != local_bounds
	if resized:
		solid_cache.erase(mesh)
	if not solid_cache.has(mesh):
		solid_cache[mesh] = TreeAnchor.bark_faces(mesh)
	var faces: PackedVector3Array = solid_cache[mesh]
	if faces.is_empty():
		return false
	if not cover.has("parts") or resized or cover["transform"] != transform or cover["mesh"] != mesh:
		var parts: Array[Dictionary] = [{"faces": faces, "transform": transform}]
		cover["parts"] = parts
		cover["transform"] = transform
		cover["mesh"] = mesh
		cover["local_bounds"] = local_bounds
		cover["bounds"] = transform * local_bounds
		cover.erase("world_faces")
		cover.erase("anchor_sections")
		cover.erase("ground_sections")
	return true

static func cached_sections(cover: Dictionary, ground_y: float, key: StringName) -> Array[PackedVector3Array]:
	var cached: Dictionary = cover.get(key, {})
	if cached.is_empty() or not is_equal_approx(cached["ground_y"], ground_y):
		cached = {"ground_y": ground_y, "sections": sections(cover["parts"], ground_y, cover["bounds"])}
		cover[key] = cached
	return cached["sections"]

static func world_faces(cover: Dictionary) -> PackedVector3Array:
	if not cover.has("world_faces"):
		cover["world_faces"] = TreeAnchor.world_bark_faces(cover["parts"])
	return cover["world_faces"]
