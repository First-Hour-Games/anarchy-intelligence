extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func run() -> void:
	print("--- Running Barrier Tree Dialogue Smoke Test ---")

	var packed_forest := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(packed_forest != null, "starting_forest.tscn loaded")

	var forest := packed_forest.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var player := forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in starting_forest")
	check(not player.inventory.has_item(&"map"), "Player starts WITHOUT town map")

	var barrier_tree := forest.get_node_or_null("Interactables/BarrierTree") as InteractableBlock3D
	check(is_instance_valid(barrier_tree), "BarrierTree interactable block found")

	var dm := Engine.get_singleton("DialogueManager")
	check(dm != null, "DialogueManager singleton active")

	var dialogue_res: DialogueResource = barrier_tree.dialogue_resource
	check(dialogue_res != null, "BarrierTree has dialogue resource")

	# Test 1: Without map item -> Evaluate next line from visitor_center_barrier
	var line_nomap: DialogueLine = await dialogue_res.get_next_dialogue_line("visitor_center_barrier", [barrier_tree, player])
	check(line_nomap != null, "Dialogue line retrieved for barrier without map")
	check("big tree blocking the road" in line_nomap.text, "Plays tree blocking line without map")
	check(line_nomap.responses.size() == 0, "No choices shown in nomap branch")

	# Advance to second and third line
	var line_nomap_2: DialogueLine = await dialogue_res.get_next_dialogue_line(line_nomap.next_id, [barrier_tree, player])
	check("climb over the log" in line_nomap_2.text, "Second line talks about climbing over log")
	var line_nomap_3: DialogueLine = await dialogue_res.get_next_dialogue_line(line_nomap_2.next_id, [barrier_tree, player])
	check("navigate easier" in line_nomap_3.text, "Third line suggests finding something to navigate easier")
	var line_nomap_end: DialogueLine = await dialogue_res.get_next_dialogue_line(line_nomap_3.next_id, [barrier_tree, player])
	check(line_nomap_end == null, "Dialogue ends after third line when player has no map")

	# Test 2: Add map item -> Evaluate next line from visitor_center_barrier
	player.inventory.add_item(&"map")
	check(player.inventory.has_item(&"map"), "Player now has map in inventory")
	check(player.has_item(&"map"), "player.has_item('map') returns true")
	check(barrier_tree.has_item(&"map"), "barrier_tree.has_item('map') returns true")

	var line_map: DialogueLine = await dialogue_res.get_next_dialogue_line("visitor_center_barrier", [barrier_tree, player])
	check(line_map != null, "Dialogue line retrieved for barrier with map")
	check("big tree blocking the road" in line_map.text, "Plays tree blocking line with map")

	var line_map_2: DialogueLine = await dialogue_res.get_next_dialogue_line(line_map.next_id, [barrier_tree, player])
	check("climb over the log" in line_map_2.text, "Second line talks about climbing over log")

	var line_map_3: DialogueLine = await dialogue_res.get_next_dialogue_line(line_map_2.next_id, [barrier_tree, player])
	check("Should I proceed?" in line_map_3.text, "Third line asks 'Should I proceed?'")
	check(line_map_3.responses.size() == 2, "Presents 2 choices (Yes and No)")

	var response_yes: DialogueResponse = null
	var response_no: DialogueResponse = null
	for resp in line_map_3.responses:
		if resp.text == "Yes":
			response_yes = resp
		elif resp.text == "No":
			response_no = resp

	check(response_yes != null, "Response 'Yes' is available")
	check(response_no != null, "Response 'No' is available")

	# Test selecting 'No' -> dialogue ends
	if response_no != null:
		var line_after_no: DialogueLine = await dialogue_res.get_next_dialogue_line(response_no.next_id, [barrier_tree, player])
		check(line_after_no == null, "Selecting 'No' ends the dialogue cleanly")

	# Test 3: Test direct interact() call spawning balloon without map
	player.global_position = barrier_tree.global_position
	player.inventory._items = [PlayerInventory.EMPTY_ITEM, PlayerInventory.EMPTY_ITEM, PlayerInventory.EMPTY_ITEM, PlayerInventory.EMPTY_ITEM, PlayerInventory.EMPTY_ITEM, PlayerInventory.EMPTY_ITEM]
	barrier_tree.cooldown = 0.0
	barrier_tree._is_cooling_down = false
	barrier_tree.interact(player)
	await process_frame

	var balloon_nomap := _get_latest_balloon(forest)
	check(is_instance_valid(balloon_nomap), "Interact spawns BottomDialogueBalloon without map")
	if is_instance_valid(balloon_nomap):
		check(balloon_nomap.start_from_cue == "visitor_center_barrier_nomap", "Balloon started from visitor_center_barrier_nomap")
		balloon_nomap._end_dialogue()
		await process_frame

	# Test 4: Test direct interact() call spawning balloon WITH map
	player.inventory.add_item(&"map")
	barrier_tree.cooldown = 0.0
	barrier_tree._is_cooling_down = false
	barrier_tree.interact(player)
	await process_frame

	var balloon_map := _get_latest_balloon(forest)
	check(is_instance_valid(balloon_map), "Interact spawns BottomDialogueBalloon with map")
	if is_instance_valid(balloon_map):
		check(balloon_map.start_from_cue == "visitor_center_barrier_map", "Balloon started from visitor_center_barrier_map")
		balloon_map._end_dialogue()
		await process_frame

	# Test 5: ClimbOverTeleport node resolution and teleportation sequence
	var teleport_marker := forest.get_node_or_null("ClimbOverTeleport") as Node3D
	if not is_instance_valid(teleport_marker):
		teleport_marker = Marker3D.new()
		teleport_marker.name = "ClimbOverTeleport"
		forest.add_child(teleport_marker)
		teleport_marker.global_position = Vector3(-245.0, 0.25, 10.5)
		teleport_marker.global_rotation.y = -PI * 0.5

	var resolved_target := barrier_tree.get_climb_over_teleport_node()
	check(is_instance_valid(resolved_target), "barrier_tree finds ClimbOverTeleport node in scene")
	check(resolved_target == teleport_marker, "Resolved target matches ClimbOverTeleport instance")

	# Speed up fade intervals for test execution
	barrier_tree.climb_fade_out_duration = 0.05
	barrier_tree.climb_black_hold_duration = 0.05
	barrier_tree.climb_fade_in_duration = 0.05

	var player_pos_before := player.global_position
	check(player_pos_before.distance_to(teleport_marker.global_position) > 5.0, "Player is initially far from ClimbOverTeleport position")

	# Selecting 'Yes' triggers proceed() -> climb_over_barrier()
	if response_yes != null:
		var line_after_yes: DialogueLine = await dialogue_res.get_next_dialogue_line(response_yes.next_id, [barrier_tree, player])
		check(line_after_yes == null, "Selecting 'Yes' ends dialogue")
		await process_frame

		# Verify climb over is active
		check(barrier_tree._is_climbing_over, "BarrierTree marks climb over as active")
		check(player.get_meta("is_climbing_over", false), "Player meta marks is_climbing_over true during fade")
		check(player.is_frozen, "Player is frozen during climb over sequence")

		# Wait for the fade and teleport sequence to complete
		await create_timer(0.25).timeout
		await process_frame

		check(not barrier_tree._is_climbing_over, "Climb over finishes and resets state")
		check(not player.get_meta("is_climbing_over", false), "Player is_climbing_over meta cleared")
		check(player.global_position.distance_to(teleport_marker.global_position) < 0.1, "Player successfully teleported to ClimbOverTeleport position")
		check(current_scene == forest, "Scene remains in starting_forest (stays in current scene rather than loading map.tscn)")

		# Verify post-teleport dialogue with placeholder text
		var post_balloon := _get_latest_balloon(forest)
		check(is_instance_valid(post_balloon), "Post-teleport dialogue balloon spawned")
		if is_instance_valid(post_balloon):
			check(player.is_frozen, "Player is frozen while post-teleport dialogue is active")
			for i in range(10):
				if post_balloon.dialogue_line != null:
					break
				await process_frame
			check(post_balloon.dialogue_line != null, "Post-teleport dialogue line is valid")
			if post_balloon.dialogue_line != null:
				check(post_balloon.dialogue_line.text.contains("Placeholder text"), "Post-teleport dialogue line contains placeholder text (got: '%s')" % post_balloon.dialogue_line.text)
			post_balloon._end_dialogue()
			await process_frame
			check(not player.is_frozen, "Player is unfrozen after post-teleport dialogue ends")


	if is_instance_valid(forest):
		forest.queue_free()

	print("--- Barrier Tree Dialogue Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d errors" % failures)
		quit(1)


func _get_latest_balloon(parent: Node) -> BottomDialogueBalloon:
	var balloons: Array = []
	for child in parent.get_children():
		if child is BottomDialogueBalloon:
			balloons.append(child)
	return balloons.back() if balloons.size() > 0 else null

