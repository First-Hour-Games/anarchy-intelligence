extends Node

signal silo_sound_started(silo: Node3D, stream: AudioStream)

@export var sounds: Array[AudioStream] = [
	preload("res://sounds/ambience/forest/silo/siloWheel1.mp3"),
	preload("res://sounds/ambience/forest/silo/siloWheel2.mp3"),
	preload("res://sounds/ambience/forest/silo/siloWheel3.mp3"),
	preload("res://sounds/ambience/forest/silo/siloWheel4.mp3"),
]
@export_range(0.1, 60.0, 0.1) var minimum_delay := 5.0
@export_range(0.1, 60.0, 0.1) var maximum_delay := 15.0
@export_range(1, 2, 1) var maximum_simultaneous := 2
@export_range(-40.0, 6.0, 1.0) var volume_db := -14.0
@export var audible_distance := 150.0
@export_range(0.1, 50.0, 0.1) var unit_size := 20.0
@export var emitter_height := 3.0

var _rng := RandomNumberGenerator.new()
var _emitters: Array[AudioStreamPlayer3D] = []
var _cooldowns: Dictionary = {}
var _active: Dictionary = {}
var _enabled := false


func _ready() -> void:
	_rng.randomize()
	for silo in get_parent().get_children():
		if not silo is Node3D or not str(silo.name).begins_with("Silo"):
			continue
		var emitter := AudioStreamPlayer3D.new()
		emitter.name = "SiloWheelAudio"
		emitter.position.y = emitter_height
		emitter.volume_db = volume_db
		emitter.unit_size = unit_size
		emitter.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		emitter.max_distance = audible_distance
		emitter.bus = &"Reverb"
		emitter.finished.connect(_on_sound_finished.bind(emitter))
		silo.add_child(emitter)
		_emitters.append(emitter)
		_cooldowns[emitter] = _random_delay()


func _random_delay() -> float:
	var low := maxf(minimum_delay, 0.1)
	return _rng.randf_range(low, maxf(maximum_delay, low))


func start_ambience() -> void:
	if _enabled:
		return
	_enabled = true
	for emitter in _emitters:
		_cooldowns[emitter] = _random_delay()


func _process(delta: float) -> void:
	if not _enabled:
		return
	var eligible: Array[AudioStreamPlayer3D] = []
	for emitter in _emitters:
		if not is_instance_valid(emitter) or _active.has(emitter):
			continue
		_cooldowns[emitter] = maxf(float(_cooldowns[emitter]) - delta, 0.0)
		if float(_cooldowns[emitter]) <= 0.0:
			eligible.append(emitter)
	var available_sounds: Array[AudioStream] = []
	for sound in sounds:
		if sound != null:
			available_sounds.append(sound)
	if available_sounds.is_empty():
		return
	# Pick randomly from ready silos rather than always preferring scene-tree order.
	while _active.size() < clampi(maximum_simultaneous, 1, 2) and not eligible.is_empty():
		var index := _rng.randi_range(0, eligible.size() - 1)
		var emitter := eligible[index]
		eligible.remove_at(index)
		var stream := available_sounds[_rng.randi_range(0, available_sounds.size() - 1)]
		# Force one-shot playback privately even if an imported clip has looping enabled.
		if stream is AudioStreamMP3:
			stream = stream.duplicate()
			(stream as AudioStreamMP3).loop = false
		emitter.stream = stream
		_active[emitter] = true
		emitter.play()
		silo_sound_started.emit(emitter.get_parent(), emitter.stream)


func _on_sound_finished(emitter: AudioStreamPlayer3D) -> void:
	if not _active.has(emitter):
		return
	_active.erase(emitter)
	# The next delay begins at completion, never during the current clip.
	_cooldowns[emitter] = _random_delay()
