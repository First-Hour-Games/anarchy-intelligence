extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1


func _initialize() -> void:
	print("--- Running Scene Start Frozen Floor Smoke Test ---")
	run.call_deferred()


func run() -> void:
	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "starting_forest.tscn loaded successfully")
	if packed_forest == null:
		quit(1)
		return

	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest

	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player node found in scene")
	if not is_instance_valid(player):
		quit(1)
		return

	# Frame 1: Scene start & initial frozen state
	await process_frame
	await physics_frame

	print("--- Test 1: Initial Scene Start & Frozen Floor State ---")
	check(player.is_frozen, "Player is frozen upon scene start")
	check(player.is_on_floor(), "Player is already on floor in frozen state on start")
	check(player.velocity.is_zero_approx(), "Player velocity is zero (not falling or moving)")

	# Raycast to find exact floor height
	var space_state: PhysicsDirectSpaceState3D = forest.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(player.global_position.x, player.global_position.y + 0.5, player.global_position.z),
		Vector3(player.global_position.x, player.global_position.y - 3.0, player.global_position.z)
	)
	query.exclude = [player.get_rid()]
	var res: Dictionary = space_state.intersect_ray(query)
	check(not res.is_empty(), "Ground surface detected directly beneath player")
	if not res.is_empty():
		var ground_y: float = float(res["position"].y)
		var y_diff: float = absf(player.global_position.y - ground_y)
		print("Player Y: %.4f, Ground Y: %.4f, Diff: %.4f m" % [player.global_position.y, ground_y, y_diff])
		check(y_diff < 0.02, "Player Y is directly on the floor surface (diff < 2 cm)")

	# Test 2: Stability during frozen state across multiple physics frames
	print("--- Test 2: Ground Stability During Frozen Hold ---")
	var start_y := player.global_position.y
	for i in range(15):
		await physics_frame

	check(player.is_frozen, "Player remains frozen during hold")
	check(player.is_on_floor(), "Player remains on floor during hold")
	var drift_amount := absf(player.global_position.y - start_y)
	check(drift_amount < 0.01, "Player position did not drift or fall during frozen hold (drift: %.4f m)" % drift_amount)

	# Test 3: Unfreezing transition produces no drop
	print("--- Test 3: Unfreeze Transition ---")
	var y_before_unfreeze := player.global_position.y
	player.unfreeze()
	for i in range(10):
		await physics_frame

	check(not player.is_frozen, "Player is unfrozen")
	check(player.is_on_floor(), "Player remains securely on floor after unfreezing")
	var unfreeze_drop := absf(player.global_position.y - y_before_unfreeze)
	check(unfreeze_drop < 0.01, "Player did not drop when unfreezing (drop: %.4f m)" % unfreeze_drop)

	forest.queue_free()
	await process_frame

	print("--- Scene Start Frozen Floor Smoke Test Complete ---")
	if failures == 0:
		print("ALL PASS")
	else:
		print("FAILED with %d errors" % failures)

	quit(failures)
