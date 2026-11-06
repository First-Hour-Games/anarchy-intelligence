extends Node
## Each streetlight independently starts off, dim, or with an intermittent fault.

enum State { OFF, DIM, FLICKER }

var state: State
var _random := RandomNumberGenerator.new()
var _light: Light3D
var _base_energy: float
var _remaining: float = 0.0


static func attach(light: Light3D) -> void:
	if Engine.is_editor_hint() or not light.visible or light.light_energy <= 0.0:
		return
	light.add_child(load("res://scenes/environment/streetlight_fault.gd").new())


func _ready() -> void:
	_light = get_parent() as Light3D
	_base_energy = _light.light_energy
	_random.randomize()
	state = _random.randi_range(State.OFF, State.FLICKER) as State
	if state == State.OFF:
		_light.light_energy = 0.0
	elif state == State.DIM:
		_light.light_energy = _base_energy * _random.randf_range(0.15, 0.45)
	set_process(state == State.FLICKER)
	if state == State.FLICKER:
		_process(0.0)


func _process(delta: float) -> void:
	_remaining -= delta
	if _remaining > 0.0:
		return
	_light.light_energy = 0.0 if _random.randf() < 0.4 else _base_energy * _random.randf_range(0.15, 0.65)
	_remaining = _random.randf_range(1.0, 3.0) if _random.randf() < 0.25 else _random.randf_range(0.06, 0.25)
