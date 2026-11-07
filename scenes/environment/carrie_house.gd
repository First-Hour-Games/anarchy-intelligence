extends Node3D

## Carrie's house, the model exported by tools/blender/prepare_carrie_house.py, made playable.
## Floors and structure get trimesh collision (floors carry their footstep surface), furniture
## gets box collision from carrie_house_markers.json, and the beds and closets become hiding
## spots. The house opens the ground over its cellar, lights the porch and the two rooms that
## still have power, gives enemies route gates through the front door and up the main stair, and
## names the places the story uses (the door note, the notebook...) through point(). The cellar
## and attic are shut for the opening chapter, so routes only join the ground floor and upstairs.

const MARKERS_PATH := "res://models/buildings/carrie_house/carrie_house_markers.json"
const HOUSE_LIGHT := preload("res://scenes/environment/hospital_light.gd")
const LIGHT_MODES := {"steady": 0, "flicker": 1, "strobe": 2, "dying": 3, "noise": 4, "pulse": 5}
const FLOOR_SURFACES := {"Floor_Wood": "wood", "Floor_Tile": "tile", "Floor_Concrete": "concrete"}
const HIDING_KINDS := {"bed": HidingSpot.Kind.UNDER_BED, "closet": HidingSpot.Kind.CLOSET, "locker": HidingSpot.Kind.LOCKER}
## The way between the ground floor and upstairs, from the bottom up: enemies walk it point to point.
const MAIN_STAIR: Array = ["stairs_bottom", "stairs_top"]
const ENTRY_PATH: Array = ["yard_front", "porch", "front_door", "hall"]

## The map's ground. Its collision is opened over the cellar, and its shader (cutout_rect in
## snow_ground.gdshader) leaves the footprint undrawn, so the cellar stair looks down into the cellar.
@export var ground_collision_path: NodePath
@export var ground_mesh_path: NodePath

var markers: Dictionary = {}


func _ready() -> void:
	markers = load_markers()
	if markers.is_empty():
		return
	add_to_group("enemy_route_building")
	_build_collision()
	_build_furniture_collision()
	_build_hiding_spots()
	_build_lights()
	_build_navigation_links()
	_open_ground()


static func load_markers() -> Dictionary:
	var file := FileAccess.open(MARKERS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Carrie's house markers are missing: %s" % MARKERS_PATH)
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


## One of the house's named places (see "points" in the markers file), in house-local space.
func local_point(id: StringName) -> Vector3:
	var values: Array = markers.get("points", {}).get(str(id), [])
	if values.size() != 3:
		push_warning("Carrie's house has no point named %s." % id)
		return Vector3.ZERO
	return _vector(values)


## The same place in world space.
func point(id: StringName) -> Vector3:
	return to_global(local_point(id))


func contains_route_point(world_point: Vector3) -> bool:
	if markers.is_empty():
		return false
	var local := to_local(world_point)
	var footprint: Dictionary = markers.footprint
	return (local.x > float(footprint.min[0]) and local.x < float(footprint.max[0])
		and local.z > float(footprint.min[1]) and local.z < float(footprint.max[1])
		and local.y > -2.5 and local.y < 9.0)


## Gates for the shared entity route (scenes/shared/entity_route.gd): in through the front door,
## up or down the main stair, and out the same way. The first gate of each leg is reached over
## the navigation mesh, the rest walked straight.
func route_transitions(from: Vector3, destination: Vector3) -> Array[Dictionary]:
	var gates: Array[Dictionary] = []
	var inside_start := contains_route_point(from)
	var inside_goal := contains_route_point(destination)
	if not inside_start and not inside_goal:
		return gates
	var upstairs := inside_start and is_upstairs(from)
	if not inside_start:
		_add_gates(gates, ENTRY_PATH)
	if upstairs != (inside_goal and is_upstairs(destination)):
		var stair := MAIN_STAIR.duplicate()
		if upstairs:
			stair.reverse()
		_add_gates(gates, stair)
	if not inside_goal:
		var exit := ENTRY_PATH.duplicate()
		exit.reverse()
		_add_gates(gates, exit)
	return gates


func _add_gates(gates: Array[Dictionary], names: Array) -> void:
	for index in names.size():
		gates.append({"point": point(StringName(names[index])), "direct": index > 0})


## Whether a world position is on the upstairs floor rather than the ground floor.
func is_upstairs(world_point: Vector3) -> bool:
	return to_local(world_point).y > float(markers.floors.UPPER) - 0.6


func _build_collision() -> void:
	var source := get_node("Source") as Node3D
	for node: Node in source.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var label := str(mesh.name)
		if not (label.begins_with("Floor_") or label.begins_with("Structure_")):
			continue
		mesh.create_trimesh_collision()
		var body := mesh.get_node_or_null(label + "_col")
		if body != null:
			body.set_meta("surface", FLOOR_SURFACES.get(label, "wood"))


func _build_furniture_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "FurnitureCollision"
	body.set_meta("surface", "wood")
	add_child(body)
	for piece: Dictionary in markers.furniture:
		# The beds and the wardrobe belong to their hiding spots instead (_build_hiding_spots).
		if piece.blocks and piece.role != "hide":
			body.add_child(_furniture_box(piece))


func _furniture_box(piece: Dictionary) -> CollisionShape3D:
	var low := _vector(piece.min)
	var high := _vector(piece.max)
	var shape := CollisionShape3D.new()
	shape.name = str(piece.name)
	var box := BoxShape3D.new()
	box.size = (high - low).abs()
	shape.shape = box
	shape.position = (low + high) * 0.5
	return shape


func _build_hiding_spots() -> void:
	var pieces := {}
	for piece: Dictionary in markers.furniture:
		pieces[str(piece.name)] = piece
	for data: Dictionary in markers.hiding:
		var spot := HidingSpot.new()
		spot.name = str(data.name) + "Hide"
		spot.kind = HIDING_KINDS.get(str(data.kind), HidingSpot.Kind.CLOSET)
		spot.builtin_model = false
		spot.position = _vector(data.position)
		spot.rotation.y = deg_to_rad(float(data.yaw))
		add_child(spot, true)
		# The bed or wardrobe is the spot's own Collision body, as on the stock models, so a hidden
		# player still watches enemies past it (HidingSpot.collision_rids()). Closets built into the
		# walls have none: their closed doors hide the player from view both ways.
		var piece: Dictionary = pieces.get(str(data.name), {})
		if piece.get("blocks", false):
			var body := StaticBody3D.new()
			body.name = "Collision"
			body.set_meta("surface", "wood")
			# Cancels the spot's placement, so the box keeps its house-local position.
			body.transform = spot.transform.affine_inverse()
			body.add_child(_furniture_box(piece))
			spot.add_child(body)


func _build_lights() -> void:
	for data: Dictionary in markers.lights:
		var mode := str(data.mode)
		if mode == "off":
			continue
		var light := OmniLight3D.new()
		light.set_script(HOUSE_LIGHT)
		light.set("mode", LIGHT_MODES[mode])
		light.name = "Light" + str(data.room).capitalize().replace(" ", "").replace("'", "")
		light.light_color = Color(data.color[0], data.color[1], data.color[2])
		light.light_energy = float(data.energy)
		light.omni_range = float(data.range)
		light.shadow_enabled = true
		add_child(light)
		light.position = _vector(data.position)


## Enemies can't path through a doorway on their own: it is narrower than the navigation mesh can
## pass. Closed doors get no link.
func _build_navigation_links() -> void:
	for doorway: Dictionary in markers.get("doorways", []):
		if not doorway.open:
			continue
		var centre := _vector(doorway.centre)
		var normal := _vector(doorway.normal)
		var link := NavigationLink3D.new()
		link.name = "Doorway%sRoute" % str(doorway.wall)
		link.start_position = centre + normal * 0.7
		link.end_position = centre - normal * 0.7
		add_child(link, true)


## Opens the map's ground over the house so the cellar below it is reachable and visible.
func _open_ground() -> void:
	var footprint: Dictionary = markers.footprint
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for x: float in [float(footprint.min[0]), float(footprint.max[0])]:
		for z: float in [float(footprint.min[1]), float(footprint.max[1])]:
			var corner := to_global(Vector3(x, 0.0, z))
			low = Vector2(minf(low.x, corner.x), minf(low.y, corner.z))
			high = Vector2(maxf(high.x, corner.x), maxf(high.y, corner.z))
	var ground := get_node_or_null(ground_collision_path) as CollisionObject3D
	if ground != null:
		_cut_ground(ground, Rect2(low, high - low))
	var mesh := get_node_or_null(ground_mesh_path) as MeshInstance3D
	if mesh != null:
		var material := mesh.get_active_material(0) as ShaderMaterial
		if material != null:
			material.set_shader_parameter("cutout_rect", Vector4(low.x + 0.02, low.y + 0.02, high.x - 0.02, high.y - 0.02))


## Replaces each world-aligned box of the ground's collision that overlaps the hole with up to
## four boxes around it.
func _cut_ground(ground: CollisionObject3D, hole: Rect2) -> void:
	for child: Node in ground.get_children():
		var shape := child as CollisionShape3D
		if shape == null or not shape.shape is BoxShape3D or shape.disabled:
			continue
		var size := (shape.shape as BoxShape3D).size
		var centre := shape.global_position
		var area := Rect2(Vector2(centre.x - size.x * 0.5, centre.z - size.z * 0.5), Vector2(size.x, size.z))
		if not area.intersects(hole):
			continue
		var cut := area.intersection(hole)
		var pieces: Array[Rect2] = [
			Rect2(area.position, Vector2(cut.position.x - area.position.x, area.size.y)),
			Rect2(Vector2(cut.end.x, area.position.y), Vector2(area.end.x - cut.end.x, area.size.y)),
			Rect2(Vector2(cut.position.x, area.position.y), Vector2(cut.size.x, cut.position.y - area.position.y)),
			Rect2(Vector2(cut.position.x, cut.end.y), Vector2(cut.size.x, area.end.y - cut.end.y)),
		]
		for index in pieces.size():
			var piece := pieces[index]
			if piece.size.x < 0.001 or piece.size.y < 0.001:
				continue
			var box := BoxShape3D.new()
			box.size = Vector3(piece.size.x, size.y, piece.size.y)
			var replacement := CollisionShape3D.new()
			replacement.name = "%sAround%s%d" % [shape.name, name, index]
			replacement.shape = box
			ground.add_child(replacement)
			replacement.global_position = Vector3(piece.get_center().x, centre.y, piece.get_center().y)
		ground.remove_child(shape)
		shape.queue_free()


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
