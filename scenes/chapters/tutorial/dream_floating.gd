extends Node3D

## Gentle wandering around the authored position, with independent timing per prop.
@export_range(0.01, 1.0, 0.01) var vertical_amplitude := 0.12
@export_range(0.0, 0.2, 0.005) var sideways_amplitude := 0.035
@export_range(0.5, 10.0, 0.1) var minimum_duration := 2.4
@export_range(0.5, 10.0, 0.1) var maximum_duration := 4.5

var _base_position: Vector3
var _direction := 1.0
var _random := RandomNumberGenerator.new()
var _float_tween: Tween


func _ready() -> void:
	_base_position = position
	_random.randomize()
	_direction = -1.0 if _random.randf() < 0.5 else 1.0
	_float_to_next_position()


func _float_to_next_position() -> void:
	var offset := Vector3.ZERO
	offset.y = _direction * _random.randf_range(vertical_amplitude * 0.45, vertical_amplitude)
	# Some turns drift sideways; others gently return toward the resting center.
	if _random.randf() < 0.65:
		offset.x = _random.randf_range(-sideways_amplitude, sideways_amplitude)
	_direction *= -1.0
	_float_tween = create_tween()
	_float_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position", _base_position + offset,
		_random.randf_range(minimum_duration, maxf(minimum_duration, maximum_duration)))
	_float_tween.tween_callback(_float_to_next_position)
