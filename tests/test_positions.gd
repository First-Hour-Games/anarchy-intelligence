extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node("Player") as Node3D
	var barrier := forest.get_node("Interactables/BarrierTree") as Node3D
	var teleport := forest.get_node("ClimbOverTeleport") as Node3D

	print("Player initial pos: ", player.global_position, " yaw: ", player.global_rotation.y)
	print("Barrier pos: ", barrier.global_position)
	print("Teleport pos: ", teleport.global_position)

	quit()
