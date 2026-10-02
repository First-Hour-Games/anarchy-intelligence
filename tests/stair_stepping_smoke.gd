extends SceneTree
## Proves StairStepping actually lets a capsule cross a curb-height ledge
## without jumping, and still refuses to climb a true wall.

const StairStepping = preload("res://scenes/shared/stair_stepping.gd")

var failures: int = 0


func _initialize() -> void:
	run.call_deferred()


func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1


func _make_capsule_body() -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	body.floor_snap_length = 0.3
	body.floor_max_angle = deg_to_rad(45.0)
	return body


func _make_box(size: Vector3, position: Vector3) -> StaticBody3D:
	var box_body := StaticBody3D.new()
	var box_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	box_shape.shape = box
	box_body.add_child(box_shape)
	box_body.position = position
	return box_body


func _drive_forward(body: CharacterBody3D, seconds: float, speed: float = 2.0, max_step_height: float = 0.3) -> void:
	var delta := 0.02
	var steps := int(seconds / delta)
	for i in steps:
		if not body.is_on_floor():
			body.velocity.y -= 9.8 * delta
		else:
			body.velocity.y = 0.0
		body.velocity.x = speed
		body.velocity.z = 0.0
		StairStepping.apply(body, delta, max_step_height)
		body.move_and_slide()


func run() -> void:
	# --- Scenario 1: a 3-inch curb (0.076m), well under the default 0.3m step height.
	var world_a := Node3D.new()
	root.add_child(world_a)
	world_a.add_child(_make_box(Vector3(50, 1, 50), Vector3(0, -0.5, 0)))
	var curb := _make_box(Vector3(2, 0.076, 2), Vector3(2, 0.038, 0))
	world_a.add_child(curb)
	var body_a := _make_capsule_body()
	body_a.position = Vector3(-1, 0, 0)
	world_a.add_child(body_a)
	await physics_frame
	await physics_frame
	_drive_forward(body_a, 3.0)
	check(body_a.position.x > 2.5, "Capsule crosses a 3-inch curb without jumping (x=%.2f)" % body_a.position.x)
	check(body_a.position.y < 0.5, "Capsule settles back near floor height after the curb (y=%.2f)" % body_a.position.y)

	# --- Scenario 2: a real wall (1.2m) must still block movement.
	var world_b := Node3D.new()
	root.add_child(world_b)
	world_b.add_child(_make_box(Vector3(50, 1, 50), Vector3(0, -0.5, 0)))
	var wall := _make_box(Vector3(2, 1.2, 2), Vector3(2, 0.6, 0))
	world_b.add_child(wall)
	var body_b := _make_capsule_body()
	body_b.position = Vector3(-1, 0, 0)
	world_b.add_child(body_b)
	await physics_frame
	await physics_frame
	_drive_forward(body_b, 3.0)
	check(body_b.position.x < 1.0, "A real wall still blocks movement (x=%.2f)" % body_b.position.x)

	quit(1 if failures else 0)
