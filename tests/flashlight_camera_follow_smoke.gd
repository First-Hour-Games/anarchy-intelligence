extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func aim_error(flashlight: Node3D, camera: Node3D) -> float:
	return flashlight.global_basis.get_rotation_quaternion().angle_to(camera.global_basis.get_rotation_quaternion())

func run() -> void:
	var rig := Node3D.new()
	root.add_child(rig)
	var camera := Camera3D.new()
	rig.add_child(camera)
	var flashlight := (load("res://scenes/player/flashlight/player_flashlight.tscn") as PackedScene).instantiate() as PlayerFlashlight
	camera.add_child(flashlight)
	flashlight.set_process(false)
	flashlight.set_enabled(true)
	rig.rotation.y = deg_to_rad(45.0)
	flashlight._process(1.0 / 60.0)
	var error := aim_error(flashlight, camera)
	check(error > deg_to_rad(1.0), "beam trails a body/camera yaw turn")
	check(error <= deg_to_rad(flashlight.max_rotation_lag_degrees) + 0.001, "fast turn stays within lag limit")
	check(flashlight.beam.global_basis.is_equal_approx(flashlight.global_basis), "beam shares weighted flashlight orientation")
	var previous_error := error
	var settles_without_overshoot := true
	for i in 60:
		flashlight._process(1.0 / 60.0)
		error = aim_error(flashlight, camera)
		settles_without_overshoot = settles_without_overshoot and error <= previous_error + 0.0001
		previous_error = error
	check(settles_without_overshoot, "catch-up does not overshoot")
	check(error < deg_to_rad(0.1), "beam settles onto camera after turning stops")
	camera.rotation.x = deg_to_rad(-20.0)
	flashlight._process(1.0 / 60.0)
	check(aim_error(flashlight, camera) > deg_to_rad(1.0), "beam also trails vertical camera look")
	rig.position.x += 10.0
	flashlight._process(1.0 / 60.0)
	check(aim_error(flashlight, camera) < 0.001, "teleport resets follow without beam sweep")
	camera.rotation.x += 0.2
	camera.top_level = true
	flashlight._process(1.0 / 60.0)
	check(aim_error(flashlight, camera) < 0.001, "inspection camera cut resets follow")
	camera.top_level = false
	flashlight.set_enabled(false)
	camera.rotation.x += 0.5
	flashlight.set_enabled(true)
	check(aim_error(flashlight, camera) < 0.001, "switching on starts at current camera direction")
	var outcomes: Array[Quaternion] = []
	for fps: int in [30, 60, 144]:
		camera.rotation = Vector3.ZERO
		rig.rotation = Vector3.ZERO
		flashlight._reset_camera_follow()
		camera.rotation.y = deg_to_rad(8.0)
		for i in fps:
			flashlight._update_camera_follow(1.0 / float(fps))
		outcomes.append(flashlight.global_basis.get_rotation_quaternion())
	check(outcomes[0].angle_to(outcomes[1]) < 0.001 and outcomes[1].angle_to(outcomes[2]) < 0.001, "follow converges consistently at 30, 60 and 144 FPS")
	flashlight.rotation_follow_enabled = false
	camera.rotation.y += 0.4
	flashlight._process(1.0 / 60.0)
	check(aim_error(flashlight, camera) < 0.001, "Inspector toggle restores immediate camera follow")
	rig.queue_free()
	await process_frame
	print("flashlight_camera_follow_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures else 0)
