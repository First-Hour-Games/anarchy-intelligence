extends SceneTree

func _initialize() -> void:
	print("--- Testing starting_forest.tscn loading and props ---")
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	if not scene:
		printerr("FAILED to load starting_forest.tscn")
		quit(1)
		return

	var root_node := scene.instantiate()
	var log_node := root_node.get_node_or_null("Sketchfab_Scene") as Node3D
	var b1 := root_node.get_node_or_null("barricade") as Node3D
	var b2 := root_node.get_node_or_null("barricade2") as Node3D
	var b3 := root_node.get_node_or_null("barricade3") as Node3D

	print("Sketchfab_Scene found: ", log_node != null)
	if log_node:
		print("  Position: ", log_node.position)
		print("  Scale: ", log_node.scale)
		print("  Rotation: ", log_node.rotation_degrees)

	print("barricade found: ", b1 != null)
	if b1:
		print("  barricade pos: ", b1.position, " scale: ", b1.scale, " rot: ", b1.rotation_degrees)

	print("barricade2 found: ", b2 != null)
	if b2:
		print("  barricade2 pos: ", b2.position, " scale: ", b2.scale, " rot: ", b2.rotation_degrees)

	print("barricade3 found: ", b3 != null)
	if b3:
		print("  barricade3 pos: ", b3.position, " scale: ", b3.scale, " rot: ", b3.rotation_degrees)

	var success := (log_node != null and b1 != null and b2 != null and b3 != null)
	if success:
		print("SUCCESS: All props placed and verified!")
	else:
		printerr("FAILURE: Missing props!")

	root_node.free()
	quit(0 if success else 1)
