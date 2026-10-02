extends CorruptedFriend
const ROUTE := preload("res://scenes/shared/entity_route.gd")
var navigation_route := ROUTE.new()

@export var light_retreat_distance: float = 13.0
@export var light_retreat_speed: float = 3.8
@export var light_memory_seconds: float = 2.5
var light_fear: float = 0.0
var retreat_destination := Vector3.ZERO

func _physics_process(delta: float) -> void:
	var before := global_position
	super._physics_process(delta)
	var travelled := global_position - before
	var speed := Vector2(travelled.x, travelled.z).length() / maxf(delta, 0.0001)
	if visual.has_method("set_movement_speed"):
		visual.set_movement_speed(speed)

func _physics_process_watcher(delta: float) -> void:
	if not activation_enabled or not is_instance_valid(target):
		super._physics_process_watcher(delta)
		return
	var beam_hit := _flashlight_hits_me()
	var player_safe := _world_light_at(target.global_position + Vector3.UP) > 0.12
	if beam_hit or (player_safe and global_position.distance_to(target.global_position) < light_retreat_distance):
		if light_fear <= 0.0:
			retreat_destination = _choose_dark_retreat()
			# A light scare reverses the current pursuit immediately; do not spend
			# the old route's refresh interval still walking toward the player.
			route_timer = 0.0
			route.clear()
			route_index = 0
			navigation_route.reset()
		light_fear = light_memory_seconds
	else:
		light_fear = maxf(0.0, light_fear - delta)
	if light_fear <= 0.0:
		var previous_facing := rotation.y
		super._physics_process_watcher(delta)
		if Vector2(velocity.x, velocity.z).length() > 0.1:
			rotation.y = previous_facing
		_face_motion(delta)
		return
	watching_player = true
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	var distance := global_position.distance_to(target.global_position)
	var motion := _path_direction(retreat_destination) * light_retreat_speed if distance < light_retreat_distance else Vector3.ZERO
	velocity.x = move_toward(velocity.x, motion.x, delta * watch_acceleration)
	velocity.z = move_toward(velocity.z, motion.z, delta * watch_acceleration)
	var facing := motion if motion.length() > 0.1 else target.global_position - global_position
	rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-watch_turn_speed * delta))
	visual.play("walk" if motion.length() > 0.1 else "alert")
	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()

func _face_motion(delta: float) -> void:
	var motion := Vector3(velocity.x, 0, velocity.z)
	if motion.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-motion.x, -motion.z), 1.0 - exp(-watch_turn_speed * delta))

func _flashlight_hits_me() -> bool:
	var flashlight := target.get_node_or_null("Head/Camera3D/Flashlight") as PlayerFlashlight
	if flashlight == null or not flashlight.is_enabled():
		return false
	var beam := flashlight.beam
	var direction := global_position + Vector3.UP * 1.2 - beam.global_position
	if direction.length() > beam.spot_range:
		return false
	if (-beam.global_basis.z).dot(direction.normalized()) < cos(deg_to_rad(beam.spot_angle)):
		return false
	return _unblocked(beam.global_position, global_position + Vector3.UP * 1.2)

func _world_light_at(point: Vector3) -> float:
	var strength := 0.0
	for node: Node in get_tree().get_nodes_in_group("ridgeback_repellent"):
		var light := node as OmniLight3D
		if light == null or not light.is_visible_in_tree() or light.light_energy <= 0.0:
			continue
		var distance := light.global_position.distance_to(point)
		if distance < light.omni_range and _unblocked(light.global_position, point):
			strength += light.light_energy * pow(1.0 - distance / light.omni_range, 2.0)
	return strength

func _unblocked(from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from, to)
	var exclusions: Array[RID] = [get_rid()]
	if target is CollisionObject3D:
		exclusions.append((target as CollisionObject3D).get_rid())
	ray.exclude = exclusions
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _choose_dark_retreat() -> Vector3:
	var away := global_position - target.global_position
	away.y = 0.0
	away = away.normalized()
	var best := target.global_position + away * (light_retreat_distance + 2.0)
	var cost := INF
	for angle: float in [-0.75, -0.35, 0.0, 0.35, 0.75]:
		var point := target.global_position + away.rotated(Vector3.UP, angle) * (light_retreat_distance + 2.0)
		var candidate_cost := _world_light_at(point + Vector3.UP) * 20.0 + absf(angle)
		if candidate_cost < cost:
			cost = candidate_cost
			best = point
	return best

func reset_enemy() -> void:
	light_fear = 0.0
	navigation_route.reset()
	super.reset_enemy()

func _path_direction(destination: Vector3) -> Vector3:
	if NavigationServer3D.map_get_regions(agent.get_navigation_map()).is_empty():
		return super._path_direction(destination)
	return navigation_route.direction(self, agent.get_navigation_map(), destination, get_physics_process_delta_time())
