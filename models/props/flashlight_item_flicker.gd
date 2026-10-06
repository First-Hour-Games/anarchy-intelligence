extends Node3D
## One failing electrical source drives both the beam and nearby spill light.

@export var interval_range := Vector2(2.0, 7.0)
@export var burst_duration_range := Vector2(0.25, 1.8)
@export var short_outage_range := Vector2(0.025, 0.12)
@export var long_outage_range := Vector2(0.3, 1.1)
@export_range(0.0, 1.0) var long_outage_chance: float = 0.2

@onready var _spot := $SpotLight3D as SpotLight3D
@onready var _omni := $OmniLight3D as OmniLight3D

var _rng := RandomNumberGenerator.new()
var _spot_energy: float
var _omni_energy: float
var _remaining: float = 0.0
var _burst_remaining: float = 0.0
var _is_dip: bool = false


func _ready() -> void:
	_rng.randomize()
	_spot_energy = _spot.light_energy
	_omni_energy = _omni.light_energy
	_remaining = _random_duration(interval_range)


func _process(delta: float) -> void:
	_remaining -= delta
	_burst_remaining = maxf(0.0, _burst_remaining - delta)
	if _remaining > 0.0:
		return

	if _is_dip:
		# Brief recoveries between failures make irregular clusters of stutters.
		_set_output(1.0)
		_is_dip = false
		if _burst_remaining > 0.0:
			_remaining = _rng.randf_range(0.035, 0.22)
		else:
			_remaining = _random_duration(interval_range)
		return

	if _burst_remaining <= 0.0:
		_burst_remaining = _random_duration(burst_duration_range)
	_is_dip = true
	# Some failures go completely dark; others leave a weak, unstable glow.
	_set_output(0.0 if _rng.randf() < 0.65 else _rng.randf_range(0.04, 0.3))
	_remaining = _random_duration(
		long_outage_range if _rng.randf() < long_outage_chance else short_outage_range
	)


func _set_output(multiplier: float) -> void:
	_spot.light_energy = _spot_energy * multiplier
	_omni.light_energy = _omni_energy * multiplier


func _random_duration(duration_range: Vector2) -> float:
	return maxf(0.001, _rng.randf_range(
		minf(duration_range.x, duration_range.y),
		maxf(duration_range.x, duration_range.y)
	))
