extends SceneTree
func _initialize() -> void:
	for path in ["res://models/props/flashlightItem.tscn", "res://assets/local_licensed/exploration_objects/Flashlight/Flashlight.fbx"]:
		var model = load(path).instantiate()
		root.add_child(model)
		print(path)
		for mesh in model.find_children("*", "MeshInstance3D", true, false):
			print(mesh.name, " ", mesh.global_transform, " bounds ", mesh.get_aabb())
		model.queue_free()
	quit()
