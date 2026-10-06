extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as StartingForest
	forest.auto_start_fade = false
	root.add_child(forest)
	await process_frame
	var environment := forest.get_node("WorldEnvironment").environment as Environment
	var ambient := environment.ambient_light_color
	assert(environment.volumetric_fog_enabled)
	assert(is_equal_approx(environment.volumetric_fog_density, 0.0472))
	assert(is_equal_approx(environment.fog_density, 0.055))
	assert(not forest.fog_volume.visible and forest.player.distance_fog.visible)
	forest._on_climb_over_started(forest.player)
	forest._on_climb_over_completed(forest.player)
	forest.finish_fog_transition_immediately()
	await process_frame
	assert(not forest.fog_volume.visible and forest.player.distance_fog.visible)
	assert(environment.ambient_light_color == ambient)
	print("PASS: Original forest fog stays unchanged and log FogVolume never activates")
	forest.queue_free()
	await process_frame
	quit()
