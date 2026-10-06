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
	var aabbs = filter_node.get_exclusion_aabbs()
	print("Exclusion AABBs count: ", aabbs.size())
	for b in aabbs:
		print("  AABB: pos=", b.position, " end=", b.end, " size=", b.size)

	scene.queue_free()
	quit()
