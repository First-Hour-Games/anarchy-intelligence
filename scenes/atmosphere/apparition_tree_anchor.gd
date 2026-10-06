extends RefCounted

## Measure solid bark, excluding the large transparent foliage cards.
static func bark_faces(mesh: Mesh) -> PackedVector3Array:
	var faces := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface) as BaseMaterial3D
		if material != null and material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			continue
		if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			faces.append_array(vertices)
		else:
			for index: int in indices:
				faces.append(vertices[index])
	return faces

static func sections(parts: Array[Dictionary], base_y: float) -> Array[PackedVector3Array]:
	var result: Array[PackedVector3Array] = []
	var previous_center := Vector3.ZERO
	for height: float in [0.65, 1.20, 1.80, 2.40]:
		var points := PackedVector3Array()
		for part: Dictionary in parts:
			var faces: PackedVector3Array = part["faces"]
			var transform: Transform3D = part["transform"]
			for triangle in range(0, faces.size(), 3):
				var a := transform * faces[triangle]
				var b := transform * faces[triangle + 1]
				var c := transform * faces[triangle + 2]
				if minf(a.y, minf(b.y, c.y)) > base_y + height or maxf(a.y, maxf(b.y, c.y)) < base_y + height:
					continue
				var vertices: Array[Vector3] = [a, b, c]
				for edge in 3:
					var start := vertices[edge]
					var end := vertices[(edge + 1) % 3]
					if (start.y < base_y + height and end.y >= base_y + height) or (end.y < base_y + height and start.y >= base_y + height):
						var point := start.lerp(end, (base_y + height - start.y) / (end.y - start.y))
						# Follow the stem upward, rather than anchoring to a distant branch.
						if result.is_empty() or Vector2(point.x - previous_center.x, point.z - previous_center.z).length() < 0.65:
							points.append(point)
		if points.size() < 3:
			return []
		var bounds := AABB(points[0], Vector3.ZERO)
		for point: Vector3 in points:
			bounds = bounds.expand(point)
		if maxf(bounds.size.x, bounds.size.z) > 1.2:
			return []
		previous_center = bounds.get_center()
		result.append(points)
	return result

static func visible_edge(points: PackedVector3Array, camera: Vector3, away: Vector3, outward: Vector3) -> Vector3:
	var best := points[0]
	var slope := -INF
	for point: Vector3 in points:
		var offset := point - camera
		var candidate := offset.dot(outward) / maxf(offset.dot(away), 0.01)
		if candidate > slope:
			slope = candidate
			best = point
	return best

static func world_bark_faces(parts: Array[Dictionary]) -> PackedVector3Array:
	var result := PackedVector3Array()
	for part: Dictionary in parts:
		var transform: Transform3D = part["transform"]
		for point: Vector3 in part["faces"]:
			result.append(transform * point)
	return result

static func bark_line_clear(faces: PackedVector3Array, start: Vector3, end: Vector3) -> bool:
	# Branch meshes often lack physics collision, but still hide a rendered figure.
	for index in range(0, faces.size(), 3):
		if Geometry3D.segment_intersects_triangle(start, end, faces[index], faces[index + 1], faces[index + 2]) != null:
			return false
	return true
