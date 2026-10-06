extends MeshInstance3D

@export var flicker_enabled := true
@export_range(0.05, 1.0, 0.01) var minimum_brightness := 0.6
@export_range(1.0, 2.0, 0.01) var maximum_brightness := 1.08
@export_range(0.01, 1.0, 0.01) var flicker_interval_min := 0.04
@export_range(0.01, 1.0, 0.01) var flicker_interval_max := 0.18
@export_range(1.0, 80.0, 1.0) var flicker_response := 35.0

var _rng := RandomNumberGenerator.new()
var _materials: Array[StandardMaterial3D] = []
var _base_emission: Array[float] = []
var _lights: Array[Light3D] = []
var _base_light_energy: Array[float] = []
var _time_left := 0.0
var _target_brightness := 1.0
var _brightness := 1.0


func _ready() -> void:
	_rng.randomize()
	_collect_glow(self, {})
	_time_left = _rng.randf_range(flicker_interval_min, flicker_interval_max)
	var audio := get_node_or_null("NeonAmbience") as AudioStreamPlayer3D
	if audio != null and audio.stream is AudioStreamMP3:
		# Loop only this sign's stream, without changing the imported audio resource.
		var loop_stream := audio.stream.duplicate() as AudioStreamMP3
		loop_stream.loop = true
		audio.stream = loop_stream
		audio.play(_rng.randf_range(0.0, maxf(loop_stream.get_length(), 0.001)))


func _collect_glow(node: Node, copies: Dictionary) -> void:
	if node is MeshInstance3D:
		var source := node.material_override as StandardMaterial3D
		if source != null and source.emission_enabled:
			if not copies.has(source):
				var local := source.duplicate() as StandardMaterial3D
				copies[source] = local
				_materials.append(local)
				_base_emission.append(local.emission_energy_multiplier)
			node.material_override = copies[source]
	if node is Light3D:
		_lights.append(node)
		_base_light_energy.append(node.light_energy)
	for child in node.get_children():
		_collect_glow(child, copies)


func _process(delta: float) -> void:
	if not flicker_enabled:
		_brightness = 1.0
		_target_brightness = 1.0
		_apply_brightness()
		return
	_time_left -= delta
	if _time_left <= 0.0:
		var low := clampf(minimum_brightness, 0.05, 1.0)
		var high := maxf(maximum_brightness, 1.0)
		# Mostly steady light, punctuated by short dips and recoveries.
		if _rng.randf() < 0.35 and low < 0.9:
			_target_brightness = _rng.randf_range(low, 0.9)
		else:
			_target_brightness = _rng.randf_range(maxf(low, 0.9), high)
		_time_left = _rng.randf_range(maxf(flicker_interval_min, 0.01), maxf(flicker_interval_max, flicker_interval_min))
	_brightness = lerpf(_brightness, _target_brightness, 1.0 - exp(-maxf(flicker_response, 1.0) * delta))
	_apply_brightness()


func _apply_brightness() -> void:
	for index in _materials.size():
		_materials[index].emission_energy_multiplier = _base_emission[index] * _brightness
	for index in _lights.size():
		_lights[index].light_energy = _base_light_energy[index] * _brightness
