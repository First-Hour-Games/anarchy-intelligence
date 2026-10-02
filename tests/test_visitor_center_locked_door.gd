extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func run_test() -> void:
	print("--- VISITOR CENTER LOCKED DOOR TEST ---")

	var forest_scene: PackedScene = load("res://scenes/chapters/main/starting_forest.tscn")
	check(forest_scene != null, "starting_forest.tscn loads successfully")

	var forest = forest_scene.instantiate()
	root.add_child(forest)
	current_scene = forest
	await process_frame

	var door_block := forest.get_node_or_null("welcomeCenterTextured2/VisitorCenterLockedDoor") as InteractableBlock3D
	check(door_block != null, "welcomeCenterTextured2 has VisitorCenterLockedDoor child")
	if not door_block:
		print("FAIL: Cannot continue without VisitorCenterLockedDoor")
		quit(1)
		return

	check(door_block.is_in_group(&"interactable"), "door block is in 'interactable' group")
	check(door_block.size == Vector3(2.6, 2.4, 0.8), "door block size is (2.6, 2.4, 0.8)")
	check(door_block.interaction_distance >= 2.5, "interaction_distance is >= 2.5")

	var prompt_pos := door_block.get_prompt_world_position()
	print("Prompt world pos: ", prompt_pos)
	check(prompt_pos.distance_to(Vector3(-270.885, 1.467, -8.245)) < 0.2, "prompt world position is at visitor center entrance")

	# Mock player approaching door
	var player_mock := Node3D.new()
	player_mock.name = "MockPlayer"
	player_mock.position = prompt_pos + Vector3(0, 0, 1.5) # 1.5m in front of door
	forest.add_child(player_mock)
	await process_frame

	# Dismiss intro monologue first
	var intro_balloon := forest.get_node_or_null("BottomDialogueBalloon") as BottomDialogueBalloon
	if intro_balloon:
		intro_balloon._end_dialogue()
		await process_frame
		check(not intro_balloon.balloon.visible, "intro balloon is now hidden after completion")

	check(door_block.can_interact(player_mock), "player standing in front of visitor center door can interact")

	player_mock.position = prompt_pos + Vector3(0, 0, 15.0) # far away in parking lot
	check(not door_block.can_interact(player_mock), "player far away cannot interact")

	# Move player back to door and interact
	player_mock.position = prompt_pos + Vector3(0, 0, 1.5)
	var signal_received := [false]
	door_block.interacted.connect(func(_who: Node3D) -> void:
		signal_received[0] = true
	)

	door_block.interact(player_mock)
	await process_frame

	check(signal_received[0], "interacting with door emitted interacted signal")

	# Find the newly spawned dialogue balloon (in root or forest)
	var balloons := root.find_children("*", "BottomDialogueBalloon", true, false)
	var active_balloon: BottomDialogueBalloon = null
	for b in balloons:
		var balloon := b as BottomDialogueBalloon
		if balloon != intro_balloon and balloon.dialogue_line != null:
			active_balloon = balloon
			break

	check(active_balloon != null, "Found active door dialogue balloon")
	if active_balloon:
		print("Active dialogue speaker: ", active_balloon.dialogue_line.character)
		print("Active dialogue text: ", active_balloon.dialogue_line.text)
		check(active_balloon.dialogue_line.text == "The doors are locked.", "dialogue text is 'The doors are locked.'")
		check(active_balloon.dialogue_line.character == "Thomas", "speaker is Thomas")
		active_balloon._end_dialogue()
		await process_frame

	print("--- TEST SUMMARY: failures=", failures, " ---")
	quit(1 if failures > 0 else 0)
