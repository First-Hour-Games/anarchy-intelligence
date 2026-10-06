extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var zone := Node3D.new()
	for index in range(8):
		var silo := Node3D.new()
		silo.name = "Silo%d" % index
		zone.add_child(silo)
	var unrelated := Node3D.new()
	unrelated.name = "gantryTankStation"
	zone.add_child(unrelated)
	var controller := Node.new()
	controller.set_script(load("res://scenes/environment/silo_ambience.gd"))
	zone.add_child(controller)
	root.add_child(zone)
	controller.set_process(false)
	assert(controller.get("_emitters").size() == 8)
	assert(not unrelated.has_node("SiloWheelAudio"))
	var rng: RandomNumberGenerator = controller.get("_rng")
	rng.seed = 101
	var emitters: Array = controller.get("_emitters")
	var delays: Dictionary = controller.get("_cooldowns")
	var active: Dictionary = controller.get("_active")
	controller.call("_process", 60.0)
	assert(active.is_empty())
	controller.call("start_ambience")
	for emitter in emitters:
		assert(emitter.bus == &"Reverb")
		assert(emitter.max_distance == 150.0)
		assert(emitter.unit_size == 20.0)
		assert(emitter.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE)
		assert(delays[emitter] >= 5.0 and delays[emitter] <= 15.0)
	controller.call("_process", 4.9)
	assert(active.is_empty())
	controller.call("_process", 15.0)
	assert(active.size() == 2)
	var started: Dictionary = {}
	for cycle in range(80):
		assert(active.size() <= 2)
		var finishing: Array = active.keys()
		for emitter in finishing:
			assert(emitter.playing and emitter.stream != null)
			assert(not (emitter.stream as AudioStreamMP3).loop)
			started[emitter.get_parent().name] = true
			emitter.stop()
			emitter.finished.emit()
			assert(delays[emitter] >= 5.0 and delays[emitter] <= 15.0)
		controller.call("_process", 0.0)
		for emitter in finishing:
			assert(not active.has(emitter))
		controller.call("_process", 15.0)
		assert(active.size() <= 2)
	assert(started.size() == 8)
	paused = true
	assert(not controller.can_process())
	for emitter in emitters:
		assert(not emitter.can_process())
	paused = false
	zone.queue_free()
	await process_frame
	print("PASS: eight silo emitters, randomized selection, 5-15s completion cooldowns, two-voice cap, one-shot clips and pause behavior")
	quit()
