extends SceneTree

const LOTS := "res://models/buildings/neighborhood_lots"
var failures := 0
var total_boxes := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func ray(from: Vector3, to: Vector3, mask: int) -> Dictionary:
	return root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, mask))

func audit(lot: Node3D) -> int:
	var count := 0
	for collision in lot.find_children("*", "CollisionShape3D", true, false):
		check(collision.shape is BoxShape3D, "All neighborhood shapes must be boxes")
		check(collision.shape.size.x > 0 and collision.shape.size.y > 0 and collision.shape.size.z > 0, "Boxes must have positive dimensions")
		count += 1
	check(count > 8 and count <= 50, "Each lot must use a small set of boxes; got %d" % count)
	return count

func run() -> void:
	var lots_checked := 0
	var first_lot: Node3D
	for file in DirAccess.get_files_at(LOTS):
		if not file.ends_with(".glb"):
			continue
		var lot: Node3D = load(LOTS + "/" + file).instantiate()
		var boxes := audit(lot)
		total_boxes += boxes
		root.add_child(lot)
		var lawn: MeshInstance3D
		var house: MeshInstance3D
		var fence: MeshInstance3D
		for mesh: MeshInstance3D in lot.find_children("*", "MeshInstance3D", true, false):
			if mesh.name.ends_with("_Lawn"):
				lawn = mesh
			elif mesh.name.ends_with("_House"):
				house = mesh
			elif mesh.name.ends_with("_Fence"):
				fence = mesh
		for body: StaticBody3D in lot.find_children("*", "StaticBody3D", true, false):
			body.collision_layer = 2 if body.get_parent() == lawn else (4 if body.get_parent() == fence else 8)
		await physics_frame
		await physics_frame
		check(lawn != null and lawn.has_node("LotCollision"), "Lawn needs ground support")
		var arrays := lawn.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bounds := lawn.mesh.get_aabb()
		var samples := 0
		for index in range(0, vertices.size(), maxi(1, vertices.size() / 80)):
			var vertex := vertices[index]
			if vertex.x < bounds.position.x + 0.02 or vertex.x > bounds.end.x - 0.02 or vertex.z < bounds.position.z + 0.02 or vertex.z > bounds.end.z - 0.02:
				continue
			var point := lawn.to_global(vertex)
			var hit := ray(point + Vector3.UP, point - Vector3.UP, 2)
			check(not hit.is_empty(), "Ground ray must hit the lawn")
			if not hit.is_empty():
				check(absf(hit.position.y - point.y) < 0.013, "Ground boxes must follow the lawn profile within 1.3 cm")
			samples += 1
		check(samples > 10, "Expected ground samples across the lot")
		var wall_bounds: AABB
		for surface in house.mesh.get_surface_count():
			if house.mesh.surface_get_material(surface).resource_name.begins_with("Siding_"):
				var data := house.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
				wall_bounds = AABB(points[0], Vector3.ZERO)
				for point in points:
					wall_bounds = wall_bounds.expand(point)
		var center := wall_bounds.get_center()
		check(not ray(house.to_global(Vector3(wall_bounds.position.x - 1, center.y, center.z)), house.to_global(center), 8).is_empty(), "House wall blocks entry")
		var fence_checks := 0
		for shape: CollisionShape3D in fence.get_node("LotCollision").get_children():
			var axis: int = 0 if shape.shape.size.x < shape.shape.size.z else 2
			var offset := Vector3.ZERO
			offset[axis] = 0.7
			check(not ray(shape.to_global(offset), shape.to_global(-offset), 4).is_empty(), "Fence run blocks crossing")
			fence_checks += 1
		check(fence_checks >= 3 and fence_checks <= 12, "Fence boards must merge into a few runs")
		var front_z := -INF
		var front_runs: Array[AABB] = []
		for shape: CollisionShape3D in fence.get_node("LotCollision").get_children():
			if shape.shape.size.x > shape.shape.size.z:
				front_z = maxf(front_z, shape.position.z)
		for shape: CollisionShape3D in fence.get_node("LotCollision").get_children():
			if shape.shape.size.x > shape.shape.size.z and absf(shape.position.z - front_z) < 0.15:
				front_runs.append(AABB(shape.position - shape.shape.size * 0.5, shape.shape.size))
		front_runs.sort_custom(func(a: AABB, b: AABB): return a.position.x < b.position.x)
		var tested_gap := false
		for index in range(1, front_runs.size()):
			if front_runs[index].position.x - front_runs[index - 1].end.x < 0.5:
				continue
			var gap := Vector3((front_runs[index].position.x + front_runs[index - 1].end.x) * 0.5, front_runs[index].get_center().y, front_z)
			check(ray(fence.to_global(gap + Vector3(0, 0, 0.7)), fence.to_global(gap - Vector3(0, 0, 0.7)), 4).is_empty(), "Fence entrance must remain open")
			tested_gap = true
		check(tested_gap, "Expected a preserved entrance between front fence runs")
		print("Checked ", file, ": ", boxes, " boxes, ", fence_checks, " fence runs, ", samples, " ground samples")
		if first_lot == null:
			first_lot = lot
			# Keep one lot for a real CharacterBody walk over the sloping lawn.
		else:
			lot.free()
		lots_checked += 1
		if first_lot == lot:
			lot.position.x = 100
	var walker := CharacterBody3D.new()
	var streaming := root.get_node("WorldStreaming")
	streaming._cache_foliage_obstacles(first_lot)
	for obstacle: AABB in streaming._obstacle_bounds:
		check(not (obstacle.size.x > 20 and obstacle.size.z > 35), "Walkable ground and hollow fence perimeters must not exclude foliage from the whole yard")
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.25
	capsule_shape.height = 1.8
	capsule.shape = capsule_shape
	capsule.position.y = 0.9
	walker.add_child(capsule)
	walker.collision_layer = 0
	walker.collision_mask = 2
	walker.floor_snap_length = 0.2
	root.add_child(walker)
	walker.position = Vector3(100, 0.18, -1)
	for frame in 240:
		await physics_frame
		walker.velocity = Vector3(0, -2, -3)
		walker.move_and_slide()
	check(walker.position.z < -12 and walker.position.y > 0.58 and walker.is_on_floor(), "Capsule can walk continuously from street-height lawn to backyard-height lawn")
	walker.free()
	first_lot.free()
	check(lots_checked == 12, "Expected twelve lot assets")
	var full: Node3D = load("res://scenes/chapters/main/hood.Final.glb").instantiate()
	check(full.find_children("*", "CollisionShape3D", true, false).size() == total_boxes, "Full neighborhood must contain the same box colliders as the separate lots")
	full.free()
	print("Neighborhood collision: ", lots_checked, " lots, ", total_boxes, " boxes, ", failures, " failures")
	quit(0 if failures == 0 else 1)
