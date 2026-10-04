extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node("Player") as FirstPersonPlayer
	player.unfreeze()
	var space_state: PhysicsDirectSpaceState3D = forest.get_world_3d().direct_space_state

	var query := PhysicsRayQueryParameters3D.create(
		Vector3(-245.7455, 5.0, 10.45689),
		Vector3(-245.7455, -5.0, 10.45689)
	)
	var result: Dictionary = space_state.intersect_ray(query)
	var ground_y: float = result["position"].y
	print("Ground Y: ", ground_y)

	# Test 1: with original ClimbOverTeleport Y (1.03889)
	player.global_position = Vector3(-245.7455, 1.03889, 10.45689)
	player.velocity = Vector3.ZERO
	await physics_frame
	print("With Y=1.03889: is_on_floor = ", player.is_on_floor())
	for i in range(15):
		await physics_frame
	print("After 15 frames falling from 1.03889: Y = ", player.global_position.y, " is_on_floor = ", player.is_on_floor())

	# Test 2: with ground_y + 0.01
	player.global_position = Vector3(-245.7455, ground_y + 0.01, 10.45689)
	player.velocity = Vector3.ZERO
	await physics_frame
	print("With Y=ground_y + 0.01: is_on_floor = ", player.is_on_floor(), " Y = ", player.global_position.y)
	for i in range(15):
		await physics_frame
	print("After 15 frames on ground: Y = ", player.global_position.y, " is_on_floor = ", player.is_on_floor())

	quit()
