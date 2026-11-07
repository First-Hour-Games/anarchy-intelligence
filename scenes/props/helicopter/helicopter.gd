class_name RescueHelicopter
extends Node3D
## The rescue helicopter waiting on the alt hospital's roof (models/props/helicopter/helicopter.glb, built by
## tools/blender/build_helicopter.py). Its rotors turn over while it waits, its beacons blink, and a light
## under its nose lights the pad. Once `can_board` is set, the open door offers "Board" and boarding emits
## `boarded`. fly_away() then carries the rider off: the rotors wind up, it lifts off the pad, climbs, turns and
## heads out over the town, and `departed` fires once it is well away. The rider sits on the back bench
## looking out of the open door, frozen in place, and rides with it.

signal boarded(rider: FirstPersonPlayer)
signal departed

## Rotor speed while waiting (1 is flying).
@export_range(0.0, 1.0, 0.05) var idle_rotor_speed: float = 0.35
## Seconds: winding up, lifting off, and flying away until `departed`.
@export var spin_up_time: float = 2.5
@export var lift_time: float = 3.0
@export var away_time: float = 9.0
## How high it lifts before it moves off, and how far up and away it flies.
@export var hover_height: float = 4.0
@export var away_climb: float = 24.0
@export var away_distance: float = 70.0

## Whether the door offers boarding.
var can_board: bool = false:
	set(value):
		can_board = value
		if _door != null:
			if value:
				_door.add_to_group(&"interactable")
			else:
				_door.remove_from_group(&"interactable")
var rotor_speed: float = 0.0
var flying: bool = false
var _main_rotor: Node3D
var _tail_rotor: Node3D
var _seat: Node3D
var _door: Interactable3D
var _beacons: Array[OmniLight3D] = []
var _rider: FirstPersonPlayer
var _eye_offset := Vector3.ZERO
var _flight_time: float = 0.0
var _pad := Transform3D.IDENTITY
var _time: float = 0.0
var _departed: bool = false


func _ready() -> void:
	var model := $Model as Node3D
	_main_rotor = model.find_child("MainRotor", true, false) as Node3D
	_tail_rotor = model.find_child("TailRotor", true, false) as Node3D
	_seat = model.find_child("PassengerSeat", true, false) as Node3D
	var board_point := model.find_child("BoardPoint", true, false) as Node3D
	rotor_speed = idle_rotor_speed
	for at: Vector3 in [Vector3(0.0, 3.1, 7.3), Vector3(0.0, 0.4, 0.5)]:
		var beacon := OmniLight3D.new()
		beacon.light_color = Color(1.0, 0.1, 0.06)
		beacon.omni_range = 7.0
		beacon.light_energy = 0.0
		add_child(beacon)
		beacon.position = at
		_beacons.append(beacon)
	var landing := SpotLight3D.new()
	landing.name = "LandingLight"
	landing.light_color = Color(1.0, 0.96, 0.85)
	landing.light_energy = 2.2
	landing.spot_range = 16.0
	landing.spot_angle = 32.0
	add_child(landing)
	landing.position = Vector3(0.0, 0.66, -2.45)
	landing.rotation = Vector3(deg_to_rad(-38.0), 0.0, 0.0)
	_door = Interactable3D.new()
	_door.name = "Door"
	_door.interaction_distance = 2.4
	_door.interaction_message = "Board"
	_door.visual_target_path = NodePath(".")
	add_child(_door)
	_door.position = Vector3(1.0, 1.2, 0.6) if board_point == null else (board_point.position + Vector3(-0.9, 1.2, 0.0))
	_door.interacted.connect(_on_board)
	can_board = false


func _process(delta: float) -> void:
	_time += delta
	if _main_rotor != null:
		_main_rotor.rotate_object_local(Vector3.UP, rotor_speed * 38.0 * delta)
	if _tail_rotor != null:
		_tail_rotor.rotate_object_local(Vector3.RIGHT, rotor_speed * 120.0 * delta)
	# The beacons flash once a second, out of step with each other.
	for index in _beacons.size():
		var phase := fposmod(_time + index * 0.5, 1.0)
		_beacons[index].light_energy = 2.4 if phase < 0.12 else 0.0
	if flying:
		_fly(delta)


func _on_board(interactor: Node3D) -> void:
	if not can_board or flying:
		return
	var player := interactor as FirstPersonPlayer
	if player == null:
		return
	can_board = false
	boarded.emit(player)


## Takes off with `rider` in the back. Call after `boarded` (the story decides when).
func fly_away(rider: FirstPersonPlayer) -> void:
	_rider = rider
	flying = true
	_flight_time = 0.0
	_pad = global_transform
	if _rider != null:
		_rider.freeze()
		_eye_offset = _rider.camera.global_position - _rider.global_position
		_place_rider()


func _fly(delta: float) -> void:
	_flight_time += delta
	var t := _flight_time
	rotor_speed = lerpf(idle_rotor_speed, 1.0, clampf(t / spin_up_time, 0.0, 1.0))
	var lift := clampf((t - spin_up_time) / lift_time, 0.0, 1.0)
	var away := clampf((t - spin_up_time - lift_time) / away_time, 0.0, 1.0)
	var eased_lift := lift * lift * (3.0 - 2.0 * lift)
	var eased_away := away * away
	# Up off the pad, nose down a little as it moves off, then away along its nose and climbing, turning.
	var forward := -_pad.basis.z
	var origin := _pad.origin + Vector3.UP * (hover_height * eased_lift + away_climb * eased_away) + forward * away_distance * eased_away
	var sway := sin(t * 1.7) * 0.03 * lift
	var turn := deg_to_rad(35.0) * eased_away
	var basis := _pad.basis.rotated(Vector3.UP, turn) * Basis(Vector3.RIGHT, -0.12 * away + sway) * Basis(Vector3.FORWARD, sway * 0.6)
	global_transform = Transform3D(basis, origin)
	_place_rider()
	if away >= 1.0 and not _departed:
		_departed = true
		departed.emit()


## The rider sits on the back bench, looking out of the open door.
func _place_rider() -> void:
	if _rider == null or _seat == null:
		return
	var eye := _seat.global_position + Vector3.UP * 0.62
	_rider.global_position = eye - _eye_offset
	var out := _seat.global_basis * Vector3.FORWARD
	_rider.global_rotation.y = atan2(-out.x, -out.z)
	_rider.head.rotation.x = deg_to_rad(-14.0)
	_rider.velocity = Vector3.ZERO
