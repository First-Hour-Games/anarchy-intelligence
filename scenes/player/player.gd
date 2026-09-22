class_name FirstPersonPlayer extends CharacterBody3D

## A small, reusable first-person controller for testing level scale and movement feel.
## One Godot unit is treated as roughly one metre.

signal stamina_changed(current: float, maximum: float)

const WOOD_FOOTSTEPS := [
	preload("res://sounds/footsteps/wood/woodFootsteps1.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps2.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps3.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps4.ogg"),
	preload("res://sounds/footsteps/wood/woodFootsteps5.ogg"),
]
const FOOTSTEP_PHASE_OFFSET := PI * 0.75
const FOOTSTEP_PHASE_INTERVAL := PI

@export_category("Movement")
@export var walk_speed: float = 3.2
@export var sprint_speed: float = 4.8
@export var ground_acceleration: float = 13.0
@export var ground_deceleration: float = 17.0
@export var air_acceleration: float = 3.0

@export_category("Stamina")
@export_range(1.0, 500.0, 1.0) var max_stamina: float = 100.0
@export_range(1.0, 100.0, 1.0) var sprint_stamina_cost: float = 24.0
@export_range(1.0, 100.0, 1.0) var stamina_regeneration_rate: float = 18.0
@export_range(0.0, 5.0, 0.1) var stamina_regeneration_delay: float = 0.8
@export_range(0.0, 100.0, 1.0) var exhausted_recovery_stamina: float = 20.0

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

@export_category("Footsteps")
@export_range(-40.0, 6.0, 0.5) var footstep_volume_db: float = -13.0
@export_range(0.5, 1.5, 0.01) var footstep_pitch_min: float = 0.96
@export_range(0.5, 1.5, 0.01) var footstep_pitch_max: float = 1.04

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: ShapeCast3D = $CeilingCheck
@onready var interaction_detector: InteractionDetector = $InteractionDetector
@onready var footstep_players: Array[AudioStreamPlayer] = [$FootstepPlayerA, $FootstepPlayerB]

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var head_bob_phase: float = 0.0
var camera_rest_position: Vector3
var stamina: float = 100.0
var is_sprinting: bool = false

var capsule_shape: CapsuleShape3D
var stand_capsule_height: float
var stand_collision_y: float
var stand_head_y: float
var crouch_capsule_height: float
var crouch_collision_y: float
var crouch_head_y: float
var is_crouching: bool = false
var _stamina_regeneration_cooldown: float = 0.0
var _sprint_exhausted: bool = false
var _footstep_random := RandomNumberGenerator.new()
var _last_footstep_index: int = -1
var _footstep_player_index: int = 0
var is_frozen: bool = false


func _ready() -> void:
	_footstep_random.randomize()
	stamina = max_stamina
	stamina_changed.emit(stamina, max_stamina)
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


func freeze() -> void:
	is_frozen = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	set_process_unhandled_input(false)
	for footstep_player in footstep_players:
		if is_instance_valid(footstep_player) and footstep_player.playing:
			footstep_player.stop()
	if is_instance_valid(interaction_detector):
		interaction_detector.set_process(false)
		var viewmodel: HandViewmodel = get_node_or_null("HandViewmodel") as HandViewmodel
		if is_instance_valid(viewmodel):
			viewmodel.set_interaction_prompt(false)


func unfreeze() -> void:
	is_frozen = false
	set_physics_process(true)
	set_process_unhandled_input(true)
	if is_instance_valid(interaction_detector):
		interaction_detector.set_process(true)


func _unhandled_input(event: InputEvent) -> void:
	if is_frozen:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if interaction_detector.try_interact():
			get_viewport().set_input_as_handled()
			return

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
	if is_frozen:
		return

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
	var wants_to_sprint := Input.is_key_pressed(KEY_SHIFT) and input_vector.y < 0.0 and not is_crouching
	_update_stamina(delta, wants_to_sprint)
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


func _update_stamina(delta: float, wants_to_sprint: bool) -> void:
	var previous_stamina := stamina

	if _sprint_exhausted and stamina >= minf(exhausted_recovery_stamina, max_stamina):
		_sprint_exhausted = false

	is_sprinting = wants_to_sprint and not _sprint_exhausted and stamina > 0.0
	if is_sprinting:
		stamina = maxf(0.0, stamina - sprint_stamina_cost * delta)
		_stamina_regeneration_cooldown = stamina_regeneration_delay
		if stamina <= 0.0:
			_sprint_exhausted = true
			is_sprinting = false
	else:
		var regeneration_time := maxf(0.0, delta - _stamina_regeneration_cooldown)
		_stamina_regeneration_cooldown = maxf(0.0, _stamina_regeneration_cooldown - delta)
		if regeneration_time > 0.0:
			stamina = minf(max_stamina, stamina + stamina_regeneration_rate * regeneration_time)

	if not is_equal_approx(previous_stamina, stamina):
		stamina_changed.emit(stamina, max_stamina)


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
		var previous_bob_phase := head_bob_phase
		head_bob_phase += delta * head_bob_frequency * TAU * speed_ratio
		_play_footstep_for_phase_crossing(previous_bob_phase, head_bob_phase)
		var amplitude_scale: float = clampf(speed_ratio, 0.65, 1.5)
		target_offset.x = cos(head_bob_phase) * head_bob_horizontal_amplitude * amplitude_scale
		target_offset.y = sin(head_bob_phase * 2.0) * head_bob_vertical_amplitude * amplitude_scale
	else:
		head_bob_phase = 0.0

	var target_position := camera_rest_position + target_offset
	var blend_weight := 1.0 - exp(-head_bob_smoothing * delta)
	camera.position = camera.position.lerp(target_position, blend_weight)


func _play_footstep_for_phase_crossing(previous_phase: float, current_phase: float) -> void:
	var previous_step := floori((previous_phase - FOOTSTEP_PHASE_OFFSET) / FOOTSTEP_PHASE_INTERVAL)
	var current_step := floori((current_phase - FOOTSTEP_PHASE_OFFSET) / FOOTSTEP_PHASE_INTERVAL)
	if current_step > previous_step:
		_play_random_wood_footstep()


func _play_random_wood_footstep() -> void:
	if WOOD_FOOTSTEPS.is_empty() or footstep_players.is_empty():
		return

	var sound_index := _footstep_random.randi_range(0, WOOD_FOOTSTEPS.size() - 1)
	if WOOD_FOOTSTEPS.size() > 1 and sound_index == _last_footstep_index:
		sound_index = (sound_index + _footstep_random.randi_range(1, WOOD_FOOTSTEPS.size() - 1)) % WOOD_FOOTSTEPS.size()
	_last_footstep_index = sound_index

	var footstep_player := footstep_players[_footstep_player_index]
	_footstep_player_index = (_footstep_player_index + 1) % footstep_players.size()
	footstep_player.stream = WOOD_FOOTSTEPS[sound_index]
	footstep_player.volume_db = footstep_volume_db
	footstep_player.pitch_scale = _footstep_random.randf_range(
		minf(footstep_pitch_min, footstep_pitch_max),
		maxf(footstep_pitch_min, footstep_pitch_max)
	)
	footstep_player.play()
