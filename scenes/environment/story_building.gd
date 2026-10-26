@tool
extends Node3D

@export_enum("Hospital", "Welcome center") var building_kind: int = 0
const FURNITURE := "res://assets/local_licensed/furniture_kit/Models/GLTF format/"
const HOSPITAL_MARKERS := "res://models/buildings/hospital/hospital_markers.json"
const HOSPITAL_LIGHT := preload("res://scenes/environment/hospital_light.gd")
const HOSPITAL_LIGHT_MODES := {"steady": 0, "flicker": 1, "strobe": 2, "dying": 3, "noise": 4, "pulse": 5}
## Hospital floor finishes drawn as tiled vinyl (carpet, wood-look plank and the corridor's
## wayfinding lines keep their flat colour).
const TILED_FLOORS := ["Interior_HospitalFloor", "Interior_FloorBeige", "Interior_FloorTerrazzo", "Interior_FloorGreen",
	"Interior_FloorGreenDark", "Interior_FloorLightGrey", "Interior_FloorSafety", "Interior_FloorConcrete"]

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
						materials[key] = _hospital_finish(original)
					instance.set_surface_override_material(index, materials[key])
		# Decor_ meshes (signs, wall equipment, light fittings) have no collision.
		if not Engine.is_editor_hint() and not str(mesh.name).begins_with("Decor_"):
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

## Imported hospital materials render both faces; floor finishes become tiled vinyl.
func _hospital_finish(original: BaseMaterial3D) -> Material:
	if original.resource_name in TILED_FLOORS:
		var vinyl := ShaderMaterial.new()
		vinyl.shader = preload("res://shaders/hospital_floor.gdshader")
		vinyl.set_shader_parameter("tint", original.albedo_color)
		return vinyl
	var finish := original.duplicate() as BaseMaterial3D
	finish.cull_mode = BaseMaterial3D.CULL_DISABLED
	return finish

## The hospital interior is modelled in Blender (tools/blender/build_hospital_interior.py)
## and exported with the shell; the markers file places what Godot owns: hiding spots,
## bottles, the medical-pack props and the lights.
func _build_hospital() -> void:
	_box("EntranceWalk", Vector3(-10.2, 0.04, 12), Vector3(3, 0.08, 24), Color(0.44, 0.45, 0.42))
	var markers := hospital_markers()
	for prop: Dictionary in markers.props:
		_marker_prop(prop)
	for light: Dictionary in markers.lights:
		_marker_light(light)
	if not Engine.is_editor_hint():
		_build_hospital_hiding(markers)

static func hospital_markers() -> Dictionary:
	return (load(HOSPITAL_MARKERS) as JSON).data

## Hospital-local resting point of a story document on its desk, ledge or shelf.
func document_point(id: StringName) -> Vector3:
	return _vector(hospital_markers().documents[str(id)])

static func _vector(values: Array) -> Vector3:
	return Vector3(values[0], values[1], values[2])

## Hiding spots and throwable bottles for the Clawman encounter. Each spot opens
## toward its local +Z.
func _build_hospital_hiding(markers: Dictionary) -> void:
	var kinds := {"locker": HidingSpot.Kind.LOCKER, "closet": HidingSpot.Kind.CLOSET, "bed": HidingSpot.Kind.UNDER_BED}
	for spot: Dictionary in markers.hiding_spots:
		_hiding_spot(spot.name, kinds[spot.kind], _vector(spot.position), deg_to_rad(spot.yaw))
	for data: Dictionary in markers.bottles:
		var bottle := BottlePickup.new()
		bottle.name = "BottlePickup"
		bottle.position = _vector(data.position)
		add_child(bottle, true)

## A pack model on its marker, scaled to its target height (or native size). Floor-standing
## props get a box collider so they block players and the navigation mesh.
func _marker_prop(data: Dictionary) -> void:
	var packed := load(data.model) as PackedScene
	if packed == null:
		return
	var holder := Node3D.new()
	holder.name = data.name
	add_child(holder)
	holder.position = _vector(data.position)
	holder.rotation.y = deg_to_rad(data.yaw)
	var prop := packed.instantiate() as Node3D
	holder.add_child(prop)
	if data.target_height != null:
		PropSizing.fit_height(prop, data.target_height)
		holder.set_meta("target_height", data.target_height)
	holder.set_meta("support_y", data.position[1])
	if data.block and not Engine.is_editor_hint():
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = _vector(data.foot)
		shape.shape = box
		shape.position.y = box.size.y * 0.5
		body.add_child(shape)
		holder.add_child(body)

func _marker_light(data: Dictionary) -> void:
	var light: Light3D
	if data.spot:
		var spot := SpotLight3D.new()
		spot.spot_range = data.range
		spot.spot_angle = data.angle * 0.5
		spot.shadow_enabled = data.shadow
		light = spot
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = data.range
		omni.set_script(HOSPITAL_LIGHT)
		omni.set("mode", HOSPITAL_LIGHT_MODES[data.mode])
		light = omni
	light.name = data.name
	light.light_color = Color(data.color[0], data.color[1], data.color[2])
	light.light_energy = data.energy
	add_child(light)
	light.position = _vector(data.position)
	if data.spot:
		light.basis = Basis.looking_at(_vector(data.direction), Vector3.UP)

func _hiding_spot(title: String, kind: HidingSpot.Kind, point: Vector3, yaw: float) -> void:
	var spot := HidingSpot.new()
	spot.name = title
	spot.kind = kind
	spot.position = point
	spot.rotation.y = yaw
	add_child(spot, true)

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
	add_child(box)

func _prop(path: String, point: Vector3, factor: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var prop := packed.instantiate() as Node3D
	add_child(prop)
	prop.position = point
	PropSizing.fit_height(prop, factor)
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
