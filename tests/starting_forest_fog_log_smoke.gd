extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, msg: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + msg)
	if not condition:
		failures += 1


func run() -> void:
	print("=== Running Starting Forest Fog Volume & Log Transition Smoke Test ===")

	var packed := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed != null, "starting_forest.tscn loaded")

	var forest := packed.instantiate() as StartingForest
	check(forest != null, "starting_forest instantiated as StartingForest")
	root.add_child(forest)
	await process_frame
	await physics_frame

	var fog_vol: FogVolume = forest.fog_volume
	check(is_instance_valid(fog_vol), "FogVolume found or instantiated in starting_forest")

	# 1. Verify initially hidden before log climb
	check(not fog_vol.visible, "FogVolume is initially hidden (visible = false)")
	check(not forest._is_fog_active, "Fog state _is_fog_active is false initially")

	var player: Node3D = forest.player
	check(is_instance_valid(player), "Player exists in starting_forest")

	# 2. Trigger log climb transition
	print("Triggering log climb transition...")
	forest._on_climb_over_started(player)
	await process_frame

	check(forest._is_fog_active, "Fog is active after log climb started")
	check(fog_vol.visible, "FogVolume is visible after log climb")

	# Check welding to player
	check(is_equal_approx(fog_vol.global_position.x, player.global_position.x), "FogVolume X matches player X")
	check(is_equal_approx(fog_vol.global_position.z, player.global_position.z), "FogVolume Z matches player Z")

	# 3. Simulate moving player
	print("Simulating player movement...")
	var original_pos: Vector3 = player.global_position
	player.global_position += Vector3(25.0, 0.0, 15.0)
	await process_frame

	check(is_equal_approx(fog_vol.global_position.x, player.global_position.x), "FogVolume X followed player to new position (+25m)")
	check(is_equal_approx(fog_vol.global_position.z, player.global_position.z), "FogVolume Z followed player to new position (+15m)")

	# 4. Test immediate finish / full density reached
	forest.finish_fog_transition_immediately()
	var mat: ShaderMaterial = fog_vol.material as ShaderMaterial
	check(mat != null, "FogVolume has active ShaderMaterial")
	if mat != null:
		var density = mat.get_shader_parameter("base_density")
		check(density != null and float(density) > 0.5, "Fog density faded in successfully (density: %s)" % str(density))

	forest.queue_free()
	await process_frame

	print("=== Starting Forest Fog Volume Smoke Test Completed with %d failures ===" % failures)
	quit(1 if failures > 0 else 0)
