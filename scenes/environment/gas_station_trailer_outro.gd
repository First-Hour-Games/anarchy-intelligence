class_name GasStationTrailerOutro
extends Node3D

## An editable flight over the current forest, ending on the existing game logo.
@export_range(4.0, 30.0, 0.5) var flythrough_seconds: float = 10.0
@export_range(0.2, 2.0, 0.1) var fade_seconds: float = 0.8

@onready var camera: Camera3D = $Camera3D
@onready var moonlight: DirectionalLight3D = $Moonlight
@onready var overlay: CanvasLayer = $Overlay
@onready var blackout: ColorRect = $Overlay/Blackout
@onready var title: TextureRect = $Overlay/Title
@onready var shots: Node3D = $Shots

var active: bool = false
var flight_finished: bool = false
var elapsed: float = 0.0
var _previous_camera: Camera3D
var _audio_states: Array[Dictionary] = []
var _hidden_geometry: Dictionary = {}

func begin() -> void:
	stop()
	# Shot markers use forest coordinates, independent of the rotated station.
	global_transform = (get_tree().current_scene as Node3D).global_transform
	_previous_camera = get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player and is_instance_valid(player.distance_fog):
		_hide_geometry(player.distance_fog)
	for node: Node in get_tree().current_scene.find_children("_ZoneBoxPreview", "MeshInstance3D", true, false):
		_hide_geometry(node as GeometryInstance3D)
	var world := get_tree().current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world and world.environment:
		var cinematic := world.environment.duplicate() as Environment
		cinematic.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		cinematic.ambient_light_color = Color(0.46, 0.55, 0.65)
		cinematic.ambient_light_energy = 0.35
		cinematic.volumetric_fog_enabled = false
		cinematic.fog_enabled = true
		cinematic.fog_density = 0.003
		cinematic.fog_light_color = Color(0.18, 0.23, 0.28)
		cinematic.fog_sky_affect = 0.2
		cinematic.glow_enabled = false
		camera.environment = cinematic
	# Let the scream finish the gameplay audio; keep the title flight quiet.
	for node: Node in get_tree().current_scene.find_children("*", "", true, false):
		if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
			_audio_states.append({"node": node, "paused": node.stream_paused})
			node.stream_paused = true
	active = true
	flight_finished = false
	elapsed = 0.0
	moonlight.show()
	overlay.show()
	camera.make_current()
	advance(0.0)

func advance(delta: float) -> void:
	if not active or flight_finished:
		return
	elapsed = minf(elapsed + delta, flythrough_seconds)
	var progress := elapsed / flythrough_seconds
	var position := progress * float(shots.get_child_count() - 1)
	var index := mini(int(position), shots.get_child_count() - 2)
	var weight := position - float(index)
	camera.global_position = _sample(index, weight, false)
	camera.look_at(_sample(index, weight, true))
	var ending := smoothstep(flythrough_seconds - fade_seconds, flythrough_seconds, elapsed)
	blackout.color.a = maxf(1.0 - smoothstep(0.0, fade_seconds, elapsed), ending)
	title.modulate.a = smoothstep(0.0, fade_seconds * 0.5, elapsed)
	title.anchor_top = lerpf(0.67, 0.41, ending)
	title.anchor_bottom = lerpf(0.82, 0.56, ending)
	if elapsed >= flythrough_seconds:
		flight_finished = true
		moonlight.hide()

func _sample(index: int, weight: float, target: bool) -> Vector3:
	var points: Array[Vector3] = []
	for offset in [-1, 0, 1, 2]:
		var marker := shots.get_child(clampi(index + offset, 0, shots.get_child_count() - 1)) as Marker3D
		points.append((marker.get_node("LookAt") as Marker3D).global_position if target else marker.global_position)
	return points[1].cubic_interpolate(points[2], points[0], points[3], weight)

func _hide_geometry(node: GeometryInstance3D) -> void:
	_hidden_geometry[node] = node.visible
	node.hide()

func stop() -> void:
	active = false
	flight_finished = false
	if is_instance_valid(overlay):
		overlay.hide()
	if is_instance_valid(moonlight):
		moonlight.hide()
	if is_instance_valid(camera):
		camera.current = false
		camera.environment = null
	if is_instance_valid(_previous_camera) and _previous_camera.is_inside_tree():
		_previous_camera.make_current()
	_previous_camera = null
	for state: Dictionary in _audio_states:
		var node: Node = state["node"]
		if is_instance_valid(node):
			node.stream_paused = state["paused"]
	_audio_states.clear()
	for node: GeometryInstance3D in _hidden_geometry:
		if is_instance_valid(node):
			node.visible = _hidden_geometry[node]
	_hidden_geometry.clear()

func _exit_tree() -> void:
	stop()
