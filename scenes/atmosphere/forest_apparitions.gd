extends Node3D

enum State { IDLE, REVEALING, PEEKING, RETREATING, DOG_PASS }
const Silhouette = preload("res://scenes/atmosphere/apparition_silhouette.gd")
const TreeAnchor = preload("res://scenes/atmosphere/apparition_tree_anchor.gd")
@export var developer_trigger_enabled: bool = true
@export var trigger_action: StringName = &"debug_apparition"
@export var minimum_distance: float = 7.0
@export var maximum_distance: float = 22.0
@export var reveal_seconds: float = 0.55
@export var screen_border_margin: float = 0.12
@export var screen_edge_width: float = 0.24
@export var maximum_peek_seconds: float = 3.0
@export var gaze_seconds: float = 0.18
@export var retreat_seconds: float = 0.28
@export var approach_distance: float = 4.0
@export var peek_body_shift: float = 0.36
@export var tree_paths: Array[NodePath] = []
@export_category("Automatic Sightings")
@export var automatic_sightings_enabled: bool = true
@export_range(1.0, 600.0, 1.0) var hat_man_interval_seconds: float = 30.0
@export_range(1.0, 600.0, 1.0) var dog_interval_seconds: float = 100.0
@export_range(0.1, 10.0, 0.1) var automatic_retry_seconds: float = 1.0
@export_category("Dog Glimpse")
@export var dog_pass_seconds: float = 0.40
@export var dog_scale: float = 0.65
@export var dog_top_screen_y: float = 0.86
@export var dog_look_down_degrees: float = 6.0

var state: State = State.IDLE
var next_shape: int = Silhouette.Shape.HAT_MAN
var active_figure: Node3D
var _player: FirstPersonPlayer
var _trees: Array[Dictionary] = []
var _bark_cache: Dictionary = {}
var _elapsed: float = 0.0
var _gaze: float = 0.0
var _retreat_elapsed: float = 0.0
var _hidden_position: Vector3
var _target: Vector3
var _peek_amount: float = 0.0
var _retreat_amount: float = 0.0
var _peek_side: float = 1.0
var _peek_direction: Vector3
var _active_sections: Array[PackedVector3Array] = []
var _dog_start: Vector3
var _dog_end: Vector3
var _dog_forward: Vector3
var _dog_initial_camera_forward: Vector3
var _dog_travel_velocity: Vector3
var _dog_depth: float = 0.0
var _hat_man_clock: float = 0.0
var _dog_clock: float = 0.0
var _hat_man_retry: float = 0.0
var _dog_retry: float = 0.0

func _gameplay_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_size := Vector2(minf(viewport_size.x, viewport_size.y * 4.0 / 3.0), minf(viewport_size.y, viewport_size.x * 3.0 / 4.0))
	return Rect2((viewport_size - safe_size) * 0.5, safe_size)

func _screen_position(point: Vector3) -> Vector2:
	var rect := _gameplay_rect()
	return (_player.camera.unproject_position(point) - rect.position) / rect.size

func _at_edge(point: Vector3) -> bool:
	if _player.camera.is_position_behind(point):
		return false
	var screen := _screen_position(point)
	return screen.y > 0.32 and screen.y < 0.78 and screen.x >= screen_border_margin and screen.x <= 1.0 - screen_border_margin and (screen.x <= screen_edge_width or screen.x >= 1.0 - screen_edge_width)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent().get_node_or_null("Player") as FirstPersonPlayer
	_cache_trees.call_deferred()

func _cache_trees() -> void:
	_trees.clear()
	if not tree_paths.is_empty():
		for path: NodePath in tree_paths:
			var tree := get_node_or_null(path) as Node3D
			if tree != null:
				_add_tree_node(tree)
		return
	# Use actual tree instances, including the forest's filtered MultiMeshes.
	for child: Node in get_parent().get_children():
		if child is Node3D and (str(child.name).begins_with("tree_") or str(child.name).begins_with("dead_tree_")):
			_add_tree_node(child as Node3D)
	var foliage := get_parent().get_node_or_null("Foliage")
	if foliage == null:
		return
	for child: Node in foliage.get_children():
		if not child is MultiMeshInstance3D or not str(child.name).begins_with("treeMulti"):
			continue
		var trees := child as MultiMeshInstance3D
		if trees.multimesh == null:
			continue
		var count := trees.multimesh.instance_count
		if trees.multimesh.visible_instance_count >= 0:
			count = mini(count, trees.multimesh.visible_instance_count)
		# Read the saved buffer, which also works with the headless rendering server.
		var buffer := trees.multimesh.buffer
		var stride := 12 + (4 if trees.multimesh.use_colors else 0) + (4 if trees.multimesh.use_custom_data else 0)
		for index in count:
			var offset := index * stride
			if offset + 11 >= buffer.size():
				continue
			var transform := Transform3D(Basis(Vector3(buffer[offset], buffer[offset + 4], buffer[offset + 8]), Vector3(buffer[offset + 1], buffer[offset + 5], buffer[offset + 9]), Vector3(buffer[offset + 2], buffer[offset + 6], buffer[offset + 10])), Vector3(buffer[offset + 3], buffer[offset + 7], buffer[offset + 11]))
			transform = trees.global_transform * transform
			var parts: Array[Dictionary] = [{"faces": _bark_faces(trees.multimesh.mesh), "transform": transform}]
			_trees.append({"position": transform.origin, "parts": parts})

func _bark_faces(mesh: Mesh) -> PackedVector3Array:
	if not _bark_cache.has(mesh):
		_bark_cache[mesh] = TreeAnchor.bark_faces(mesh)
	return _bark_cache[mesh]

func _add_tree_node(tree: Node3D) -> void:
	var visuals: Array[Node] = tree.find_children("*", "MeshInstance3D", true, false)
	if tree is MeshInstance3D:
		visuals.append(tree)
	var parts: Array[Dictionary] = []
	for node: Node in visuals:
		var visual := node as MeshInstance3D
		if visual.mesh != null and visual.is_visible_in_tree():
			parts.append({"faces": _bark_faces(visual.mesh), "transform": visual.global_transform})
	if not parts.is_empty():
		_trees.append({"position": tree.global_position, "parts": parts})

func _can_show() -> bool:
	if not is_instance_valid(_player) or _player.is_frozen or get_tree().paused:
		return false
	for overlay: Node in get_tree().get_nodes_in_group("world_map"):
		if overlay.is_map_open():
			return false
	return true

func _unhandled_input(event: InputEvent) -> void:
	if not developer_trigger_enabled or not OS.is_debug_build() or event.is_echo():
		return
	if event.is_action_pressed(trigger_action) and _can_show():
		trigger_sighting()
		get_viewport().set_input_as_handled()

func trigger_sighting() -> bool:
	if not _can_show() or state != State.IDLE:
		return false
	var started := _start_dog_pass(true) if next_shape == Silhouette.Shape.DOG else _start_hat_man(true)
	if started:
		next_shape = Silhouette.Shape.HAT_MAN if next_shape == Silhouette.Shape.DOG else Silhouette.Shape.DOG
	return started

func _start_hat_man(report_failure: bool = false) -> bool:
	var camera := _player.camera
	var best: Dictionary = {}
	var best_score := INF
	for tree: Dictionary in _trees:
		var point: Vector3 = tree["position"]
		var distance := camera.global_position.distance_to(point)
		if distance < minimum_distance or distance > maximum_distance:
			continue
		if camera.is_position_behind(point):
			continue
		var tree_screen := _screen_position(point + Vector3.UP * 1.8)
		if tree_screen.x > 0.32 and tree_screen.x < 0.68:
			continue
		var away := camera.global_position.direction_to(point)
		away.y = 0.0
		away = away.normalized()
		var right := away.cross(Vector3.UP).normalized()
		var ground := _ground_below(point)
		if ground.is_empty():
			continue
		var ground_y: float = (ground["position"] as Vector3).y
		if not tree.has("sections"):
			tree["sections"] = TreeAnchor.sections(tree["parts"], ground_y)
		var sections: Array[PackedVector3Array] = tree["sections"]
		if sections.is_empty():
			continue
		for side: float in [-1.0, 1.0]:
			var outward := right * side
			var edges := PackedVector3Array()
			for section: PackedVector3Array in sections:
				edges.append(TreeAnchor.visible_edge(section, camera.global_position, away, outward))
			# At full reveal, the upright body's center meets the bark edge: half shows.
			var hidden_side := edges[1] + away * 0.22 - outward * peek_body_shift
			hidden_side.y = ground_y + 0.025
			var target := hidden_side + Vector3.UP * 1.97 + outward * (peek_body_shift + 0.10)
			if not _at_edge(target) or not _line_clear(target):
				continue
			var screen := _screen_position(target)
			var preferred := (screen_border_margin + screen_edge_width) * 0.5
			var score := minf(absf(screen.x - preferred), absf(screen.x - (1.0 - preferred))) * 100.0 + distance * 0.2
			if score < best_score:
				best_score = score
				best = {"hidden": hidden_side, "target": target, "away": away, "side": side, "outward": outward, "edges": edges, "sections": sections}
	if best.is_empty():
		if report_failure:
			print("[Apparitions] No tree at the far left/right edge. Reframe nearby trees and try the developer shortcut again.")
		return false
	_hidden_position = best["hidden"]
	_target = best["target"]
	active_figure = Silhouette.new()
	active_figure.shape = Silhouette.Shape.HAT_MAN
	add_child(active_figure)
	active_figure.global_position = _hidden_position
	active_figure.scale.x = 0.85
	var away: Vector3 = best["away"]
	active_figure.rotation.y = atan2(away.x, away.z)
	_peek_amount = 0.0
	_peek_side = best["side"]
	_peek_direction = best["outward"]
	_active_sections.assign(best["sections"])
	active_figure.configure_peek(camera.global_position, away, _peek_direction, best["edges"])
	_player.camera.cull_mask |= Silhouette.VIEW_LAYER
	_elapsed = 0.0
	_gaze = 0.0
	state = State.REVEALING
	print("[Apparitions] Hat man peripheral peek triggered.")
	return true

func _start_dog_pass(report_failure: bool = false) -> bool:
	var camera := _player.camera
	var forward := -camera.global_basis.z
	if absf(forward.y) > 0.25:
		if report_failure:
			print("[Apparitions] Face ahead to test the bottom-edge dog glimpse.")
		return false
	forward.y = 0.0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var ground := _ground_below(camera.global_position + forward)
	if ground.is_empty():
		return false
	var ground_y: float = (ground["position"] as Vector3).y + 0.025
	var safe := _gameplay_rect()
	var bottom_ray := camera.project_ray_normal(safe.position + safe.size * Vector2(0.5, dog_top_screen_y))
	if bottom_ray.y >= -0.05:
		return false
	# Place the ears near the bottom edge while keeping the paws grounded.
	var top_y := ground_y + 1.475 * dog_scale
	_dog_depth = ((top_y - camera.global_position.y) / bottom_ray.y) * bottom_ray.dot(forward)
	if _dog_depth < 0.4 or _dog_depth > 2.5:
		return false
	var edge := camera.project_position(safe.position + safe.size * Vector2(1.0, 0.5), _dog_depth)
	var half_width := absf((edge - camera.global_position).dot(right))
	_dog_start = camera.global_position + forward * _dog_depth - right * (half_width + dog_scale * 0.85)
	_dog_end = camera.global_position + forward * _dog_depth + right * (half_width + dog_scale * 0.85)
	_dog_start.y = ground_y
	_dog_end.y = ground_y
	# Carry the crossing forward at the player's initial speed, so running cannot
	# overtake it before the head reaches the bottom of the view. The trajectory
	# remains in world space and does not turn or follow camera motion afterward.
	_dog_travel_velocity = Vector3(_player.velocity.x, 0.0, _player.velocity.z)
	_dog_forward = forward
	var previous := _dog_start
	for step in range(1, 5):
		var point := _dog_position(float(step) / 4.0)
		if not _dog_path_clear(previous, point):
			return false
		previous = point
	active_figure = Silhouette.new()
	active_figure.shape = Silhouette.Shape.DOG
	add_child(active_figure)
	active_figure.scale = Vector3.ONE * dog_scale
	active_figure.global_position = _dog_start
	active_figure.rotation.y = atan2(right.z, -right.x)
	_dog_initial_camera_forward = -camera.global_basis.z
	_player.camera.cull_mask |= Silhouette.VIEW_LAYER
	_elapsed = 0.0
	state = State.DOG_PASS
	print("[Apparitions] Close bottom-edge dog pass triggered.")
	return true

func _advance_automatic_sightings(delta: float) -> bool:
	if not automatic_sightings_enabled:
		return false
	var hat_interval := maxf(hat_man_interval_seconds, 1.0)
	var dog_interval := maxf(dog_interval_seconds, 1.0)
	# Keep one pending sighting per shape; blocked locations never build a backlog.
	_hat_man_clock = minf(_hat_man_clock + delta, hat_interval)
	_dog_clock = minf(_dog_clock + delta, dog_interval)
	_hat_man_retry = maxf(_hat_man_retry - delta, 0.0)
	_dog_retry = maxf(_dog_retry - delta, 0.0)
	if state != State.IDLE:
		return false
	# Give the less frequent dog priority when both timers are due together.
	if _dog_clock >= dog_interval and _dog_retry <= 0.0:
		if _start_dog_pass():
			_dog_clock = 0.0
			return true
		_dog_retry = maxf(automatic_retry_seconds, 0.1)
	if _hat_man_clock >= hat_interval and _hat_man_retry <= 0.0:
		if _start_hat_man():
			_hat_man_clock = 0.0
			return true
		_hat_man_retry = maxf(automatic_retry_seconds, 0.1)
	return false

func _dog_position(progress: float) -> Vector3:
	return _dog_start.lerp(_dog_end, progress) + _dog_travel_velocity * dog_pass_seconds * progress - _dog_forward * _dog_depth * 0.72 * smoothstep(0.5, 1.0, progress)

func _dog_path_clear(start: Vector3, end: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(start + Vector3.UP * 0.5, end + Vector3.UP * 0.5)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _ground_below(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3.0, point - Vector3.UP * 4.0)
	query.exclude = [_player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit["normal"] as Vector3).dot(Vector3.UP) < 0.8:
		return {}
	return hit

func _line_clear(target: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(_player.camera.global_position, target)
	query.exclude = [_player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _process(delta: float) -> void:
	if not _can_show():
		if state != State.IDLE:
			clear_sighting()
		return
	if _advance_automatic_sightings(delta):
		# This frame's time precedes the new sighting, so animate from the next frame.
		return
	if state == State.IDLE:
		return
	if state == State.DOG_PASS:
		_elapsed += delta
		var looking_down := (-_player.camera.global_basis.z).y < _dog_initial_camera_forward.y - sin(deg_to_rad(dog_look_down_degrees))
		if looking_down or _elapsed >= dog_pass_seconds:
			clear_sighting()
			return
		var progress := clampf(_elapsed / maxf(dog_pass_seconds, 0.01), 0.0, 1.0)
		var point := _dog_position(progress)
		if not _dog_path_clear(active_figure.global_position, point):
			clear_sighting()
			return
		active_figure.global_position = point
		active_figure.position.y += sin(progress * TAU * 2.0) * 0.012
		return
	_update_peek_occlusion()
	if state == State.RETREATING:
		_retreat_elapsed += delta
		var weight := clampf(_retreat_elapsed / maxf(retreat_seconds, 0.01), 0.0, 1.0)
		_apply_peek_pose(lerpf(_retreat_amount, 0.0, smoothstep(0.0, 1.0, weight)))
		if weight >= 1.0:
			clear_sighting()
		return
	_elapsed += delta
	if state == State.REVEALING:
		_apply_peek_pose(smoothstep(0.0, 1.0, clampf(_elapsed / maxf(reveal_seconds, 0.01), 0.0, 1.0)))
		if _elapsed >= reveal_seconds:
			state = State.PEEKING
			_elapsed = 0.0
	var direction := _player.camera.global_position.direction_to(_target)
	var noticed := direction.dot(-_player.camera.global_basis.z) > cos(deg_to_rad(8.0)) and _line_clear(_target)
	_gaze = _gaze + delta if noticed else 0.0
	var screen := _screen_position(_target)
	var moved_into_center := screen.x > 0.30 and screen.x < 0.70
	if moved_into_center or _gaze >= gaze_seconds or _player.global_position.distance_to(_hidden_position) < approach_distance or (state == State.PEEKING and _elapsed >= maximum_peek_seconds):
		state = State.RETREATING
		_retreat_elapsed = 0.0
		_retreat_amount = _peek_amount

func _apply_peek_pose(amount: float) -> void:
	_peek_amount = amount
	active_figure.rotation.z = 0.0
	active_figure.global_position = _hidden_position + _peek_direction * peek_body_shift * amount
	active_figure.set_reveal_amount(amount)

func _update_peek_occlusion() -> void:
	var camera := _player.camera.global_position
	var away := camera.direction_to(_hidden_position)
	away.y = 0.0
	away = away.normalized()
	var outward := away.cross(Vector3.UP).normalized() * _peek_side
	var edges := PackedVector3Array()
	for section: PackedVector3Array in _active_sections:
		edges.append(TreeAnchor.visible_edge(section, camera, away, outward))
	active_figure.update_peek_occlusion(camera, away, outward, edges)

func clear_sighting() -> void:
	if is_instance_valid(active_figure):
		active_figure.queue_free()
	active_figure = null
	_active_sections.clear()
	state = State.IDLE
