class_name CorruptedFriend
extends CharacterBody3D
signal state_changed(state_name: String)
signal attack_landed(target: Node)
signal died
enum State { DORMANT, ACTIVATING, PURSUIT, SEARCH, WINDUP, RECOVERY, HIT, DEAD }
@export var activation_enabled: bool = true
@export var watch_only: bool = true
@export var watch_distance: float = 20.0
@export var watch_requires_line_of_sight: bool = true
@export var watch_turn_speed: float = 2.2
@export var watch_follow_speed: float = 0.85
@export var watch_stop_distance: float = 3.25
@export var watch_retreat_distance: float = 0.0
@export var watch_acceleration: float = 3.0
@export var detection_distance: float = 14.0
@export var walk_speed: float = 1.15
@export var chase_speed: float = 2.0
@export var damage_enabled: bool = false
@export var turn_speed: float = 4.0
@export var attack_range: float = 1.65
@export var attack_damage: float = 25.0
@export var windup_seconds: float = 0.7
@export var recovery_seconds: float = 1.2
@export var memory_seconds: float = 4.0
@export var max_health: float = 100.0
@export var max_step_height: float = 0.3
@onready var visual: Node3D = $Visual
@onready var agent: NavigationAgent3D = $NavigationAgent3D
var state: State = State.DORMANT
var health: float
var target: Node3D
var timer: float = 0.0
var lost_time: float = 0.0
var last_seen: Vector3
var spawn_transform: Transform3D
var route: PackedVector3Array = []
var route_index: int = 0
var route_timer: float = 0.0
var watching_player: bool = false
var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("corrupted_friend")
	health = max_health
	spawn_transform = global_transform
	last_seen = global_position

func activate() -> void:
	activation_enabled = true
	if watch_only:
		if state != State.DEAD:
			_enter(State.DORMANT)
		return
	if state == State.DORMANT:
		_enter(State.ACTIVATING, 0.9)

func reset_enemy() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	health = max_health
	lost_time = 0.0
	route_timer = 0.0
	$CollisionShape3D.set_deferred("disabled", false)
	_enter(State.DORMANT)

func take_damage(amount: float) -> void:
	if state == State.DEAD or amount <= 0.0:
		return
	health = maxf(health - amount, 0.0)
	if health == 0.0:
		_enter(State.DEAD)
		$CollisionShape3D.set_deferred("disabled", true)
		died.emit()
	else:
		_enter(State.HIT, 0.5)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
	timer = maxf(0.0, timer - delta)
	route_timer = maxf(0.0, route_timer - delta)
	if watch_only:
		_physics_process_watcher(delta)
		return
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	var motion := Vector3.ZERO
	var visible_target := _can_see_target()
	var distance := global_position.distance_to(target.global_position) if is_instance_valid(target) else INF
	if visible_target:
		last_seen = target.global_position
		lost_time = 0.0
	else:
		lost_time += delta
	match state:
		State.DORMANT:
			if activation_enabled and visible_target:
				activate()
		State.ACTIVATING, State.HIT:
			if timer <= 0.0:
				_enter(State.PURSUIT)
		State.PURSUIT:
			if visible_target and distance <= attack_range:
				_enter(State.WINDUP, windup_seconds)
			elif lost_time > memory_seconds:
				_enter(State.SEARCH, 3.0)
			else:
				var speed := chase_speed if visible_target else walk_speed
				motion = _path_direction(last_seen) * speed
				visual.play("chase" if speed == chase_speed else "walk")
		State.SEARCH:
			if visible_target:
				_enter(State.PURSUIT)
			elif timer <= 0.0:
				_enter(State.DORMANT)
		State.WINDUP:
			if timer <= 0.0:
				# Impact rechecks range and sight: stepping away dodges the hit.
				if damage_enabled and visible_target and distance <= attack_range:
					var receiver := target.get_node_or_null("CombatHealth")
					if receiver and receiver.has_method("take_damage"):
						receiver.take_damage(attack_damage, self)
					elif target.has_method("take_damage"):
						target.take_damage(attack_damage)
					attack_landed.emit(target)
				_enter(State.RECOVERY, recovery_seconds)
		State.RECOVERY:
			if timer <= 0.0:
				_enter(State.PURSUIT)
		State.DEAD:
			velocity = Vector3.ZERO
			return
	velocity.x = move_toward(velocity.x, motion.x, delta * 8.0)
	velocity.z = move_toward(velocity.z, motion.z, delta * 8.0)
	var facing := motion
	if visible_target and state in [State.ACTIVATING, State.WINDUP]:
		facing = target.global_position - global_position
	if Vector2(facing.x, facing.z).length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-facing.x, -facing.z), 1.0 - exp(-turn_speed * delta))
	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()

func _physics_process_watcher(delta: float) -> void:
	velocity.y = velocity.y - gravity * delta if not is_on_floor() else 0.0
	if state == State.DEAD:
		velocity = Vector3.ZERO
		watching_player = false
		return
	if state == State.HIT and timer <= 0.0:
		_enter(State.DORMANT)
	watching_player = activation_enabled and state != State.HIT and _can_watch_target()
	var motion := Vector3.ZERO
	if watching_player:
		var facing := target.global_position - global_position
		facing.y = 0.0
		var distance_to_target := facing.length()
		if distance_to_target > watch_stop_distance:
			motion = _path_direction(target.global_position) * watch_follow_speed
		elif watch_retreat_distance > 0.0 and distance_to_target < watch_retreat_distance and distance_to_target > 0.01:
			# Back away to hold a standoff radius instead of letting the player
			# walk right up to it. Still faces the player (below), so it reads
			# as backing off while continuing to watch, not fleeing.
			motion = -facing.normalized() * watch_follow_speed
		if facing.length_squared() > 0.0001:
			rotation.y = lerp_angle(
				rotation.y,
				atan2(-facing.x, -facing.z),
				1.0 - exp(-watch_turn_speed * delta)
			)
		visual.play("walk" if motion.length_squared() > 0.0001 else "alert")
	else:
		visual.play("dormant")
	velocity.x = move_toward(velocity.x, motion.x, delta * watch_acceleration)
	velocity.z = move_toward(velocity.z, motion.z, delta * watch_acceleration)
	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()

func _can_see_target() -> bool:
	return _target_is_visible(detection_distance, true)

func _can_watch_target() -> bool:
	return _target_is_visible(watch_distance, watch_requires_line_of_sight)

func _target_is_visible(max_distance: float, require_line_of_sight: bool) -> bool:
	if not is_instance_valid(target) or global_position.distance_to(target.global_position) > max_distance:
		return false
	var receiver := target.get_node_or_null("CombatHealth")
	if receiver and receiver.get("is_dead") == true:
		return false
	if not require_line_of_sight:
		return true
	var eye := target.get_node_or_null("Head/Camera3D") as Node3D
	var destination := eye.global_position if eye else target.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.5, destination)
	ray.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.get("collider") == target

func _path_direction(destination: Vector3) -> Vector3:
	var point := destination
	var nav_map := agent.get_navigation_map()
	# An empty map still has an iteration ID after syncing. It has no paths.
	if NavigationServer3D.map_get_iteration_id(nav_map) > 0 and not NavigationServer3D.map_get_regions(nav_map).is_empty():
		# The map's displaced render terrain bakes below its flat collider.
		# Advance waypoints in XZ, leaving actual height to physics.
		if route_timer <= 0.0:
			route = NavigationServer3D.map_get_path(nav_map, global_position, destination, true)
			route_index = 0
			route_timer = 0.35
			# Some authored spawn points sit just outside the baked navmesh. Keep
			# passive following responsive and let CharacterBody collision handle
			# the direct fallback instead of freezing in place.
			if route.is_empty():
				var direct_offset := destination - global_position
				direct_offset.y = 0.0
				return direct_offset.normalized() if direct_offset.length() > 0.3 else Vector3.ZERO
		while route_index < route.size():
			var flat_offset := route[route_index] - global_position
			flat_offset.y = 0.0
			if flat_offset.length() > 0.35:
				break
			route_index += 1
		if route_index >= route.size():
			var fallback_offset := destination - global_position
			fallback_offset.y = 0.0
			return fallback_offset.normalized() if fallback_offset.length() > 0.3 else Vector3.ZERO
		point = route[route_index]
	var offset := point - global_position
	offset.y = 0.0
	return offset.normalized() if offset.length() > 0.3 else Vector3.ZERO

func _enter(next_state: State, duration: float = 0.0) -> void:
	state = next_state
	timer = duration
	var clips := ["dormant", "activate", "walk", "search", "windup", "attack", "hit", "dead"]
	visual.play(clips[state])
	state_changed.emit(State.keys()[state])
