extends Node3D

## The downtown's traffic signal, left flashing when the town emptied: amber toward the Connector
## road and red toward the Crossroad, on and off together, with a little light on the street.

@export var lenses: Array[NodePath] = []
@export var glow: NodePath
@export_range(0.2, 3.0, 0.05) var period := 1.1
@export_range(0.0, 4.0, 0.05) var glow_energy := 1.2

var _time := 0.0


func _process(delta: float) -> void:
	_time = fmod(_time + delta, period)
	var on := _time < period * 0.5
	for path in lenses:
		var lens := get_node_or_null(path) as Node3D
		if lens != null:
			lens.visible = on
	var light := get_node_or_null(glow) as Light3D
	if light != null:
		light.light_energy = glow_energy if on else 0.0
