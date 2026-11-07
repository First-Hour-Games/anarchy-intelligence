extends SceneTree

class Walker extends CharacterBody3D:
	var speed := 0.0
	func _physics_process(delta: float) -> void:
		velocity = Vector3(speed, velocity.y - 9.8 * delta, 0)
		move_and_slide()

var walker: Walker
var steps: AudioStreamPlayer3D

func _initialize() -> void:
	run.call_deferred()

func count_steps(ticks: int) -> int:
	var count := 0
	var previous := steps.stream
	for tick in range(ticks):
		await physics_frame
		if steps.stream != previous:
			count += 1
			previous = steps.stream
	return count

func run() -> void:
	for path in ["the_wrapper.tscn", "the_clawman.tscn", "the_ridgeback/the_ridgeback.tscn",
			"corrupted_friend/corrupted_friend.tscn", "robot_kid/robot_kid.tscn", "scrap_automaton/scrap_automaton.tscn"]:
		var enemy := load("res://scenes/monsters/" + path).instantiate() as CharacterBody3D
		assert(enemy.get_node("Footsteps") is AudioStreamPlayer3D, "Missing enemy footsteps: " + path)
		enemy.free()
	var floor_body := StaticBody3D.new()
	floor_body.set_meta("surface", "concrete")
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 0.2, 20)
	floor_shape.shape = box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	floor_body.position.y = -0.1
	walker = Walker.new()
	walker.floor_snap_length = 0.3
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	walker.add_child(shape)
	steps = AudioStreamPlayer3D.new()
	steps.set_script(load("res://scenes/monsters/enemy_footsteps.gd"))
	walker.add_child(steps)
	root.add_child(walker)
	assert(await count_steps(10) == 0, "Standing enemies stay silent")
	walker.speed = 0.7
	var slow := await count_steps(120)
	assert(slow >= 1 and slow <= 2, "Slow movement must produce spaced footsteps")
	var slow_pitch := steps.pitch_scale
	assert(steps.stream.resource_path.contains("footsteps/concrete/"), "Enemy uses the actual floor surface")
	walker.speed = 2.1
	var fast := await count_steps(120)
	assert(fast >= 4 and fast <= 5 and fast > slow, "Cadence follows distance traveled")
	assert(slow_pitch < steps.pitch_scale and slow_pitch < 1.0, "Slower movement has lower pitch")
	walker.speed = 0.0
	assert(await count_steps(60) == 0, "Stopping produces no extra steps")
	walker.position.x = 30.0
	assert(await count_steps(5) == 0, "Teleporting does not produce footsteps")
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.2, 4, 10)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	root.add_child(wall)
	wall.position = Vector3(31, 1, 0)
	walker.speed = 2.1
	await count_steps(90)
	assert(await count_steps(120) == 0, "Walking against a wall stays silent despite desired velocity")
	walker.position = Vector3(35, 4, 0)
	assert(await count_steps(8) == 0, "Airborne movement has no footsteps")
	walker.position = Vector3(35, 0, 0)
	walker.hide()
	assert(await count_steps(60) == 0 and not steps.playing, "Hidden enemies stay silent")
	walker.show()
	shape.disabled = true
	assert(await count_steps(20) == 0 and not steps.playing, "Dead bodies with disabled collision stay silent")
	paused = true
	assert(not steps.can_process(), "Enemy footsteps pause with the game")
	paused = false
	print("PASS: all six enemy scenes; grounded, surface-aware steps follow actual distance and speed; idle, blocked, hidden, airborne, dead and teleport cases stay silent")
	quit()
