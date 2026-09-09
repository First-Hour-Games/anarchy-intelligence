@tool
extends Node3D

var asphalt: StandardMaterial3D
var concrete: StandardMaterial3D
var trim: StandardMaterial3D

func _ready() -> void:
	call_deferred("build")

func build() -> void:
	var station := get_node("../Buildings/GasStation") as Node3D
	var store := station.get_node("Store") as Node3D
	store.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(145, 0.03, 26))
	station.get_node("StaticBody3D/CollisionShape3D").disabled = true
	var hidden := ["Wall", "Tiles", "Parking_lot", "Post_light", "Post_light_01", "Post_light_02", "Post_light_03", "Door", "Door_01"]
	for item in store.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if String(mesh.name) in hidden:
			mesh.visible = false
		if mesh.is_visible_in_tree() and (String(mesh.name) in ["6twelve", "Glasses", "Mostrator"] or String(mesh.name).begins_with("Shelf")):
			mesh.create_trimesh_collision()
	asphalt = _material(Color(0.78, 0.78, 0.78), "res://assets/local_licensed/street_materials/textures/asphalt_02_diff_4k.jpg")
	asphalt.uv1_scale = Vector3.ONE / 3.0
	concrete = _material(Color(0.82, 0.82, 0.77), "res://assets/local_licensed/materials/concrete034/Concrete034_Color.jpg")
	trim = _material(Color(0.15, 0.23, 0.22))
	var white := _material(Color(0.8, 0.79, 0.7))
	var floor_material := ShaderMaterial.new()
	floor_material.shader = load("res://shaders/clinic_floor.gdshader")
	_box("ShopFloor", Vector3(150.8, 0.055, 43.75), Vector3(22.3, 0.13, 19), floor_material)
	# Keep the selected tree style, but clear trunks out of the new shop/forecourt.
	var relocated := 0
	for node in get_parent().find_children("*", "Node3D", true, false):
		var tree := node as Node3D
		if not ("trees_v1/" in tree.scene_file_path or "retro_tree_pack/" in tree.scene_file_path):
			continue
		if Rect2(110, 7, 70, 49).has_point(Vector2(tree.global_position.x, tree.global_position.z)):
			tree.global_position = Vector3(186 + (relocated % 3) * 7, tree.global_position.y, 38 + (relocated / 3) * 8)
			relocated += 1
	# One asphalt scale across all road runs; sidewalks keep a separate concrete finish.
	for road in get_node("../Roads").get_children():
		if road is CSGBox3D:
			road.material = asphalt
	for path: String in ["../ConnectedUpperStreet/Properties/UpperTurnaround/RoadSurface", "../CulDeSacs/CrossroadWestTurnaround/LowerTurnaround/RoadSurface"]:
		var surface := get_node_or_null(path) as MeshInstance3D
		if surface != null:
			surface.material_override = asphalt
	_box("Forecourt", Vector3(145, 0.045, 21), Vector3(66, 0.09, 24), asphalt, false)
	_box("ConnectorEntry", Vector3(108, 0.05, 15), Vector3(8, 0.10, 8), asphalt, false)
	_box("MainStripExit", Vector3(173.5, 0.05, 6.5), Vector3(7, 0.10, 5), asphalt, false)
	_box("ShopWalk", Vector3(150.8, 0.06, 33.7), Vector3(24, 0.12, 2.5), concrete, false)
	_box("FrontCurb", Vector3(141, 0.12, 9), Vector3(58, 0.24, 0.18), concrete)
	_box("ExitCurbEnd", Vector3(177.6, 0.12, 9), Vector3(1.0, 0.24, 0.18), concrete)
	# Canopy clearance and wide circulation around two pump islands.
	_box("FuelCanopy", Vector3(151, 4.7, 20), Vector3(25, 0.32, 12), white)
	_box("CanopyFascia", Vector3(151, 4.7, 13.94), Vector3(25, 0.38, 0.12), trim, false)
	_label("NORTHWOOD FUEL", Vector3(151, 4.7, 13.85), 0.006, PI)
	for x: float in [145, 157]:
		_box("PumpIsland", Vector3(x, 0.16, 20), Vector3(1.7, 0.22, 5.0), concrete)
		_box("CanopyColumn", Vector3(x, 2.4, 21.5), Vector3(0.28, 4.6, 0.28), trim)
		_box("PumpBase", Vector3(x, 0.85, 19.5), Vector3(0.85, 1.2, 0.65), trim)
		_box("PumpHousing", Vector3(x, 1.65, 19.5), Vector3(1.0, 0.6, 0.72), white)
		for z: float in [19.12, 19.88]:
			_box("PumpDisplay", Vector3(x, 1.75, z), Vector3(0.64, 0.2, 0.025), trim, false)
		# Hanging hose and nozzle silhouettes on the side of each dispenser.
		_box("FuelHose", Vector3(x + 0.58, 1.05, 19.5), Vector3(0.06, 1.2, 0.06), trim, false)
		_box("HoseReturn", Vector3(x + 0.40, 0.49, 19.5), Vector3(0.36, 0.06, 0.06), trim, false)
		_box("Nozzle", Vector3(x + 0.49, 1.42, 19.5), Vector3(0.18, 0.25, 0.09), trim, false)
		for z: float in [17.7, 22.3]:
			_box("Bollard", Vector3(x, 0.63, z), Vector3(0.18, 1.0, 0.18), white)
		var light := OmniLight3D.new()
		add_child(light)
		light.position = Vector3(x, 4.25, 20)
		light.omni_range = 10
		light.light_energy = 0.7
		light.light_color = Color(0.75, 0.82, 0.72)
	for x: float in [166, 169, 172, 175]:
		_box("ParkingStripe", Vector3(x, 0.097, 29), Vector3(0.08, 0.01, 5), white, false)
	# Preserve the source shop's stocked aisles and register; make the story item visible inside.
	var flashlight := get_node("../AtmosphereProps/DroppedFlashlight") as Node3D
	flashlight.global_position = store.to_global(Vector3(-13.0, 1.63, -12.7))
	for point: Vector3 in [Vector3(-6, 3, -10), Vector3(-6, 3, -16), Vector3(-13, 3, -13)]:
		var light := OmniLight3D.new()
		add_child(light)
		light.global_position = store.to_global(point)
		light.omni_range = 7
		light.light_energy = 0.55
		light.light_color = Color(0.8, 0.86, 0.75)
	var marker := Marker3D.new()
	marker.name = "StoreEntrance"
	add_child(marker)
	marker.global_position = store.to_global(Vector3(-5.8, 0.12, -8.0))

func _material(color: Color, texture: String = "") -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	if not texture.is_empty():
		material.albedo_texture = load(texture)
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * 0.5
	return material

func _box(label: String, point: Vector3, dimensions: Vector3, material: Material, solid: bool = true) -> void:
	var item := MeshInstance3D.new()
	item.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	item.mesh = mesh
	item.material_override = material
	add_child(item)
	item.position = point
	if solid:
		item.create_trimesh_collision()

func _label(text: String, point: Vector3, pixels: float, yaw: float) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = pixels
	add_child(label)
	label.position = point
	label.rotation.y = yaw
