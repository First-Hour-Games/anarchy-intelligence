class_name PlayerFlashlight
extends Node3D

## Camera-mounted flashlight presentation. The beam follows the camera while the
## held model has a small amount of independent weight, bob, and look lag.

signal toggled(is_on: bool)

@export_category("Presentation")
@export var held_position: Vector3 = Vector3(0.23, -0.20, -0.42)
@export var lowered_position: Vector3 = Vector3(0.34, -0.52, -0.43)
@export var held_rotation_degrees: Vector3 = Vector3(-8.0, -14.0, -8.0)
@export var raise_speed: float = 13.0

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


func _ready() -> void:
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
		model_pivot.visible = true
	toggled.emit(_is_on)


func is_enabled() -> bool:
	return _is_on


func add_look_impulse(relative_motion: Vector2) -> void:
	_look_lag -= relative_motion * look_lag_strength
	_look_lag.x = clampf(_look_lag.x, -look_lag_limit, look_lag_limit)
	_look_lag.y = clampf(_look_lag.y, -look_lag_limit, look_lag_limit)


func _process(delta: float) -> void:
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
	# Start the beam at the supplied model's lens while keeping camera aim stable.
	beam.position = model_pivot.transform * Vector3(0, 0, -0.123)
	spill.position = beam.position

	if not _is_on and _presentation < 0.01:
		model_pivot.visible = false
