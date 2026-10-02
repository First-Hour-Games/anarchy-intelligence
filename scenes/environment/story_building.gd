@tool
extends Node3D

@export_enum("Hospital", "Welcome center") var building_kind: int = 0
const FURNITURE := "res://assets/local_licensed/furniture_kit/Models/GLTF format/"
const MEDICAL := "res://assets/local_licensed/clinic_hospital/"

func _ready() -> void:
	var source := $Source as Node3D
	var materials: Dictionary = {}
	for mesh: Node in source.find_children("*", "MeshInstance3D", true, false):
		if building_kind == 1 and str(mesh.name).begins_with("Door_") and not str(mesh.name).contains("transom"):
			(mesh as Node3D).hide()
			continue
		if building_kind == 0:
			var instance := mesh as MeshInstance3D
			for index in instance.mesh.get_surface_count():
				var original := instance.get_active_material(index) as BaseMaterial3D
				if original != null:
					var key := original.get_instance_id()
					if not materials.has(key):
						var finish := original.duplicate() as BaseMaterial3D
						finish.cull_mode = BaseMaterial3D.CULL_DISABLED
						materials[key] = finish
					instance.set_surface_override_material(index, materials[key])
		if not Engine.is_editor_hint():
			(mesh as MeshInstance3D).create_trimesh_collision()
	if building_kind == 0:
		_build_hospital()
	else:
		_box("HallFloor", Vector3(0, 0.04, -5), Vector3(8.2, 0.08, 10), Color(0.39, 0.36, 0.3))
		_box("InformationDesk", Vector3(0, 0.6, -6), Vector3(3.2, 1.2, 0.8), Color(0.23, 0.29, 0.26))
		_label("TouristMap", "CICELY TOWN\nVISITOR INFORMATION", Vector3(0, 2.5, -8.8))
		_label("WelcomeSign", "CICELY TOWN\nWELCOME CENTER", Vector3(0, 2.8, 0.2))
		_box("RoadBarrier", Vector3(17, 1.1, 14), Vector3(0.2, 0.3, 7), Color(0.72, 0.49, 0.12))
		for z: float in [11, 17]:
			_box("BarrierSupport", Vector3(17, 0.5, z), Vector3(0.3, 1, 0.3), Color(0.22, 0.24, 0.22))
		for x: float in [-2.7, 2.7]:
			_prop(FURNITURE + "chair.glb", Vector3(x, 0.08, -4), 0.9)
		_light(Vector3(0, 2.8, -4), 9.0)

func _build_hospital() -> void:
	_box("GroundFloor", Vector3(-1, 0.06, -4.7), Vector3(37.8, 0.12, 9.4), Color(0.56, 0.58, 0.53))
	_box("GroundFloorCeiling", Vector3(-1, 3.25, -4.7), Vector3(37.8, 0.12, 9.4), Color(0.64, 0.65, 0.60))
	# A continuous inner shell closes gaps in the exterior-only source model.
	_box("RearPartition", Vector3(-1, 1.81, -9.1), Vector3(37.8, 3.38, 0.6), Color(0.64, 0.65, 0.59))
	for x: float in [-19.8, 17.8]:
		_box("SidePartition", Vector3(x, 1.81, -4.7), Vector3(0.18, 3.38, 9.4), Color(0.64, 0.65, 0.59))
	_box("FrontPartitionWest", Vector3(-15.81, 1.81, -0.35), Vector3(7.98, 3.38, 0.65), Color(0.64, 0.65, 0.59))
	_box("FrontPartitionEast", Vector3(4.56, 1.81, -0.35), Vector3(26.48, 3.38, 0.65), Color(0.64, 0.65, 0.59))
	_box("EntryHeader", Vector3(-10.2, 3.2, -0.12), Vector3(3.24, 0.6, 0.18), Color(0.64, 0.65, 0.59))
	# Reception stays open; the rear rooms share a continuous central passage.
	_box("ReceptionDesk", Vector3(-14, 0.72, -2), Vector3(3.8, 1.2, 0.85), Color(0.22, 0.32, 0.3))
	_box("RecordsDesk", Vector3(11, 0.57, -7.7), Vector3(2.6, 0.9, 1), Color(0.28, 0.32, 0.27))
	for x: float in [-15, -5, 5, 14]:
		_box("RoomPartition", Vector3(x, 1.81, -5.3), Vector3(6, 3.38, 0.16), Color(0.64, 0.65, 0.59))
	for x: float in [-9, 1, 9]:
		_box("RoomDivider", Vector3(x, 1.81, -7.3), Vector3(0.16, 3.38, 4), Color(0.64, 0.65, 0.59))
	for x: float in [-17, -15, -13]:
		_prop(FURNITURE + "chair.glb", Vector3(x, 0.12, -3.9), 0.9)
	for x: float in [-6, -2, 4]:
		_prop(MEDICAL + "bed_1.glb", Vector3(x, 0.12, -7.6), 1.1)
		_prop(MEDICAL + "tray_1.glb", Vector3(x + 1.3, 0.12, -7.1), 0.8)
	_prop(MEDICAL + "machine_1.glb", Vector3(-7.7, 0.12, -8.2), 1.1)
	_prop(MEDICAL + "cupboard_bottom.glb", Vector3(-17, 0.12, -8), 0.9)
	_prop(MEDICAL + "cupboard_top.glb", Vector3(-17, 1.02, -8), 0.65)
	for x: float in [-13.65, -10.35]:
		_box("SupplyShelfUpright", Vector3(x, 0.955, -8.5), Vector3(0.08, 1.67, 0.65), Color(0.27, 0.34, 0.31))
	for y: float in [0.55, 1.15, 1.75]:
		_box("SupplyShelf", Vector3(-12, y, -8.5), Vector3(3.5, 0.08, 0.65), Color(0.27, 0.34, 0.31))
		for x: float in [-13, -12, -11]:
			_prop("res://assets/local_licensed/clinic_medical/Med_12.glb", Vector3(x, y + 0.04, -8.5), 0.22)
	_box("PrivacyScreen", Vector3(-4, 1.07, -6.8), Vector3(0.1, 1.9, 1.6), Color(0.57, 0.62, 0.57))
	_label("ShelterNotice", "EMERGENCY SHELTER\nREGISTER AT RECEPTION", Vector3(-14, 2.3, -4.8))
	_label("SuppliesSign", "MEDICAL STORES", Vector3(-13, 2.8, -5.18))
	_label("WardSign", "TREATMENT", Vector3(-4, 2.8, -5.18))
	_label("RecordsSign", "STAFF RECORDS", Vector3(12, 2.8, -5.18))
	for point: Vector3 in [Vector3(-13, 3, -2), Vector3(-3, 3, -3), Vector3(7, 3, -3), Vector3(13, 3, -7), Vector3(-13, 3, -7)]:
		_light(point, 10.0)
	_box("EntranceWalk", Vector3(-10.2, 0.04, 12), Vector3(3, 0.08, 24), Color(0.44, 0.45, 0.42))

func _box(title: String, point: Vector3, dimensions: Vector3, color: Color) -> void:
	var box := CSGBox3D.new()
	box.name = title
	box.size = dimensions
	box.position = point
	box.use_collision = true
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if title.contains("Partition") or title.contains("Divider") or title.contains("Ceiling"):
		material.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.65
	box.material = material
	if title == "GroundFloor":
		var flooring := ShaderMaterial.new()
		flooring.shader = load("res://shaders/clinic_floor.gdshader")
		box.material = flooring
	add_child(box)

func _prop(path: String, point: Vector3, factor: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	add_child(prop)
	prop.position = point
	var bounds := AABB()
	var found := false
	for child: Node in prop.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		var relative := prop.global_transform.affine_inverse() * instance.global_transform
		var mesh_bounds := relative * instance.get_aabb()
		bounds = bounds.merge(mesh_bounds) if found else mesh_bounds
		found = true
	if found and bounds.size.y > 0.001:
		var scale_factor := factor / bounds.size.y
		prop.scale = Vector3.ONE * scale_factor
		prop.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z) * scale_factor
	prop.set_meta("target_height", factor)

func _label(title: String, words: String, point: Vector3) -> void:
	var label := Label3D.new()
	label.name = title
	label.text = words
	label.position = point
	label.pixel_size = 0.004
	label.font_size = 42
	add_child(label)

func _light(point: Vector3, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = Color(0.72, 0.79, 0.67)
	light.light_energy = 0.7
	light.omni_range = radius
	light.add_to_group("ridgeback_repellent")
	add_child(light)
