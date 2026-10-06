extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var packed := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	await process_frame

	var foliage := scene.get_node("Foliage")
	var filter_node := foliage.get_node("treeMulti2")
	var results = filter_node.prune_all_foliage()
	print("Prune results: ", results)

	scene.queue_free()
	quit()
