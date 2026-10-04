extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, msg: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + msg)
	if not condition:
		failures += 1

func run() -> void:
	print("=== Testing Teleport Ground Surface & Fall Prevention ===")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await physics_frame
	await physics_frame

	var player := forest.get_node("Player") as FirstPersonPlayer
	player.inventory.add_item(&"map")
	var barrier := forest.get_node("Interactables/BarrierTree") as InteractableBlock3D
	var teleport := forest.get_node("ClimbOverTeleport") as Node3D

	# Find expected ground Y at teleport location via raycast
	var space_state: PhysicsDirectSpaceState3D = forest.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(teleport.global_position.x, 5.0, teleport.global_position.z),
		Vector3(teleport.global_position.x, -5.0, teleport.global_position.z)
	)
	var ray_res: Dictionary = space_state.intersect_ray(query)
	var expected_ground_y: float = ray_res["position"].y
	print("Expected road ground Y: ", expected_ground_y)

	# Set fast fade durations
	barrier.climb_fade_out_duration = 0.05
	barrier.climb_black_hold_duration = 0.05
	barrier.climb_fade_in_duration = 0.05

	# Interact with barrier
	barrier.cooldown = 0.0
	barrier._is_cooling_down = false
	barrier.interact(player)
	await process_frame

	var balloon := forest.find_child("BottomDialogueBalloon", true, false) as BottomDialogueBalloon
	check(is_instance_valid(balloon), "Dialogue balloon appeared")

	# Skip lines to line 3 (responses)
	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	balloon.next(balloon.dialogue_line.next_id)
	await process_frame
	if balloon.dialogue_label.is_typing: balloon.dialogue_label.skip_typing()
	await process_frame

	var responses_menu := balloon.get_node("%ResponsesMenu") as DialogueResponsesMenu
	check(responses_menu.visible, "Responses menu is visible")

	# Confirm 'Yes' via E key
	var e_event := InputEventKey.new()
	e_event.keycode = KEY_E
	e_event.pressed = true
	balloon._unhandled_input(e_event)
	await process_frame

	check(barrier._is_climbing_over, "Climb over started")
	check(player.is_frozen, "Player is frozen during climb over")

	# Wait for fade and teleport to complete
	await create_timer(0.25).timeout
	await physics_frame
	await physics_frame

	check(not barrier._is_climbing_over, "Climb over transition completed")
	check(not player.is_frozen, "Player is unfrozen")

	print("Player final pos: ", player.global_position)
	print("Player final velocity: ", player.velocity)
	print("Player is_on_floor: ", player.is_on_floor())

	var y_diff: float = absf(player.global_position.y - expected_ground_y)
	check(y_diff < 0.05, "Player Y is directly on the surface (diff: %.4f m)" % y_diff)

	# Now run 20 physics frames and check if player drops/falls
	var y_before: float = player.global_position.y
	for i in range(20):
		await physics_frame

	var y_after: float = player.global_position.y
	var fall_amount: float = absf(y_after - y_before)
	print("Y before 20 frames: %.4f, after: %.4f, fall_amount: %.4f" % [y_before, y_after, fall_amount])
	check(fall_amount < 0.02, "Player did not fall down after unfreezing (fall: %.4f m)" % fall_amount)
	check(player.is_on_floor(), "Player remains securely on floor")
	check(absf(player.velocity.y) < 0.1, "Player vertical velocity is zero / stable")

	print("\nTest completed with ", failures, " failure(s).")
	if failures == 0:
		print("ALL TELEPORT SURFACE CHECKS PASSED!")
	quit(failures)
