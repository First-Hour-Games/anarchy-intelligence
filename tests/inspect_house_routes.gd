extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1).timeout
	var house := map.get_node("Buildings/ResidentialLots/WestStubBrickHouse") as Node3D
	for node: Node in house.get_node("Source").get_children():
		print("ROOT ", node.name, " ", node.get_class())
		if node is MeshInstance3D:
			print("ROOT BOUNDS ", node.name, " ", house.global_transform.affine_inverse() * node.global_transform * node.get_aabb())
	for node: Node in house.get_node("Source/Casa").find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := house.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		print("MESH ", mesh.name, " ", bounds)
	var nav := house.get_world_3d().navigation_map
	var structure := house.get_node("GeneratedStructuralCollision/StructureCollision_000") as CollisionShape3D
	var faces := (structure.shape as ConcavePolygonShape3D).get_faces()
	var levels: Dictionary = {}
	for i in range(0, faces.size(), 3):
		var a := faces[i]
		var b := faces[i + 1]
		var c := faces[i + 2]
		if absf((b - a).cross(c - a).normalized().y) < 0.95 or a.y < 0.05 or a.y > 3.5:
			continue
		var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c)
		var level := snappedf(a.y, 0.01)
		levels[level] = (levels[level] as AABB).merge(bounds) if levels.has(level) else bounds
	print("TREADS ", levels)
	NavigationServer3D.map_force_update(nav)
	for x: float in [5.65, 6, 8, 11.75, 14]:
		for z: float in [1.25, 3, 5, 7]:
			var point := house.to_global(Vector3(x, 3.58, z))
			var floor_ray := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.5, point - Vector3.UP)
			var hit := house.get_world_3d().direct_space_state.intersect_ray(floor_ray)
			print("UPPER ", Vector2(x,z), " nav ", house.to_local(NavigationServer3D.map_get_closest_point(nav, point)), " floor ", house.to_local(hit.position) if not hit.is_empty() else Vector3.INF)
	for x: float in [2, 5, 8, 11.75]:
		for z: float in [2, 5, 8]:
			var point := house.to_global(Vector3(x, 0.1, z))
			var route := NavigationServer3D.map_get_path(nav, house.to_global(Vector3(11.75, 0.1, 16)), point, true)
			print("PATH ", Vector2(x, z), " ", route)
	quit()
