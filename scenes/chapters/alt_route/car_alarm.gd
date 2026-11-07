class_name CarAlarm
extends Node3D
## The alarm of a car in the alt route's downtown jam (rooftop_street.gd) set off by a Ridgeback landing on
## it: the siren looping (sounds/props/car_alarm) and the indicators blinking orange at its four corners
## for `seconds`, then quiet. sound() starts it again on a car already wailing.

const ALARM: AudioStream = preload("res://sounds/props/car_alarm/car_alarm_loop.wav")
const BLINK := 0.5
const INDICATOR := Color(1.0, 0.55, 0.12)

var seconds := 24.0
var _left := 0.0
var _blink := 0.0
var _siren: AudioStreamPlayer3D
var _lights: Array[OmniLight3D] = []


## Puts an alarm on a car whose footprint has these half extents along its own x and z.
static func fit(car: Node3D, half: Vector2, height: float) -> CarAlarm:
	var alarm := CarAlarm.new()
	alarm.name = "CarAlarm"
	car.add_child(alarm)
	alarm._build(half, height)
	return alarm


func _build(half: Vector2, height: float) -> void:
	_siren = AudioStreamPlayer3D.new()
	_siren.stream = ALARM
	_siren.volume_db = 1.0
	_siren.unit_size = 9.0
	_siren.max_distance = 90.0
	_siren.position = Vector3(0.0, height * 0.4, 0.0)
	add_child(_siren)
	for corner: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
		var light := OmniLight3D.new()
		light.light_color = INDICATOR
		light.light_energy = 0.0
		light.omni_range = 3.2
		light.shadow_enabled = false
		light.position = Vector3(corner.x * half.x * 0.9, height * 0.45, corner.y * half.y * 0.95) / global_basis.get_scale()
		add_child(light)
		_lights.append(light)
	set_process(false)


func sound() -> void:
	_left = seconds
	_blink = 0.0
	if not _siren.playing:
		_siren.play()
	set_process(true)


func silence() -> void:
	_left = 0.0
	_siren.stop()
	for light in _lights:
		light.light_energy = 0.0
	set_process(false)


func is_sounding() -> bool:
	return _left > 0.0


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		silence()
		return
	_blink += delta
	var on := fmod(_blink, BLINK * 2.0) < BLINK
	for light in _lights:
		light.light_energy = 2.2 if on else 0.0
