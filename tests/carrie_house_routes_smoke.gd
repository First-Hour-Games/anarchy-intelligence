extends SceneTree

# Walks the real player through Carrie's house the way the story goes: in at the front door and
# up the main stair to Carrie's desk, down the back stair and out the back door, and between the
# hall, living room and kitchen. A monster's capsule must also fit every open doorway and every
# point enemies route through. The layout keeps this true (tools/blender/carrie_house/validate.py);
# this checks the exported house in the engine.

const TEST_SCENE := "res://scenes/chapters/playground/carrie_house_test.tscn"

var failures: int = 0
var house: Node3D
var player: CharacterBody3D


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


## Walks the player through house-local waypoints, steering at each in turn. True when it gets
## to the last one; a player stuck against something for a second gives up.
func walk(waypoints: Array) -> bool:
	player.velocity = Vector3.ZERO
	player.global_position = house.to_global(waypoints[0])
	await physics_frame
	var index := 1
	var last := player.global_position
	var still := 0
	key(KEY_W, true)
	for frame in 2400:
		var target := house.to_global(waypoints[index])
		var flat := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
		if flat.length() < 0.3 and absf(target.y - player.global_position.y) < 0.5:
			index += 1
			if index >= waypoints.size():
				break
			continue
		player.rotation.y = atan2(-flat.x, -flat.z)
		await physics_frame
		still = still + 1 if player.global_position.distance_to(last) < 0.002 else 0
		last = player.global_position
		if still > 60:
			break
	key(KEY_W, false)
	if index < waypoints.size():
		print("  stopped before ", waypoints[index], " at ", house.to_local(player.global_position))
	return index >= waypoints.size()


func monster_fits(local: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, house.to_global(local) + Vector3.UP * 1.0)
	query.exclude = [player.get_rid()]
	return house.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func run() -> void:
	var scene := (load(TEST_SCENE) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	for frame in 6:
		await physics_frame
	house = scene.get_node("CarrieHouse") as Node3D
	player = scene.get_node("Player") as CharacterBody3D
	player.call("unfreeze")
	var g := float(house.markers.floors.GROUND)
	var up := float(house.markers.floors.UPPER)
	var p := func(id: StringName) -> Vector3: return house.local_point(id)
	var desk_front: Vector3 = p.call(&"notebook") * Vector3(1, 0, 1) + Vector3(0, up, -1.1)

	check(await walk([p.call(&"porch"), p.call(&"front_door"), p.call(&"hall"), p.call(&"stairs_bottom"), p.call(&"stairs_top"),
			Vector3(-1.9, up, -5.1), Vector3(-1.9, up, -3.6), Vector3(-3.1, up, -3.6), p.call(&"carrie_room"),
			Vector3(-3.1, up, -1.6), desk_front]),
			"In at the front door, up the main stair and along the landing to Carrie's desk")
	check(await walk([p.call(&"stairs_top"), p.call(&"back_stair_bottom"), p.call(&"kitchen"), Vector3(2.25, g, -9.4),
			p.call(&"back_door"), p.call(&"back_yard")]),
			"Down the back stair, through the kitchen and out the back door")
	check(await walk([p.call(&"hall"), Vector3(0.6, g, -2.4), Vector3(-1.2, g, -1.5)]), "From the hall into the living room")
	check(await walk([p.call(&"hall"), Vector3(1.9, g, -4.4), Vector3(1.9, g, -5.6), Vector3(2.2, g, -7.4), p.call(&"kitchen")]),
			"From the hall past the kitchen table to the back stair's door")
	check(await walk([p.call(&"back_yard"), p.call(&"back_door"), Vector3(2.25, g, -9.4), p.call(&"back_stair_bottom"), p.call(&"stairs_top")]),
			"In at the back door and up the back stair")

	var stuck: Array[String] = []
	for doorway: Dictionary in house.markers.doorways:
		var centre := Vector3(float(doorway.centre[0]), float(doorway.centre[1]), float(doorway.centre[2]))
		if doorway.open and not monster_fits(centre):
			stuck.append(str(doorway.wall))
	for id: StringName in [&"hall", &"stairs_bottom", &"stairs_top", &"back_stair_bottom", &"kitchen", &"carrie_room", &"wrapper_post"]:
		if not monster_fits(p.call(id)):
			stuck.append(str(id))
	if not stuck.is_empty():
		print("  no room for a monster at: ", ", ".join(stuck))
	check(stuck.is_empty(), "A monster fits every open doorway and every point enemies route through")

	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
