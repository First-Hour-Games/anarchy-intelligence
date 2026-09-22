extends SceneTree

const FlickerLight = preload("res://scenes/chapters/tutorial/flicker_light.gd")

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var tutorial_packed := load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene
	check(tutorial_packed != null, "tutorial.tscn loaded successfully")

	var tutorial := tutorial_packed.instantiate()
	root.add_child(tutorial)
	await process_frame

	var bulb1_light := tutorial.get_node_or_null("CeilingBulb/SpotLight3D") as SpotLight3D
	var bulb2_light := tutorial.get_node_or_null("CeilingBulb2/SpotLight3D") as SpotLight3D

	check(is_instance_valid(bulb1_light), "CeilingBulb has SpotLight3D")
	check(is_instance_valid(bulb2_light), "CeilingBulb2 has SpotLight3D")
	check(bulb1_light.get_script() == null, "CeilingBulb SpotLight3D does not flicker (untouched)")
	check(bulb2_light.get_script() != null and bulb2_light is FlickerLight, "CeilingBulb2 SpotLight3D has FlickerLight script")

	var flicker: FlickerLight = bulb2_light as FlickerLight
	check(flicker.visible and flicker.is_light_on(), "CeilingBulb2 spotlight starts ON")
	check(is_equal_approx(flicker.light_energy, 1.208), "Spotlight maintains base light_energy when ON")

	var mesh_node := tutorial.get_node_or_null("CeilingBulb2").find_child("defaultMaterial", true, false) as MeshInstance3D
	check(is_instance_valid(mesh_node), "CeilingBulb2 lamp mesh exists")
	var override_mat := mesh_node.get_surface_override_material(0) as StandardMaterial3D
	check(is_instance_valid(override_mat), "Lamp mesh has local surface override material for emission sync")

	var saw_off := false
	var saw_on_after_off := false

	# Simulate process frames with time steps to test random flicker transitions
	for step in 500:
		flicker._process(0.05)
		if not flicker.is_light_on():
			saw_off = true
			if not flicker.visible and flicker.light_energy == 0.0:
				pass
			else:
				check(false, "Spotlight is not completely dark when turned off")
			if is_instance_valid(override_mat) and override_mat.emission_energy_multiplier != 0.0:
				check(false, "Bulb emission is not zero when off")
		elif saw_off:
			saw_on_after_off = true
			if flicker.visible and flicker.light_energy > 0.0:
				pass
			else:
				check(false, "Spotlight is not lit when turned on")
			if is_instance_valid(override_mat) and override_mat.emission_energy_multiplier <= 0.0:
				check(false, "Bulb emission is not positive when on")
		if saw_off and saw_on_after_off:
			break

	check(saw_off, "CeilingBulb2 spotlight flickered OFF during simulation")
	check(saw_on_after_off, "CeilingBulb2 spotlight turned back ON after flickering OFF")

	# Test disabling flicker
	flicker.set_flicker_enabled(false)
	check(flicker.visible and flicker.is_light_on(), "Spotlight turns back ON when flicker is disabled")
	check(is_equal_approx(flicker.light_energy, 1.208), "Spotlight restores base energy when flicker is disabled")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
