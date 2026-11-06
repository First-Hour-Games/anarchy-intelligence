extends SceneTree

const Fault := preload("res://scenes/environment/streetlight_fault.gd")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var seen := {}
	for index in 128:
		var light := OmniLight3D.new()
		light.light_energy = 4.0
		root.add_child(light)
		Fault.attach(light)
		var fault = light.get_child(0)
		seen[fault.state] = true
		if fault.state == Fault.State.OFF:
			assert(light.light_energy == 0.0 and not fault.is_processing())
		elif fault.state == Fault.State.DIM:
			assert(light.light_energy >= 0.6 and light.light_energy <= 1.8)
			assert(not fault.is_processing())
		else:
			var energies := {}
			for step in 100:
				fault._process(3.1)
				assert(light.light_energy >= 0.0 and light.light_energy <= 2.6)
				energies[light.light_energy] = true
			assert(energies.size() > 1)
		light.free()
	assert(seen.size() == 3)
	var streetlight = load("res://models/map/residence/streetlight.tscn").instantiate()
	root.add_child(streetlight)
	await process_frame
	assert(streetlight.spot_light.get_child_count() == 1)
	streetlight.light_enabled = false
	assert(not streetlight.spot_light.visible)
	streetlight.queue_free()
	await process_frame
	print("PASS: Streetlights independently select off, dim or flicker; flicker changes brightness, and manual disabling still works.")
	quit()
