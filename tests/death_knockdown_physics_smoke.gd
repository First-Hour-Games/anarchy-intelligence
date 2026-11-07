extends SceneTree
## The death knockdown's physics on a plain test floor: it starts at the gameplay camera, is
## pushed away from the attacker, stays above the floor and in front of a wall, stops at a
## bounded depth over a hole, blacks out into the phone game over on time, retries cleanly,
## never stacks rigs over repeated deaths, and survives the scene going away mid-fall.

var failures: int = 0
var world: Node3D
var player: FirstPersonPlayer
var health: Node
var attacker: Node3D
var scare_script: GDScript

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func rigs() -> int:
	return root.find_children("DeathFallRig", "RigidBody3D", true, false).size()

func box(size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cube := BoxShape3D.new()
	cube.size = size
	shape.shape = cube
	body.add_child(shape)
	world.add_child(body)
	body.global_position = at
	return body

func build(with_floor: bool, wall_behind: bool) -> void:
	world = Node3D.new()
	world.name = "KnockdownTestWorld"
	root.add_child(world)
	current_scene = world
	if with_floor:
		box(Vector3(40, 1, 40), Vector3(0, -0.5, 0))
	else:
		# A small ledge to stand on with nothing behind it.
		box(Vector3(1.2, 1, 1.2), Vector3(0, -0.5, 0))
	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	world.add_child(player)
	var combat := Node.new()
	combat.name = "CombatHealth"
	combat.set_script(load("res://scenes/player/combat_health.gd"))
	player.add_child(combat)
	health = combat
	player.set_physics_process(false)
	player.global_position = Vector3.ZERO
	# The attacker stands in front (-Z); the knockback goes toward +Z.
	attacker = Node3D.new()
	world.add_child(attacker)
	attacker.global_position = Vector3(0, 0, -1.4)
	player.look_at(Vector3(0, 0, -5))
	if wall_behind:
		box(Vector3(6, 4, 0.3), Vector3(0, 2, 0.45))

func teardown() -> void:
	world.queue_free()
	current_scene = null
	for i in 4:
		await process_frame

func run() -> void:
	scare_script = load("res://scenes/ui/death_scare.gd")
	var save_game := root.get_node("SaveGame")
	var original_dir: String = save_game.save_dir
	save_game.save_dir = "user://test_death_knockdown_no_saves"

	# Open floor: start, push, stay above the floor, timing, retry.
	build(true, false)
	await physics_frame
	health.take_damage(20.0, attacker)
	check(not health.is_dead and health.death_scare == null and health.daze > 0.0, "A non-lethal hit only dazes, as before")
	health.health = health.max_health
	health.immunity = 0.0
	var view: Transform3D = player.camera.global_transform
	var layers := player.collision_layer
	health.take_damage(health.max_health, attacker)
	var scare = health.death_scare
	check(scare != null and scare.rig != null and rigs() == 1, "A lethal hit starts one fall rig")
	check(scare.rig.global_position.is_equal_approx(view.origin), "The fall starts exactly at the gameplay camera")
	var initial_blur: float = scare._motion_blur.alpha
	check(initial_blur > 0.0 and initial_blur <= health.DAZE_BLUR, "The fall starts with hit-like motion blur")
	var lowest := INF
	var farthest := 0.0
	var spin := 0.0
	var peak_blur := initial_blur
	var start_ms := Time.get_ticks_msec()
	while health.game_over == null and Time.get_ticks_msec() - start_ms < 9000:
		await physics_frame
		peak_blur = maxf(peak_blur, scare._motion_blur.alpha)
		if is_instance_valid(scare.rig):
			lowest = minf(lowest, scare.rig.global_position.y)
			farthest = maxf(farthest, scare.rig.global_position.z)
			spin = maxf(spin, scare.rig.angular_velocity.length())
	var took := (Time.get_ticks_msec() - start_ms) / 1000.0
	check(farthest > 0.4, "The view is knocked back away from the attacker (%.2f m)" % farthest)
	# Contact can press the head in a few centimetres; the camera stays well clear of its near plane.
	check(lowest >= scare_script.HEAD_RADIUS - 0.06, "The view never sinks into the floor (lowest %.2f m)" % lowest)
	# Clamped before each step; a bounce can add a little within one.
	check(spin <= scare_script.MAX_SPIN * 1.3, "Spin stays bounded (%.1f rad/s)" % spin)
	check(health.game_over != null and took > 4.0 and took < 6.5, "Down, blackout, then the phone after %.1f s" % took)
	check(scare.settled, "The body came to rest before the blackout")
	check(peak_blur > health.DAZE_BLUR, "The fall builds to stronger motion blur than a hit")
	check(scare._defocus.get_shader_parameter(&"lod") >= 5.0, "The view reaches full defocus before the phone")
	check(scare._motion_blur.alpha == 0.0 and health.daze_blur.get(&"alpha") == 0.0, "The phone and gameplay camera are clear of death blur")
	if health.game_over != null:
		health.game_over.choose(0)
		for i in 180:
			if not health.is_dead:
				break
			await process_frame
	await process_frame
	check(not health.is_dead and not player.is_frozen and player.camera.current, "Retry gives back control and the gameplay camera")
	check(player.collision_layer == layers and rigs() == 0 and health.death_scare == null, "Retry restores collision and removes the rig")

	# Dying again straight away leaves no extra rig and still finishes.
	for round in 2:
		health.immunity = 0.0
		health.take_damage(health.max_health, attacker)
		check(rigs() == 1, "Death %d has exactly one rig" % (round + 2))
		await create_timer(5.4).timeout
		check(health.game_over != null, "Death %d reaches the phone" % (round + 2))
		if health.game_over != null:
			health.game_over.choose(0)
			for i in 180:
				if not health.is_dead:
					break
				await process_frame
		await process_frame
	check(rigs() == 0 and not player.is_frozen and player.is_processing_unhandled_input(), "Repeated deaths leave no rigs or disabled controls")
	await teardown()

	# Backed against a wall: the knockback must not carry the view through it.
	build(true, true)
	await physics_frame
	health.take_damage(health.max_health, attacker)
	scare = health.death_scare
	var deepest := -INF
	for i in 120:
		await physics_frame
		if is_instance_valid(scare.rig):
			deepest = maxf(deepest, scare.rig.global_position.z)
	check(deepest <= 0.3 - scare_script.HEAD_RADIUS + 0.03, "The view stays in front of the wall (%.2f m)" % deepest)
	await teardown()

	# Nothing under the knockback: the fall stops at its bound and the phone still comes.
	build(false, false)
	await physics_frame
	var top: float = player.camera.global_position.y
	health.take_damage(health.max_health, attacker)
	scare = health.death_scare
	await create_timer(5.4).timeout
	check(scare.settled and scare.rig.global_position.y >= top - scare_script.MAX_DROP - 0.5, "Falling off a ledge stops at a bounded depth")
	check(health.game_over != null, "The phone appears even when the fall has no floor")
	await teardown()

	# The scene goes away mid-fall (a load or the menu): nothing is left behind.
	build(true, false)
	await physics_frame
	health.take_damage(health.max_health, attacker)
	await create_timer(0.5).timeout
	await teardown()
	check(rigs() == 0, "Leaving the scene mid-fall frees the rig")

	save_game.save_dir = original_dir
	print("Death knockdown failures: ", failures)
	quit(1 if failures else 0)
