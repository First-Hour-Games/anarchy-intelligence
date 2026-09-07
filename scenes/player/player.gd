class_name FirstPersonPlayer extends CharacterBody3D

## A small, reusable first-person controller for testing level scale and movement feel.
## One Godot unit is treated as roughly one metre.

@export_category("Movement")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 4.8
@export var ground_acceleration: float = 13.0
@export var ground_deceleration: float = 17.0
@export var air_acceleration: float = 3.0

@export_category("Jump")
@export var jump_velocity: float = 3.4

@export_category("Crouch")
@export_range(0.3, 0.9, 0.01) var crouch_height_scale: float = 0.55
@export_range(0.2, 1.0, 0.05) var crouch_speed_multiplier: float = 0.5
@export var crouch_transition_speed: float = 10.0

@export_category("Camera")
@export_range(0.0005, 0.01, 0.0001) var mouse_sensitivity: float = 0.0017
@export_range(45.0, 89.0, 1.0) var vertical_look_limit_degrees: float = 85.0

@export_category("Head Bob")
@export var head_bob_frequency: float = 1.8
@export var head_bob_vertical_amplitude: float = 0.035
@export var head_bob_horizontal_amplitude: float = 0.018
@export var head_bob_smoothing: float = 12.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var head_bob_phase: float = 0.0
var camera_rest_position: Vector3

var capsule_shape: CapsuleShape3D
var stand_capsule_height: float
var stand_collision_y: float
var stand_head_y: float
var crouch_capsule_height: float
var crouch_collision_y: float
var crouch_head_y: float
var is_crouching: bool = false


func _ready() -> void:
	camera_rest_position = camera.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	capsule_shape = collision_shape.shape.duplicate()
	collision_shape.shape = capsule_shape
	stand_capsule_height = capsule_shape.height
	stand_collision_y = collision_shape.position.y
	stand_head_y = head.position.y

	var height_diff := stand_capsule_height * (1.0 - crouch_height_scale)
	crouch_capsule_height = stand_capsule_height - height_diff
	crouch_collision_y = stand_collision_y - height_diff * 0.5
	crouch_head_y = stand_head_y - height_diff


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		var look_limit: float = deg_to_rad(vertical_look_limit_degrees)
		head.rotation.x = clamp(head.rotation.x, -look_limit, look_limit)


func _physics_process(delta: float) -> void:
	_update_crouch(delta)

	if is_on_floor():
		velocity.y = 0.0
		if Input.is_key_pressed(KEY_SPACE) and not is_crouching:
			velocity.y = jump_velocity
	else:
		velocity.y -= gravity * delta

	var input_vector: Vector2 = _get_movement_input()
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and input_vector.y < 0.0 and not is_crouching
	var target_speed := sprint_speed if is_sprinting else walk_speed
	if is_crouching:
		target_speed = walk_speed * crouch_speed_multiplier
	var target_velocity := world_direction * target_speed

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	if world_direction.is_zero_approx() and is_on_floor():
		acceleration = ground_deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()
	_update_head_bob(delta)


func _update_crouch(delta: float) -> void:
	var wants_crouch := Input.is_key_pressed(KEY_CTRL)
	if is_crouching and not wants_crouch and ceiling_check.is_colliding():
		wants_crouch = true
	is_crouching = wants_crouch

	var target_capsule_height := crouch_capsule_height if is_crouching else stand_capsule_height
	var target_collision_y := crouch_collision_y if is_crouching else stand_collision_y
	var target_head_y := crouch_head_y if is_crouching else stand_head_y

	var blend_weight := 1.0 - exp(-crouch_transition_speed * delta)
	capsule_shape.height = lerp(capsule_shape.height, target_capsule_height, blend_weight)
	collision_shape.position.y = lerp(collision_shape.position.y, target_collision_y, blend_weight)
	head.position.y = lerp(head.position.y, target_head_y, blend_weight)


func _get_movement_input() -> Vector2:
	var input_vector := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	)
	return input_vector.limit_length(1.0)


func _update_head_bob(delta: float) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving_on_floor := is_on_floor() and horizontal_speed > 0.1
	var target_offset := Vector3.ZERO

	if is_moving_on_floor:
		var speed_ratio := horizontal_speed / walk_speed
		head_bob_phase += delta * head_bob_frequency * TAU * speed_ratio
		var amplitude_scale: float = clampf(speed_ratio, 0.65, 1.5)
		target_offset.x = cos(head_bob_phase) * head_bob_horizontal_amplitude * amplitude_scale
		target_offset.y = sin(head_bob_phase * 2.0) * head_bob_vertical_amplitude * amplitude_scale
	else:
		head_bob_phase = 0.0

	var target_position := camera_rest_position + target_offset
	var blend_weight := 1.0 - exp(-head_bob_smoothing * delta)
	camera.position = camera.position.lerp(target_position, blend_weight)
