extends RefCounted

## Cached individual meshes, preserving multipart offsets and original UVs.
const ROOT := "res://assets/local_licensed/cyberthreat_urban/"
const PACKS := ["UrbanPack1.fbx", "UrbanPack2 - RoadSigns.fbx", "UrbanPack3 - Street Props.fbx"]
static var templates: Dictionary = {}

static func place(parent: Node3D, pack: int, names: Array[String], point: Vector3, longest_side: float, yaw: float = 0.0, solid: bool = true) -> Node3D:
	if not templates.has(pack):
		var source := (load(ROOT + PACKS[pack]) as PackedScene).instantiate() as Node3D
		var parts: Dictionary = {}
		for node in source.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var pose := mesh.transform
			var ancestor := mesh.get_parent() as Node3D
			while ancestor != null and ancestor != source:
				pose = ancestor.transform * pose
				ancestor = ancestor.get_parent() as Node3D
			parts[String(mesh.name)] = {"mesh": mesh.mesh, "pose": pose}
		templates[pack] = parts
		source.free()
	var bounds := AABB()
	var first := true
	for name: String in names:
		assert(templates[pack].has(name), "Missing urban prop: " + name)
		var part: Dictionary = templates[pack][name]
		var part_bounds: AABB = part.pose * (part.mesh as Mesh).get_aabb()
		bounds = part_bounds if first else bounds.merge(part_bounds)
		first = false
	var holder := Node3D.new()
	holder.name = names[0]
	parent.add_child(holder)
	var factor := longest_side / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	for name: String in names:
		var part: Dictionary = templates[pack][name]
		var visual := MeshInstance3D.new()
		visual.mesh = part.mesh
		holder.add_child(visual)
		visual.transform = part.pose
		visual.position -= center
		if solid:
			visual.create_trimesh_collision()
	holder.scale = Vector3.ONE * factor
	holder.rotation.y = yaw
	holder.position = point
	return holder
