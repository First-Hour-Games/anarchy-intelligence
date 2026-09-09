@tool
extends Node3D

## Reuses selected meshes from the existing building kit as a street-facing row.
## The source GLB is untouched; unused showcase buildings are hidden locally.
func _ready() -> void:
	var selected := ["Building_03", "Building_04", "Building_08", "Building_09"]
	var centers := [-35.0, -7.0, 25.0, 55.0]
	var widths := [22.0, 24.0, 25.0, 20.0]
	var titles := ["NORTHWOOD POST OFFICE", "GENERAL STORE", "LAUNDRY", "POLICE STATION"]
	var pavement := _material(Color(0.83, 0.82, 0.77), "res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	var metal := _material(Color(0.19, 0.25, 0.24))
	var wood := _material(Color(0.65, 0.61, 0.53), "res://assets/local_licensed/street_materials/textures/old_planks_02_diff_4k.jpg")
	var asphalt := _material(Color(0.7, 0.7, 0.7), "res://assets/local_licensed/street_materials/textures/asphalt_02_diff_4k.jpg")
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var building := child as MeshInstance3D
		var index := selected.find(String(building.name))
		building.visible = index >= 0
		if index < 0:
			continue
		var bounds := building.transform * building.get_aabb()
		building.scale *= widths[index] / bounds.size.x
		if index >= 2:
			building.rotation.y += PI
		bounds = building.transform * building.get_aabb()
		building.scale.y *= minf(1.0, 12.0 / bounds.size.y)
		bounds = building.transform * building.get_aabb()
		building.position += Vector3(centers[index] - bounds.get_center().x, -bounds.position.y, -48.0 - bounds.position.z)
		building.create_trimesh_collision()
		var center: float = centers[index]
		# Consistent ground-floor shopfronts keep the reused upper stories grounded.
		var glazing := _material(Color(0.10, 0.17, 0.18))
		for offset: float in [-6.0, 6.0]:
			_box("DisplayFrame", Vector3(center + offset, 1.55, -48.2), Vector3(4.6, 2.4, 0.18), metal)
			_box("DisplayWindow", Vector3(center + offset, 1.55, -48.31), Vector3(4.35, 2.15, 0.04), glazing)
			_box("DisplayMullion", Vector3(center + offset, 1.55, -48.35), Vector3(0.08, 2.2, 0.05), pavement)
		_box("ClosedShopDoor", Vector3(center, 1.2, -48.2), Vector3(1.4, 2.4, 0.18), metal)
		_box("DoorGlass", Vector3(center, 1.55, -48.31), Vector3(1.15, 1.35, 0.04), glazing)
		_box("ShopApron", Vector3(center, 0.06, -49.45), Vector3(widths[index] + 1, 0.12, 2.9), pavement)
		_mount_sign(building, center, minf(widths[index] * 0.72, 14.0), titles[index], metal)
		_box("ShopCanopy", Vector3(center, 2.75, -49), Vector3(6, 0.12, 2), metal)
		for x: float in [center - 3, center + 3]:
			_box("CanopyPost", Vector3(x, 1.35, -49.8), Vector3(0.09, 2.7, 0.09), metal)
		if index == 2:
			for y: float in [0.9, 1.35, 1.8]:
				_box("BoardedWindow", Vector3(center - 5, y, -48.3), Vector3(2.8, 0.2, 0.08), wood)
		var lamp := OmniLight3D.new()
		add_child(lamp)
		lamp.position = Vector3(center, 2.6, -50)
		lamp.light_color = Color(0.85, 0.69, 0.43)
		lamp.light_energy = 0.45
		lamp.omni_range = 6
		lamp.shadow_enabled = true
		_box("WallLamp", Vector3(center, 2.55, -48.4), Vector3(0.3, 0.35, 0.2), pavement)
	# Shared pedestrian apron connects to the clinic's existing frontage sidewalk.
	_box("SharedPromenade", Vector3(13, 0.06, -52), Vector3(134, 0.12, 2.2), pavement)
	_box("RearServiceLane", Vector3(12, 0.04, -15), Vector3(136, 0.08, 5), asphalt)
	for x: float in [-21, 9, 41]:
		_box("ServicePassage", Vector3(x, 0.04, -33), Vector3(3, 0.08, 31), asphalt)

func _material(color: Color, path: String = "") -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if not path.is_empty():
		material.albedo_texture = load(path)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.5
	return material

func _mount_sign(building: MeshInstance3D, center: float, width: float, title: String, material: Material) -> void:
	var height := 7.5 if title == "POLICE STATION" else (4.7 if title == "LAUNDRY" else 4.1)
	var front := Vector3(center, height, -70)
	var back := Vector3(center, height, 0)
	var facade_z := -48.0
	var nearest := INF
	var faces := building.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(front, back, building.transform * faces[i], building.transform * faces[i + 1], building.transform * faces[i + 2])
		if hit != null and (hit as Vector3).z < nearest:
			nearest = (hit as Vector3).z
	if nearest < INF:
		facade_z = nearest
	var mount := Node3D.new()
	mount.name = "MountedBusinessSign"
	add_child(mount)
	mount.position = Vector3(center, height, facade_z - 0.12)
	var backing := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var text_width := ThemeDB.fallback_font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 64).x
	var pixel_size := minf(0.014 if title in ["LAUNDRY", "POLICE STATION"] else 0.008, (width - 0.8) / text_width)
	mesh.size = Vector3(text_width * pixel_size + 0.8, 1.15, 0.2)
	backing.mesh = mesh
	backing.material_override = material
	mount.add_child(backing)
	var sign := Label3D.new()
	sign.name = "BusinessName"
	sign.text = title
	sign.font_size = 64
	sign.pixel_size = pixel_size
	sign.outline_size = 2
	sign.double_sided = false
	sign.modulate = Color(1.0, 0.95, 0.8)
	sign.shaded = false
	mount.add_child(sign)
	sign.position.z = -0.115
	sign.rotation.y = PI
	# Follow this actual building, including later designer translations/rotations.
	mount.reparent(building, true)

func _box(label: String, point: Vector3, size: Vector3, material: Material) -> void:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	add_child(item)
	item.position = point
