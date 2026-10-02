extends SceneTree

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(50, 1, 50)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)

	var player := CharacterBody3D.new()
	player.name = "Player"
	player.add_to_group("player")
	# Inside watch_distance but past watch_stop_distance (6.1), so the
	# watcher should notice, close in visibly, then settle near 6.1m out.
	player.position = Vector3(14.0, 0, 0)
	world.add_child(player)

	var enemy := load("res://scenes/monsters/the_ridgeback/the_ridgeback.tscn").instantiate() as CharacterBody3D
	world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	enemy.target = player
	enemy.watch_requires_line_of_sight = false
	enemy.watch_turn_speed = 100.0

	check(enemy.watch_only, "Ridgeback defaults to watch-only behavior")
	check(is_equal_approx(enemy.watch_distance, 1000.0), "Ridgeback retains town-wide tracking")
	check(is_equal_approx(enemy.watch_stop_distance, 6.1), "Ridgeback holds well short of the player")
	check(is_equal_approx(enemy.watch_follow_speed, 3.2), "Ridgeback matches the player's walk speed")
	check(is_equal_approx(enemy.watch_retreat_distance, 5.5), "Ridgeback has a standoff retreat threshold")

	var start_distance := enemy.global_position.distance_to(player.global_position)
	for iteration in 60:
		enemy._physics_process(0.1)
	var end_distance := enemy.global_position.distance_to(player.global_position)
	check(enemy.watching_player, "Ridgeback notices a player within range")
	check(end_distance < start_distance, "Ridgeback closes in somewhat once it notices")
	check(end_distance > enemy.watch_stop_distance - 0.5, "Ridgeback does not close past its stop distance")

	# Now invade its space from the other side and confirm it backs off to
	# hold the standoff radius instead of letting the player stand on top of it.
	player.position = enemy.global_position + Vector3(1.0, 0, 0)
	for iteration in 60:
		enemy._physics_process(0.1)
	var retreated_distance := enemy.global_position.distance_to(player.global_position)
	check(retreated_distance > 1.0, "Ridgeback backs away when the player gets too close")
	check(retreated_distance < enemy.watch_distance, "Ridgeback does not flee out of its own watch radius")

	var visual := enemy.get_node("Visual")
	var animation_player := _find_animation_player(visual.model)
	check(animation_player != null, "Ridgeback model imports with an AnimationPlayer")
	var expected_clips := PackedStringArray(["ManThing_IDLE", "ManThing_WALK", "ManThing_CHASE", "ManThing_NOTICE", "ManThing_ATTACK"])
	var available_clips: PackedStringArray = visual.get_available_model_clips()
	for clip_name in expected_clips:
		check(clip_name in available_clips, "Ridgeback resolves the %s clip" % clip_name)
	visual.play("alert", true)
	check(animation_player.current_animation == "ManThing_NOTICE", "Watching plays the notice clip")
	visual.play("walk", true)
	check(animation_player.current_animation == "ManThing_WALK", "Approaching plays the walk clip")
	check(animation_player.get_animation("ManThing_WALK").loop_mode == Animation.LOOP_LINEAR, "Walk clip loops")
	check(animation_player.get_animation("ManThing_ATTACK").loop_mode == Animation.LOOP_NONE, "Attack clip is a one-shot")
	visual.set_movement_speed(1.4)
	var slow_cadence: float = animation_player.speed_scale
	visual.set_movement_speed(3.8)
	check(animation_player.speed_scale > slow_cadence * 2.0, "Fast retreat increases leg cadence with travel speed")
	visual.set_movement_speed(0.0)
	check(is_zero_approx(animation_player.speed_scale), "Blocked movement stops the locomotion cycle")
	visual.play("attack", true)
	check(is_equal_approx(animation_player.speed_scale, 1.0), "Attack timing stays independent of movement speed")
	var wrapper := load("res://scenes/monsters/the_wrapper.tscn").instantiate() as Node3D
	check(is_equal_approx(absf(wrapper.get_node("Visual").rotation.y), PI), "Wrapper visual faces along its movement direction")
	wrapper.free()

	quit(1 if failures else 0)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
