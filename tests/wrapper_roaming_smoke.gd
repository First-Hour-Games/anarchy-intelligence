extends SceneTree
## The roaming Wrapper's states on a flat test floor with its own navigation mesh:
## wandering near home, hearing by noise and distance, hunting while watched, escaping,
## returning home (interruptible), and staying dead.

var failures: int = 0
var wrapper  # untyped: its roaming properties are read directly
var player: FirstPersonPlayer

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func seconds(duration: float) -> void:
	await create_timer(duration, true, true).timeout

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

## Waits until condition holds or the time runs out; returns whether it held.
func wait_for(condition: Callable, timeout: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await physics_frame
	return condition.call()

## The imported mesh faces +Z. Compare its visible front against a world-space direction.
func facing_direction(direction: Vector3) -> float:
	var forward: Vector3 = wrapper.get_node("Visual").global_basis.z
	return Vector2(forward.x, forward.z).normalized().dot(Vector2(direction.x, direction.z).normalized())

func facing_player() -> float:
	return facing_direction(player.global_position - wrapper.global_position)

func place_player(offset: Vector3, moving: Vector3 = Vector3.ZERO, sprint: bool = false, crouch: bool = false) -> void:
	player.global_position = wrapper.global_position + offset
	player.velocity = moving
	player.is_sprinting = sprint
	player.is_crouching = crouch

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(120, 1, 120)
	floor_shape.shape = box
	floor_shape.position.y = -0.5
	floor.add_child(floor_shape)
	world.add_child(floor)
	var navigation := NavigationRegion3D.new()
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-60, 0, -60), Vector3(60, 0, -60), Vector3(60, 0, 60), Vector3(-60, 0, 60)])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	navigation.navigation_mesh = mesh
	world.add_child(navigation)

	player = (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	world.add_child(player)
	player.set_physics_process(false)
	player.global_position = Vector3(50, 0, 50)
	# Areas give their player combat health; this test floor does the same.
	var combat := Node.new()
	combat.name = "CombatHealth"
	combat.set_script(load("res://scenes/player/combat_health.gd"))
	player.add_child(combat)

	wrapper = (load("res://scenes/monsters/the_wrapper.tscn") as PackedScene).instantiate()
	wrapper.set("roaming", true)
	wrapper.set("freeze_when_watched", false)
	wrapper.set("wander_radius", 6.0)
	wrapper.set("wander_speed", 1.5)
	wrapper.set("wander_pause_min", 0.2)
	wrapper.set("wander_pause_max", 0.4)
	wrapper.set("escape_time", 1.0)
	var spawn_marker := Marker3D.new()
	spawn_marker.rotation.y = -PI / 2.0
	world.add_child(spawn_marker)
	spawn_marker.add_child(wrapper)
	wrapper.global_position = Vector3.ZERO
	wrapper.set("spawn", wrapper.global_transform)
	wrapper.set("home", Vector3.ZERO)
	wrapper.set("player", player)
	wrapper.set("enabled", true)
	var home: Vector3 = wrapper.home
	await seconds(0.3)

	# Wandering: it visits several reachable points, never far from home.
	var targets := {}
	var farthest := 0.0
	var deadline := Time.get_ticks_msec() + 9000
	while Time.get_ticks_msec() < deadline and targets.size() < 3:
		await physics_frame
		farthest = maxf(farthest, flat(wrapper.global_position, home))
		if wrapper.wander_target.is_finite():
			targets[wrapper.wander_target] = true
	check(targets.size() >= 3, "Wrapper wanders between destinations (%d)" % targets.size())
	check(farthest > 0.5 and farthest <= wrapper.wander_radius + 1.0, "Wandering stays within its radius of home (%.1f m)" % farthest)
	check(wrapper.roam_state == wrapper.RoamState.WANDERING, "A distant player is not detected")

	# Detection needs both noise and proximity.
	place_player(Vector3(1.5, 0, 0))
	check(not wrapper.hears_player(), "A stationary player right next to it is not heard")
	place_player(Vector3(5, 0, 0), Vector3(1.6, 0, 0), false, true)
	check(not wrapper.hears_player(), "Crouch-walking at 5 m is too quiet")
	place_player(Vector3(3, 0, 0), Vector3(1.6, 0, 0), false, true)
	check(wrapper.hears_player(), "Crouch-walking at 3 m is heard")
	place_player(Vector3(15, 0, 0), Vector3(3.2, 0, 0))
	check(not wrapper.hears_player(), "Walking at 15 m is out of hearing")
	place_player(Vector3(15, 0, 0), Vector3(4.8, 0, 0), true)
	check(wrapper.hears_player(), "Sprinting at 15 m is heard")
	place_player(Vector3(25, 0, 0), Vector3(4.8, 0, 0), true)
	check(not wrapper.hears_player(), "Sprinting beyond the detection distance is not heard")
	place_player(Vector3(8, 0, 0))
	await seconds(0.3)
	check(wrapper.roam_state == wrapper.RoamState.WANDERING, "A silent player nearby stays undetected")
	# Heard from behind, so it has to turn round to the player.
	var behind: Vector3 = wrapper.global_basis.z
	behind.y = 0.0
	place_player(behind.normalized() * 7.0, Vector3(3.2, 0, 0))
	await physics_frame
	await physics_frame
	check(wrapper.roam_state == wrapper.RoamState.HUNTING, "A walking player nearby starts the hunt")
	player.velocity = Vector3.ZERO
	# It turns to the player while it screams, before it moves.
	await seconds(0.6)
	check(facing_player() > 0.95, "It turns to face the player while it screams (%.2f)" % facing_player())

	# Hunting: it keeps moving while watched, then attacks.
	player.look_at(Vector3(wrapper.global_position.x, player.global_position.y, wrapper.global_position.z))
	player.head.look_at(wrapper.global_position + Vector3.UP * 1.4)
	await physics_frame
	check(wrapper.is_watched_by_player(), "The player is watching the Wrapper")
	var gap := flat(wrapper.global_position, player.global_position)
	await seconds(2.0)
	check(flat(wrapper.global_position, player.global_position) < gap - 1.0, "It closes in while watched")
	check(facing_direction(wrapper.get_real_velocity()) > 0.95, "Its visible front points along its movement under a rotated spawn marker")
	var health := player.get_node("CombatHealth")
	var full: float = health.health
	check(await wait_for(func() -> bool: return health.health < full, 10.0), "It reaches and strikes the player")
	check(facing_player() > 0.95, "It faces the player as it strikes (%.2f)" % facing_player())
	check(wrapper.get_node("HuntAudio").playing or wrapper.is_hunting(), "Hunting drives the hunt music")

	# Escape: far away for escape_time ends the hunt and sends it home, not to a wander point.
	player.global_position = wrapper.global_position + Vector3(30, 0, 0)
	await seconds(0.5)
	check(wrapper.roam_state == wrapper.RoamState.HUNTING, "A brief escape does not end the hunt")
	check(await wait_for(func() -> bool: return wrapper.roam_state == wrapper.RoamState.RETURNING, 3.0), "Staying beyond the escape distance ends the hunt")
	check(wrapper.home.is_equal_approx(home), "Home is still where it was placed")

	# Detection interrupts the walk home.
	player.global_position = wrapper.global_position + Vector3(6, 0, 0)
	player.velocity = Vector3(3.2, 0, 0)
	await physics_frame
	await physics_frame
	check(wrapper.roam_state == wrapper.RoamState.HUNTING, "Noise interrupts the walk home")
	player.velocity = Vector3.ZERO
	player.global_position = Vector3(50, 0, 50)
	check(await wait_for(func() -> bool: return wrapper.roam_state == wrapper.RoamState.RETURNING, 3.0), "Escaping again sends it home")
	check(await wait_for(func() -> bool: return wrapper.roam_state == wrapper.RoamState.WANDERING, 25.0), "It reaches home and resumes wandering")
	check(flat(wrapper.global_position, home) < 1.5, "It went back to its original home (%.1f m away)" % flat(wrapper.global_position, home))

	# Death: it stops roaming for good.
	for i in wrapper.hits_to_kill:
		wrapper.take_melee_hit(player.global_position, 0.1, 1.0)
	check(wrapper.dead and not wrapper.is_hunting(), "The pipe still kills it")
	var corpse: Vector3 = wrapper.global_position
	wrapper.reset_enemy()
	wrapper.set("enabled", true)
	place_player(Vector3(4, 0, 0), Vector3(4.8, 0, 0), true)
	await seconds(0.5)
	check(wrapper.dead and wrapper.global_position == corpse and not wrapper.get_node("HuntAudio").playing, "A dead Wrapper neither revives, roams nor hunts")
	world.queue_free()
	for i in 3:
		await process_frame
	quit(1 if failures else 0)
