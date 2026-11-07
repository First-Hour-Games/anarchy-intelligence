extends SceneTree
## Run normally for GPU light/view alignment checks; --headless checks scene wiring.
## Comparison captures are written to the operating system temp directory.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as Node3D
	for sign_name in ["Sketchfab_Scene", "welcomeSign"]:
		var helper := forest.get_node(sign_name + "/ReflectiveSheeting")
		helper.call("_apply_material")
		var target := helper.get_node(helper.mesh_path) as MeshInstance3D
		assert(target != null)
		assert(target.get_surface_override_material(helper.surface_index) == helper.sign_material)
		assert(helper.sign_material.get_shader_parameter("albedo_texture") != null)
		if sign_name == "welcomeSign":
			var rect: Vector4 = helper.sign_material.get_shader_parameter("reflective_uv_rect")
			assert(rect.x > 0.3 and rect.z < 0.7 and rect.w < 0.75)
		else:
			var pole := target.get_parent().get_node("pCube19_lambert31_0") as MeshInstance3D
			assert(pole.get_surface_override_material(0) == null)
	forest.free()
	print("PASS: forest sign materials, atlas mask and unchanged pole surface")
	if DisplayServer.get_name() == "headless":
		print("SKIP: rendered light alignment check requires a rendering display driver")
		quit()
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(0, 0, 4)
	camera.current = true
	var sign_mesh := MeshInstance3D.new()
	sign_mesh.mesh = QuadMesh.new()
	sign_mesh.mesh.size = Vector2(2.5, 2.5)
	sign_mesh.rotation.y = deg_to_rad(35.0)
	var material := load("res://models/props/stop_sign_retroreflective.tres") as ShaderMaterial
	sign_mesh.material_override = material
	scene.add_child(sign_mesh)
	var light := SpotLight3D.new()
	light.light_energy = 1.0
	light.spot_range = 12.0
	light.spot_angle = 40.0
	scene.add_child(light)
	light.position = camera.position
	light.look_at(Vector3.ZERO)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var aligned := viewport.get_texture().get_image()
	aligned.save_png(OS.get_environment("TEMP").path_join("sign-retro-aligned.png"))
	light.position = Vector3(3, 0, 4)
	light.look_at(Vector3.ZERO)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var offset := viewport.get_texture().get_image()
	offset.save_png(OS.get_environment("TEMP").path_join("sign-retro-offset.png"))
	var aligned_luminance := luminance(aligned)
	var offset_luminance := luminance(offset)
	print("SIGN CHECK: aligned=", aligned_luminance, " offset=", offset_luminance)
	assert(aligned_luminance > offset_luminance * 1.5, "Sign should return more light toward a light near the camera")
	viewport.queue_free()
	await process_frame
	print("PASS: rendered retroreflection responds to light/view alignment")
	quit()

func luminance(image: Image) -> float:
	var total := 0.0
	for y in range(150, 330):
		for x in range(250, 390):
			total += image.get_pixel(x, y).get_luminance()
	return total / (180.0 * 140.0)
