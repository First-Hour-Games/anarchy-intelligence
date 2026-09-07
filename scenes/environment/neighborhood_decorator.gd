@tool
extends Node3D

## Deterministic neighborhood dressing that respects house lots and road space.

class MeshTemplate:
	extends RefCounted
	var mesh: Mesh
	var source_transform := Transform3D.IDENTITY
	var ground_center := Vector3.ZERO


const GENERATED_ROOT_NAME := "GeneratedNeighborhood"
const HOUSE_PACK_PATH := "res://assets/local_licensed/house/Models/House.fbx"
const BUSH_SCENE_PATH := "res://assets/local_licensed/psx_hedges/bush_overgrown_dead.glb"
const CITY_MODEL_ROOT := "res://assets/local_licensed/city_kit_roads/Models/"
const TREE_SCENE_PATHS := [
	"res://assets/local_licensed/retro_tree_pack/low_res/small_tree_rt_1.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/tree_rt_1.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/tree_rt_2.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/tree_rt_2_1.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/tree_rt_3.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/tree_rt_4.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/dead_tree_rt_1.glb",
	"res://assets/local_licensed/retro_tree_pack/low_res/dead_tree_rt_2.glb",
	"res://assets/local_licensed/trees_v1/trees_v1_tree.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_001.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_002.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_003.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_004.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_005.tscn",
	"res://assets/local_licensed/trees_v1/trees_v1_tree_006.tscn",
]
const CAR_SCENE_PATHS := [
	"res://assets/local_licensed/cars_bundle/Car.glb",
	"res://assets/local_licensed/cars_bundle/SUV.glb",
	"res://assets/local_licensed/cars_bundle/Taxi.glb",
]
## 1m-wide modular fence segment (Kenney Graveyard Kit); chained along Z to
## form a side-yard fence line for a subset of houses.
const FENCE_SCENE_PATHS := [
	"res://assets/local_licensed/graveyard_kit/Models/iron-fence.glb",
	"res://assets/local_licensed/graveyard_kit/Models/iron-fence-damaged.glb",
]
const YARD_CLUTTER_SCENE_PATHS := [
	"res://assets/local_licensed/nature_kit/Models/rock_smallA.glb",
	"res://assets/local_licensed/nature_kit/Models/rock_smallB.glb",
	"res://assets/local_licensed/nature_kit/Models/rock_smallC.glb",
	"res://assets/local_licensed/nature_kit/Models/rock_smallD.glb",
	"res://assets/local_licensed/nature_kit/Models/stump_old.glb",
	"res://assets/local_licensed/nature_kit/Models/stump_round.glb",
	"res://assets/local_licensed/nature_kit/Models/log_large.glb",
]
## These props sit ~0.05m below their own origin (measured via headless AABB
## dump), so lift them slightly to avoid sinking into the ground plane.
const YARD_CLUTTER_Y_OFFSET := 0.05
const DRIVEWAY_TEXTURE_BASE := "res://assets/local_licensed/materials/concrete034/Concrete034_"
const DRIVEWAY_SIZE := Vector3(3.4, 0.05, 9.0)
const HOUSE_PROP_NAMES := [
	"Hedges",
	"NaturePlants_01_001",
	"NaturePlants_02_001",
	"NaturePlants_04_001",
	"NaturePlants_05_001",
	"NaturePlants_06_001",
	"trash_can",
	"Garbage_bags_001",
	"Mower",
]
const PERIMETER_BANDS := [
	Rect2(-335.0, -62.0, 670.0, 30.0),
	Rect2(-335.0, 392.0, 670.0, 28.0),
	Rect2(-338.0, -30.0, 95.0, 420.0),
	Rect2(275.0, -25.0, 58.0, 420.0),
]
const PERIMETER_COUNTS := [45, 45, 30, 25]
## Extra margin (world units) added around each road's actual footprint when
## deriving clearance rects, so scattered props keep clear of shoulders/sidewalks.
const ROAD_CLEARANCE_PADDING := 12.0
const CULDESAC_TREE_CLEARANCE_RADIUS := 22.0
const STREETLIGHTS := [
	Vector3(-90.0, 0.0, 114.0), Vector3(-20.0, 0.0, 114.0), Vector3(50.0, 0.0, 114.0),
	Vector3(-55.0, 0.0, 136.0), Vector3(15.0, 0.0, 136.0), Vector3(75.0, 0.0, 136.0),
	Vector3(90.0, 0.0, 60.0), Vector3(90.0, 0.0, 175.0), Vector3(90.0, 0.0, 300.0),
	Vector3(110.0, 0.0, 90.0), Vector3(110.0, 0.0, 195.0),
	Vector3(160.0, 0.0, 214.0), Vector3(240.0, 0.0, 214.0), Vector3(20.0, 0.0, 236.0),
	Vector3(-210, 0, -7), Vector3(-155, 0, 7), Vector3(-100, 0, -7),
	Vector3(-45, 0, 7), Vector3(10, 0, -7), Vector3(65, 0, 7),
	Vector3(120, 0, -7), Vector3(180, 0, -7), Vector3(235, 0, 7),
	Vector3(94, 0, 25), Vector3(106, 0, 145), Vector3(94, 0, 250),
	Vector3(106, 0, 330), Vector3(94, 0, 370),
	Vector3(-132, 0, 111), Vector3(-55, 0, 211), Vector3(65, 0, 214),
]
const STREETLIGHT_ROTATIONS := [
	PI, PI, PI, 0.0, 0.0, 0.0,
	-PI * 0.5, -PI * 0.5, -PI * 0.5, PI * 0.5, PI * 0.5,
	PI, PI, 0.0,
	PI, 0.0, PI, 0.0, PI, 0.0, PI, PI, 0.0,
	-PI * 0.5, PI * 0.5, -PI * 0.5, PI * 0.5, -PI * 0.5,
	PI, PI, PI,
]
const UTILITY_POLES := [
	Vector3(-240.0, 0.0, 12.0), Vector3(-180.0, 0.0, 12.0),
	Vector3(-120.0, 0.0, 12.0), Vector3(-60.0, 0.0, 12.0),
	Vector3(0.0, 0.0, 12.0), Vector3(60.0, 0.0, 12.0),
	Vector3(180.0, 0.0, 12.0), Vector3(240.0, 0.0, 12.0),
]
const STOP_SIGNS := [
	Vector3(91.0, 0.0, 10.0),
	Vector3(91.0, 0.0, 115.0), Vector3(109.0, 0.0, 135.0),
	Vector3(91.0, 0.0, 215.0), Vector3(109.0, 0.0, 235.0),
]

@export_group("Generation")
@export_range(0.0, 5.0, 0.05) var streetlight_energy: float = 2.2:
	set(value):
		streetlight_energy = value
		_queue_rebuild()
@export var decoration_enabled := true:
	set(value):
		decoration_enabled = value
		_queue_rebuild()
@export var preview_in_editor := true:
	set(value):
		preview_in_editor = value
		_queue_rebuild()
@export var generation_seed := 1978:
	set(value):
		generation_seed = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var lot_shrub_chance := 0.85:
	set(value):
		lot_shrub_chance = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var yard_tree_chance := 0.7:
	set(value):
		yard_tree_chance = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var driveway_chance := 0.55:
	set(value):
		driveway_chance = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var parked_car_chance := 0.45:
	set(value):
		parked_car_chance = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var side_fence_chance := 0.3:
	set(value):
		side_fence_chance = value
		_queue_rebuild()
@export_range(0.0, 1.0, 0.05) var yard_clutter_chance := 0.35:
	set(value):
		yard_clutter_chance = value
		_queue_rebuild()
@export var houses_path := NodePath("../Buildings/ResidentialLots")
@export var roads_path := NodePath("../Roads")
@export var culdesacs_path := NodePath("../CulDeSacs")

var _scene_cache: Dictionary[String, PackedScene] = {}
var _rebuild_queued := false
var _driveway_material: StandardMaterial3D
## Derived each rebuild from the actual Roads/CulDeSacs nodes so clearance
## zones can never drift out of sync with the road geometry they protect.
var _road_clearance_rects: Array[Rect2] = []
var _culdesac_clearance_centers: Array[Vector2] = []


func _ready() -> void:
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_rebuild")


func _rebuild() -> void:
	_rebuild_queued = false
	var existing := get_node_or_null(GENERATED_ROOT_NAME)
	if existing:
		existing.free()
	if not decoration_enabled or (Engine.is_editor_hint() and not preview_in_editor):
		return

	var generated_root := Node3D.new()
	generated_root.name = GENERATED_ROOT_NAME
	add_child(generated_root)

	_update_road_clearances()

	var random := RandomNumberGenerator.new()
	random.seed = generation_seed
	var occupied_tree_positions: Array[Vector3] = []
	_add_perimeter_forest(generated_root, random, occupied_tree_positions)
	_add_lot_dressing(generated_root, random, occupied_tree_positions)
	_add_street_furniture(generated_root)


func _add_perimeter_forest(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	occupied_positions: Array[Vector3]
) -> void:
	for band_index in PERIMETER_BANDS.size():
		var band: Rect2 = PERIMETER_BANDS[band_index]
		var target_count: int = PERIMETER_COUNTS[band_index]
		var placed := 0
		var attempts := 0
		while placed < target_count and attempts < target_count * 30:
			attempts += 1
			var point := Vector3(
				random.randf_range(band.position.x, band.end.x),
				0.0,
				random.randf_range(band.position.y, band.end.y)
			)
			if _inside_road_clearance(point) or not _far_enough(point, occupied_positions, 11.0):
				continue
			_spawn_tree(generated_root, random, point, "PerimeterTree_%03d" % occupied_positions.size())
			occupied_positions.append(point)
			placed += 1


func _add_lot_dressing(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	occupied_tree_positions: Array[Vector3]
) -> void:
	var houses := get_node_or_null(houses_path) as Node3D
	if houses == null:
		push_warning("Neighborhood decorator could not find residential lots at %s." % houses_path)
		return

	var prop_templates := _load_house_prop_templates()
	var house_nodes: Array[Node3D] = []
	for child in houses.get_children():
		# The upper street has an explicit connected property layout.
		if str(child.name).begins_with("WestStubNorth_") or str(child.name).begins_with("WestStubSouth_"):
			continue
		if child is Node3D and not child.get_meta("skip_neighborhood_decoration", false):
			house_nodes.append(child as Node3D)

	for index in house_nodes.size():
		var house: Node3D = house_nodes[index]
		if random.randf() <= lot_shrub_chance:
			_spawn_lot_scene(
				generated_root,
				house,
				BUSH_SCENE_PATH,
				Vector3(-5.6, 0.0, 10.8),
				random.randf_range(0.85, 1.3),
				random.randf_range(-PI, PI),
				"FrontBush_%02d_A" % index
			)
		if random.randf() <= lot_shrub_chance * 0.6:
			_spawn_lot_scene(
				generated_root,
				house,
				BUSH_SCENE_PATH,
				Vector3(5.6, 0.0, 10.8),
				random.randf_range(0.8, 1.2),
				random.randf_range(-PI, PI),
				"FrontBush_%02d_B" % index
			)

		if random.randf() <= yard_tree_chance:
			var tree_side := -1.0 if index % 2 == 0 else 1.0
			var local_tree_position := Vector3(tree_side * 10.8, 0.0, random.randf_range(-2.0, 5.0))
			var world_tree_position: Vector3 = house.global_transform * local_tree_position
			if not _inside_road_clearance(world_tree_position) and _far_enough(world_tree_position, occupied_tree_positions, 9.0):
				_spawn_tree(generated_root, random, world_tree_position, "YardTree_%02d" % index, true)
				occupied_tree_positions.append(world_tree_position)

		if index % 4 == 0:
			_spawn_house_prop(
				generated_root,
				house,
				prop_templates,
				"Hedges",
				Vector3(14.0, 0.0, 0.0),
				Vector3(1.0, random.randf_range(0.8, 1.05), random.randf_range(0.82, 0.96)),
				0.0,
				"LotHedge_%02d" % index
			)

		if index % 3 == 1:
			var plant_names := [
				"NaturePlants_01_001", "NaturePlants_02_001", "NaturePlants_04_001",
				"NaturePlants_05_001", "NaturePlants_06_001",
			]
			var plant_name: String = plant_names[random.randi_range(0, plant_names.size() - 1)]
			_spawn_house_prop(
				generated_root,
				house,
				prop_templates,
				plant_name,
				Vector3(random.randf_range(-4.5, 4.5), 0.0, 10.6),
				Vector3.ONE * random.randf_range(0.75, 1.1),
				random.randf_range(-PI, PI),
				"FoundationPlant_%02d" % index
			)

		if index % 6 == 2:
			_spawn_house_prop(
				generated_root, house, prop_templates, "trash_can",
				Vector3(7.8, 0.0, 11.2), Vector3.ONE, random.randf_range(-0.2, 0.2),
				"TrashCan_%02d" % index
			)
		if index % 12 == 2:
			_spawn_house_prop(
				generated_root, house, prop_templates, "Garbage_bags_001",
				Vector3(8.8, 0.0, 11.0), Vector3.ONE, random.randf_range(-PI, PI),
				"GarbageBags_%02d" % index
			)
		if index % 17 == 5:
			_spawn_house_prop(
				generated_root, house, prop_templates, "Mower",
				Vector3(-8.5, 0.0, -4.0), Vector3.ONE, random.randf_range(-0.35, 0.35),
				"AbandonedMower_%02d" % index
			)

		# Driveway/car go on the opposite side from the yard tree so they don't
		# overlap it; the side fence runs down the yard-tree side instead.
		var driveway_side := 1.0 if index % 2 == 0 else -1.0
		if random.randf() <= driveway_chance:
			_spawn_driveway(generated_root, house, driveway_side, "Driveway_%02d" % index)
			if random.randf() <= parked_car_chance:
				_spawn_parked_car(generated_root, random, house, driveway_side, "ParkedCar_%02d" % index)

		if random.randf() <= side_fence_chance:
			_spawn_side_fence(generated_root, random, house, -driveway_side, "SideFence_%02d" % index)

		if random.randf() <= yard_clutter_chance:
			var clutter_side := driveway_side if random.randf() < 0.5 else -driveway_side
			var local_clutter_position := Vector3(
				clutter_side * random.randf_range(11.5, 14.0),
				YARD_CLUTTER_Y_OFFSET,
				random.randf_range(-3.0, 9.0)
			)
			_spawn_yard_clutter(generated_root, random, house, local_clutter_position, "YardClutter_%02d" % index)


func _get_driveway_material() -> StandardMaterial3D:
	if _driveway_material != null:
		return _driveway_material
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(DRIVEWAY_TEXTURE_BASE + "Color.jpg")
	material.roughness_texture = load(DRIVEWAY_TEXTURE_BASE + "Roughness.jpg")
	material.normal_enabled = true
	material.normal_texture = load(DRIVEWAY_TEXTURE_BASE + "NormalGL.jpg")
	material.uv1_scale = Vector3(1.2, 3.2, 1.0)
	_driveway_material = material
	return material


func _spawn_driveway(generated_root: Node3D, house: Node3D, side: float, node_name: String) -> void:
	if _has_connected_drive(house):
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = DRIVEWAY_SIZE
	mesh_instance.mesh = box
	mesh_instance.material_override = _get_driveway_material()
	generated_root.add_child(mesh_instance)
	var local_position := Vector3(side * 9.5, 0.03, 6.5)
	mesh_instance.global_transform = house.global_transform * Transform3D(Basis.IDENTITY, local_position)


func _spawn_parked_car(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	house: Node3D,
	side: float,
	node_name: String
) -> void:
	var scene_path: String = CAR_SCENE_PATHS[random.randi_range(0, CAR_SCENE_PATHS.size() - 1)]
	var local_position := Vector3(side * 9.5, 0.0, random.randf_range(7.5, 9.5))
	var rotation_y := 0.0 if random.randf() < 0.5 else PI
	_spawn_lot_scene(generated_root, house, scene_path, local_position, 1.0, rotation_y, node_name)


func _has_connected_drive(house: Node3D) -> bool:
	var name := String(house.name)
	return name.begins_with("Connector") or name.begins_with("CrossroadNorth") or name.begins_with("CrossroadSouth")

func _spawn_side_fence(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	house: Node3D,
	side: float,
	node_name: String
) -> void:
	var scene_path: String = FENCE_SCENE_PATHS[random.randi_range(0, FENCE_SCENE_PATHS.size() - 1)]
	var segment_count := random.randi_range(4, 7)
	var start_z := random.randf_range(-2.0, 0.0)
	for segment_index in segment_count:
		var local_position := Vector3(side * 13.5, 0.0, start_z + segment_index * 1.0)
		_spawn_lot_scene(
			generated_root, house, scene_path, local_position, 1.0, PI * 0.5,
			"%s_%d" % [node_name, segment_index]
		)


func _spawn_yard_clutter(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	house: Node3D,
	local_position: Vector3,
	node_name: String
) -> void:
	var scene_path: String = YARD_CLUTTER_SCENE_PATHS[random.randi_range(0, YARD_CLUTTER_SCENE_PATHS.size() - 1)]
	_spawn_lot_scene(
		generated_root, house, scene_path, local_position,
		random.randf_range(0.85, 1.3), random.randf_range(-PI, PI), node_name
	)


func _add_street_furniture(generated_root: Node3D) -> void:
	for index in STREETLIGHTS.size():
		var position: Vector3 = STREETLIGHTS[index]
		var rotation_y: float = STREETLIGHT_ROTATIONS[index]
		_spawn_world_scene(
			generated_root,
			CITY_MODEL_ROOT + "light-curved.glb",
			position,
			rotation_y,
			10.0,
			"Streetlight_%02d" % index
		)
		var lamp_light := OmniLight3D.new()
		lamp_light.name = "StreetlightGlow_%02d" % index
		lamp_light.position = position + Vector3(0.0, 6.2, 0.0)
		lamp_light.light_color = Color(1.0, 0.72, 0.43)
		# Steady, uneven pools of light; no strobing or map-wide ambient boost.
		lamp_light.light_energy = streetlight_energy * (0.72 if index % 5 == 3 else 1.0)
		lamp_light.omni_range = 18.0
		lamp_light.shadow_enabled = false
		generated_root.add_child(lamp_light)

	for index in UTILITY_POLES.size():
		_spawn_world_scene(
			generated_root,
			CITY_MODEL_ROOT + "electricity-pole-single.glb",
			UTILITY_POLES[index],
			0.0,
			10.0,
			"UtilityPole_%02d" % index
		)

	for index in STOP_SIGNS.size():
		_spawn_world_scene(
			generated_root,
			CITY_MODEL_ROOT + "road-sign-stop.glb",
			STOP_SIGNS[index],
			PI * 0.5 if index % 2 == 0 else 0.0,
			5.5,
			"StopSign_%02d" % index
		)

	_spawn_world_scene(
		generated_root,
		CITY_MODEL_ROOT + "road-sign-street.glb",
		Vector3(109.0, 0.0, 115.0),
		0.0,
		5.5,
		"WestStubStreetSign"
	)
	_spawn_world_scene(
		generated_root,
		CITY_MODEL_ROOT + "road-sign-street.glb",
		Vector3(109.0, 0.0, 215.0),
		0.0,
		5.5,
		"CrossroadStreetSign"
	)
	_spawn_world_scene(
		generated_root,
		CITY_MODEL_ROOT + "dumpster.glb",
		Vector3(218.0, 0.0, 268.0),
		PI * 0.5,
		6.0,
		"CivicDumpster"
	)


func _spawn_tree(
	generated_root: Node3D,
	random: RandomNumberGenerator,
	position: Vector3,
	node_name: String,
	yard_tree := false
) -> void:
	var maximum_tree_index := 5 if yard_tree else TREE_SCENE_PATHS.size() - 1
	var scene_path: String = TREE_SCENE_PATHS[random.randi_range(0, maximum_tree_index)]
	var scale_factor := _tree_scale_for_path(scene_path, random, yard_tree)
	_spawn_world_scene(
		generated_root,
		scene_path,
		position,
		random.randf_range(-PI, PI),
		scale_factor,
		node_name
	)


func _tree_scale_for_path(
	scene_path: String,
	random: RandomNumberGenerator,
	yard_tree: bool
) -> float:
	var scale_modifier := 0.95 if yard_tree else 1.0
	if "trees_v1/" in scene_path:
		# These are already full-scale trees (unlike the low-res retro pack,
		# which is modeled small and relies on the multipliers below).
		return random.randf_range(0.85, 1.15) * scale_modifier
	if "small_tree" in scene_path:
		return random.randf_range(3.0, 5.0) * scale_modifier
	if "tree_rt_1.glb" in scene_path and not "dead_tree" in scene_path:
		return random.randf_range(2.5, 4.0) * scale_modifier
	if "dead_tree_rt_1" in scene_path:
		return random.randf_range(1.2, 1.8) * scale_modifier
	if "dead_tree_rt_2" in scene_path:
		return random.randf_range(2.0, 3.0) * scale_modifier
	return random.randf_range(1.45, 2.25) * scale_modifier


func _spawn_lot_scene(
	generated_root: Node3D,
	house: Node3D,
	scene_path: String,
	local_position: Vector3,
	scale_factor: float,
	rotation_y: float,
	node_name: String
) -> void:
	var packed := _get_scene(scene_path)
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return
	instance.name = node_name
	generated_root.add_child(instance)
	var local_basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	var lot_transform := house.global_transform * Transform3D(local_basis, local_position)
	instance.global_transform = lot_transform


func _spawn_world_scene(
	generated_root: Node3D,
	scene_path: String,
	position: Vector3,
	rotation_y: float,
	scale_factor: float,
	node_name: String
) -> void:
	var packed := _get_scene(scene_path)
	if packed == null:
		return
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return
	instance.name = node_name
	generated_root.add_child(instance)
	var basis := Basis(Vector3.UP, rotation_y).scaled(Vector3.ONE * scale_factor)
	instance.global_transform = Transform3D(basis, position)


func _get_scene(scene_path: String) -> PackedScene:
	if _scene_cache.has(scene_path):
		return _scene_cache[scene_path]
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("Unable to load neighborhood asset: %s" % scene_path)
		return null
	_scene_cache[scene_path] = packed
	return packed


func _load_house_prop_templates() -> Dictionary:
	var templates := {}
	var packed := load(HOUSE_PACK_PATH) as PackedScene
	if packed == null:
		push_warning("Unable to load neighborhood prop source: %s" % HOUSE_PACK_PATH)
		return templates
	var source_root: Node = packed.instantiate()
	for prop_name: String in HOUSE_PROP_NAMES:
		var source_mesh := source_root.get_node_or_null(NodePath(prop_name)) as MeshInstance3D
		if source_mesh == null or source_mesh.mesh == null:
			continue
		var bounds: AABB = source_mesh.transform * source_mesh.get_aabb()
		var template := MeshTemplate.new()
		template.mesh = source_mesh.mesh
		template.source_transform = source_mesh.transform
		template.ground_center = Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		templates[prop_name] = template
	source_root.free()
	return templates


func _spawn_house_prop(
	generated_root: Node3D,
	house: Node3D,
	templates: Dictionary,
	prop_name: String,
	local_position: Vector3,
	local_scale: Vector3,
	rotation_y: float,
	node_name: String
) -> void:
	var template := templates.get(prop_name) as MeshTemplate
	if template == null:
		return
	var wrapper := Node3D.new()
	wrapper.name = node_name
	generated_root.add_child(wrapper)
	var local_basis := Basis(Vector3.UP, rotation_y).scaled(local_scale)
	wrapper.global_transform = house.global_transform * Transform3D(local_basis, local_position)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = prop_name
	mesh_instance.mesh = template.mesh
	mesh_instance.transform = template.source_transform
	mesh_instance.position -= template.ground_center
	wrapper.add_child(mesh_instance)


## Reads the live Roads/CulDeSacs nodes and rebuilds the clearance zones from
## their actual transforms and sizes, replacing what used to be a second,
## hand-copied set of numbers that could silently drift from the real geometry.
func _update_road_clearances() -> void:
	_road_clearance_rects.clear()
	_culdesac_clearance_centers.clear()

	var roads := get_node_or_null(roads_path)
	if roads:
		for child in roads.get_children():
			var box := child as CSGBox3D
			if box == null:
				continue
			var center := Vector2(box.global_position.x, box.global_position.z)
			var half_extents := Vector2(box.size.x, box.size.z) * 0.5 + Vector2.ONE * ROAD_CLEARANCE_PADDING
			_road_clearance_rects.append(Rect2(center - half_extents, half_extents * 2.0))
	else:
		push_warning("Neighborhood decorator could not find roads at %s." % roads_path)

	var culdesacs := get_node_or_null(culdesacs_path)
	if culdesacs:
		for child in culdesacs.get_children():
			if child is Node3D:
				var position: Vector3 = (child as Node3D).global_position
				_culdesac_clearance_centers.append(Vector2(position.x, position.z))
	else:
		push_warning("Neighborhood decorator could not find cul-de-sacs at %s." % culdesacs_path)


func _inside_road_clearance(point: Vector3) -> bool:
	var point_2d := Vector2(point.x, point.z)
	for clearance: Rect2 in _road_clearance_rects:
		if clearance.has_point(point_2d):
			return true
	for center: Vector2 in _culdesac_clearance_centers:
		if point_2d.distance_to(center) < CULDESAC_TREE_CLEARANCE_RADIUS:
			return true
	return false


func _far_enough(point: Vector3, occupied_positions: Array[Vector3], minimum_distance: float) -> bool:
	var minimum_distance_squared := minimum_distance * minimum_distance
	for occupied: Vector3 in occupied_positions:
		var flat_offset := Vector2(point.x - occupied.x, point.z - occupied.z)
		if flat_offset.length_squared() < minimum_distance_squared:
			return false
	return true
