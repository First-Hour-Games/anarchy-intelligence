extends SceneTree

func _initialize() -> void:
	for path: String in ["res://models/enemies/the_clawman/TheClawman.glb", "res://assets/local_licensed/clinic_medical/Med_12.glb", "res://assets/local_licensed/clinic_hospital/bed_1.glb", "res://assets/local_licensed/clinic_hospital/tray_1.glb", "res://assets/local_licensed/clinic_hospital/machine_1.glb", "res://assets/local_licensed/clinic_hospital/cupboard_bottom.glb", "res://assets/local_licensed/clinic_hospital/cupboard_top.glb"]:
		var model := (load(path) as PackedScene).instantiate() as Node3D
		print("ASSET ", path)
		for node: Node in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			print("MESH ", node.name, " ", mesh.transform * mesh.get_aabb())
		for node: Node in model.find_children("*", "AnimationPlayer", true, false):
			print("CLIPS ", (node as AnimationPlayer).get_animation_list())
		for node: Node in model.find_children("*", "Skeleton3D", true, false):
			var skeleton := node as Skeleton3D
			for i in skeleton.get_bone_count():
				print("BONE ", skeleton.get_bone_name(i))
		model.free()
	quit()
