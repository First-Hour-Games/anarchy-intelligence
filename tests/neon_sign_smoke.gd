extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	var scene := load("res://models/map/gas_station.tscn") as PackedScene
	assert(scene != null)
	var station := scene.instantiate()
	var sign_a := station.get_node("PumpSign") as MeshInstance3D
	var sign_b := station.get_node("PumpSign2") as MeshInstance3D
	var original := sign_a.material_override as StandardMaterial3D
	var base := original.emission_energy_multiplier
	var imported := (sign_a.get_node("NeonAmbience") as AudioStreamPlayer3D).stream as AudioStreamMP3
	root.add_child(station)
	assert(sign_a.material_override != original)
	assert(sign_a.material_override != sign_b.material_override)
	assert((sign_a.get_node("MeshInstance3D") as MeshInstance3D).material_override == sign_a.material_override)
	for sign in [sign_a, sign_b]:
		var audio := sign.get_node("NeonAmbience") as AudioStreamPlayer3D
		assert(audio.playing)
		assert((audio.stream as AudioStreamMP3).loop)
		assert(audio.stream != imported)
	assert(not imported.loop)
	sign_a.set_process(false)
	sign_b.set_process(false)
	var rng_a: RandomNumberGenerator = sign_a.get("_rng")
	var rng_b: RandomNumberGenerator = sign_b.get("_rng")
	rng_a.seed = 10
	rng_b.seed = 99
	var lowest := base
	var highest := base
	var independent := false
	var light_a := sign_a.get_node("OmniLight3D") as OmniLight3D
	var base_light := light_a.light_energy
	for frame in range(600):
		sign_a.call("_process", 1.0 / 60.0)
		sign_b.call("_process", 1.0 / 60.0)
		var energy := (sign_a.material_override as StandardMaterial3D).emission_energy_multiplier
		assert(energy >= base * 0.6 - 0.0001 and energy <= base * 1.08 + 0.0001)
		assert(is_equal_approx(light_a.light_energy / base_light, energy / base))
		lowest = minf(lowest, energy)
		highest = maxf(highest, energy)
		if not is_equal_approx(energy, (sign_b.material_override as StandardMaterial3D).emission_energy_multiplier):
			independent = true
	assert(lowest < base * 0.9 and highest > base and independent)
	assert(original.emission_energy_multiplier == base)
	sign_a.set("flicker_enabled", false)
	sign_a.call("_process", 0.1)
	assert(is_equal_approx((sign_a.material_override as StandardMaterial3D).emission_energy_multiplier, base))
	paused = true
	assert(not sign_a.can_process())
	assert(not (sign_a.get_node("NeonAmbience") as AudioStreamPlayer3D).can_process())
	paused = false
	station.queue_free()
	await process_frame
	print("PASS: independent nonzero flicker, synced lights, private materials, positional audio loops and pause behavior")
	quit()
