class_name FlickerLight
extends SpotLight3D

## Flickers a light randomly on and off with configurable steady intervals and rapid burst flickers.

@export var flicker_enabled: bool = true

@export_group("Steady Durations")
## Minimum duration in seconds the light stays ON during a steady interval.
@export_range(0.01, 10.0, 0.01) var min_on_time: float = 0.2
## Maximum duration in seconds the light stays ON during a steady interval.
@export_range(0.01, 10.0, 0.01) var max_on_time: float = 2.5
## Minimum duration in seconds the light stays OFF during a normal off interval.
@export_range(0.01, 5.0, 0.01) var min_off_time: float = 0.04
## Maximum duration in seconds the light stays OFF during a normal off interval.
@export_range(0.01, 5.0, 0.01) var max_off_time: float = 0.45

@export_group("Burst Flicker")
## Probability (0 to 1) that transitioning triggers a rapid multi-blink burst instead of a single off period.
@export_range(0.0, 1.0, 0.05) var burst_chance: float = 0.45
## Minimum duration in seconds the light stays ON between burst flickers.
@export_range(0.01, 0.5, 0.01) var burst_on_time_min: float = 0.02
## Maximum duration in seconds the light stays ON between burst flickers.
@export_range(0.01, 0.5, 0.01) var burst_on_time_max: float = 0.08
## Minimum duration in seconds the light stays OFF during a burst flicker.
@export_range(0.01, 0.5, 0.01) var burst_off_time_min: float = 0.02
## Maximum duration in seconds the light stays OFF during a burst flicker.
@export_range(0.01, 0.5, 0.01) var burst_off_time_max: float = 0.1
## Minimum number of rapid blinks in a burst.
@export_range(1, 10, 1) var burst_count_min: int = 2
## Maximum number of rapid blinks in a burst.
@export_range(1, 10, 1) var burst_count_max: int = 5

@export_group("Mesh Sync")
## If enabled, attempts to find and toggle emission on the parent bulb's mesh material.
@export var sync_bulb_emission: bool = true

var _base_energy: float = 1.0
var _base_emission_energy: float = 1.0
var _is_on: bool = true
var _time_left: float = 0.0
var _burst_count: int = 0
var _bulb_material: StandardMaterial3D = null


func _ready() -> void:
	_base_energy = light_energy
	_setup_bulb_material()
	_set_light_state(true)
	_time_left = randf_range(min_on_time, max_on_time)


func _process(delta: float) -> void:
	if not flicker_enabled:
		if not _is_on:
			_set_light_state(true)
		return

	_time_left -= delta
	if _time_left <= 0.0:
		_advance_flicker()


func _setup_bulb_material() -> void:
	if not sync_bulb_emission:
		return

	var parent_node := get_parent()
	if not is_instance_valid(parent_node):
		return

	var mesh_node := parent_node.find_child("defaultMaterial", true, false) as MeshInstance3D
	if not is_instance_valid(mesh_node):
		return

	var active_mat := mesh_node.get_active_material(0)
	if active_mat is StandardMaterial3D:
		_bulb_material = active_mat.duplicate() as StandardMaterial3D
		_base_emission_energy = _bulb_material.emission_energy_multiplier
		mesh_node.set_surface_override_material(0, _bulb_material)


func _advance_flicker() -> void:
	if _is_on:
		_set_light_state(false)
		if _burst_count > 0:
			_time_left = randf_range(burst_off_time_min, burst_off_time_max)
		else:
			_time_left = randf_range(min_off_time, max_off_time)
	else:
		_set_light_state(true)
		if _burst_count > 0:
			_burst_count -= 1
			_time_left = randf_range(burst_on_time_min, burst_on_time_max)
		else:
			if randf() < burst_chance:
				_burst_count = randi_range(burst_count_min, burst_count_max)
			_time_left = randf_range(min_on_time, max_on_time)


func _set_light_state(on: bool) -> void:
	_is_on = on
	visible = on
	light_energy = _base_energy if on else 0.0
	if is_instance_valid(_bulb_material):
		_bulb_material.emission_energy_multiplier = _base_emission_energy if on else 0.0


func set_flicker_enabled(enabled: bool) -> void:
	flicker_enabled = enabled
	if not flicker_enabled:
		_burst_count = 0
		_set_light_state(true)


func is_light_on() -> bool:
	return _is_on
