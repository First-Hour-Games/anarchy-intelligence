extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	print("=== Running Moving Gradient Noise Fog Smoke Test ===")
	
	# 1. Test shader loading
	var shader := load("res://shaders/moving_gradient_noise_fog.gdshader") as Shader
	check(shader != null, "Shader loaded successfully")
	if shader != null:
		check(shader.get_mode() == Shader.MODE_FOG, "Shader mode is MODE_FOG")

	# 2. Test material loading
	var material := load("res://shaders/moving_gradient_noise_fog_material.tres") as ShaderMaterial
	check(material != null, "ShaderMaterial loaded successfully")
	if material != null:
		check(material.shader == shader, "ShaderMaterial references the correct shader")
		var density = material.get_shader_parameter("base_density")
		check(density != null and is_equal_approx(float(density), 0.8), "base_density default matches (0.8)")

	# 3. Test FogVolume node instantiation
	var fog_volume := FogVolume.new()
	fog_volume.name = "TestFogVolume"
	fog_volume.size = Vector3(20, 4, 20)
	fog_volume.material = material

	# 4. Create a test 3D scene with WorldEnvironment and Camera3D
	var scene_root := Node3D.new()
	scene_root.name = "TestScene"
	root.add_child(scene_root)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.1, 0.1, 0.1)
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.01
	world_env.environment = env
	scene_root.add_child(world_env)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2, 10)
	scene_root.add_child(camera)
	camera.current = true

	var light := DirectionalLight3D.new()
	light.position = Vector3(0, 10, 0)
	scene_root.add_child(light)

	scene_root.add_child(fog_volume)

	# Process frames to test shader compilation and rendering
	for i in range(5):
		await process_frame

	check(is_instance_valid(fog_volume), "FogVolume is alive and valid in scene tree")
	check(fog_volume.material == material, "FogVolume maintains active material")

	# Clean up
	scene_root.queue_free()
	await process_frame

	print("=== Moving Gradient Noise Fog Smoke Test Completed with ", failures, " failures ===")
	quit(1 if failures > 0 else 0)
