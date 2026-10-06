extends Node3D

@export var moving_wall_zone_path: NodePath = NodePath("../TutorialRooms/MovingWallZone")
@export_range(0.1, 5.0, 0.1) var light_interval: float = 1.0
@export var light_on_sound: AudioStreamMP3 = preload("res://sounds/chapters/intro/lightOn.mp3")
@export_range(-30.0, 6.0, 0.5) var light_on_volume_db: float = 2.0

var _bulbs: Array[Node3D] = []
var _emissions: Dictionary = {}
var _sequence: Tween


func _ready() -> void:
	for bulb_name in ["CeilingBulb4", "CeilingBulb5", "CeilingBulb6"]:
		var bulb := get_node(bulb_name) as Node3D
		_bulbs.append(bulb)
		var switch_audio := AudioStreamPlayer3D.new()
		switch_audio.name = "LightOnAudio"
		if light_on_sound:
			var local_stream := light_on_sound.duplicate() as AudioStreamMP3
			local_stream.loop = false
			switch_audio.stream = local_stream
		switch_audio.volume_db = light_on_volume_db
		switch_audio.bus = &"Reverb"
		switch_audio.max_distance = 55.0
		switch_audio.unit_size = 15.0
		bulb.add_child(switch_audio)
		for node in bulb.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			if not mesh.mesh:
				continue
			for surface in range(mesh.mesh.get_surface_count()):
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				if material and material.emission_enabled:
					var local_material := material.duplicate() as StandardMaterial3D
					mesh.set_surface_override_material(surface, local_material)
					_emissions[local_material] = [bulb, local_material.emission_energy_multiplier]
		_set_bulb_on(bulb, false)
	var zone := get_node(moving_wall_zone_path) as MovingWallZone
	zone.wall_move_started.connect(_on_wall_started)
	zone.wall_move_completed.connect(_on_wall_completed)


func _set_bulb_on(bulb: Node3D, enabled: bool) -> void:
	var switch_audio := bulb.get_node_or_null("LightOnAudio") as AudioStreamPlayer3D
	if switch_audio:
		if enabled:
			switch_audio.play()
		else:
			switch_audio.stop()
	for light in bulb.find_children("*", "Light3D", true, false):
		light.visible = enabled
	for material in _emissions:
		var entry: Array = _emissions[material]
		if entry[0] == bulb:
			material.emission_energy_multiplier = entry[1] if enabled else 0.0
	var buzzing := bulb.get_node_or_null("BuzzingAudio") as AudioStreamPlayer3D
	if buzzing:
		if enabled:
			buzzing.play()
		else:
			buzzing.stop()


func _on_wall_started(_wall: Node3D, _target_z: float, _duration: float) -> void:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	for bulb in _bulbs:
		_set_bulb_on(bulb, false)


func _on_wall_completed(_wall: Node3D, _final_z: float) -> void:
	if _sequence and _sequence.is_valid():
		_sequence.kill()
	_sequence = create_tween()
	for bulb in _bulbs:
		_sequence.tween_interval(light_interval)
		_sequence.tween_callback(_set_bulb_on.bind(bulb, true))
