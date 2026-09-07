extends RefCounted

## Common cul-de-sac surface with an exact straight-road mouth at x=join.
static func build(parent: Node3D, join: float, half_width: float, asphalt: Material, concrete: Material) -> void:
	var radius := Vector2(join, half_width).length()
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(128):
		var a := boundary(float(i) / 128.0, join, half_width, radius, 0.0, 0.1)
		var b := boundary(float(i + 1) / 128.0, join, half_width, radius, 0.0, 0.1)
		for point: Vector3 in [Vector3(0, 0.1, 0), a, b]:
			road.add_vertex(point)
	# Close the mouth with a straight edge, not an overlapping circular cap.
	for point: Vector3 in [Vector3(0, 0.1, 0), Vector3(join, 0.1, -half_width), Vector3(join, 0.1, half_width)]:
		road.add_vertex(point)
	finish(parent, road, "RoadSurface", asphalt)
	for strip: Array in [[0.0, 0.2, 0.18, "Curb"], [1.7, 3.5, 0.12, "Sidewalk"]]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(128):
			# Estate access on the northwest/southwest arc has a dropped curb.
			var t := float(i) / 128.0
			var y: float = 0.10 if strip[3] == "Curb" and ((t > 0.35 and t < 0.46) or (t > 0.54 and t < 0.65)) else strip[2]
			var a := boundary(t, join, half_width, radius, strip[0], y)
			var b := boundary(t, join, half_width, radius, strip[1], y)
			var c := boundary(float(i + 1) / 128.0, join, half_width, radius, strip[1], y)
			var d := boundary(float(i + 1) / 128.0, join, half_width, radius, strip[0], y)
			for point: Vector3 in [a, b, c, a, c, d]:
				surface.add_vertex(point)
		finish(parent, surface, strip[3], concrete)

static func boundary(t: float, join: float, half_width: float, radius: float, offset: float, y: float) -> Vector3:
	var angle := atan2(half_width + offset, join)
	var theta := lerpf(angle, TAU - angle, t)
	var point := Vector3(cos(theta) * (radius + offset), y, sin(theta) * (radius + offset))
	# Blend the first/last arc section into the street's exact sidewalk endpoints.
	var blend := pow(maxf(0.0, 1.0 - minf(t, 1.0 - t) / 0.12), 2.0)
	var circle_end := Vector2(cos(angle), sin(angle)) * (radius + offset)
	point.x += (join - circle_end.x) * blend
	point.z += (half_width + offset - circle_end.y) * blend * (1.0 if t < 0.5 else -1.0)
	return point

static func finish(parent: Node3D, surface: SurfaceTool, label: String, material: Material) -> void:
	surface.generate_normals()
	var item := MeshInstance3D.new()
	item.name = label
	item.mesh = surface.commit()
	item.material_override = material
	parent.add_child(item)
	item.create_trimesh_collision()
