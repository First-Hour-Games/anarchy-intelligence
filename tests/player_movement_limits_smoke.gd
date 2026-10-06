extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run_test")


func check(condition: bool, label: String) -> void:
	print("PASS " if condition else "FAIL ", label)
	if not condition:
		failures += 1


func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()


func run_test() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50.0, 1.0, 50.0)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	world.add_child(player)
	for frame in range(10):
		await physics_frame
	check(player.is_on_floor(), "player settles on the floor")
	var standing_y := player.position.y
	var standing_height := player.capsule_shape.height
	var head_y := player.head.position.y
	key(KEY_SPACE, true)
	check(Input.is_key_pressed(KEY_SPACE), "test holds Space")
	var stayed_grounded := true
	for frame in range(35):
		await physics_frame
		stayed_grounded = stayed_grounded and player.position.y <= standing_y + 0.01 and player.velocity.y <= 0.0
	check(stayed_grounded, "holding Space cannot jump or repeatedly hop")
	key(KEY_SPACE, false)
	key(KEY_CTRL, true)
	check(Input.is_key_pressed(KEY_CTRL), "test holds Ctrl")
	for frame in range(20):
		await physics_frame
	check(not player.is_crouching, "holding Ctrl cannot crouch")
	check(is_equal_approx(player.capsule_shape.height, standing_height) and is_equal_approx(player.head.position.y, head_y), "capsule and head remain at standing height")
	key(KEY_W, true)
	key(KEY_SHIFT, true)
	player.sprint_enabled = false
	var stamina_before := player.stamina
	for frame in range(25):
		await physics_frame
	check(not player.is_sprinting and absf(player.velocity.z) <= player.walk_speed + 0.01, "disabled sprint keeps Shift movement at walking speed")
	check(is_equal_approx(player.stamina, stamina_before), "disabled sprint does not drain stamina")
	player.sprint_enabled = true
	for frame in range(25):
		await physics_frame
	check(player.is_sprinting and absf(player.velocity.z) > player.walk_speed, "forward sprint still works while Ctrl is held")
	for code in [KEY_CTRL, KEY_W, KEY_SHIFT]:
		key(code, false)
	player.global_position.y = 3.0
	player.velocity = Vector3.ZERO
	for frame in range(15):
		await physics_frame
	check(player.velocity.y < 0.0, "gravity still pulls the player down")
	for frame in range(60):
		await physics_frame
	check(player.is_on_floor(), "player lands normally without jump or crouch")
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
