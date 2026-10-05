extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("--- Running Gas Station Platform Verification ---")
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	assert(scene != null, "starting_forest.tscn should load")
	
	var forest := scene.instantiate() as StartingForest
	root.add_child(forest)
	await process_frame
	
	var platform := forest.get_node_or_null("GasStationPlatform") as MeshInstance3D
	assert(platform != null, "GasStationPlatform node exists in starting_forest")
	print("Platform global position: ", platform.global_position)
	assert(is_equal_approx(platform.global_position.x, 146.0), "Platform X is 146.0")
	assert(is_equal_approx(platform.global_position.z, 28.0), "Platform Z is 28.0")
	assert(platform.mesh is PlaneMesh, "Platform mesh is PlaneMesh")
	
	var plane_mesh := platform.mesh as PlaneMesh
	print("Platform size: ", plane_mesh.size)
	assert(plane_mesh.size == Vector2(40.0, 28.0), "Platform size is 40 x 28 meters")
	
	var col := platform.get_node_or_null("StaticBody3D/CollisionShape3D") as CollisionShape3D
	assert(col != null, "CollisionShape3D exists under GasStationPlatform")
	assert(col.shape is BoxShape3D, "Collision shape is BoxShape3D")
	
	var marker := platform.get_node_or_null("GasStationMarker") as Label3D
	assert(marker != null, "GasStationMarker Label3D exists")
	print("Marker text: ", marker.text)
	
	forest.queue_free()
	print("PASS: Gas Station Platform verified successfully!")
	quit(0)
