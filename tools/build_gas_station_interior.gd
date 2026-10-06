extends SceneTree

## Bakes an editable scene; no furniture generation runs during gameplay.
const ASSETS: String = "res://models/gas_station_interior/"
const OUTPUT: String = "res://scenes/environment/gas_station_interior.tscn"
var scene: Node3D
var shell: Node3D
var dimensions: Dictionary
var stock: Dictionary = {}
var cream: StandardMaterial3D
var green: StandardMaterial3D
var dark: StandardMaterial3D
var wood: StandardMaterial3D
var paper: StandardMaterial3D
var glass: StandardMaterial3D

func _initialize() -> void:
	build.call_deferred()

func own(node: Node, parent: Node, label: String) -> void:
	node.name = label
	parent.add_child(node, true)
	node.owner = scene

func group(label: String) -> Node3D:
	var node := Node3D.new()
	own(node, scene, label)
	return node

func material(color: Color, roughness: float = 0.85) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	return result

func collision(parent: Node3D, label: String, size: Vector3, at: Vector3) -> void:
	var body := StaticBody3D.new()
	own(body, parent, label)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	own(shape, body, "Shape")
	shape.position = at

func box(parent: Node3D, label: String, at: Vector3, size: Vector3, finish: Material, solid: bool = false) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = finish
	own(visual, parent, label)
	visual.position = at
	if solid:
		collision(visual, "Collision", size, Vector3.ZERO)
	return visual

func cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, finish: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 16
	visual.mesh = mesh
	visual.material_override = finish
	own(visual, parent, label)
	visual.position = at
	return visual

func text(parent: Node3D, label: String, words: String, at: Vector3, pixels: float = 0.004, yaw: float = 0.0, color: Color = Color(0.83, 0.8, 0.65)) -> Label3D:
	var writing := Label3D.new()
	writing.text = words
	writing.font_size = 48
	writing.pixel_size = pixels
	writing.modulate = color
	writing.outline_size = 0
	writing.no_depth_test = false
	writing.shaded = true
	own(writing, parent, label)
	writing.position = at
	writing.rotation.y = yaw
	return writing

func asset(parent: Node3D, label: String, source: String, at: Vector3, yaw: float = 0.0) -> Node3D:
	var packed := load(ASSETS + source + ".glb") as PackedScene
	var item := packed.instantiate() as Node3D
	own(item, parent, label)
	item.position = at
	item.rotation.y = yaw
	item.set_meta("source_asset", source)
	var values: Array = dimensions[source]["size"]
	var size := Vector3(values[0], values[1], values[2])
	collision(item, "Footprint", size, Vector3.UP * size.y * 0.5)
	return item

func stock_item(source: String, pose: Transform3D) -> void:
	if not stock.has(source):
		stock[source] = []
	stock[source].append(pose)

func checkout_pose() -> Transform3D:
	# Rotate the entire checkout arrangement along the left wall, facing the shop.
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-5.9, 0, -0.5)) * Transform3D(Basis.IDENTITY, Vector3(4.1, 0, -2.1))

func stock_shelf(item: Node3D, wall_shelf: bool, index: int) -> void:
	var levels: Array[float] = [0.175, 0.459, 0.759]
	if wall_shelf:
		levels.append_array([1.059, 1.359])
	var types: Array[String] = ["Prop_Chip_Bag", "Prop_Snack_Box", "Prop_Soda_Can", "Prop_Juice_Bottle", "Prop_Water_Bottle"]
	# Imported wall shelving opens toward -Z; packaging labels face +Z.
	var faces: Array[float] = [-1.0 if wall_shelf else 1.0]
	if not wall_shelf:
		faces.append(-1.0)
	for shelf in levels.size():
		for side: float in faces:
			for column in 9:
				if (column + shelf * 3 + index) % 7 == 0:
					continue
				var source: String = types[(index + shelf + column / 3) % types.size()]
				var z := side * (0.035 if wall_shelf else 0.205)
				var point := Vector3(-0.72 + column * 0.18, levels[shelf] + 0.003, z)
				var twist := side * 0.04 * ((column % 3) - 1)
				var pose := item.transform * Transform3D(Basis(Vector3.UP, twist + (PI if side < 0.0 else 0.0)), point)
				stock_item(source, pose)

func transform_buffer(poses: Array) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for pose: Transform3D in poses:
		result.append_array(PackedFloat32Array([pose.basis.x.x, pose.basis.y.x, pose.basis.z.x, pose.origin.x, pose.basis.x.y, pose.basis.y.y, pose.basis.z.y, pose.origin.y, pose.basis.x.z, pose.basis.y.z, pose.basis.z.z, pose.origin.z]))
	return result

func bake_stock(parent: Node3D) -> void:
	for source: String in stock:
		var temporary := (load(ASSETS + source + ".glb") as PackedScene).instantiate()
		var visual := temporary.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = visual.mesh
		multimesh.instance_count = stock[source].size()
		multimesh.buffer = transform_buffer(stock[source])
		var display := MultiMeshInstance3D.new()
		display.multimesh = multimesh
		display.set_meta("source_asset", source)
		own(display, parent, source.trim_prefix("Prop_") + "Stock")
		temporary.free()

func architecture() -> void:
	var room := group("Architecture")
	# Keep the reimported station's UVs and wall, floor, and ceiling textures.
	# Bake collision from its geometry rather than covering it with replacement walls.
	var source := shell.get_node("stationV2") as Node3D
	for label: String in ["Store_Body", "Store_Cornice_001", "Store_Foundation", "Porch_Step", "Store_SideWindow1", "Store_SideWindow-1"]:
		var visual := source.get_node(label) as MeshInstance3D
		var body := StaticBody3D.new()
		own(body, room, label + "Collision")
		body.set_meta("surface", "tile" if label == "Store_Foundation" else "wood" if label == "Porch_Step" else "concrete")
		var shape := CollisionShape3D.new()
		var geometry := ConcavePolygonShape3D.new()
		geometry.backface_collision = true
		geometry.set_faces(visual.mesh.get_faces())
		shape.shape = geometry
		own(shape, body, "Shape")
		var pose: Transform3D = source.transform * visual.transform
		pose.origin -= Vector3(0.015458405, 0.43130732, -10.430483)
		shape.transform = pose
	for x: float in [-4.4, 4.4]:
		box(room, "FrontWindowGlass", Vector3(x, 1.65, 5.07), Vector3(3.78, 2.23, 0.02), glass, true)
	var door := Node3D.new()
	own(door, room, "OpenEntranceDoor")
	door.position = Vector3(-0.84, 0, 4.99)
	door.rotation.y = PI * 0.5
	box(door, "Glass", Vector3(0.8, 1.30, 0), Vector3(1.54, 2.50, 0.025), glass, true)
	for x: float in [0.015, 1.59]:
		box(door, "VerticalFrame", Vector3(x, 1.30, 0), Vector3(0.04, 2.60, 0.045), dark)
	for y: float in [0.035, 1.0, 2.575]:
		box(door, "HorizontalFrame", Vector3(0.8, y, 0), Vector3(1.60, 0.05, 0.045), dark)
	box(door, "Handle", Vector3(1.38, 1.1, 0.09), Vector3(0.035, 0.3, 0.035), cream)
	box(room, "EntranceMat", Vector3(0.2, 0.008, 3.7), Vector3(2.25, 0.016, 1.12), dark)
	text(room, "ExitSign", "EXIT", Vector3(0, 2.98, 4.84), 0.003, PI, Color(0.45, 0.8, 0.51))
	box(room, "Threshold", Vector3(0, -0.025, 4.97), Vector3(1.66, 0.05, 0.38), green, true)

func furniture() -> void:
	var shop := group("Furniture")
	var checkout := asset(shop, "CheckoutCounter", "Counter_Straight_L96in", Vector3(-4.1, 0, 2.1))
	var extension := asset(shop, "CounterExtension", "Counter_Straight_L72in", Vector3(-6.2336, 0, 2.1))
	checkout.transform = checkout_pose() * checkout.transform
	extension.transform = checkout_pose() * extension.transform
	asset(shop, "CoffeeCounter", "Counter_Raised_L72in", Vector3(6.93, 0, -1.55), -PI * 0.5)
	var shelf_index := 0
	for x: float in [-1.5, 1.5]:
		for z: float in [-1.45, 0.43]:
			var aisle := asset(shop, "LowAisle", "Gondola_2Side_L72in_H48in", Vector3(x, 0, z), PI * 0.5)
			stock_shelf(aisle, false, shelf_index)
			shelf_index += 1
	# All food bays belong in the customer area, clear of the cashier/storage space.
	for point: Vector3 in [Vector3(-7.2, 0, 3.75), Vector3(7.2, 0, 0.35), Vector3(7.2, 0, 2.3)]:
		var shelf := asset(shop, "WallShelving", "Gondola_Wall_L72in_H72in", point, -PI * 0.5 if point.x < 0.0 else PI * 0.5)
		stock_shelf(shelf, true, shelf_index)
		shelf_index += 1
	for x: float in [-1.7, 0.38, 2.46]:
		asset(shop, "DrinkCooler", "Island_Cooler_L72in", Vector3(x, 0, -4.1))
	asset(shop, "BaggedIce", "Ice_Merchandiser_2Door_W72in", Vector3(4.5, 0, -3.78))
	bake_stock(group("Merchandise"))

func decorations() -> void:
	var props := group("Details")
	box(props, "TillBase", Vector3(-3.5, 0.975, 2.05), Vector3(0.5, 0.11, 0.36), dark)
	var display := box(props, "RegisterScreen", Vector3(-3.5, 1.18, 1.96), Vector3(0.33, 0.3, 0.075), dark)
	display.rotation.x = -0.12
	var monitor := material(Color(0.075, 0.17, 0.13))
	box(props, "TillDisplayGlass", Vector3(-3.5, 1.18, 2.005), Vector3(0.285, 0.245, 0.007), monitor)
	text(props, "TillDisplayText", "THIRD WARD\n$ 0.00", Vector3(-3.5, 1.18, 2.013), 0.00052, 0, Color(0.53, 0.78, 0.53))
	for row in 3:
		for column in 5:
			box(props, "TillKey", Vector3(-3.68 + column * 0.086, 1.037, 2.095 + row * 0.06), Vector3(0.057, 0.018, 0.04), cream)
	box(props, "CounterNotice", Vector3(-2.98, 1.07, 2.30), Vector3(0.23, 0.30, 0.035), paper)
	text(props, "CashOnly", "CASH\nONLY", Vector3(-2.98, 1.07, 2.324), 0.00095, 0, Color(0.27, 0.08, 0.06))
	box(props, "Receipt", Vector3(-3.94, 0.924, 2.30), Vector3(0.09, 0.003, 0.22), paper)
	box(props, "CounterNotebook", Vector3(-4.94, 0.936, 1.99), Vector3(0.25, 0.03, 0.31), green)
	# Counter clutter is a tiny separate batch, avoiding individual draw calls.
	var counter_stock := MultiMeshInstance3D.new()
	var bag_scene := (load(ASSETS + "Prop_Chip_Bag.glb") as PackedScene).instantiate()
	var bag_mesh := bag_scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var bags := MultiMesh.new()
	bags.transform_format = MultiMesh.TRANSFORM_3D
	bags.mesh = bag_mesh.mesh
	bags.instance_count = 3
	var bag_poses: Array[Transform3D] = []
	for index in 3:
		bag_poses.append(Transform3D(Basis(Vector3.UP, 0.12 * index), Vector3(-3.12 + index * 0.16, 0.922, 1.94)))
	bags.buffer = transform_buffer(bag_poses)
	counter_stock.multimesh = bags
	own(counter_stock, props, "ImpulseSnacks")
	bag_scene.free()
	var flashlight := (load("res://scenes/items/counter_flashlight.tscn") as PackedScene).instantiate() as Node3D
	own(flashlight, props, "CounterFlashlight")
	flashlight.position = Vector3(-4.46, 0.956, 2.13)
	flashlight.rotation = Vector3(deg_to_rad(-3), deg_to_rad(-55), 0)
	cylinder(props, "CashierStoolSeat", Vector3(-4.85, 0.58, 0.95), 0.20, 0.075, dark)
	cylinder(props, "CashierStoolStem", Vector3(-4.85, 0.3, 0.95), 0.025, 0.55, dark)
	cylinder(props, "CashierStoolBase", Vector3(-4.85, 0.015, 0.95), 0.18, 0.025, dark)
	# Counter clutter, labels, stool, collisions and pickup move as one arrangement.
	for node: Node in props.get_children():
		var item := node as Node3D
		item.transform = checkout_pose() * item.transform
	# Aim the resting flashlight across the customer area, away from the left wall.
	flashlight.rotation = Vector3(deg_to_rad(-3), deg_to_rad(-90), 0)
	box(props, "CoffeeMachine", Vector3(6.91, 1.17, -1.85), Vector3(0.46, 0.50, 0.36), dark)
	cylinder(props, "CoffeeUrn", Vector3(6.92, 1.22, -1.18), 0.12, 0.6, cream)
	cylinder(props, "UrnLid", Vector3(6.92, 1.5325, -1.18), 0.14, 0.025, dark)
	box(props, "UrnTap", Vector3(6.72, 1.07, -1.18), Vector3(0.17, 0.045, 0.035), dark)
	for z: float in [-1.48, -1.62]:
		cylinder(props, "PaperCups", Vector3(6.67, 0.98, z), 0.037, 0.12, paper)
	box(props, "CoffeeDripTray", Vector3(6.68, 0.9325, -1.18), Vector3(0.22, 0.025, 0.18), dark)
	cylinder(props, "WasteBin", Vector3(5.7, 0.27, -0.4), 0.18, 0.54, dark)
	var cardboard := material(Color(0.32, 0.22, 0.13))
	for point: Vector3 in [Vector3(-5.65, 0.21, -3.77), Vector3(-5.45, 0.63, -3.77)]:
		box(props, "DeliveryCarton", point, Vector3(0.55, 0.42, 0.5), cardboard, true)
		box(props, "CartonTape", point + Vector3.UP * 0.212, Vector3(0.12, 0.005, 0.49), paper)
	box(props, "NoticeBoard", Vector3(-7.46, 2.25, 0.25), Vector3(0.045, 0.85, 0.75), wood)
	for index in 3:
		var notice := box(props, "CommunityNotice", Vector3(-7.427, 2.15 + index * 0.16, 0.05 + index * 0.17), Vector3(0.009, 0.27, 0.22), paper)
		notice.rotation.x = 0.08 * (index - 1)
	text(props, "CommunityHeading", "LOCAL NOTICES", Vector3(-7.408, 2.53, 0.25), 0.001, PI * 0.5, Color(0.26, 0.12, 0.07))
	for words: String in ["COLD DRINKS", "ICE / BAIT", "HOT COFFEE"]:
		var point := Vector3(0.38, 2.55, -4.58)
		var yaw := 0.0
		if words == "ICE / BAIT":
			point.x = 4.5
		elif words == "HOT COFFEE":
			point = Vector3(7.47, 2.78, -1.55)
			yaw = -PI * 0.5
		text(props, words.replace(" ", ""), words, point, 0.0038, yaw)
	text(props, "CoffeePrice", "FRESH POT  $1.25", Vector3(7.47, 2.49, -1.55), 0.0018, -PI * 0.5)
	text(props, "CheckoutHeading", "THIRD WARD\nFUEL & GENERAL STORE", Vector3(-7.46, 3.13, 1.2), 0.0023, PI * 0.5)
	for x: float in [-1.5, 1.5]:
		text(props, "AislePriceStrip", "SNACKS  /  TRAVEL", Vector3(x, 1.105, 1.351), 0.00125)

func lighting() -> void:
	var lights := group("Lighting")
	var diffuser := material(Color(0.22, 0.24, 0.21))
	for point: Vector3 in [Vector3(-3.8, 4.27, 0.9), Vector3(0, 4.27, -0.6), Vector3(4.3, 4.27, 1.0)]:
		box(lights, "FluorescentHousing", point, Vector3(0.24, 0.1, 1.4), dark)
		box(lights, "FluorescentDiffuser", point - Vector3.UP * 0.06, Vector3(0.18, 0.025, 1.30), diffuser)
	# Outdoor fog should not fill an enclosed, furnished room.
	var clear_air := FogVolume.new()
	own(clear_air, lights, "InteriorAir")
	clear_air.position = Vector3(0, 2.1, 0.1)
	clear_air.size = Vector3(15.0, 4.2, 9.0)
	var fog_material := FogMaterial.new()
	fog_material.density = -0.0472
	clear_air.material = fog_material

func encounter() -> void:
	var stage := group("Encounter")
	stage.set_script(load("res://scenes/environment/gas_station_encounter.gd"))
	var actor := (load("res://scenes/monsters/the_ridgeback/the_ridgeback.tscn") as PackedScene).instantiate() as Node3D
	own(actor, stage, "Ridgeback")
	actor.position = Vector3(-6.95, 0, -0.14)
	actor.set("activation_enabled", false)
	actor.set("damage_enabled", false)
	var markers: Dictionary = {
		"HiddenPosition": Vector3(-6.95, 0, -0.14),
		"RevealPosition": Vector3(-6.95, 0, -0.14),
		"AttackPosition": Vector3(-6.67, 0, -0.14),
		"PreviewPosition": Vector3(-4.55, 0.05, -0.14),
	}
	for label: String in markers:
		var marker := Marker3D.new()
		own(marker, stage, label)
		marker.position = markers[label]
	var roar := AudioStreamPlayer3D.new()
	own(roar, stage, "Roar")
	roar.stream = load("res://sounds/entities/gas_station/ridgeback_pickup_scream.wav")
	roar.bus = &"Effects"
	roar.position = markers["RevealPosition"] + Vector3.UP * 1.6
	roar.volume_db = -11.0
	roar.unit_size = 4.0
	roar.max_distance = 22.0
	var outro := (load("res://scenes/environment/gas_station_trailer_outro.tscn") as PackedScene).instantiate() as Node3D
	own(outro, stage, "TrailerOutro")

func build() -> void:
	dimensions = JSON.parse_string(FileAccess.get_file_as_string(ASSETS + "asset_dimensions.json"))
	scene = Node3D.new()
	scene.name = "Interior"
	scene.set_script(load("res://scenes/environment/gas_station_interior.gd"))
	root.add_child(scene)
	shell = (load("res://models/map/gas_station.tscn") as PackedScene).instantiate() as Node3D
	cream = material(Color(0.55, 0.56, 0.46))
	green = material(Color(0.13, 0.24, 0.21))
	dark = material(Color(0.035, 0.045, 0.04))
	wood = material(Color(0.27, 0.16, 0.09))
	paper = material(Color(0.68, 0.62, 0.45))
	glass = material(Color(0.17, 0.31, 0.28, 0.16), 0.15)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	architecture()
	furniture()
	decorations()
	lighting()
	encounter()
	var packed := PackedScene.new()
	var error := packed.pack(scene)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	print("Saved editable gas-station interior: ", OUTPUT, " (", error_string(error), ")")
	shell.free()
	scene.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
