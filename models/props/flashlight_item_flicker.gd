extends Node3D
## One failing electrical source drives the beam, nearby spill light, and lens glow.

@export var interval_range := Vector2(2.0, 7.0)
@export var burst_duration_range := Vector2(0.25, 1.8)
@export var short_outage_range := Vector2(0.025, 0.12)
@export var long_outage_range := Vector2(0.3, 1.1)
@export_range(0.0, 1.0) var long_outage_chance: float = 0.2

@onready var _spot := $SpotLight3D as SpotLight3D
@onready var _omni := $OmniLight3D as OmniLight3D
@onready var _lens := $Flashlight_Body/Flashlight_Lens as MeshInstance3D

var _rng := RandomNumberGenerator.new()
var _spot_energy: float
var _omni_energy: float
var _lens_material: BaseMaterial3D
var _lens_off_material: StandardMaterial3D
var _lens_energy: float
var _remaining: float = 0.0
var _burst_remaining: float = 0.0
var _is_dip: bool = false


func _ready() -> void:
	_rng.randomize()
	_spot_energy = _spot.light_energy
	_omni_energy = _omni.light_energy
	var material := _lens.get_active_material(0) as BaseMaterial3D
	if material != null:
		# Keep the held flashlight and pickup/inventory previews at their authored glow.
		_lens_material = material.duplicate() as BaseMaterial3D
		_lens.material_override = _lens_material
		_lens_energy = _lens_material.emission_energy_multiplier
		# A dark emitter alone still has a white, reflective surface. Use an
		# unlit black material during a complete outage so the lens goes black too.
		_lens_off_material = StandardMaterial3D.new()
		_lens_off_material.albedo_color = Color.BLACK
		_lens_off_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_lens_off_material.cull_mode = _lens_material.cull_mode
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
	if _lens_material != null:
		_lens_material.emission_energy_multiplier = _lens_energy * multiplier
		_lens.material_override = _lens_off_material if multiplier <= 0.0 else _lens_material


func _random_duration(duration_range: Vector2) -> float:
	return maxf(0.001, _rng.randf_range(
		minf(duration_range.x, duration_range.y),
		maxf(duration_range.x, duration_range.y)
	))
