@tool
extends Node3D

## Street furniture for the downtown beside the hospital, placed from the markers that
## tools/blender/prepare_downtown.py writes from tools/blender/downtown/plan.py: lamps with their
## lights, benches, bins, the mailbox, phone boxes, hydrants, road signs, dumpsters, bare trees in
## the sidewalk grates and dead cars in the lots and at the curbs. The parking meters, newspaper
## boxes, tree grates and lot fences are part of the downtown model itself. Also the hospital's
## entrance light, two manholes and the fence behind the service lane.

const Urban := preload("res://scenes/environment/urban_prop_library.gd")
const Alignment := preload("res://scenes/environment/surface_alignment.gd")
const MARKERS := "res://models/buildings/downtown/downtown_markers.json"
## Urban prop pack, mesh names and longest side in metres, per kind in the markers.
const PROPS := {
	"bench": [2, ["Bench"], 1.6],
	"trash": [0, ["TrashCan_001"], 0.9],
	"mailbox": [0, ["Mailbox_001"], 1.15],
	"phone": [2, ["PhoneBox"], 2.35],
	"hydrant": [0, ["FireHydrant_001"], 0.85],
	"no_parking": [1, ["NoParking"], 2.5],
	"traffic_lights_ahead": [1, ["TrafficLightsAhead"], 2.5],
	"dumpster": [2, ["Dumpster_001", "Dumpster_002"], 2.0],
	"lamp": [0, ["LampPost_003"], 4.2],
}
const TREES := [
	"res://assets/local_licensed/retro_tree_pack/low_res/dead_tree_rt_1.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/dead_tree_rt_2.glb",
]
const TREE_HEIGHT := 5.0
const CARS := {
	"Car": "res://assets/local_licensed/cars_bundle/Car.glb",
	"SUV": "res://assets/local_licensed/cars_bundle/SUV.glb",
	"Taxi": "res://assets/local_licensed/cars_bundle/Taxi.glb",
	"Police Car": "res://assets/local_licensed/cars_bundle/Police Car.glb",
}
@export_range(0.0, 3.0) var street_light_energy: float = 1.8

func _ready() -> void:
	var markers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MARKERS))
	var top := float(markers.sidewalk_top)
	var trees := 0
	for item: Dictionary in markers.furniture:
		var kind := String(item.kind)
		var point := Vector3(float(item.position[0]), top, float(item.position[1]))
		var yaw := deg_to_rad(float(item.yaw))
		if kind == "tree":
			_tree(point, yaw, TREES[trees % TREES.size()])
			trees += 1
			continue
		if not PROPS.has(kind):
			continue            # modelled with the downtown: newspaper boxes
		var spec: Array = PROPS[kind]
		var names: Array[String] = []
		names.assign(spec[1])
		Urban.place(self, int(spec[0]), names, point, float(spec[2]), yaw)
		if kind == "lamp":
			var lamp := OmniLight3D.new()
			lamp.name = "StreetLampLight"
			add_child(lamp, true)
			lamp.position = point + Vector3(0, 3.7, 0)
			lamp.light_color = Color(0.95, 0.73, 0.47)
			lamp.light_energy = street_light_energy
			lamp.omni_range = 13
			# The bulb is enclosed by the imported lantern mesh; no self-shadow blackout.
			lamp.shadow_enabled = false
	for i in markers.cars.size():
		var car: Dictionary = markers.cars[i]
		_car(String(car.scene), "DeadCar%d" % i, Vector3(car.position[0], car.position[1], car.position[2]),
				deg_to_rad(float(car.yaw)))
	# Over the forecourt in front of the hospital's entrance.
	var entrance_light := OmniLight3D.new()
	entrance_light.name = "ClinicEntranceLight"
	add_child(entrance_light)
	entrance_light.position = Vector3(255.2, 2.6, 245.5)
	entrance_light.light_color = Color(0.76, 0.85, 0.73)
	entrance_light.light_energy = 0.8
	entrance_light.omni_range = 7
	entrance_light.shadow_enabled = true
	for x: float in [143, 204]:
		Urban.place(self, 0, ["ManholeCover_001"], Vector3(x, 0.105, 226.7), 0.7, 0, false)
	_rear_fence()
	if not Engine.is_editor_hint():
		_align_ground_props.call_deferred()

func _align_ground_props() -> void:
	await get_tree().physics_frame
	for child: Node in get_children():
		if child is Node3D and child.is_in_group("grounded_urban_prop"):
			Alignment.settle(child)

## A bare tree standing in a sidewalk grate, with a trunk you can't walk through.
func _tree(point: Vector3, yaw: float, path: String) -> void:
	var tree := (load(path) as PackedScene).instantiate() as Node3D
	tree.name = "StreetTree"
	add_child(tree)
	var bounds := Alignment.world_bounds(tree)
	var factor := TREE_HEIGHT / maxf(bounds.size.y, 0.01)
	tree.transform = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * factor), point)
	_solid(point + Vector3(0, 1.0, 0), Vector3(0.35, 2.0, 0.35), "StreetTreeTrunk")

## A dead car, its wheels on the ground, with a box around it.
func _car(model: String, label: String, point: Vector3, yaw: float) -> void:
	var car := (load(CARS[model]) as PackedScene).instantiate() as Node3D
	car.name = label
	add_child(car)
	car.transform = Transform3D(Basis(Vector3.UP, yaw), point)
	var bounds := Alignment.world_bounds(car)
	car.position.y += point.y - bounds.position.y
	bounds = Alignment.world_bounds(car)
	var body := StaticBody3D.new()
	body.name = car.name + "Body"
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var local := car.global_transform.affine_inverse() * bounds
	box.size = local.size
	shape.shape = box
	body.add_child(shape)
	body.global_transform = car.global_transform
	shape.position = local.get_center()

## The timber fence behind the service lane: one mesh and one box.
func _rear_fence() -> void:
	var timber := StandardMaterial3D.new()
	timber.albedo_texture = load("res://assets/local_licensed/street_materials/textures/old_planks_02_diff_4k.jpg")
	timber.albedo_color = Color(0.48, 0.45, 0.40)
	timber.uv1_triplanar = true
	timber.roughness = 1.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(106, 239, 4):
		_add_box(tool, Vector3(x, 0.8, 275), Vector3(0.15, 1.6, 0.15))
	for y: float in [0.45, 1.1]:
		_add_box(tool, Vector3(172, y, 275), Vector3(132, 0.16, 0.12))
	tool.generate_normals()
	var fence := MeshInstance3D.new()
	fence.name = "RearFence"
	fence.mesh = tool.commit()
	fence.material_override = timber
	add_child(fence)
	_solid(Vector3(172, 0.8, 275), Vector3(132.15, 1.6, 0.15), "RearFenceBody")

func _add_box(tool: SurfaceTool, centre: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index in indices:
		tool.add_vertex(vertices[index] + centre)

func _solid(centre: Vector3, size: Vector3, label: String) -> void:
	var body := StaticBody3D.new()
	body.name = label
	add_child(body)
	body.position = centre
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
