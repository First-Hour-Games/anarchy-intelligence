@tool
extends RefCounted
## Import-time box collision for the authored neighborhood's exterior geometry.

static func add_to_mesh(instance: MeshInstance3D, owner_root: Node) -> void:
	if instance.has_node("LotCollision"):
		return
	var name := String(instance.name)
	var kind := ""
	for suffix in ["House", "Garage", "Fence", "Lawn"]:
		if name.ends_with("_" + suffix):
			kind = suffix
	if kind.is_empty():
		return
	var body := StaticBody3D.new()
	body.name = "LotCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("surface", "grass" if kind == "Lawn" else "concrete")
	instance.add_child(body)
	body.owner = owner_root
	for surface in instance.mesh.get_surface_count():
		var material := instance.mesh.surface_get_material(surface)
		if material == null:
			continue
		var material_name := material.resource_name
		var arrays := instance.mesh.surface_get_arrays(surface)
		if kind == "Lawn" and material_name == "Lawn_Surface":
			add_ground(body, owner_root, arrays[Mesh.ARRAY_VERTEX])
		elif kind == "Fence" and material_name in ["Cedar_Fence_Boards", "Picket_White"]:
			add_fences(body, owner_root, arrays)
		elif kind in ["House", "Garage"] and (material_name.begins_with("Siding_") or material_name in ["Foundation_Concrete", "Concrete_Broom"]):
			for bounds in component_bounds(arrays):
				add_box(body, owner_root, bounds.size, Transform3D(Basis.IDENTITY, bounds.get_center()))
	if body.get_child_count() == 0:
		body.free()

static func add_box(body: StaticBody3D, owner_root: Node, size: Vector3, pose: Transform3D) -> void:
	if size.min_axis_index() < 0 or minf(size.x, minf(size.y, size.z)) < 0.005:
		return
	var collision := CollisionShape3D.new()
	collision.name = "Box%d" % (body.get_child_count() + 1)
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	collision.transform = pose
	body.add_child(collision)
	collision.owner = owner_root

static func add_ground(body: StaticBody3D, owner_root: Node, vertices: PackedVector3Array) -> void:
	var heights := {}
	var min_x := INF
	var max_x := -INF
	for vertex in vertices:
		var z := snappedf(vertex.z, 0.0001)
		heights[z] = maxf(float(heights.get(z, -INF)), vertex.y)
		min_x = minf(min_x, vertex.x)
		max_x = maxf(max_x, vertex.x)
	var depths := heights.keys()
	depths.sort()
	var start := 0
	while start < depths.size() - 1:
		var end := start + 1
		while end + 1 < depths.size():
			var candidate := end + 1
			var valid := true
			for middle in range(start + 1, candidate):
				var weight := float(depths[middle] - depths[start]) / float(depths[candidate] - depths[start])
				if absf(lerpf(heights[depths[start]], heights[depths[candidate]], weight) - heights[depths[middle]]) > 0.008:
					valid = false
					break
			if not valid:
				break
			end = candidate
		var dz := float(depths[end] - depths[start])
		var dy := float(heights[depths[end]] - heights[depths[start]])
		var basis := Basis(Vector3.RIGHT, -atan2(dy, dz))
		var top := Vector3((min_x + max_x) * 0.5, (heights[depths[start]] + heights[depths[end]]) * 0.5, (depths[start] + depths[end]) * 0.5)
		add_box(body, owner_root, Vector3(max_x - min_x, 0.5, Vector2(dz, dy).length()), Transform3D(basis, top - basis.y * 0.25))
		start = end

static func add_fences(body: StaticBody3D, owner_root: Node, arrays: Array) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var faces: Array[Dictionary] = []
	for triangle in range(0, indices.size(), 3):
		var a := vertices[indices[triangle]]
		var b := vertices[indices[triangle + 1]]
		var c := vertices[indices[triangle + 2]]
		var normal := (b - a).cross(c - a).normalized().abs()
		if normal.y > 0.1:
			continue
		var axis := 0 if normal.x > normal.z else 2
		var along := 2 if axis == 0 else 0
		var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c)
		# Ignore thin plank end caps; retain the broad vertical faces.
		if bounds.size[along] < 0.08 or bounds.size.y < 0.5:
			continue
		faces.append({"axis": axis, "plane": a[axis], "start": bounds.position[along], "end": bounds.end[along], "low": bounds.position.y, "high": bounds.end.y})
	faces.sort_custom(func(a: Dictionary, b: Dictionary): return a.plane < b.plane)
	var groups: Array[Dictionary] = []
	for face in faces:
		var group: Dictionary = {}
		for candidate in groups:
			if candidate.axis == face.axis and absf(candidate.plane - face.plane) < 0.12:
				group = candidate
				break
		if group.is_empty():
			group = {"axis": face.axis, "plane": face.plane, "faces": []}
			groups.append(group)
		group.faces.append(face)
	for group in groups:
		group.faces.sort_custom(func(a: Dictionary, b: Dictionary): return a.start < b.start)
		var runs: Array[Dictionary] = []
		for face: Dictionary in group.faces:
			if runs.is_empty() or face.start > runs[-1].end + 0.25:
				runs.append(face.duplicate())
			else:
				runs[-1].end = maxf(runs[-1].end, face.end)
				runs[-1].low = minf(runs[-1].low, face.low)
				runs[-1].high = maxf(runs[-1].high, face.high)
		for run in runs:
			var size := Vector3(0.2, run.high - run.low + 0.12, 0.2)
			var center := Vector3(0, (run.low + run.high) * 0.5, 0)
			var along := 2 if group.axis == 0 else 0
			size[along] = run.end - run.start + 0.12
			center[along] = (run.start + run.end) * 0.5
			center[group.axis] = group.plane
			add_box(body, owner_root, size, Transform3D(Basis.IDENTITY, center))
	# Picket post end caps can produce tiny perpendicular boxes already covered
	# by a continuous fence run. Keep the run rather than a box for each post.
	for shape: CollisionShape3D in body.get_children():
		if maxf(shape.shape.size.x, shape.shape.size.z) > 0.4:
			continue
		var bounds := AABB(shape.position - shape.shape.size * 0.5, shape.shape.size)
		for other: CollisionShape3D in body.get_children():
			if maxf(other.shape.size.x, other.shape.size.z) < 1.0:
				continue
			var run := AABB(other.position - other.shape.size * 0.5, other.shape.size)
			if run.grow(0.08).encloses(bounds):
				shape.free()
				break

static func find_root(parents: Array[int], index: int) -> int:
	while parents[index] != index:
		parents[index] = parents[parents[index]]
		index = parents[index]
	return index

static func component_bounds(arrays: Array) -> Array[AABB]:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var parents: Array[int] = []
	var welded := {}
	for index in vertices.size():
		parents.append(index)
		var key := vertices[index].snapped(Vector3.ONE * 0.0001)
		if welded.has(key):
			parents[index] = welded[key]
		else:
			welded[key] = index
	for triangle in range(0, indices.size(), 3):
		for corner in [1, 2]:
			parents[find_root(parents, indices[triangle + corner])] = find_root(parents, indices[triangle])
	var components := {}
	for index in vertices.size():
		var component := find_root(parents, index)
		var bounds: AABB = components.get(component, AABB(vertices[index], Vector3.ZERO))
		components[component] = bounds.expand(vertices[index])
	var result: Array[AABB] = []
	for bounds: AABB in components.values():
		result.append(bounds)
	return result
