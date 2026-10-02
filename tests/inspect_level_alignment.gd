extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var house := map.get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	var nav := house.get_world_3d().navigation_map
	NavigationServer3D.map_force_update(nav)
	for z: float in [7.5, 8.6, 10.6, 12.5, 16.0]:
		var point := house.to_global(Vector3(11.75, 0.25, z))
		print("HOUSE ", z, " point ", point, " closest ", NavigationServer3D.map_get_closest_point(nav, point))
	var route := NavigationServer3D.map_get_path(nav, house.to_global(Vector3(11.75, 0.25, 16)), house.to_global(Vector3(11.75, 0.25, 7.5)), true)
	print("HOUSE ROUTE ", route)
	for node: Node in map.find_children("*", "Node3D", true, false):
		if str(node.name).begins_with("ACUnit") or str(node.name) == "CondenserPad":
			print("PROP ", node.get_path(), " position ", node.global_position)
	for mesh: Node in map.get_node("Buildings/NeighborhoodHospital/Source").find_children("*", "MeshInstance3D", true, false):
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		if bounds.size.y < 3:
			print("HOSP ", mesh.name, " bounds ", bounds)
	quit()
