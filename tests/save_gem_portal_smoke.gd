extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func draw_frames() -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	if DisplayServer.get_name() == "headless":
		print("SKIP save_gem_portal_smoke requires a rendering display")
		quit(0)
		return
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0.123, 0.7)
	camera.current = true
	var gem: Node3D = load("res://models/props/gem/gem.tscn").instantiate()
	world.add_child(gem)
	var view: SubViewport = gem.get("_sky_view")
	var sky_camera: Camera3D = gem.get("_sky_camera")
	var tutorial_environment := load("res://shaders/tutorial_sky_environment.tres") as Environment
	check(sky_camera.environment.sky == tutorial_environment.sky, "gem uses the tutorial's actual shared sky resource")
	check(sky_camera.environment.adjustment_saturation == tutorial_environment.adjustment_saturation, "gem preserves the tutorial's monochrome grade")
	check(is_equal_approx(sky_camera.environment.background_energy_multiplier, 0.6), "gem matches tutorial runtime sky energy")
	# Freeze only private test copies of the star animation for image comparison.
	sky_camera.environment.sky = sky_camera.environment.sky.duplicate() as Sky
	var sky_material := sky_camera.environment.sky.sky_material.duplicate() as ShaderMaterial
	sky_material.set_shader_parameter("drift_speed", 0.0)
	sky_material.set_shader_parameter("rotation_speed", 0.0)
	sky_material.set_shader_parameter("twinkle_amount", 0.0)
	sky_camera.environment.sky.sky_material = sky_material
	await draw_frames()
	var portal_image := root.get_texture().get_image()
	var near_sky := view.get_texture().get_image()
	camera.position.z = 1.8
	await draw_frames()
	var far_sky := view.get_texture().get_image()
	check(near_sky.get_data() == far_sky.get_data(), "approaching and leaving the gem cannot zoom or warp its sky")
	check(is_equal_approx(sky_camera.fov, camera.fov) and sky_camera.keep_aspect == camera.keep_aspect, "portal follows the player's projection without magnification")
	camera.position.z = 0.7
	gem.hide()
	camera.environment = sky_camera.environment
	await draw_frames()
	var reference := root.get_texture().get_image()
	var difference := 0.0
	var count := 0
	# This central patch is entirely inside the gem's silhouette at the near position.
	var center := reference.get_size() / 2
	for y in range(center.y - 60, center.y + 60, 2):
		for x in range(center.x - 25, center.x + 25, 2):
			var a := reference.get_pixel(x, y)
			var b := portal_image.get_pixel(x, y)
			difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			count += 3
	print("Tutorial sky / gem mean channel difference: ", difference / count)
	check(difference / count < 0.02, "rendered gem interior matches the actual tutorial sky")
	world.queue_free()
	await process_frame
	print("save_gem_portal_smoke: %d failures" % failures)
	quit(1 if failures else 0)
