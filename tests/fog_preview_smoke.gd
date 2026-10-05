extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	print("=== Running Fog Preview Scene Smoke Test ===")
	
	var packed := load("res://scenes/chapters/playground/fog_preview.tscn") as PackedScene
	check(packed != null, "fog_preview.tscn packed scene loaded")

	var instance = packed.instantiate()
	check(instance != null, "fog_preview.tscn instantiated")
	root.add_child(instance)
	await process_frame

	var fog_vol := instance.get_node_or_null("FogVolume") as FogVolume
	check(is_instance_valid(fog_vol), "FogVolume node exists in preview scene")

	var env_node := instance.get_node_or_null("WorldEnvironment") as WorldEnvironment
	check(is_instance_valid(env_node), "WorldEnvironment node exists")
	if env_node and env_node.environment:
		check(env_node.environment.volumetric_fog_enabled, "Volumetric fog is enabled in Environment")

	var cam := instance.get_node_or_null("Camera3D") as Camera3D
	check(is_instance_valid(cam), "Camera3D exists and is active")

	# Test UI interaction
	var density_slider: HSlider = instance.get_node_or_null("HUD/Panel/VBox/DensityRow/HSlider")
	check(is_instance_valid(density_slider), "Density slider exists")
	if density_slider:
		density_slider.value = 0.5
		await process_frame
		var mat: ShaderMaterial = fog_vol.material
		var val = mat.get_shader_parameter("base_density")
		check(is_equal_approx(float(val), 0.5), "Slider adjusted base_density to 0.5")

	# Test camera preset switching
	instance._set_camera_preset(Vector3(5, 5, 5), -0.1, 0.2)
	check(is_equal_approx(cam.position.x, 5.0), "Camera preset switched successfully")

	# Run a few frames of rendering
	for i in range(10):
		await process_frame

	instance.queue_free()
	await process_frame

	print("=== Fog Preview Scene Smoke Test Completed with ", failures, " failures ===")
	quit(1 if failures > 0 else 0)
