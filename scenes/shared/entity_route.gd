extends RefCounted

var points := PackedVector3Array()
var committed: Array[bool] = []
var cursor: int = 0
var goal := Vector3.INF
var retry_time: float = 0.0
var stuck_time: float = 0.0
var previous_position := Vector3.INF
var moving: bool = false

func reset() -> void:
	points.clear()
	committed.clear()
	cursor = 0
	goal = Vector3.INF
	stuck_time = 0.0
	retry_time = 0.0
	previous_position = Vector3.INF
	moving = false

func direction(actor: CharacterBody3D, nav_map: RID, destination: Vector3, delta: float) -> Vector3:
	retry_time = maxf(0.0, retry_time - delta)
	if previous_position.is_finite():
		var progress := actor.global_position.distance_to(previous_position)
		stuck_time = stuck_time + delta if progress < 0.001 and moving else 0.0
	previous_position = actor.global_position
	var crossing := cursor < committed.size() and committed[cursor]
	var moved_goal := goal.distance_to(destination) > 1.0
	if goal == Vector3.INF or (not crossing and retry_time <= 0.0 and (moved_goal or stuck_time > 0.8 or cursor >= points.size())):
		build(actor, nav_map, destination)
		retry_time = 0.4
		stuck_time = 0.0
	while cursor < points.size():
		var offset := points[cursor] - actor.global_position
		var height := absf(offset.y)
		offset.y = 0.0
		if offset.length() > 0.22 or height > 1.0:
			moving = not offset.is_zero_approx()
			return offset.normalized()
		cursor += 1
	moving = false
	return Vector3.ZERO

func build(actor: CharacterBody3D, nav_map: RID, destination: Vector3) -> void:
	points.clear()
	committed.clear()
	cursor = 0
	goal = destination
	var from := actor.global_position
	var buildings: Array[Node] = actor.get_tree().get_nodes_in_group("enemy_route_building")
	# Exit the current building before entering a different one.
	buildings.sort_custom(func(a: Node, b: Node) -> bool: return a.contains_route_point(from) and not b.contains_route_point(from))
	for building: Node in buildings:
		for gate: Dictionary in building.route_transitions(from, destination):
			var point: Vector3 = gate.point
			if gate.direct:
				points.append(point)
				committed.append(true)
			else:
				_append_path(nav_map, from, point)
			from = point
	_append_path(nav_map, from, destination)

func _append_path(nav_map: RID, from: Vector3, to: Vector3) -> void:
	# Voxelized walkable surfaces sit above the physical floor. Query just
	# above the feet so a landing selects its floor, not a lower stair sliver.
	var query_lift := Vector3.UP * 0.6
	var path := NavigationServer3D.map_get_path(nav_map, from + query_lift, to + query_lift, true)
	for point: Vector3 in path:
		points.append(point)
		committed.append(false)
