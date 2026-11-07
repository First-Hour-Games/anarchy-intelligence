extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var house := map.get_node("Buildings/ResidentialLots/CarrieHouse") as Node3D
	var nav := house.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav)
	for id: StringName in [&"yard_front", &"porch", &"front_door", &"hall", &"stairs_bottom", &"stairs_top", &"back_stair_bottom"]:
		var point: Vector3 = house.call("point", id)
		print("HOUSE ", id, " point ", point, " closest ", NavigationServer3D.map_get_closest_point(nav, point))
	var route := NavigationServer3D.map_get_path(nav, house.call("point", &"yard_front"), house.call("point", &"hall"), true)
	print("HOUSE ROUTE ", route)
	for node: Node in map.find_children("*", "Node3D", true, false):
		if str(node.name).begins_with("ACUnit") or str(node.name) == "CondenserPad":
			print("PROP ", node.get_path(), " position ", node.global_position)
	for mesh: Node in map.get_node("Buildings/NeighborhoodHospital/Source").find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if bounds.size.y < 3:
			print("HOSP ", mesh.name, " bounds ", bounds)
	quit()
