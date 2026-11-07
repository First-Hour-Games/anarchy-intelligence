extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func run() -> void:
	# Use the authored forest block without running foliage or the opening cutscene.
	var forest := (load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene).instantiate()
	var barrier := forest.get_node("Interactables/BarrierTree") as InteractableBlock3D
	var authored_transform: Transform3D = forest.transform * barrier.get_parent().transform * barrier.transform
	barrier.get_parent().remove_child(barrier)
	forest.free()
	root.add_child(barrier)
	barrier.global_transform = authored_transform
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	var detector := player.get_node("InteractionDetector") as InteractionDetector
	await process_frame
	check(barrier.proximity_prompt, "only authored log opts into proximity prompt")
	check(is_equal_approx(barrier.global_basis.get_scale().x, 1.0), "log interaction distances use world-scale units")
	for offset: float in [-5.0, 0.0, 5.0]:
		player.global_position = barrier.to_global(Vector3(0.0, -1.2, -10.0))
		detector._process(0.0)
		player.global_position = barrier.to_global(Vector3(offset, -1.2, -2.0))
		var anchor := barrier.get_prompt_world_position_for(player)
		var local_anchor := barrier.to_local(anchor)
		check(is_equal_approx(local_anchor.x, offset) and is_equal_approx(local_anchor.z, -barrier.size.z * 0.5), "floating prompt follows nearest log edge across width")
		check(is_equal_approx(anchor.y, player.camera.global_position.y), "floating prompt matches player eye height")
		player.look_at(Vector3(anchor.x, player.global_position.y, anchor.z))
		detector._process(0.0)
		check(detector.viewmodel.interaction_prompt_should_show, "floating prompt appears when facing nearby edge")
		detector.viewmodel._update_interaction_prompt_fade(1.0)
		var prompt := detector.viewmodel.interaction_prompt
		check((prompt.position + prompt.size * 0.5).distance_to(player.camera.unproject_position(anchor)) < 0.01, "prompt projects from world edge rather than fixed screen position")
		for yaw: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
			player.rotation.y = yaw
			detector._process(0.0)
			check(detector.current_interactable == barrier, "log selected across width %.1f, facing %.2f" % [offset, yaw])
			var expected_visible := not player.camera.is_position_behind(anchor)
			if expected_visible:
				expected_visible = detector._get_gameplay_screen_rect().has_point(player.camera.unproject_position(anchor))
			check(detector.viewmodel.interaction_prompt_should_show == expected_visible, "world prompt hides when its anchor leaves camera view")
			check(detector._get_prompt_position(barrier).is_equal_approx(anchor), "rotating camera keeps world anchor pinned")
		player.global_position += barrier.global_basis.x * 0.4
		player.get_node("Head").position.y -= 0.3
		detector._process(0.0)
		check(detector._get_prompt_position(barrier).is_equal_approx(anchor), "walking and changing camera height keep world anchor pinned")
		player.get_node("Head").position.y += 0.3
	# A brief look away preserves the point until its fade completes.
	var previous_anchor := detector._get_prompt_position(barrier)
	player.look_at(Vector3(previous_anchor.x, player.global_position.y, previous_anchor.z))
	detector._process(0.0)
	detector.viewmodel._update_interaction_prompt_fade(1.0)
	player.rotation.y += PI
	detector._process(0.0)
	detector.viewmodel._update_interaction_prompt_fade(0.05)
	detector._process(0.0)
	check(detector._pinned_interactable == barrier and detector._get_prompt_position(barrier).is_equal_approx(previous_anchor), "partial look-away fade keeps original pin")
	detector.viewmodel._update_interaction_prompt_fade(1.0)
	detector._process(0.0)
	check(detector._pinned_interactable == null, "completed look-away fade releases pin without leaving range")
	player.global_position += barrier.global_basis.x * 0.5
	var next_anchor := barrier.get_prompt_world_position_for(player)
	player.look_at(Vector3(next_anchor.x, player.global_position.y, next_anchor.z))
	detector._process(0.0)
	check(not next_anchor.is_equal_approx(previous_anchor) and detector._get_prompt_position(barrier).is_equal_approx(next_anchor), "looking back pins a fresh nearest point at current position")
	player.global_position = barrier.to_global(Vector3(2.0, -1.2, 0.2))
	var inside_anchor := barrier.to_local(barrier.get_prompt_world_position_for(player))
	check(is_equal_approx(inside_anchor.x, 2.0) and is_equal_approx(inside_anchor.z, barrier.size.z * 0.5), "inside area still anchors prompt to nearest perimeter")
	player.global_position = barrier.to_global(Vector3(5.0, -1.2, -2.0))
	detector._process(0.0)
	# Exercise the real detector-to-block interaction path from the outer edge.
	barrier.dialogue_resource = null
	barrier.cooldown = 0.0
	var interactions: Array[int] = [0]
	barrier.interacted.connect(func(_player: Node3D) -> void: interactions[0] += 1)
	check(detector.try_interact() and interactions[0] == 1, "interaction works from outer log approach area")
	barrier._is_dialogue_active = true
	check(not detector.try_interact(), "active dialogue still blocks repeat interaction")
	barrier._is_dialogue_active = false
	player.global_position = barrier.to_global(Vector3(0, -1.2, -5.0))
	detector._process(0.0)
	check(detector.current_interactable == null and not detector.viewmodel.interaction_prompt_should_show, "prompt clears when too far from log")
	player.global_position = barrier.to_global(Vector3(10, -1.2, -2.0))
	check(not barrier.can_interact(player), "interaction area ends beyond log width")
	barrier.disable()
	var ordinary := Interactable3D.new()
	root.add_child(ordinary)
	ordinary.visual_target_path = NodePath(".")
	ordinary.global_position = player.camera.global_position + player.camera.global_basis.z
	check(not ordinary.proximity_prompt and detector._find_nearest_interactable() == null, "ordinary objects retain on-screen targeting requirement")
	ordinary.queue_free()
	barrier.queue_free()
	player.queue_free()
	await process_frame
	print("log_interaction_area_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures else 0)
