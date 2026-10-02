extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1

func run_test() -> void:
	print("--- INTERACTABLE BLOCK TESTS ---")

	var block_scene: PackedScene = load("res://scenes/interaction/interactable_block.tscn")
	check(block_scene != null, "interactable_block.tscn loads successfully")

	var block: InteractableBlock3D = block_scene.instantiate() as InteractableBlock3D
	block.cooldown = 0.0 # disable cooldown for rapid test calls
	root.add_child(block)
	await process_frame

	check(block.is_in_group(&"interactable"), "block automatically registers in interactable group")
	check(block.size == Vector3(1.5, 2.0, 0.8), "default size is 1.5, 2.0, 0.8")

	block.position = Vector3(10, 0, 5)
	block.prompt_offset = Vector3(0, 1.2, 0)
	check(block.get_prompt_world_position().is_equal_approx(Vector3(10, 1.2, 5)), "prompt world position matches world transform + prompt_offset")

	# Mock interactor / player
	var dummy_interactor := Node3D.new()
	dummy_interactor.position = Vector3(10, 1.2, 5.5)
	root.add_child(dummy_interactor)
	await process_frame

	check(block.can_interact(dummy_interactor), "dummy interactor can interact when near box")

	dummy_interactor.position = Vector3(10, 1.2, 20.0) # far away
	check(not block.can_interact(dummy_interactor), "dummy interactor cannot interact when far from box")

	# Test custom callback
	dummy_interactor.position = Vector3(10, 1.2, 5.5)
	var callback_called := [false]
	block.custom_callback = func(who: Node3D) -> void:
		callback_called[0] = true
		check(who == dummy_interactor, "custom_callback receives interactor parameter")

	var triggered_signal_received := [false]
	block.triggered.connect(func(who: Node3D) -> void:
		triggered_signal_received[0] = true
	)

	block.interact(dummy_interactor)
	check(callback_called[0], "interact() executes custom_callback")
	check(triggered_signal_received[0], "interact() emits triggered signal")

	# Test single-use (trigger_once)
	block.trigger_once = true
	block.interact(dummy_interactor)
	check(not block.is_enabled, "trigger_once disables the block after interaction")
	check(not block.is_in_group(&"interactable"), "disabled block is removed from interactable group")

	# Test collision generation
	var solid_block: InteractableBlock3D = block_scene.instantiate() as InteractableBlock3D
	solid_block.has_collision = true
	solid_block.size = Vector3(2.0, 3.0, 1.0)
	root.add_child(solid_block)
	await process_frame

	var body := solid_block.get_node_or_null("CollisionBody") as StaticBody3D
	check(body != null, "has_collision creates StaticBody3D at runtime")
	var col_shape := solid_block.get_node_or_null("CollisionBody/CollisionShape3D") as CollisionShape3D
	check(col_shape != null and col_shape.shape is BoxShape3D, "has_collision creates BoxShape3D")
	if col_shape and col_shape.shape is BoxShape3D:
		check((col_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(2.0, 3.0, 1.0)), "collision box size matches block size")

	# Test dialogue trigger
	var dialogue_block: InteractableBlock3D = block_scene.instantiate() as InteractableBlock3D
	dialogue_block.single_line_dialogue = "The doors are locked."
	dialogue_block.speaker_name = "Thomas"
	dialogue_block.position = dummy_interactor.position
	root.add_child(dialogue_block)
	await process_frame

	dialogue_block.interact(dummy_interactor)
	await process_frame

	var balloon := root.get_node_or_null("BottomDialogueBalloon") as BottomDialogueBalloon
	check(balloon != null, "interact() with single_line_dialogue spawned BottomDialogueBalloon")
	if balloon:
		check(balloon.dialogue_line != null, "dialogue line is active")
		if balloon.dialogue_line:
			check(balloon.dialogue_line.text == "The doors are locked.", "dialogue text is 'The doors are locked.'")
		balloon.next("")
		await process_frame

	print("--- TEST SUMMARY: failures=", failures, " ---")
	quit(1 if failures > 0 else 0)
