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
	player.position = Vector3(4, 0, 0)
	world.add_child(player)
	var health := load("res://scenes/player/combat_health.gd").new() as Node
	health.name = "CombatHealth"
	player.add_child(health)

	var enemy := load("res://scenes/monsters/corrupted_friend/corrupted_friend.tscn").instantiate() as CharacterBody3D
	world.add_child(enemy)
	enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	enemy.target = player
	enemy.watch_requires_line_of_sight = false
	enemy.watch_turn_speed = 100.0
	check(enemy.watch_only, "Watcher defaults to watch-only behavior")
	check(enemy.watch_distance == 20.0, "Watcher has a useful observation radius")
	check(enemy.watch_follow_speed == 0.85, "Passive follow speed stays slow")

	var start_position := Vector2(enemy.global_position.x, enemy.global_position.z)
	for iteration in 30:
		enemy._physics_process(0.1)
	var end_position := Vector2(enemy.global_position.x, enemy.global_position.z)
	var target_direction := (player.global_position - enemy.global_position).normalized()
	var forward := -enemy.global_basis.z.normalized()
	check(enemy.watching_player, "Watcher notices a nearby player")
	check(forward.dot(target_direction) > 0.95, "Watcher turns to face the player")
	check(start_position.distance_to(end_position) > 0.2, "Watcher slowly follows a distant player")
	check(enemy.velocity.length() > 0.1, "Passive watcher has visible walking motion")

	enemy.damage_enabled = true
	player.position = enemy.position + Vector3(0, 0, -1.0)
	for iteration in 30:
		enemy._physics_process(0.1)
	check(health.health == 100.0, "Watch-only enemy never damages the player")
	check(enemy.state == enemy.State.DORMANT, "Watch-only enemy never enters an attack state")

	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(4, 3, 0.5)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1.5, -2.0)
	player.position = Vector3(0, 0, -4.0)
	world.add_child(wall)
	await physics_frame
	await physics_frame
	enemy.watch_requires_line_of_sight = true
	check(not enemy._can_watch_target(), "World geometry can block the watcher's gaze")
	wall.queue_free()
	await physics_frame
	await physics_frame

	var visual := enemy.get_node("Visual")
	check(visual.use_3d_model and visual.model.visible, "Animated Yeti is the active visual")
	check(not visual.previous_bear.visible, "Previous bear starts hidden")
	check(not visual.sprite_fallback.visible, "Legacy sprite fallback starts hidden")
	var animation_player := _find_animation_player(visual.model)
	check(animation_player != null, "Yeti imports with an AnimationPlayer")
	var expected_clips := PackedStringArray(["idle", "walk", "run", "windup", "attack", "hit", "death"])
	var available_clips: PackedStringArray = visual.get_available_model_clips()
	for clip_name in expected_clips:
		check(clip_name in available_clips, "Yeti resolves the %s clip" % clip_name)
	for clip_name in ["idle", "walk", "run"]:
		check(
			animation_player.get_animation(clip_name).loop_mode == Animation.LOOP_LINEAR,
			"Yeti loops the %s clip" % clip_name
		)
	for clip_name in ["windup", "attack", "hit", "death"]:
		check(
			animation_player.get_animation(clip_name).loop_mode == Animation.LOOP_NONE,
			"Yeti keeps the %s clip as a one-shot" % clip_name
		)
	var model_meshes: Array[MeshInstance3D] = []
	_collect_meshes(visual.model, model_meshes)
	check(model_meshes.size() == 1, "Yeti imports as one efficient skinned mesh")
	if not model_meshes.is_empty():
		var model_mesh := model_meshes[0]
		var triangle_count := 0
		for surface_index in model_mesh.mesh.get_surface_count():
			var indices := model_mesh.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_INDEX] as PackedInt32Array
			triangle_count += indices.size() / 3
		check(triangle_count > 1000 and triangle_count < 60000, "Yeti stays inside the prototype triangle budget")
		check(model_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Yeti casts world and flashlight shadows")
		var material := model_mesh.get_active_material(0)
		check(material is BaseMaterial3D and material.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "Yeti material responds to lighting")
	visual.play("walk", true)
	check(animation_player != null and animation_player.current_animation == "walk", "Watcher movement plays the real walk clip")
	visual.set_use_previous_bear(true)
	check(not visual.model.visible and visual.previous_bear.visible, "Previous bear remains available as a fallback")
	visual.set_use_previous_bear(false)
	visual.set_use_3d_model(false)
	check(not visual.model.visible and visual.sprite_fallback.visible, "Legacy sprite fallback remains available")
	visual.set_use_3d_model(true)

	# The old pursuit/combat controller remains opt-in for future enemy variants,
	# but the placed watcher never enters this mode by default.
	enemy.watch_only = false
	enemy.reset_enemy()
	enemy.target = player
	player.position = enemy.position + Vector3(0, 0, -1.2)
	enemy.damage_enabled = true
	enemy._enter(enemy.State.WINDUP, 0.0)
	enemy._physics_process(0.016)
	check(health.health == 75.0, "Legacy combat remains available only when watch-only is disabled")

	if "--capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.05, 0.06, 0.08)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.55
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-55, -30, 0)
		light.light_energy = 1.0
		world.add_child(light)
		var camera := Camera3D.new()
		world.add_child(camera)
		# The watcher faces the test player on -Z; capture from that side so the
		# screenshot validates the authored face rather than the back of its head.
		camera.position = Vector3(2.8, 1.45, -4.6)
		camera.look_at(Vector3(0, 1.0, 0))
		camera.current = true
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../watching-yeti.png")

	quit(1 if failures else 0)


func _collect_meshes(node: Node, result: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		result.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_meshes(child, result)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

