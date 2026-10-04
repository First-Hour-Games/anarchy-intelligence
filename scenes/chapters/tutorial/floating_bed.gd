class_name FloatingBed
extends Node3D

## Tweens a node up and down continuously to give it a gentle, eerie floating effect.

@export_group("Floating Effect")
## Whether floating is active.
@export var float_enabled: bool = true
## Distance in meters the bed moves above and below its base resting Y position.
@export_range(0.01, 1.0, 0.01) var float_amplitude: float = 0.12
## Time in seconds to travel one way between the lowest and highest positions.
@export_range(0.5, 10.0, 0.1) var float_duration: float = 2.4

var _base_y: float = 0.0
var _is_base_y_set: bool = false
var _float_tween: Tween


func _ready() -> void:
	if not _is_base_y_set:
		_base_y = position.y
		_is_base_y_set = true
	if float_enabled:
		start_floating()


func start_floating() -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()

	var half_duration := float_duration * 0.5
	_float_tween = create_tween().set_loops()
	_float_tween.set_trans(Tween.TRANS_SINE)
	_float_tween.set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_property(self, "position:y", _base_y + float_amplitude, half_duration)
	_float_tween.tween_property(self, "position:y", _base_y - float_amplitude, float_duration)
	_float_tween.tween_property(self, "position:y", _base_y, half_duration)


func stop_floating(reset_to_base: bool = false) -> void:
	if _float_tween and _float_tween.is_valid():
		_float_tween.kill()
	if reset_to_base and _is_base_y_set:
		position.y = _base_y


func is_floating() -> bool:
	return _float_tween != null and _float_tween.is_valid() and _float_tween.is_running()


func get_base_y() -> float:
	return _base_y


func set_base_y(new_y: float) -> void:
	_base_y = new_y
	_is_base_y_set = true
	if is_floating():
		start_floating()
	else:
		position.y = new_y
