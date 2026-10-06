extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func run_test() -> void:
	var tutorial := (load("res://scenes/chapters/tutorial/tutorial.tscn") as PackedScene).instantiate()
	var world := Node3D.new()
	root.add_child(world)
	var stairs_packed := load("res://models/tutorial/stairs.tscn") as PackedScene
	var previous: Node3D
	var spacing := Vector3(0.0, 1.8557838, -3.593084)
	for stair_name in ["Stair", "Stair2", "Stair3", "Stair4", "Stair5"]:
		var source := tutorial.get_node(stair_name) as Node3D
		var stair := stairs_packed.instantiate() as Node3D
		stair.name = stair_name
		stair.transform = source.transform
		world.add_child(stair)
		check(not stair.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s has collision" % stair_name)
		if previous:
			check((stair.position - previous.position).is_equal_approx(spacing), "%s matches the existing stack spacing" % stair_name)
		previous = stair
	tutorial.free()
	var platform := StaticBody3D.new()
	var platform_collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.0, 0.4, 4.0)
	platform_collision.shape = box
	platform.add_child(platform_collision)
	platform.position = Vector3(-1.7052734, -0.7, -48.4)
	world.add_child(platform)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	player.position = Vector3(-1.7052734, -0.499, -49.5)
	world.add_child(player)
	for frame in range(10):
		await physics_frame
	var forward := InputEventKey.new()
	forward.keycode = KEY_W
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	Input.flush_buffered_events()
	for frame in range(500):
		await physics_frame
		if player.position.z < -67.5:
			break
	forward.pressed = false
	Input.parse_input_event(forward)
	Input.flush_buffered_events()
	print("Final player position: ", player.position)
	check(player.position.z < -67.5 and player.position.y > 7.0, "player walks up all five stair sections without jumping")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
