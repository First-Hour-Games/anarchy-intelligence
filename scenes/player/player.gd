class_name FirstPersonPlayer extends CharacterBody3D

## A small, reusable first-person controller for testing level scale and movement feel.
## One Godot unit is treated as roughly one metre.

@export_category("Movement")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 4.8
@export var ground_acceleration: float = 13.0
@export var ground_deceleration: float = 17.0
@export var air_acceleration: float = 3.0

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

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var head_bob_phase: float = 0.0
var camera_rest_position: Vector3


func _ready() -> void:
	camera_rest_position = camera.position
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


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
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var input_vector: Vector2 = _get_movement_input()
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := (global_transform.basis * local_direction).normalized()
	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and input_vector.y < 0.0
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var target_velocity := world_direction * target_speed

	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	if world_direction.is_zero_approx() and is_on_floor():
		acceleration = ground_deceleration

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	move_and_slide()
	_update_head_bob(delta)


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
