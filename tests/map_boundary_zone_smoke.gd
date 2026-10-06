extends SceneTree

const MapBoundaryZone = preload("res://scenes/zones/map_boundary_zone.gd")

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func _run() -> void:
	print("--- Running MapBoundaryZone Smoke Tests ---")

	# Test 1: Load and instantiate zone scene
	var zone_packed := load("res://scenes/zones/map_boundary_zone.tscn") as PackedScene
	check(zone_packed != null, "Load map_boundary_zone.tscn")

	var zone := zone_packed.instantiate() as MapBoundaryZone
	check(zone != null, "Instantiate MapBoundaryZone3D")
	root.add_child(zone)
	await process_frame

	# Test 2: Check shape sizing
	zone.size = Vector3(10.0, 4.0, 10.0)
	var col_shape := zone.get_node_or_null("CollisionShape3D") as CollisionShape3D
	check(col_shape != null and col_shape.shape is BoxShape3D, "CollisionShape3D exists with BoxShape3D")
	if col_shape and col_shape.shape is BoxShape3D:
		var box := col_shape.shape as BoxShape3D
		check(box.size == Vector3(10.0, 4.0, 10.0), "BoxShape3D size matches zone size")

	# Test 3: Point inside logic
	check(zone.is_point_inside(Vector3(0, 0, 0)), "Origin is inside zone")
	check(zone.is_point_inside(Vector3(4.0, 1.0, 4.0)), "Near border is inside zone")
	check(not zone.is_point_inside(Vector3(6.0, 0, 0)), "Outside X is detected outside")
	check(not zone.is_point_inside(Vector3(0, 0, 8.0)), "Outside Z is detected outside")

	# Test 4: Signals on body enter / exit
	var dummy_player := CharacterBody3D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group(&"player")
	dummy_player.position = Vector3.ZERO
	root.add_child(dummy_player)
	await process_frame

	var results := {
		"entered": false,
		"exited": false,
		"warning": false,
		"msg": ""
	}

	zone.player_entered_zone.connect(func(_p: Node3D) -> void:
		results["entered"] = true
	)
	zone.player_exited_zone.connect(func(_p: Node3D) -> void:
		results["exited"] = true
	)
	zone.boundary_warning_triggered.connect(func(_p: Node3D, msg: String) -> void:
		results["warning"] = true
		results["msg"] = msg
	)

	# Simulate player entering
	zone._on_body_entered(dummy_player)
	check(results["entered"], "player_entered_zone signal emitted")

	# Simulate player exiting
	dummy_player.global_position = Vector3(6.0, 0, 0)
	zone._on_body_exited(dummy_player)
	await process_frame
	check(results["exited"], "player_exited_zone signal emitted")
	check(results["warning"], "boundary_warning_triggered signal emitted on leaving play area")
	check(results["msg"].contains("should"), "Warning message contains expected dialogue text")

	# Test 5: Cooldown check
	results["warning"] = false
	zone._on_body_exited(dummy_player)
	check(not results["warning"], "Warning suppressed during cooldown")

	# Test 6: Blink and teleport inwards check
	check(zone.blink_and_return == true, "blink_and_return enabled by default")
	dummy_player.global_position = Vector3(12.0, 0.0, 0.0) # Player is outside +X
	var returned_pos := Vector3.ZERO
	zone.player_returned_to_bounds.connect(func(_p: Node3D, pos: Vector3) -> void:
		returned_pos = pos
	, CONNECT_ONE_SHOT)
	zone._teleport_player_inwards(dummy_player)
	# Half size is 5.0 (size is 10.0), teleport_inset is 1.5, so X should be clamped to 3.5
	check(dummy_player.global_position.x <= 3.51 and dummy_player.global_position.x >= 3.49, "Player teleported inside boundary edge (X ≈ 3.5)")
	# Center is at 0,0,0, player is at +X, inward direction is -X (West). Facing -X means target_yaw is PI/2 (approx 1.57 rad)
	var expected_yaw := PI / 2.0
	check(absf(dummy_player.rotation.y - expected_yaw) < 0.05, "Player rotated to face inwards towards zone center")

	# Test 7: Load full zone_test.tscn scene
	var test_scene_packed := load("res://scenes/zones/zone_test.tscn") as PackedScene
	check(test_scene_packed != null, "Load zone_test.tscn")
	var test_scene := test_scene_packed.instantiate()
	check(test_scene != null, "Instantiate zone_test.tscn")
	root.add_child(test_scene)
	await process_frame
	test_scene.queue_free()

	# Cleanup
	zone.queue_free()
	dummy_player.queue_free()
	await process_frame

	print("--- Smoke Test Completed: %d failures ---" % failures)
	quit(0 if failures == 0 else 1)
