extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Post-Teleport Dialogue Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var forest_scene: PackedScene = load("res://scenes/chapters/main/starting_forest.tscn")
	check(forest_scene != null, "starting_forest.tscn loaded successfully")
	if forest_scene == null:
		quit(1)
		return

	var forest: StartingForest = forest_scene.instantiate() as StartingForest
	root.add_child(forest)
	current_scene = forest
	await process_frame
	await process_frame

	var player: FirstPersonPlayer = forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in scene")
	player.unfreeze()

	var barrier: InteractableBlock3D = forest.get_node_or_null("Interactables/BarrierTree") as InteractableBlock3D
	check(is_instance_valid(barrier), "BarrierTree found in scene")

	var teleport: Node3D = forest.get_node_or_null("ClimbOverTeleport") as Node3D
	check(is_instance_valid(teleport), "ClimbOverTeleport marker found in scene")

	# Verify export defaults
	check(barrier.trigger_post_teleport_dialogue == true, "trigger_post_teleport_dialogue is true by default")
	check(barrier.post_teleport_dialogue_cue == "visitor_center_barrier_post_teleport", "post_teleport_dialogue_cue is visitor_center_barrier_post_teleport")
	check(barrier.post_teleport_single_line_dialogue == "Placeholder text.", "post_teleport_single_line_dialogue default is 'Placeholder text.'")

	# Set fast fade intervals for test execution
	barrier.climb_fade_out_duration = 0.05
	barrier.climb_black_hold_duration = 0.05
	barrier.climb_fade_in_duration = 0.05

	# Add map to player inventory so barrier tree can be climbed
	player.inventory.add_item(&"map")

	# Test 1: Teleport across barrier triggers post-teleport placeholder dialogue
	print("--- Test 1: Full teleport sequence triggers post-teleport placeholder dialogue ---")
	barrier.climb_over_barrier(player)
	check(barrier._is_climbing_over, "BarrierTree initiated climb-over sequence")
	check(player.is_frozen, "Player is frozen during climb-over transition")

	# Wait for fade sequence to complete (0.05 + 0.05 + 0.05 = 0.15s)
	await create_timer(0.25).timeout
	await process_frame

	check(not barrier._is_climbing_over, "Climb over transition completed")
	check(player.global_position.distance_to(teleport.global_position) < 1.0, "Player teleported to destination across barrier")

	# Find post-teleport dialogue balloon
	var post_balloon := _get_latest_balloon(forest)
	check(is_instance_valid(post_balloon), "Post-teleport dialogue balloon spawned")
	if is_instance_valid(post_balloon):
		# Wait for dialogue_line to load
		for i in range(10):
			if post_balloon.dialogue_line != null:
				break
			await process_frame

		check(post_balloon.dialogue_line != null, "Post-teleport dialogue line is valid")
		if post_balloon.dialogue_line != null:
			check(post_balloon.dialogue_line.text.contains("Placeholder text") or not post_balloon.dialogue_line.text.is_empty(), "Post-teleport dialogue text is present (got: '%s')" % post_balloon.dialogue_line.text)
			check(post_balloon.dialogue_line.character.to_lower() == "thomas", "Speaker is Thomas")

		check(player.is_frozen, "Player is frozen while post-teleport dialogue is active")

		# Advance / end dialogue
		post_balloon._end_dialogue()
		await process_frame
		await process_frame

		check(not player.is_frozen, "Player is unfrozen after dismissing post-teleport dialogue")

	# Test 2: Verify custom fallback single-line dialogue on block with no cue
	print("--- Test 2: Fallback single-line dialogue when cue is missing ---")
	var custom_block := InteractableBlock3D.new()
	custom_block.name = "CustomClimbBlock"
	custom_block.trigger_post_teleport_dialogue = true
	custom_block.post_teleport_dialogue_cue = "non_existent_cue"
	custom_block.post_teleport_single_line_dialogue = "Custom fallback placeholder line."
	custom_block.post_teleport_speaker_name = "Narrator"
	forest.add_child(custom_block)

	custom_block.play_post_teleport_dialogue(player)
	await process_frame

	var fallback_balloon := _get_latest_balloon(forest)
	check(is_instance_valid(fallback_balloon), "Fallback balloon spawned for custom single-line dialogue")
	if is_instance_valid(fallback_balloon):
		for i in range(10):
			if fallback_balloon.dialogue_line != null:
				break
			await process_frame

		check(fallback_balloon.dialogue_line != null, "Fallback dialogue line created")
		if fallback_balloon.dialogue_line != null:
			check(fallback_balloon.dialogue_line.text == "Custom fallback placeholder line.", "Fallback dialogue line text matches custom single-line")
			check(fallback_balloon.dialogue_line.character == "Narrator", "Fallback speaker matches Narrator")

		fallback_balloon._end_dialogue()
		await process_frame

	custom_block.queue_free()

	# Test 3: Disabled trigger_post_teleport_dialogue does not spawn dialogue
	print("--- Test 3: trigger_post_teleport_dialogue = false ---")
	barrier.trigger_post_teleport_dialogue = false
	barrier.finish_climb_over_immediately()
	await process_frame

	var disabled_balloon := _get_latest_balloon(forest)
	check(disabled_balloon == null, "No dialogue balloon spawned when trigger_post_teleport_dialogue is false")
	check(not player.is_frozen, "Player remains unfrozen when post-teleport dialogue is disabled")

	forest.queue_free()
	await process_frame

	print("--- Post-Teleport Dialogue Smoke Test Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d failures" % failures)
		quit(1)

func _get_latest_balloon(parent: Node) -> BottomDialogueBalloon:
	var balloons: Array = []
	for child in parent.get_children():
		if child is BottomDialogueBalloon and child != parent.get_node_or_null("BottomDialogueBalloon") and not child.is_queued_for_deletion() and child.visible:
			balloons.append(child)
	return balloons.back() if balloons.size() > 0 else null
