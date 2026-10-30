extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	player.freeze()
	player.get_node("CombatHealth").set_process(false)
	var house := map.get_node("Buildings/ResidentialLots/CarrieHouse") as Node3D
	var wrapper := map.get_node("Wrapper") as CharacterBody3D
	check(map.find_children("ACUnit*", "Node3D", true, false).is_empty(), "AC units removed")
	check(map.get_node("Buildings/CivicFinishing").find_children("*CondenserPad*", "MeshInstance3D", true, false).is_empty(), "Unneeded AC pads removed")
	# Carrie's house faces the street (its +Z), so looking along world LEFT faces away from the door.
	var yard: Vector3 = house.call("point", &"yard_front") + Vector3.UP * 0.1
	var hall: Vector3 = house.call("point", &"hall") + Vector3.UP * 0.1
	var kitchen: Vector3 = house.call("point", &"kitchen") + Vector3.UP * 0.1
	var bedroom: Vector3 = house.call("point", &"carrie_room") + Vector3.UP * 0.1
	wrapper.enabled = true
	wrapper.attack_cooldown = 100
	player.global_position = kitchen
	player.camera.look_at(player.camera.global_position + Vector3.LEFT)
	wrapper.global_position = yard
	wrapper.navigation_route.reset()
	for i in 850:
		await physics_frame
	var local := house.to_local(wrapper.global_position)
	print("Deep house position ", local)
	check(local.z < -1.0, "Wrapper reaches player deep inside through front door")
	# Move the player upstairs after committing to the building route. The Wrapper starts in the
	# hall, so it has to find its own way onto the main stair.
	player.global_position = bedroom
	player.camera.look_at(player.camera.global_position + Vector3.RIGHT)
	wrapper.global_position = hall
	wrapper.velocity = Vector3.ZERO
	wrapper.navigation_route.reset()
	for i in 1500:
		await physics_frame
	local = house.to_local(wrapper.global_position)
	print("Upper floor position ", local)
	check(local.y > 3.2, "Wrapper gets from the hall up the actual house staircase")
	check(wrapper.global_position.distance_to(bedroom) < 2.0, "Wrapper continues to player on upper floor")
	# While crossing the door, a moving player must not reset the approach.
	wrapper.global_position = yard
	wrapper.velocity = Vector3.ZERO
	wrapper.navigation_route.reset()
	player.global_position = hall
	player.camera.look_at(player.camera.global_position + Vector3.LEFT)
	for i in 280:
		await physics_frame
	player.global_position = kitchen
	for i in 620:
		await physics_frame
	local = house.to_local(wrapper.global_position)
	check(local.z < -1.0, "Wrapper retains doorway crossing when player moves deeper")
	print("Entity building route failures: ", failures)
	map.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
