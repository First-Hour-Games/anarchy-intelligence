class_name PlayerFlashlight
extends Node3D

## Camera-mounted flashlight with weighted rotational follow shared by the beam and
## held model, plus independent hand bob and small look impulses.

signal toggled(is_on: bool)

@export_category("Presentation")
@export var show_held_model: bool = false
@export var held_position: Vector3 = Vector3(0.31, -0.24, -0.58)
@export var lowered_position: Vector3 = Vector3(0.34, -0.52, -0.43)
@export var held_rotation_degrees: Vector3 = Vector3(-6.0, -8.0, -8.0)
@export var raise_speed: float = 13.0

@export_category("Camera Follow")
@export var rotation_follow_enabled: bool = true
## Higher values catch up faster. Exponential smoothing remains stable across frame rates.
@export_range(1.0, 30.0, 0.5) var rotation_follow_speed: float = 9.0
## Limits how far the beam can trail a fast camera turn.
@export_range(0.0, 45.0, 0.5) var max_rotation_lag_degrees: float = 14.0
## Reset after teleports instead of sweeping the beam through the world.
@export_range(0.1, 20.0, 0.1) var follow_teleport_distance: float = 3.0

@export_category("Held Motion")
@export var movement_bob: Vector2 = Vector2(0.012, 0.015)
@export var movement_bob_frequency: float = 1.9
@export var look_lag_strength: float = 0.00045
@export var look_lag_limit: float = 0.025
@export var look_lag_return_speed: float = 10.0

@onready var model_pivot: Node3D = $ModelPivot
@onready var beam: SpotLight3D = $Beam
@onready var spill: OmniLight3D = $Spill
@onready var player: CharacterBody3D = get_node_or_null("../../..") as CharacterBody3D

var _is_on: bool = false
var _presentation: float = 0.0
var _movement_phase: float = 0.0
var _look_lag := Vector2.ZERO
var _follow_rotation := Quaternion.IDENTITY
var _rest_rotation := Quaternion.IDENTITY
var _previous_camera_position := Vector3.ZERO
var _previous_camera_top_level: bool = false


func _ready() -> void:
	_rest_rotation = quaternion
	_reset_camera_follow()
	beam.visible = false
	spill.visible = false
	model_pivot.visible = false
	model_pivot.position = lowered_position
	model_pivot.rotation_degrees = held_rotation_degrees + Vector3(16.0, 0.0, 0.0)
	for geometry in model_pivot.find_children("*", "GeometryInstance3D", true, false):
		var geometry_instance := geometry as GeometryInstance3D
		geometry_instance.layers = 2
		geometry_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func toggle() -> void:
	set_enabled(not _is_on)


func set_enabled(should_enable: bool) -> void:
	if should_enable == _is_on:
		return
	_is_on = should_enable
	beam.visible = should_enable
	spill.visible = should_enable
	if should_enable:
		_reset_camera_follow()
		model_pivot.visible = show_held_model
	toggled.emit(_is_on)


func is_enabled() -> bool:
	return _is_on


func add_look_impulse(relative_motion: Vector2) -> void:
	_look_lag -= relative_motion * look_lag_strength
	_look_lag.x = clampf(_look_lag.x, -look_lag_limit, look_lag_limit)
	_look_lag.y = clampf(_look_lag.y, -look_lag_limit, look_lag_limit)


func _process(delta: float) -> void:
	_update_camera_follow(delta)
	var target_presentation := 1.0 if _is_on else 0.0
	var presentation_weight := 1.0 - exp(-raise_speed * delta)
	_presentation = lerpf(_presentation, target_presentation, presentation_weight)

	var return_weight := 1.0 - exp(-look_lag_return_speed * delta)
	_look_lag = _look_lag.lerp(Vector2.ZERO, return_weight)

	var bob := Vector3.ZERO
	var target_roll := 0.0
	if is_instance_valid(player):
		var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
		if player.is_on_floor() and horizontal_speed > 0.1:
			var speed_ratio := clampf(horizontal_speed / 3.2, 0.5, 1.8)
			_movement_phase += delta * movement_bob_frequency * TAU * speed_ratio
			bob.x = sin(_movement_phase) * movement_bob.x * speed_ratio
			bob.y = -abs(cos(_movement_phase)) * movement_bob.y * speed_ratio
			target_roll = sin(_movement_phase) * 1.2 * speed_ratio

	var base_position := lowered_position.lerp(held_position, _presentation)
	var look_offset := Vector3(_look_lag.x, _look_lag.y, 0.0)
	model_pivot.position = base_position + bob + look_offset
	var lowered_rotation := held_rotation_degrees + Vector3(16.0, 0.0, 0.0)
	var target_rotation := lowered_rotation.lerp(held_rotation_degrees, _presentation)
	target_rotation.z += target_roll + _look_lag.x * 80.0
	target_rotation.x += _look_lag.y * 55.0
	model_pivot.rotation_degrees = target_rotation

	if not show_held_model or (not _is_on and _presentation < 0.01):
		model_pivot.visible = false


func _reset_camera_follow() -> void:
	var camera := get_parent() as Node3D
	if camera == null:
		return
	_follow_rotation = camera.global_basis.orthonormalized().get_rotation_quaternion() * _rest_rotation
	_previous_camera_position = camera.global_position
	_previous_camera_top_level = camera.top_level
	quaternion = _rest_rotation


func _update_camera_follow(delta: float) -> void:
	var camera := get_parent() as Node3D
	if camera == null:
		return
	if not rotation_follow_enabled or not _is_on \
			or camera.global_position.distance_to(_previous_camera_position) > follow_teleport_distance \
			or camera.top_level != _previous_camera_top_level:
		_reset_camera_follow()
		return
	var camera_rotation := camera.global_basis.orthonormalized().get_rotation_quaternion()
	var target := camera_rotation * _rest_rotation
	var angle := _follow_rotation.angle_to(target)
	var max_angle := deg_to_rad(max_rotation_lag_degrees)
	if angle > max_angle and angle > 0.00001:
		_follow_rotation = _follow_rotation.slerp(target, 1.0 - max_angle / angle).normalized()
	var weight := 1.0 - exp(-rotation_follow_speed * maxf(delta, 0.0))
	_follow_rotation = _follow_rotation.slerp(target, weight).normalized()
	# Counteract the camera parent's instant turn, then let the shared root catch up.
	quaternion = (camera_rotation.inverse() * _follow_rotation).normalized()
	_previous_camera_position = camera.global_position
	_previous_camera_top_level = camera.top_level
