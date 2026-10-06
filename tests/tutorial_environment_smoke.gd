extends SceneTree

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
	check(tutorial != null, "tutorial instance created")

	# Check default exported property
	var default_bg: Color = tutorial.get("default_background_color")
	check(default_bg == Color("454545"), "default_background_color property defaults to #454545")
	check(default_bg.to_html(false).to_lower() == "454545", "default_background_color hex string is 454545")

	# Fast durations for headless test
	tutorial.set("intro_black_hold_seconds", 0.01)
	tutorial.set("intro_fade_duration", 0.01)
	tutorial.set("door_color_fade_duration", 0.01)

	root.add_child(tutorial)
	await process_frame

	var world_env := tutorial.get_node_or_null("WorldEnvironment") as WorldEnvironment
	check(is_instance_valid(world_env), "WorldEnvironment node exists in tutorial")
	if is_instance_valid(world_env):
		check(world_env.environment != null, "WorldEnvironment has environment resource assigned")
		if world_env.environment != null:
			check(world_env.environment.background_mode == Environment.BG_SKY, "WorldEnvironment uses the starfield sky")
			check(world_env.environment.sky != null and world_env.environment.sky.sky_material is ShaderMaterial, "starfield sky has its shader material")
			check(is_equal_approx(world_env.environment.background_energy_multiplier, 0.6), "runtime sky energy is 0.6")
			check(is_zero_approx(world_env.environment.adjustment_saturation), "tutorial keeps its monochrome grade")
			check(world_env.environment.background_color == Color("454545"), "WorldEnvironment background_color equals Color(\"454545\")")
			check(world_env.environment.background_color.to_html(false).to_lower() == "454545", "WorldEnvironment background_color hex is 454545")

	var fog := tutorial.get_node("Player/Head/Camera3D/DistanceFog") as MeshInstance3D
	check(is_zero_approx(float((fog.material_override as ShaderMaterial).get_shader_parameter("sky_horizon_blend"))), "tutorial fog leaves the starfield visible below the horizon")
	var shared_fog := load("res://shaders/distance_fog_material.tres") as ShaderMaterial
	check(float(shared_fog.get_shader_parameter("sky_horizon_blend")) > 0.0, "other scenes retain their shared horizon fog")

	tutorial.queue_free()
	await process_frame

	quit(1 if failures > 0 else 0)
