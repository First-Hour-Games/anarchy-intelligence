extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.18, 0.2, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.8
	world.add_child(env)
	var camera := Camera3D.new()
	camera.fov = 74
	camera.current = true
	world.add_child(camera)
	var flashlight := load("res://scenes/player/flashlight/player_flashlight.tscn").instantiate() as PlayerFlashlight
	camera.add_child(flashlight)
	flashlight.set_enabled(true)
	flashlight._process(1.0)
	var model := flashlight.get_node("ModelPivot/Model") as Node3D
	var body := model.get_node("Flashlight_Body") as MeshInstance3D
	var lens := model.get_node("Flashlight_Body/Flashlight_Lens") as MeshInstance3D
	print("Forward alignment: ", body.global_basis.y.normalized().dot(-camera.global_basis.z))
	print("Lens position: ", lens.to_global(lens.get_aabb().get_center()))
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://scratch/flashlight_held_preview.png")
	quit()
