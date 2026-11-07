extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var mixer := root.get_node("AmbienceMixer")
	mixer.set_process(false)
	var player := Node3D.new()
	player.add_to_group("player")
	root.add_child(player)
	var station := load("res://models/map/gas_station.tscn").instantiate() as Node3D
	# A transformed instance exercises the same local-to-world geometry as the map.
	station.position = Vector3(40, 0, -20)
	station.rotation.y = 0.7
	station.scale = Vector3.ONE * 1.2
	root.add_child(station)
	var zone: Node3D = station.get_node("InteriorAmbienceZone")
	var source: AudioStreamMP3 = zone.stream
	check(not source.loop, "Source factory clip should retain its imported one-shot setting")
	var front: float = zone.size.z * 0.5
	var last_weight := -1.0
	for depth in [-3.0, -2.0, -1.0, 0.0, 0.5, 1.0, 2.0, 3.0]:
		var position_world := zone.to_global(Vector3(0, 0, front - depth / 1.2))
		var weight: float = zone.get_weight(position_world)
		check(weight >= last_weight, "Approach and entry must increase smoothly")
		last_weight = weight
	check(is_equal_approx(last_weight, 1.0), "Interior must reach full ambience")
	check(zone.get_weight(zone.to_global(Vector3(10, 0, 0))) == 0.0, "No sound bleed through side walls")
	check(zone.get_weight(zone.to_global(Vector3(0, 0, -front - 1))) == 0.0, "No bleed through rear wall")
	check(zone.get_weight(zone.to_global(Vector3(0, 10, 0))) == 0.0, "Volume must not extend above building")
	player.global_position = zone.global_position
	for i in range(180):
		mixer.call("_process", 1.0 / 30.0)
	var state: Dictionary = mixer.get("_zones")[zone]
	var audio: AudioStreamPlayer = state.audio
	check(audio.playing and audio.stream.loop, "Interior MP3 must play continuously")
	check(audio.stream != source and not source.loop, "Loop only the duplicated playback stream")
	check(absf(audio.volume_db - zone.volume_db) < 0.05, "Interior reaches configured level")
	var outside := AudioServer.get_bus_index("OutdoorAmbience")
	check(absf(AudioServer.get_bus_volume_db(outside) - linear_to_db(0.06)) < 0.1, "Outdoor bed retains only configured indoor bleed")
	var filter := AudioServer.get_bus_effect(outside, 0) as AudioEffectLowPassFilter
	check(absf(filter.cutoff_hz - 1000.0) < 5.0, "Outdoor ambience is muffled inside")
	check(audio.bus == &"InteriorAmbience", "Interior has a separate acoustic bus")
	paused = true
	check(not audio.can_process() and not mixer.can_process(), "Ambience respects pause")
	paused = false
	# Overlapping zones should not double the level; higher priority takes over.
	var overlap := load("res://scenes/zones/ambient_sound_zone.tscn").instantiate() as Node3D
	overlap.stream = source
	overlap.priority = 5
	overlap.transform = zone.global_transform
	root.add_child(overlap)
	for i in range(240):
		mixer.call("_process", 1.0 / 30.0)
	var other_state: Dictionary = mixer.get("_zones")[overlap]
	check(state.weight < 0.0001 and other_state.weight > 0.999, "Higher priority wins overlapping interiors")
	overlap.is_enabled = false
	for i in range(240):
		mixer.call("_process", 1.0 / 30.0)
	check(state.weight > 0.999 and other_state.weight < 0.0001, "Disabling a zone restores the underlying zone")
	# Exit restores the outdoor bus without restarting or editing the baseline player.
	player.global_position = zone.to_global(Vector3(0, 0, front + 10))
	for i in range(300):
		mixer.call("_process", 1.0 / 30.0)
	check(absf(AudioServer.get_bus_volume_db(outside)) < 0.01, "Exit restores default ambience level")
	check(not AudioServer.is_bus_effect_enabled(outside, 0), "Exit clears outdoor muffling")
	check(not audio.playing, "Inaudible interior voices stop")
	# Streaming unload while indoors must release both the voice and outdoor ducking.
	player.global_position = zone.global_position
	for i in range(180):
		mixer.call("_process", 1.0 / 30.0)
	station.free()
	overlap.free()
	for i in range(180):
		mixer.call("_process", 1.0 / 30.0)
	check(mixer.get("_zones").is_empty(), "Unloaded sections unregister their zones")
	check(absf(AudioServer.get_bus_volume_db(outside)) < 0.01, "Unloading interior restores default ambience")
	player.free()
	print("Ambient sound zone smoke: %d failures" % failures)
	quit(1 if failures else 0)
