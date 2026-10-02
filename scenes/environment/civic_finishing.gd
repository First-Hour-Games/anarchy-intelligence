@tool
extends Node3D

const Urban := preload("res://scenes/environment/urban_prop_library.gd")
const Alignment := preload("res://scenes/environment/surface_alignment.gd")
@export_range(0.0, 2.0) var street_light_energy: float = 0.85

func _ready() -> void:
	# Shop-side furniture leaves the shared promenade clear.
	for x: float in [116, 161, 226]:
		Urban.place(self, 2, ["Bench"], Vector3(x, 0.12, 235), 1.6, PI)
		Urban.place(self, 0, ["TrashCan_001"], Vector3(x + 1.8, 0.12, 235), 0.9)
	Urban.place(self, 2, ["PhoneBox"], Vector3(230, 0.12, 234.6), 2.35, PI)
	Urban.place(self, 0, ["Mailbox_001"], Vector3(121, 0.12, 235), 1.15, PI)
	Urban.place(self, 0, ["FireHydrant_001"], Vector3(237, 0.12, 230.55), 0.85)
	Urban.place(self, 1, ["NoParking"], Vector3(257, 0.12, 230.6), 2.5, PI)
	Urban.place(self, 1, ["SlowAhead"], Vector3(109, 0.12, 230.6), 2.5, -PI * 0.5)
	for x: float in [150, 213]:
		Urban.place(self, 2, ["Dumpster_001", "Dumpster_002"], Vector3(x, 0.08, 267), 2, PI)
		Urban.place(self, 0, ["TrafficCone_002"], Vector3(x + 1.6, 0.08, 267.5), 0.55)
	Urban.place(self, 2, ["Bench"], Vector3(239, 0.12, 241.7), 1.6, PI)
	Urban.place(self, 0, ["TrashCan_001"], Vector3(241, 0.12, 241.7), 0.9)
	for x: float in [118, 149, 180, 211, 249]:
		Urban.place(self, 0, ["LampPost_003"], Vector3(x, 0.12, 231.4), 4.2)
		var lamp := OmniLight3D.new()
		lamp.name = "PromenadeLight"
		add_child(lamp)
		lamp.position = Vector3(x, 3.8, 231.4)
		lamp.light_color = Color(0.95, 0.73, 0.47)
		lamp.light_energy = street_light_energy
		lamp.omni_range = 11
		# The bulb is enclosed by the imported lantern mesh; no self-shadow blackout.
		lamp.shadow_enabled = false
	var entrance_light := OmniLight3D.new()
	entrance_light.name = "ClinicEntranceLight"
	add_child(entrance_light)
	entrance_light.position = Vector3(245, 2.5, 242)
	entrance_light.light_color = Color(0.76, 0.85, 0.73)
	entrance_light.light_energy = 0.8
	entrance_light.omni_range = 7
	entrance_light.shadow_enabled = true
	for x: float in [143, 204]:
		Urban.place(self, 0, ["ManholeCover_001"], Vector3(x, 0.105, 226.7), 0.7, 0, false)
	var timber := StandardMaterial3D.new()
	timber.albedo_texture = load("res://assets/local_licensed/street_materials/textures/old_planks_02_diff_4k.jpg")
	timber.albedo_color = Color(0.48, 0.45, 0.40)
	timber.uv1_triplanar = true
	timber.roughness = 1.0
	for x in range(106, 239, 4):
		_box("RearFencePost", Vector3(x, 0.8, 275), Vector3(0.15, 1.6, 0.15), timber)
	for y: float in [0.45, 1.1]:
		_box("RearFenceRail", Vector3(172, y, 275), Vector3(132, 0.16, 0.12), timber)
	if not Engine.is_editor_hint():
		_align_ground_props.call_deferred()

func _align_ground_props() -> void:
	await get_tree().physics_frame
	for child: Node in get_children():
		if child is Node3D and child.is_in_group("grounded_urban_prop"):
			Alignment.settle(child)

func _box(label: String, point: Vector3, dimensions: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)
	mesh.position = point
	mesh.create_trimesh_collision()
