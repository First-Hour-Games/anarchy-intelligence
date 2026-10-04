extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await physics_frame
	await physics_frame

	var teleport := forest.get_node("ClimbOverTeleport") as Node3D
	print("ClimbOverTeleport global_position: ", teleport.global_position)

	var space_state: PhysicsDirectSpaceState3D = forest.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(teleport.global_position.x, 10.0, teleport.global_position.z),
		Vector3(teleport.global_position.x, -10.0, teleport.global_position.z)
	)
	var result: Dictionary = space_state.intersect_ray(query)
	if not result.is_empty():
		print("Raycast hit ground at: ", result["position"], " collider: ", result["collider"])
	else:
		print("Raycast did NOT hit anything!")

	quit()
