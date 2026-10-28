extends Node
## Crossfades ambience separately from music, dialogue and positional effects.
## Bus gain composes with the forest's intro fade without changing its player.

const OUTDOOR_BUS := &"OutdoorAmbience"
const INTERIOR_BUS := &"InteriorAmbience"
var _zones: Dictionary = {}
var _player: Node3D
var _outdoor_gain := 1.0
var _cutoff := 20000.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_apply_outdoor(1.0, 20000.0)

func register_zone(zone: Node3D) -> void:
	if _zones.has(zone):
		return
	var audio := AudioStreamPlayer.new()
	audio.name = "ZoneAmbience"
	audio.bus = INTERIOR_BUS
	audio.volume_db = -80.0
	if zone.stream != null:
		# Do not change the source resource's loop setting for other uses.
		audio.stream = zone.stream.duplicate()
		if audio.stream is AudioStreamMP3 or audio.stream is AudioStreamOggVorbis:
			audio.stream.loop = true
		elif audio.stream is AudioStreamWAV:
			audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.finished.connect(audio.play)
	add_child(audio)
	_zones[zone] = {"audio": audio, "weight": 0.0, "playback": 0.0}

func unregister_zone(zone: Node3D) -> void:
	if not _zones.has(zone):
		return
	# Keep the voice alive for its release if a streamed section disappears.
	var state: Dictionary = _zones[zone]
	_zones.erase(zone)
	var audio: AudioStreamPlayer = state.audio
	var release := create_tween()
	release.tween_property(audio, "volume_db", -80.0, 0.65)
	release.tween_callback(audio.queue_free)

func _process(delta: float) -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var targets: Dictionary = {}
	var highest_priority := -2147483648
	for zone: Node3D in _zones:
		var weight: float = zone.get_weight(_player.global_position) if is_instance_valid(_player) else 0.0
		targets[zone] = weight
		if weight > 0.0:
			highest_priority = maxi(highest_priority, zone.priority)
	var total := 0.0
	var inside_gain := 0.0
	var cutoff_log := 0.0
	for zone: Node3D in _zones:
		var state: Dictionary = _zones[zone]
		var target: float = targets[zone] if zone.priority == highest_priority else 0.0
		state.weight = lerpf(state.weight, target, 1.0 - exp(-delta / maxf(zone.fade_time, 0.05)))
		total += state.weight
		inside_gain += state.weight * zone.outdoor_gain_inside
		cutoff_log += state.weight * log(zone.outdoor_cutoff_hz)
	var mix := clampf(total, 0.0, 1.0)
	var interior_gain := sin(mix * PI * 0.5)
	for zone: Node3D in _zones:
		var state: Dictionary = _zones[zone]
		var audio: AudioStreamPlayer = state.audio
		var gain := interior_gain * sqrt(state.weight / maxf(total, 0.00001))
		if gain > 0.0001 and audio.stream != null:
			audio.volume_db = zone.volume_db + linear_to_db(gain)
			if not audio.playing:
				audio.play(state.playback)
		else:
			audio.volume_db = -80.0
			if audio.playing:
				state.playback = audio.get_playback_position()
				audio.stop()
	var residual := inside_gain / maxf(total, 0.00001)
	var target_gain := sqrt(pow(cos(mix * PI * 0.5), 2.0) + pow(residual * interior_gain, 2.0))
	var target_cutoff := exp(lerpf(log(20000.0), cutoff_log / maxf(total, 0.00001), mix)) if total > 0.00001 else 20000.0
	# Also smooth release when a zone is removed or the player changes scenes.
	var response := 1.0 - exp(-delta / 0.2)
	_outdoor_gain = lerpf(_outdoor_gain, target_gain, response)
	_cutoff = lerpf(_cutoff, target_cutoff, response)
	_apply_outdoor(_outdoor_gain, _cutoff)

func _apply_outdoor(gain: float, cutoff: float) -> void:
	var index := AudioServer.get_bus_index(OUTDOOR_BUS)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(gain, 0.0001)))
	var filter := AudioServer.get_bus_effect(index, 0) as AudioEffectLowPassFilter
	if filter != null:
		filter.cutoff_hz = cutoff
		AudioServer.set_bus_effect_enabled(index, 0, cutoff < 19500.0)
