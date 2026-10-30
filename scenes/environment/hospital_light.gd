extends OmniLight3D

## A hospital fixture on emergency power: steady, a failing tube, TV static or a red
## emergency pulse. Spawned by story_building.gd from the hospital markers.

enum Mode { STEADY, FLICKER, STROBE, DYING, NOISE, PULSE }

@export var mode: Mode = Mode.STEADY

var _base_energy := 1.0
var _time_left := 0.0
var _burst := 0
var _clock := 0.0


func _ready() -> void:
	_base_energy = light_energy
	_time_left = randf_range(0.2, 2.0)
	if mode == Mode.STROBE or mode == Mode.DYING:
		light_energy = 0.0


func _process(delta: float) -> void:
	_clock += delta
	match mode:
		Mode.STEADY:
			return
		Mode.NOISE:
			light_energy = _base_energy * randf_range(0.35, 1.0)
		Mode.PULSE:
			light_energy = _base_energy * (0.55 + 0.45 * sin(_clock * TAU * 0.5))
		_:
			_time_left -= delta
			if _time_left <= 0.0:
				_step()


func _step() -> void:
	var lit := light_energy > 0.0
	match mode:
		Mode.FLICKER:
			# Mostly on, with short dropouts.
			_time_left = randf_range(0.05, 0.4) if lit else randf_range(0.3, 2.0)
			lit = not lit
		Mode.STROBE:
			# Dark for seconds, then two to four fast flashes.
			if _burst == 0 and not lit:
				_burst = randi_range(2, 4)
			if lit:
				_burst -= 1
				_time_left = randf_range(3.0, 6.0) if _burst == 0 else randf_range(0.05, 0.15)
			else:
				_time_left = randf_range(0.05, 0.12)
			lit = not lit
		Mode.DYING:
			# Long dark gaps broken by a brief flash.
			_time_left = randf_range(1.0, 3.0) if lit else randf_range(0.05, 0.25)
			lit = not lit
	light_energy = _base_energy if lit else 0.0
