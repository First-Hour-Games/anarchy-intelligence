extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Log Model Smoke Test ---")
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	if not scene:
		print("FAIL: starting_forest.tscn could not be loaded")
		quit(1)
		return
	var inst := scene.instantiate()
	var tree_node := inst.get_node_or_null("Sketchfab_Scene")
	if tree_node:
		print("PASS: Sketchfab_Scene instantiated successfully!")
		print("Node name: ", tree_node.name)
		print("Children count: ", tree_node.get_child_count())
		print("Transform: ", tree_node.transform)
		print("ALL LOG MODEL CHECKS PASSED!")
		inst.queue_free()
		quit(0)
	else:
		print("FAIL: Sketchfab_Scene not found in starting_forest")
		inst.queue_free()
		quit(1)
