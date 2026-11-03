extends Node3D

## Flickers neon lettering: every Label3D and Light3D under this node, together, like a tube on a
## failing transformer. Mostly steady, with short dips. neon_sign.gd does the same for sign meshes.

@export var flicker_enabled := true
@export_range(0.05, 1.0, 0.01) var minimum_brightness := 0.45
@export_range(0.01, 1.0, 0.01) var flicker_interval_min := 0.05
@export_range(0.01, 2.0, 0.01) var flicker_interval_max := 1.4
@export_range(1.0, 80.0, 1.0) var flicker_response := 30.0

var _rng := RandomNumberGenerator.new()
var _labels: Array[Label3D] = []
var _label_colours: Array[Color] = []
var _lights: Array[Light3D] = []
var _light_energy: Array[float] = []
var _time_left := 0.0
var _target := 1.0
var _brightness := 1.0


func _ready() -> void:
	_rng.randomize()
	for node in find_children("*", "Label3D", true, false):
		_labels.append(node as Label3D)
		_label_colours.append((node as Label3D).modulate)
	for node in find_children("*", "Light3D", true, false):
		_lights.append(node as Light3D)
		_light_energy.append((node as Light3D).light_energy)
	_time_left = _rng.randf_range(flicker_interval_min, flicker_interval_max)


func _process(delta: float) -> void:
	if not flicker_enabled:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_target = _rng.randf_range(minimum_brightness, 0.8) if _rng.randf() < 0.3 else 1.0
		_time_left = _rng.randf_range(flicker_interval_min, flicker_interval_max)
	_brightness = lerpf(_brightness, _target, 1.0 - exp(-flicker_response * delta))
	for i in _labels.size():
		var colour := _label_colours[i]
		_labels[i].modulate = Color(colour.r * _brightness, colour.g * _brightness, colour.b * _brightness, colour.a)
	for i in _lights.size():
		_lights[i].light_energy = _light_energy[i] * _brightness
