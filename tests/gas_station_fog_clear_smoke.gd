extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := scene.instantiate() as StartingForest
	forest.auto_start_fade = false
	root.add_child(forest)
	await process_frame
	var area := forest.get_node("GasStation/FogClearArea") as Area3D
	assert(area.collision_mask & forest.player.collision_layer != 0)
	forest.finish_fog_transition_immediately()
	await create_timer(0.5).timeout
	forest.gas_station_fog_clear_duration = 1.0
	forest.player.global_position = area.global_position
	await create_timer(0.3).timeout
	assert(forest._fog_cleared_at_gas_station, "Entering corner must start clearing fog")
	assert(forest._fog_material_instance.get_shader_parameter("base_density") > 0.0, "Fog should fade gradually")
	await create_timer(1.1).timeout
	assert(not forest.fog_volume.visible)
	assert(is_zero_approx(forest._fog_material_instance.get_shader_parameter("base_density")))
	assert(is_zero_approx(forest.player.get_distance_fog_material().get_shader_parameter("fog_strength")))
	assert(not forest.player.distance_fog.visible, "Fullscreen fog overlay must be disabled")
	assert(not forest.get_node("WorldEnvironment").environment.fog_enabled)
	assert(not forest.get_node("WorldEnvironment").environment.volumetric_fog_enabled)
	forest.finish_fog_transition_immediately()
	forest.activate_fog()
	assert(not forest.fog_volume.visible, "Cleared fog should stay cleared")
	print("PASS: Gas station corner gradually clears fog and prevents reactivation")
	forest.queue_free()
	await process_frame
	quit()
