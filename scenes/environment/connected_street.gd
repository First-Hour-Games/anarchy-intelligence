@tool
extends Node3D

## Explicit property plan for the upper neighborhood. Boundaries belong to the
## block, so neighboring yards share one fence instead of overlapping copies.
@export var sidewalk_width: float = 1.8
@export var driveway_width: float = 3.8
var concrete: StandardMaterial3D
var timber: StandardMaterial3D
var worn_concrete: StandardMaterial3D
const STREET_TEXTURES := "res://assets/local_licensed/street_materials/textures/"
const FURNITURE := "res://assets/local_licensed/furniture_kit/Models/GLTF format/"
var generated: Node3D


func _ready() -> void:
	call_deferred("rebuild")


func rebuild() -> void:
	if generated != null:
		generated.free()
	generated = Node3D.new()
	generated.name = "Properties"
	add_child(generated)
	concrete = StandardMaterial3D.new()
	concrete.albedo_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	concrete.normal_enabled = true
	concrete.normal_texture = load("res://assets/local_licensed/materials/concrete034/Concrete034_NormalGL.jpg")
	concrete.roughness = 0.95
	concrete.uv1_triplanar = true
	concrete.uv1_scale = Vector3.ONE * 0.5
	timber = StandardMaterial3D.new()
	timber.albedo_color = Color(0.72, 0.70, 0.66)
	timber.albedo_texture = load(STREET_TEXTURES + "old_planks_02_diff_4k.jpg")
	timber.roughness_texture = load(STREET_TEXTURES + "old_planks_02_rough_4k.jpg")
	timber.uv1_triplanar = true
	timber.uv1_scale = Vector3.ONE * 0.5
	timber.roughness = 1.0
	worn_concrete = concrete.duplicate() as StandardMaterial3D
	worn_concrete.albedo_texture = load(STREET_TEXTURES + "cracked_concrete_diff_4k.jpg")
	worn_concrete.albedo_color = Color(0.75, 0.73, 0.68)
	worn_concrete.normal_enabled = false
	var street := get_node("../Roads/WestStubRoad") as CSGBox3D
	var street_finish := street.material.duplicate() as StandardMaterial3D
	street_finish.albedo_texture = load(STREET_TEXTURES + "asphalt_02_diff_4k.jpg")
	street_finish.roughness_texture = load(STREET_TEXTURES + "asphalt_02_rough_4k.jpg")
	street_finish.normal_enabled = false
	street_finish.ao_enabled = false
	street_finish.uv1_triplanar = true
	street_finish.uv1_scale = Vector3.ONE / 3.0
	street.material = street_finish
	for north: bool in [true, false]:
		_build_row(north)
	_build_turnaround()
	# The end property shares its side boundaries with the first street lots.
	_fence(Vector3(-190, 0, 88), Vector3(-123, 0, 88))
	_fence(Vector3(-190, 0, 162), Vector3(-123, 0, 162))
	_fence(Vector3(-190, 0, 88), Vector3(-190, 0, 162))
	_fence(Vector3(-123, 0, 88), Vector3(-123, 0, 112))
	_fence(Vector3(-123, 0, 138), Vector3(-123, 0, 162))


func _build_turnaround() -> void:
	var road := get_node("../Roads/WestStubRoad") as CSGBox3D
	var asphalt := road.material.duplicate() as StandardMaterial3D
	asphalt.uv1_triplanar = true
	asphalt.uv1_scale = Vector3.ONE / 3.0
	var bulb := Node3D.new()
	bulb.name = "UpperTurnaround"
	generated.add_child(bulb)
	bulb.position = Vector3(-129, 0, 125)
	preload("res://scenes/environment/turnaround_geometry.gd").build(bulb, 10.0, 3.0, asphalt, concrete)
	var hero := get_node("../Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	var entrance := hero.get_node("Entrance") as Marker3D
	var porch := entrance.global_position
	porch.y = 0
	_strip("EstateEntryWalk", Vector3(-140, 0, 119), porch, 2.4, concrete)
	_strip("EstateParkingDrive", Vector3(-139, 0, 131), Vector3(-153, 0, 141), 4.2, concrete)
	_strip("EstateCurbApron", Vector3(-137.95, 0, 130.37), Vector3(-139, 0, 131), 4.2, concrete)
	_strip("EstateParkingPad", Vector3(-153, 0, 141), Vector3(-162, 0, 141), 5.5, concrete)
	_strip("EstatePorchConnection", Vector3(-153, 0, 141), Vector3(-153, 0, 114), 1.5, concrete)
	for point: Vector3 in [Vector3(-150, 0, 101), Vector3(-177, 0, 151), Vector3(-180, 0, 97)]:
		_asset("res://assets/local_licensed/retro_tree_pack/low_res/dead_tree_rt_1.glb", point, 1.6)
	for point: Vector3 in [Vector3(-145, 0, 109), Vector3(-146, 0, 136), Vector3(-170, 0, 148)]:
		_asset("res://assets/local_licensed/psx_hedges/bush_overgrown_dead.glb", point, 1.1)


func _arc_surface(label: String, inner: float, outer: float, start: float, finish: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a := lerpf(start, finish, float(i) / 96.0)
		var b := lerpf(start, finish, float(i + 1) / 96.0)
		var p := Vector3(cos(a) * inner - 129, 0.14, sin(a) * inner + 125)
		var q := Vector3(cos(a) * outer - 129, 0.14, sin(a) * outer + 125)
		var r := Vector3(cos(b) * outer - 129, 0.14, sin(b) * outer + 125)
		var s := Vector3(cos(b) * inner - 129, 0.14, sin(b) * inner + 125)
		for vertex: Vector3 in [p, q, r, p, r, s]:
			surface.set_uv(Vector2(vertex.x, vertex.z) * 0.5)
			surface.add_vertex(vertex)
	surface.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = surface.commit()
	mesh.material_override = material
	generated.add_child(mesh)
	mesh.create_trimesh_collision()


func _dress_property(house: Node3D, index: int, x: float, z: float, direction: float) -> void:
	var mesh := house.get_node_or_null("GeneratedHouse/HouseMesh") as MeshInstance3D
	if mesh != null:
		var palette: Array[Color] = [Color(0.85, 0.84, 0.76), Color(0.66, 0.73, 0.68), Color(0.74, 0.76, 0.81), Color(0.83, 0.70, 0.61)]
		for i in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(i) as StandardMaterial3D
			if source != null:
				var material := source.duplicate() as StandardMaterial3D
				material.albedo_color *= palette[index % palette.size()]
				mesh.set_surface_override_material(i, material)
		# Width and height variants keep the same porch depth and path alignment.
		var variants: Array[Vector3] = [Vector3(1, 1, 1), Vector3(0.92, 0.88, 1), Vector3(0.96, 1.07, 1)]
		var house_root := house.get_node("GeneratedHouse") as Node3D
		house_root.scale = variants[index % variants.size()]
	var box_color := StandardMaterial3D.new()
	box_color.albedo_color = Color(0.22, 0.28, 0.27) if index % 2 == 0 else Color(0.34, 0.23, 0.18)
	box_color.roughness = 0.9
	var mailbox := Vector3(x + 6.8, 0, z + direction * 15.0)
	_box("MailboxPost", mailbox + Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), timber, false)
	_box("Mailbox", mailbox + Vector3(0, 1.12, 0), Vector3(0.32, 0.28, 0.48), box_color, false)
	var number := Label3D.new()
	number.text = str(101 + index * 2)
	number.font_size = 40
	number.pixel_size = 0.004
	generated.add_child(number)
	number.position = mailbox + Vector3(0, 1.14, direction * 0.245)
	number.rotation.y = 0.0 if direction > 0 else PI
	_box("PlantingBed", Vector3(x - 4.5, 0.12, z + direction * 11.5), Vector3(3.8, 0.23, 1.7), timber, false)
	for offset: float in [-1.1, 0.9]:
		_asset("res://assets/local_licensed/psx_hedges/bush_overgrown_dead.glb", Vector3(x - 4.5 + offset, 0.2, z + direction * 11.5), 0.65)
	if index % 3 == 0:
		_asset("res://assets/local_licensed/retro_tree_pack/low_res/small_tree_rt_1.glb", Vector3(x - 10.5, 0, z - direction * 3), 2.6)
	if index % 4 == 2:
		# A covered parking space changes the property silhouette without blocking its drive.
		for dx: float in [7.7, 12.3]:
			for dz: float in [-3.0, 3.0]:
				_box("CarportPost", Vector3(x + dx, 1.3, z + dz), Vector3(0.14, 2.6, 0.14), timber, true)
		_box("CarportRoof", Vector3(x + 10, 2.7, z), Vector3(5.0, 0.18, 6.8), box_color, true)
	if index % 3 == 1:
		_box("Bin", Vector3(x + 6.4, 0.5, z + direction * 5.5), Vector3(0.65, 1, 0.65), box_color, true)
	if index % 4 == 1:
		_box("GardenTerrace", Vector3(x - 10, 0.08, z + direction * 7), Vector3(4.0, 0.12, 4.0), worn_concrete, false)
		_asset(FURNITURE + "tableRound.glb", Vector3(x - 10, 0.15, z + direction * 7), 1.5)
		_asset(FURNITURE + "chair.glb", Vector3(x - 11.3, 0.15, z + direction * 7), 1.5)
		_asset(FURNITURE + "pottedPlant.glb", Vector3(x - 8.6, 0.15, z + direction * 8.2), 1.5)
	elif index % 4 == 3:
		_asset(FURNITURE + "bench.glb", Vector3(x - 10, 0.08, z + direction * 8), 1.6)


func _asset(path: String, point: Vector3, size: float) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	generated.add_child(instance)
	instance.position = point
	instance.scale = Vector3.ONE * size


func _build_row(north: bool) -> void:
	var house_z := 103.0 if north else 147.0
	var direction := 1.0 if north else -1.0
	var road_edge := 122.0 if north else 128.0
	var walk_z := road_edge - direction * 2.6
	var rear_z := house_z - direction * 15.0
	var front_fence_z := house_z + direction * 8.0
	var curb_start := -119.0
	for i in range(7):
		var x := -108.0 + float(i) * 30.0
		var prefix := "WestStubNorth_" if north else "WestStubSouth_"
		var house := get_node_or_null("../Buildings/ResidentialLots/" + prefix + "%02d" % (i + 1)) as Node3D
		if house == null:
			continue
		_dress_property(house, i + (7 if not north else 0), x, house_z, direction)
		# Consistent side parking, with enough space between car and shared fence.
		var parking_x := x + 10.0
		var crossing_near := walk_z + direction * sidewalk_width * 0.5
		var crossing_far := walk_z - direction * sidewalk_width * 0.5
		_strip("DrivewayApron", Vector3(parking_x, 0, road_edge), Vector3(parking_x, 0, crossing_near), driveway_width, concrete)
		_strip("DrivewayCrossing", Vector3(parking_x, 0, crossing_near), Vector3(parking_x, 0, crossing_far), driveway_width, concrete)
		_strip("Driveway", Vector3(parking_x, 0, crossing_far), Vector3(parking_x, 0, house_z + direction * 3.0), driveway_width, concrete)
		_strip("ParkingPad", Vector3(parking_x, 0, house_z - direction * 4.0), Vector3(parking_x, 0, house_z + direction * 3.0), 4.8, worn_concrete if i % 3 == 0 else concrete)
		_strip("FrontWalk", Vector3(x, 0, crossing_far), Vector3(x, 0, house_z + direction * 8.5), 1.4, concrete)
		_strip("ParkingToPorch", Vector3(x + 0.7, 0, house_z + direction * 10.0), Vector3(parking_x - driveway_width * 0.5, 0, house_z + direction * 10.0), 1.4, concrete)
		# Sidewalk spans the entire frontage, including each driveway crossing.
		var left := maxf(-119.0, x - 15.0)
		var right := minf(87.0, x + 15.0)
		_strip("Sidewalk", Vector3(left, 0, walk_z), Vector3(parking_x - driveway_width * 0.5, 0, walk_z), sidewalk_width, concrete)
		_strip("Sidewalk", Vector3(parking_x + driveway_width * 0.5, 0, walk_z), Vector3(right, 0, walk_z), sidewalk_width, concrete)
		var opening_left := parking_x - driveway_width * 0.5 - 0.25
		var opening_right := parking_x + driveway_width * 0.5 + 0.25
		_box("Curb", Vector3((curb_start + opening_left) * 0.5, 0.10, road_edge), Vector3(opening_left - curb_start, 0.2, 0.2), concrete, true)
		curb_start = opening_right
		_fence(Vector3(x - 15.0, 0, rear_z), Vector3(x + 15.0, 0, rear_z))
		if i > 0:
			_fence(Vector3(x - 15.0, 0, rear_z), Vector3(x - 15.0, 0, front_fence_z))
		if i == 6:
			_fence(Vector3(x + 15.0, 0, rear_z), Vector3(x + 15.0, 0, front_fence_z))
		if i % 3 == 1:
			var packed := load("res://assets/local_licensed/cars_bundle/Car.glb") as PackedScene
			var car := packed.instantiate() as Node3D
			generated.add_child(car)
			car.position = Vector3(parking_x, 0.12, house_z + direction * 2.0)
			car.rotation.y = 0.0 if north else PI
	_box("Curb", Vector3((curb_start + 96.0) * 0.5, 0.10, road_edge), Vector3(96.0 - curb_start, 0.2, 0.2), concrete, true)
	_strip("JunctionWalk", Vector3(87, 0, walk_z), Vector3(95, 0, walk_z), sidewalk_width, concrete)


func _strip(label: String, start: Vector3, end: Vector3, width: float, material: Material) -> void:
	var delta := end - start
	var item := _box(label, (start + end) * 0.5 + Vector3(0, 0.075, 0), Vector3(width, 0.12, delta.length()), material, false)
	item.rotation.y = atan2(delta.x, delta.z)


func _box(label: String, center: Vector3, dimensions: Vector3, material: Material, solid: bool) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.material_override = material
	generated.add_child(item)
	item.position = center
	if solid:
		var body := StaticBody3D.new()
		item.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		body.add_child(collision)
	return item


func _fence(start: Vector3, end: Vector3) -> void:
	var delta := end - start
	var count := ceili(delta.length() / 2.5)
	for i in range(count + 1):
		var point := start.lerp(end, float(i) / float(count))
		_box("FencePost", point + Vector3(0, 0.75, 0), Vector3(0.13, 1.5, 0.13), timber, false)
	# Closely spaced boards form a residential boundary, with two visible rails.
	var boards := ceili(delta.length() / 0.18)
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(0.15, 1.34, 0.045)
	board_mesh.material = timber
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = board_mesh
	batch.instance_count = boards
	var fence_boards := MultiMeshInstance3D.new()
	fence_boards.name = "FenceBoards"
	fence_boards.multimesh = batch
	generated.add_child(fence_boards)
	for i in range(boards):
		var point := start.lerp(end, (float(i) + 0.5) / float(boards))
		batch.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(-delta.z, delta.x)), point + Vector3(0, 0.67, 0)))
	for height: float in [0.35, 1.05]:
		var rail := _box("FenceRail", (start + end) * 0.5 + Vector3(0, height, 0), Vector3(0.09, 0.09, delta.length()), timber, false)
		rail.rotation.y = atan2(delta.x, delta.z)
	var barrier := _box("FenceCollision", (start + end) * 0.5 + Vector3(0, 0.65, 0), Vector3(0.12, 1.3, delta.length()), timber, true)
	barrier.rotation.y = atan2(delta.x, delta.z)
	barrier.visible = false
