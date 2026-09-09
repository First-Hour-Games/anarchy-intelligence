@tool
extends Node3D

## Compact enterable clinic; all coordinates are local to the building.
## Roof can be hidden for map making without changing gameplay visibility.
@export var preview_hide_roof: bool = false:
	set(value):
		preview_hide_roof = value
		if is_inside_tree():
			var roof := get_node_or_null("Interior/Roof") as Node3D
			if roof != null:
				roof.visible = not (Engine.is_editor_hint() and value)
const HOSPITAL := "res://assets/local_licensed/clinic_hospital/"
const MEDICAL := "res://assets/local_licensed/clinic_medical/"
const FURNITURE := "res://assets/local_licensed/furniture_kit/Models/GLTF format/"
const TEXTURES := "res://assets/local_licensed/street_materials/textures/"
var interior: Node3D

func _ready() -> void:
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	var plaster := _material(Color(0.65, 0.65, 0.57), "cracked_concrete_diff_4k.jpg", 0.35)
	plaster.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	plaster.albedo_color = Color(0.85, 0.84, 0.75)
	plaster.uv1_scale = Vector3.ONE * 1.5
	var concrete := _material(Color(0.72, 0.70, 0.65), "cracked_concrete_diff_4k.jpg", 0.5)
	concrete.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	concrete.albedo_color = Color(0.9, 0.9, 0.86)
	var trim := _material(Color(0.20, 0.29, 0.27))
	var asphalt := _material(Color(0.75, 0.75, 0.75), "asphalt_02_diff_4k.jpg", 0.333)
	var white := _material(Color(0.72, 0.72, 0.63))
	var brick := ShaderMaterial.new()
	brick.shader = load("res://shaders/clinic_masonry.gdshader")
	var flooring := ShaderMaterial.new()
	flooring.shader = load("res://shaders/clinic_floor.gdshader")
	_box("Floor", Vector3(0, 0.06, 0), Vector3(18, 0.12, 14), flooring)
	_box("RearWall", Vector3(0, 1.8, 7), Vector3(18, 3.6, 0.24), plaster)
	for x: float in [-9.0, 9.0]:
		_box("SideWall", Vector3(x, 1.8, 0), Vector3(0.24, 3.6, 14), plaster)
	# Front opening is a real 2m-wide doorway, not a solid building collider.
	for x: float in [-5.0, 5.0]:
		_box("WindowSillWall", Vector3(x, 0.59, -7), Vector3(8, 1.18, 0.24), plaster)
		_box("WindowHeaderWall", Vector3(x, 3.15, -7), Vector3(8, 0.9, 0.24), plaster)
		for offset: float in [-2.85, 2.85]:
			_box("WindowPier", Vector3(x + offset, 1.94, -7), Vector3(2.3, 1.52, 0.24), plaster)
	_box("DoorLintel", Vector3(0, 3.1, -7), Vector3(2, 1, 0.24), plaster)
	for x: float in [-1.05, 1.05]:
		_box("DoorFrame", Vector3(x, 1.35, -7.16), Vector3(0.12, 2.7, 0.14), trim)
	_box("EntranceCanopy", Vector3(0, 2.85, -8), Vector3(3.7, 0.16, 2.4), trim)
	_build_pitched_roof(asphalt, brick, white)
	for x: float in [-1.7, 1.7]:
		_box("EntranceColumn", Vector3(x, 1.4, -8.9), Vector3(0.2, 2.8, 0.2), trim)
	_box("BrickChimney", Vector3(5.8, 5.8, 2.5), Vector3(0.85, 2.0, 0.85), brick)
	_box("ChimneyCap", Vector3(5.8, 6.83, 2.5), Vector3(1.05, 0.12, 1.05), concrete)
	for z: float in [-7.15, 7.15]:
		_box("Fascia", Vector3(0, 3.45, z), Vector3(18.3, 0.26, 0.18), trim)
	var glass := _material(Color(0.13, 0.20, 0.20))
	glass.roughness = 0.3
	glass.metallic = 0.3
	for x: float in [-5.0, 5.0]:
		_box("PaintedFrontBase", Vector3(x, 0.53, -7.14), Vector3(8, 0.85, 0.04), trim, false)
		for dx: float in [-1.64, 1.64]:
			_box("WindowFrame", Vector3(x + dx, 1.94, -7.15), Vector3(0.12, 1.5, 0.10), trim, false)
		for y: float in [1.23, 2.65]:
			_box("WindowFrame", Vector3(x, y, -7.15), Vector3(3.4, 0.12, 0.10), trim, false)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.albedo_color.a = 0.38
		_box("WindowGlass", Vector3(x, 1.94, -7.02), Vector3(3.18, 1.28, 0.04), glass)
		_box("WindowMullion", Vector3(x, 1.94, -7.26), Vector3(0.07, 1.35, 0.04), white, false)
	for x: float in [-9.13, 9.13]:
		_box("PaintedSideBase", Vector3(x, 0.53, 0), Vector3(0.04, 0.85, 14), trim, false)
		_box("Downpipe", Vector3(x, 1.65, 6.7), Vector3(0.12, 3.3, 0.12), trim, false)
	# Thin exterior skins retain pale interior walls and actual window openings.
	for x: float in [-9.16, 9.16]:
		_box("BrickSide", Vector3(x, 1.9, 0), Vector3(0.07, 3.4, 14), brick, false)
		_box("Foundation", Vector3(x, 0.22, 0), Vector3(0.13, 0.3, 14), concrete, false)
	_box("BrickRear", Vector3(0, 1.9, 7.16), Vector3(18.3, 3.4, 0.07), brick, false)
	for x: float in [-5, 5]:
		_box("BrickSillBay", Vector3(x, 0.75, -7.19), Vector3(8, 0.85, 0.06), brick, false)
		_box("BrickHeaderBay", Vector3(x, 3.16, -7.19), Vector3(8, 0.88, 0.06), brick, false)
		for dx: float in [-2.85, 2.85]:
			_box("BrickPier", Vector3(x + dx, 1.94, -7.19), Vector3(2.3, 1.52, 0.06), brick, false)
		_box("DeepStoneSill", Vector3(x, 1.18, -7.27), Vector3(3.65, 0.14, 0.42), concrete, false)
		_box("StoneWindowLintel", Vector3(x, 2.76, -7.24), Vector3(3.65, 0.18, 0.3), concrete, false)
	# Double glazed doors held open against the entry walls; 2m passage stays clear.
	for x: float in [-1.12, 1.12]:
		_box("OpenDoorRail", Vector3(x, 1.3, -6.5), Vector3(0.1, 2.4, 0.95), trim)
		_box("OpenDoorPane", Vector3(x - signf(x) * 0.065, 1.6, -6.5), Vector3(0.025, 1.5, 0.72), glass, false)
	_box("RearServiceDoor", Vector3(-5.6, 1.3, 7.23), Vector3(1.2, 2.4, 0.08), trim)
	_box("ServiceThreshold", Vector3(-5.6, 0.09, 7.7), Vector3(1.6, 0.18, 1.0), concrete)
	# Rear rooms open onto a clear central passage.
	for x: float in [-5.25, 5.25]:
		_box("RoomPartition", Vector3(x, 1.7, 0.6), Vector3(7.5, 3.2, 0.16), plaster)
	# Central corridor with a 1.6m doorway into each room at z=3.8.
	for x: float in [-1.5, 1.5]:
		_box("HallWallFront", Vector3(x, 1.86, 1.85), Vector3(0.16, 3.48, 2.5), plaster)
		_box("HallWallRear", Vector3(x, 1.86, 5.8), Vector3(0.16, 3.48, 2.4), plaster)
		_box("HallDoorHeader", Vector3(x, 3.0, 3.85), Vector3(0.16, 1.2, 1.5), plaster)
		for z: float in [3.06, 4.64]:
			_box("RoomDoorJamb", Vector3(x, 1.3, z), Vector3(0.23, 2.36, 0.08), trim)
		_box("HallDadoFront", Vector3(x - signf(x) * 0.1, 1.0, 1.85), Vector3(0.04, 0.1, 2.5), trim, false)
		_box("HallDadoRear", Vector3(x - signf(x) * 0.1, 1.0, 5.8), Vector3(0.04, 0.1, 2.4), trim, false)
	_box("ReceptionReturn", Vector3(7.5, 0.65, -1.2), Vector3(0.6, 1.06, 2.5), trim)
	_box("ReceptionDesk", Vector3(5.8, 0.65, -2.2), Vector3(3.5, 1.06, 0.85), trim)
	_box("ReceptionCounter", Vector3(5.8, 1.22, -2.2), Vector3(3.7, 0.08, 1.0), white)
	_box("ReceptionNoticeBoard", Vector3(6.9, 2.0, -6.82), Vector3(1.2, 0.85, 0.05), trim, false)
	_label("Notice", "PLEASE CHECK IN\nAT RECEPTION\n\nSTAFF ONLY BEYOND", Vector3(6.9, 2.0, -6.77), 0.0015, 0)
	_box("PatientRegister", Vector3(5.1, 1.28, -2.25), Vector3(0.35, 0.025, 0.46), white, false)
	_box("ReceptionMonitor", Vector3(6.6, 1.52, -2.2), Vector3(0.5, 0.44, 0.3), trim, false)
	_box("MonitorStand", Vector3(6.6, 1.31, -2.2), Vector3(0.3, 0.09, 0.25), trim, false)
	for x: float in [-8.84, 8.84]:
		_box("InteriorSkirting", Vector3(x, 0.23, 0), Vector3(0.05, 0.22, 13.8), trim, false)
	_box("InteriorRearSkirting", Vector3(0, 0.23, 6.84), Vector3(17.8, 0.22, 0.05), trim, false)
	_box("ClinicSignBacking", Vector3(0, 3.22, -7.3), Vector3(5.6, 0.48, 0.12), trim, false)
	_label("ClinicSign", "NORTHWOOD CLINIC", Vector3(0, 3.22, -7.375), 0.0045, PI)
	_box("HoursPlaque", Vector3(2.4, 1.8, -7.25), Vector3(1.05, 0.65, 0.06), trim, false)
	_label("Hours", "WALK-IN CARE\nRECEPTION INSIDE", Vector3(2.4, 1.8, -7.295), 0.0015, PI)
	_label("ExamSign", "EXAMINATION", Vector3(-4.5, 2.5, 0.48), 0.003, PI)
	_label("MedicineSign", "MEDICAL STORES", Vector3(4.5, 2.5, 0.48), 0.003, PI)
	for z: float in [-5.5, -3.6, -1.7]:
		_prop(FURNITURE + "chair.glb", Vector3(-7.7, 0.12, z), 0.9, PI * 0.5)
	_box("WaitingTable", Vector3(-5.9, 0.38, -4.5), Vector3(0.8, 0.52, 1.6), trim)
	_box("WaitingMagazines", Vector3(-5.9, 0.66, -4.5), Vector3(0.3, 0.025, 0.4), white, false)
	_box("ReceptionPlaque", Vector3(5.8, 0.85, -2.65), Vector3(1.6, 0.35, 0.035), white, false)
	_label("ReceptionTitle", "RECEPTION", Vector3(5.8, 0.85, -2.68), 0.0027, PI)
	_label("CorridorDirections", "EXAMINATION  <\n>  MEDICAL STORES", Vector3(0, 2.1, 6.83), 0.003, PI)
	_box("ExamWorktop", Vector3(-7.6, 0.9, 1.5), Vector3(1.8, 0.12, 0.75), white)
	_box("ExamCabinet", Vector3(-7.6, 0.48, 1.5), Vector3(1.7, 0.72, 0.7), trim)
	_box("PrivacyScreen", Vector3(-4.5, 1.15, 2.1), Vector3(2.4, 1.7, 0.07), white)
	for x: float in [-5.65, -3.35]:
		_box("ScreenFoot", Vector3(x, 0.2, 2.1), Vector3(0.12, 0.18, 0.65), trim)
	_box("EyeChartBacking", Vector3(-5.5, 1.9, 6.83), Vector3(0.7, 0.95, 0.03), white, false)
	_label("EyeChart", "E\nF  P\nT  O  Z\nL P E D", Vector3(-5.5, 1.9, 6.80), 0.0024, PI)
	_prop(HOSPITAL + "tray_1.glb", Vector3(-3.0, 0.12, 5.8), 0.85)
	for y: float in [0.55, 1.15, 1.75]:
		_box("SupplyShelves", Vector3(8.1, y, 3.8), Vector3(0.9, 0.09, 3.4), trim)
		for z: float in [2.7, 3.8, 4.9]:
			_prop(MEDICAL + "Med_12.glb", Vector3(8.1, y + 0.05, z), 0.22)
	_prop(HOSPITAL + "bed_1.glb", Vector3(-5.5, 0.12, 4.3), 2.15)
	_prop(HOSPITAL + "machine_1.glb", Vector3(-7.6, 0.12, 4.9), 1.2)
	_prop(HOSPITAL + "tray_1.glb", Vector3(-3.6, 0.12, 4.3), 0.9)
	_prop(HOSPITAL + "cupboard_bottom.glb", Vector3(5.5, 0.12, 6.0), 1.8)
	_prop(HOSPITAL + "cupboard_top.glb", Vector3(5.5, 1.8, 6.0), 1.6)
	_box("MedicineShelf", Vector3(3.0, 0.95, 5.7), Vector3(1.8, 0.12, 0.8), trim)
	for i in range(3):
		_prop(MEDICAL + "Med_%d.glb" % (i + 11), Vector3(2.4 + i * 0.5, 1.01, 5.7), 0.23)
	var marker := Marker3D.new()
	marker.name = "MedicinePickupAnchor"
	interior.add_child(marker)
	marker.position = Vector3(3, 1.25, 5.2)
	for point: Vector3 in [Vector3(-4.5, 2.7, -3.8), Vector3(4.5, 2.7, -3.8), Vector3(0, 2.7, 3.8), Vector3(-4.5, 2.7, 4), Vector3(4.5, 2.7, 4)]:
		var light := OmniLight3D.new()
		interior.add_child(light)
		light.position = point
		light.light_color = Color(0.72, 0.79, 0.67)
		light.light_energy = 0.65
		light.omni_range = 8.0
		light.shadow_enabled = true
		_box("CeilingFixture", point + Vector3(0, 0.7, 0), Vector3(1.0, 0.08, 0.25), white, false)
	# Connected frontage: road z=-22, sidewalk z=-20, entrance z=-7.
	_box("FrontageWalk", Vector3(-62.75, 0.06, -20), Vector3(156.5, 0.12, 1.8), concrete, false)
	_box("FarFrontageWalk", Vector3(25.25, 0.06, -20), Vector3(9.5, 0.12, 1.8), concrete, false)
	_box("EntranceWalk", Vector3(0, 0.06, -13.05), Vector3(2, 0.12, 12.1), concrete, false)
	_box("Parking", Vector3(18, 0.045, -6), Vector3(13, 0.09, 13), asphalt, false)
	_box("Driveway", Vector3(18, 0.05, -17.25), Vector3(5, 0.10, 9.5), asphalt, false)
	_box("ParkingWalk", Vector3(6.25, 0.06, -9), Vector3(10.5, 0.12, 1.6), concrete, false)
	for x: float in [12.0, 14.8, 17.6, 20.4, 23.2]:
		_box("BayStripe", Vector3(x, 0.097, -3), Vector3(0.09, 0.012, 5), white, false)
		if x < 23.0:
			_box("WheelStop", Vector3(x + 1.3, 0.16, -0.8), Vector3(1.6, 0.18, 0.2), concrete)
	_box("ParkingSignBacking", Vector3(12, 1.7, -14.94), Vector3(1.45, 0.9, 0.08), trim, false)
	_label("ParkingSign", "CLINIC\nPATIENT PARKING", Vector3(12, 1.7, -15), 0.003, PI)
	_box("SignPost", Vector3(12, 0.8, -15), Vector3(0.1, 1.6, 0.1), trim)
	for x: float in [-10.6, -8.4]:
		_box("ClinicMarkerPost", Vector3(x, 0.95, -15), Vector3(0.14, 1.9, 0.14), trim)
	_box("ClinicMarker", Vector3(-9.5, 1.8, -15), Vector3(2.5, 1.1, 0.14), trim)
	_label("ClinicWayfinding", "NORTHWOOD\nCLINIC\nENTRANCE  >", Vector3(-9.5, 1.8, -15.09), 0.0025, PI)
	for x: float in [-5.0, 5.0]:
		_box("PlantingBorder", Vector3(x, 0.15, -11.0), Vector3(4.5, 0.2, 1.4), concrete)
		for offset: float in [-1.4, 0, 1.4]:
			_prop("res://assets/local_licensed/psx_hedges/bush_overgrown_dead.glb", Vector3(x + offset, 0.25, -11), 1.2)

func _material(color: Color, texture: String = "", tiling: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if not texture.is_empty():
		material.albedo_texture = load(TEXTURES + texture)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * tiling
	return material

func _build_pitched_roof(finish: Material, brick: Material, fascia: Material) -> void:
	var roof := Node3D.new()
	roof.name = "Roof"
	interior.add_child(roof)
	roof.visible = not (Engine.is_editor_hint() and preview_hide_roof)
	var ceiling := _box("Ceiling", Vector3(0, 3.65, 0), Vector3(18.8, 0.12, 14.8), fascia)
	ceiling.reparent(roof)
	for side: float in [-1, 1]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var a := Vector3(-9.6, 3.7, side * 7.6)
		var b := Vector3(9.6, 3.7, side * 7.6)
		var c := Vector3(9.6, 6.3, 0)
		var d := Vector3(-9.6, 6.3, 0)
		var vertices: Array = [a, b, c, a, c, d] if side < 0 else [a, c, b, a, d, c]
		for point: Vector3 in vertices:
			surface.add_vertex(point)
		surface.generate_normals()
		var slope := MeshInstance3D.new()
		slope.mesh = surface.commit()
		slope.material_override = finish
		roof.add_child(slope)
		var gutter := _box("Gutter", Vector3(0, 3.67, side * 7.62), Vector3(19.3, 0.16, 0.18), fascia, false)
		gutter.reparent(roof)
	for side: float in [-1, 1]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var vertices: Array[Vector3] = [Vector3(side * 9.12, 3.6, -7), Vector3(side * 9.12, 6.3, 0), Vector3(side * 9.12, 3.6, 7)]
		if side > 0:
			vertices.reverse()
		for point: Vector3 in vertices:
			surface.add_vertex(point)
		surface.generate_normals()
		var gable := MeshInstance3D.new()
		gable.mesh = surface.commit()
		gable.material_override = brick
		roof.add_child(gable)

func _box(label: String, point: Vector3, size: Vector3, material: Material, solid: bool = true) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	item.mesh = mesh
	item.material_override = material
	interior.add_child(item)
	item.position = point
	if solid:
		item.create_trimesh_collision()
	return item

func _label(label: String, text: String, point: Vector3, pixels: float, yaw: float) -> void:
	var sign := Label3D.new()
	sign.name = label
	sign.text = text
	sign.font_size = 64
	sign.pixel_size = pixels
	sign.modulate = Color(0.8, 0.82, 0.7)
	interior.add_child(sign)
	sign.position = point
	sign.rotation.y = yaw

func _prop(path: String, point: Vector3, longest_side: float, yaw: float = 0.0) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var holder := Node3D.new()
	interior.add_child(holder)
	var model := packed.instantiate() as Node3D
	holder.add_child(model)
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if path.begins_with(HOSPITAL):
			for i in mesh.mesh.get_surface_count():
				var source := mesh.mesh.surface_get_material(i) as StandardMaterial3D
				if source != null:
					var finish := source.duplicate() as StandardMaterial3D
					finish.albedo_color *= Color(0.66, 0.70, 0.62)
					finish.roughness = 0.9
					mesh.set_surface_override_material(i, finish)
		if longest_side > 0.5:
			mesh.create_trimesh_collision()
		var local_bounds := holder.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
	if first:
		return
	var factor := longest_side / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	model.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
	holder.scale = Vector3.ONE * factor
	holder.rotation.y = yaw
	holder.position = point
