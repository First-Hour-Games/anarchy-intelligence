class_name ScrapAutomaton extends CharacterBody3D

## Eight-direction billboard monster used to test 2D enemies in the 3D world.
## It does not hurt the player yet; it only wakes, turns, and follows.

@export_category("Pursuit")
@export var pursuit_enabled: bool = false
@export var movement_speed: float = 1.35
@export var detection_distance: float = 8.0
@export var stopping_distance: float = 1.4
@export var turn_speed: float = 3.0
@export var movement_acceleration: float = 5.0

@export_category("Unseen Stalker")
@export var move_when_unseen_enabled: bool = true
@export var unseen_activation_distance: float = 100.0
@export var unseen_movement_speed: float = 0.44

@export_category("Presentation")
@export var movement_bob_height: float = 0.035
@export var movement_bob_frequency: float = 1.7

@onready var visual_pivot: Node3D = $VisualPivot
@onready var directional_sprite: AnimatedSprite3D = $VisualPivot/DirectionalSprite
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var player: Node3D
var player_camera: Camera3D
var visual_rest_position: Vector3
var movement_phase: float = 0.0


func _ready() -> void:
	visual_rest_position = visual_pivot.position
	_find_player()
	_update_direction_frame()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var desired_velocity := Vector3.ZERO
	if is_instance_valid(player):
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		var distance_to_player := to_player.length()
		var normal_pursuit_active := pursuit_enabled and distance_to_player <= detection_distance
		var unseen_stalker_active := (
			move_when_unseen_enabled
			and distance_to_player <= unseen_activation_distance
			and not _is_being_watched()
		)

		if (normal_pursuit_active or unseen_stalker_active) and distance_to_player > 0.001:
			var pursuit_direction := _pursuit_direction_toward(player.global_position, to_player, distance_to_player)
			_turn_toward(pursuit_direction, delta)
			if distance_to_player > stopping_distance:
				var active_speed := movement_speed if normal_pursuit_active else unseen_movement_speed
				desired_velocity = pursuit_direction * active_speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, movement_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, movement_acceleration * delta)
	move_and_slide()

	_update_movement_bob(delta)
	_update_direction_frame()


## Routes pursuit through the baked navmesh when one covers this position (the
## main map, so the automaton walks around houses instead of through them),
## and falls back to a straight line when no navmesh is available (e.g. the
## playground test scene), matching the previous behavior there.
func _pursuit_direction_toward(target_position: Vector3, direct_offset: Vector3, direct_distance: float) -> Vector3:
	var direct_direction := direct_offset / direct_distance
	nav_agent.target_position = target_position
	if not nav_agent.is_target_reachable():
		return direct_direction

	var next_point := nav_agent.get_next_path_position()
	var to_next := next_point - global_position
	to_next.y = 0.0
	if to_next.is_zero_approx():
		return direct_direction
	return to_next.normalized()


func _find_player() -> void:
	player = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player):
		player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D


func _is_being_watched() -> bool:
	if not is_instance_valid(player_camera):
		return false

	var visual_center := global_position + Vector3.UP * 1.35
	if not player_camera.is_position_in_frustum(visual_center):
		return false

	# A frustum check tells us the monster is on screen. This ray then confirms
	# that a wall or other solid object is not hiding it from the player.
	var query := PhysicsRayQueryParameters3D.create(player_camera.global_position, visual_center)
	if player is CollisionObject3D:
		query.exclude = [(player as CollisionObject3D).get_rid()]
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == self


func _turn_toward(direction: Vector3, delta: float) -> void:
	var desired_rotation := atan2(-direction.x, -direction.z)
	var turn_weight := 1.0 - exp(-turn_speed * delta)
	rotation.y = lerp_angle(rotation.y, desired_rotation, turn_weight)


func _update_direction_frame() -> void:
	if not is_instance_valid(player):
		return

	var to_viewer := player.global_position - global_position
	to_viewer.y = 0.0
	if to_viewer.is_zero_approx():
		return

	# Convert the viewer direction into the monster's local space. Local -Z is
	# its front. Rounding to eighth-turns selects 0, 45, ... 315 degrees.
	var local_viewer := global_transform.basis.inverse() * to_viewer.normalized()
	var viewer_angle := atan2(local_viewer.x, -local_viewer.z)
	var frame_index := wrapi(int(round(viewer_angle / (TAU / 8.0))), 0, 8)
	directional_sprite.frame = frame_index
	# The generated left-side drawings face the opposite screen direction.
	# Mirror only left and front-left across the vertical (Y) axis.
	directional_sprite.flip_h = frame_index == 6 or frame_index == 7


func _update_movement_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var target_position := visual_rest_position
	if is_on_floor() and horizontal_speed > 0.05:
		movement_phase += delta * movement_bob_frequency * TAU
		target_position.y += abs(sin(movement_phase)) * movement_bob_height
	else:
		movement_phase = 0.0

	var bob_weight := 1.0 - exp(-10.0 * delta)
	visual_pivot.position = visual_pivot.position.lerp(target_position, bob_weight)
