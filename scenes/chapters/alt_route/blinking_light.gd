extends OmniLight3D
## A hazard light left blinking on an abandoned car: on for part of each period, off for the rest, starting
## at a random point so the cars on a road do not blink together.

@export_range(0.2, 4.0, 0.05, "suffix:s") var period: float = 1.0
@export_range(0.05, 0.95, 0.05) var duty: float = 0.5

var _energy: float
var _time := 0.0


func _ready() -> void:
	_energy = light_energy
	_time = randf() * period


func _process(delta: float) -> void:
	_time = fmod(_time + delta, period)
	light_energy = _energy if _time < period * duty else 0.0
