extends SceneTree

## The downtown beside the hospital (tools/blender/downtown/plan.py, built into
## models/buildings/downtown/downtown.gltf): it replaces the civic block and the four houses across
## from it, every building is solid, glazed, lettered and hides what stands behind it, the
## sidewalks, alleys, service lane and the hospital's path stay walkable and on the navigation
## mesh, and the street stays within its drawing budget.

const MARKERS := "res://models/buildings/downtown/downtown_markers.json"
const MAX_SURFACES := 70
const MAX_TRIANGLES := 25000

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1


func run() -> void:
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate() as Node3D
	map.get_node("OpeningStory").set("persist_progress", false)
	root.add_child(map)
	current_scene = map
	for i in 4:
		await physics_frame
	var markers: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MARKERS))
	var downtown := map.get_node("Buildings/Downtown/Source")
	check(not map.has_node("Buildings/CivicBlock") and not map.has_node("Buildings/ResidentialLots/CrossroadNorthEast_01"),
			"The downtown replaces the civic block and the houses across from it")
	check(map.has_node("Buildings/ResidentialLots/ConnectorEast_04"), "The house on the corner stays")

	# Each building stands solid, from the sidewalk in front of it.
	var space := map.get_world_3d().direct_space_state
	for building: Dictionary in markers.buildings:
		var foot: Array = building.footprint
		var middle := Vector3((float(foot[0]) + float(foot[1])) / 2.0, 1.5, (float(foot[2]) + float(foot[3])) / 2.0)
		var street_z := float(foot[3]) + 3.0 if String(building.row) == "north" else float(foot[2]) - 3.0
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(middle.x, 1.5, street_z), middle))
		var whole := true
		for object_name: String in building.objects:
			whole = whole and downtown.has_node(object_name)
		check(whole and not hit.is_empty(), "%s stands solid on the street" % building.id)
	check(downtown.find_children("*", "OccluderInstance3D", true, false).size() == markers.buildings.size(),
			"Every building has an occluder")

	# Glass, details and lettering as the import set them up.
	var glazed := true
	for mesh_name: String in markers.objects.glass:
		var glass := downtown.get_node(mesh_name) as MeshInstance3D
		glazed = glazed and glass.material_override is ShaderMaterial and glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(glazed, "Every window shows a room behind its glass")
	var far := true
	for mesh_name: String in markers.objects.details:
		far = far and (downtown.get_node(mesh_name) as GeometryInstance3D).visibility_range_end > 0.0
	check(far, "Small details stop drawing far away")
	var lettering := downtown.find_children("*", "Label3D", true, false)
	check(lettering.size() >= markers.signs.size(), "Every sign is lettered")
	var dead := downtown.find_children("DeadLetter", "Label3D", true, false)
	check(dead.size() == 1 and (dead[0] as Label3D).text == "W", "One letter of the hotel's roof sign is dead")

	# Drawing budget: surfaces (draw calls before shadows), triangles, no shadow-casting lights.
	var surfaces := 0
	var triangles := 0
	for mesh: MeshInstance3D in downtown.find_children("*", "MeshInstance3D", true, false):
		surfaces += mesh.mesh.get_surface_count()
		for s in mesh.mesh.get_surface_count():
			var indices: int = mesh.mesh.surface_get_array_index_len(s)
			triangles += (indices if indices > 0 else mesh.mesh.surface_get_array_len(s)) / 3
	print("Downtown: %d surfaces, %d triangles" % [surfaces, triangles])
	check(surfaces <= MAX_SURFACES and triangles <= MAX_TRIANGLES, "The street stays within its drawing budget")
	var shadowed := 0
	for light: Light3D in map.get_node("Buildings/Downtown").find_children("*", "Light3D", true, false):
		shadowed += int(light.shadow_enabled)
	for light: Light3D in map.get_node("Buildings/CivicFinishing").find_children("*", "Light3D", true, false):
		shadowed += int(light.shadow_enabled and light.name != "ClinicEntranceLight")
	check(shadowed == 0, "No downtown light casts shadows")

	# Street furniture from the markers: lamps with lights, trees, cars.
	var finishing := map.get_node("Buildings/CivicFinishing")
	var lamp_lights := finishing.find_children("StreetLampLight*", "OmniLight3D", false, false).size()
	var expected_lamps: int = markers.furniture.filter(func(item: Dictionary) -> bool: return item.kind == "lamp").size()
	check(lamp_lights == expected_lamps, "Every street lamp is lit (%d)" % expected_lamps)
	var cars := finishing.get_children().filter(func(node: Node) -> bool:
		return String(node.name).begins_with("DeadCar") and not node is CollisionObject3D)
	check(cars.size() == markers.cars.size(), "Dead cars in the lots and at the curbs")
	var sidewalk := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(150, 2, 218.6), Vector3(150, -1, 218.6)))
	check(not sidewalk.is_empty() and absf(sidewalk.position.y - 0.1) < 0.02, "Sidewalks are walked at the road's height")

	# Walkable: both sidewalks, across the corner, the hospital's path, the alleys and the lane.
	var points: Dictionary = markers.points
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	for pair: Array in [["north_walk_west", "north_walk_east"], ["south_walk_west", "south_walk_east"],
			["corner_north", "corner_south"], ["hospital_path", "hospital_door"],
			["alley_139_street", "alley_139_lane"], ["alley_169_street", "alley_169_lane"],
			["alley_201_street", "alley_201_lane"], ["service_lane_west", "service_lane_east"]]:
		var from := _vector(points[pair[0]]) + Vector3(0, 1.05, 0)
		var to := _vector(points[pair[1]]) + Vector3(0, 1.05, 0)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = capsule
		query.transform = Transform3D(Basis.IDENTITY, from)
		query.motion = to - from
		check(space.cast_motion(query)[0] > 0.99, "Clear walk from %s to %s" % pair)

	# On the navigation mesh, for anything hunting the player through town.
	var nav_map := map.get_world_3d().navigation_map
	for i in 600:
		await physics_frame
		NavigationServer3D.map_force_update(nav_map)
		var probe := NavigationServer3D.map_get_path(nav_map, _vector(points.corner_north), _vector(points.hospital_door), true)
		if probe.size() > 1:
			break
	for pair: Array in [["corner_north", "hospital_door"], ["south_walk_west", "alley_169_lane"], ["north_walk_east", "service_lane_west"]]:
		var from := _vector(points[pair[0]])
		var to := _vector(points[pair[1]])
		var route := NavigationServer3D.map_get_path(nav_map, from, to, true)
		var length := 0.0
		for i in range(1, route.size()):
			length += route[i - 1].distance_to(route[i])
		var arrives := route.size() > 1 and route[route.size() - 1].distance_to(to) < 1.5
		check(arrives and length < from.distance_to(to) * 1.8, "Navigation from %s to %s (%.0f m)" % [pair[0], pair[1], length])

	# The signal flashes.
	var amber := downtown.get_node("SignalAmber") as Node3D
	var before := amber.visible
	await create_timer(0.6).timeout
	check(amber.visible != before, "The traffic signal flashes")
	map.queue_free()
	await process_frame
	quit(1 if failures else 0)


static func _vector(values: Array) -> Vector3:
	return Vector3(float(values[0]), float(values[1]), float(values[2]))
