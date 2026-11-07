extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func run() -> void:
	var player := load("res://scenes/player/player.tscn").instantiate() as FirstPersonPlayer
	# Scene edits must survive runtime updates, including attack recovery.
	var pivot: Node3D = player.get_node("Head/Camera3D/PipeWeapon/ModelPivot")
	pivot.position += Vector3(0.03, 0.02, -0.01)
	pivot.rotation.y += 0.08
	var scene_placement := pivot.transform
	root.add_child(player)
	player.set_physics_process(false)
	player.unfreeze()
	await process_frame
	var weapon: Node3D = player.get_node("Head/Camera3D/PipeWeapon")
	var arms: Node3D = weapon.get_node("ModelPivot/Arms")
	var animation: AnimationPlayer = arms.get_node("AnimationPlayer")
	var skeleton: Skeleton3D = arms.get_node("FPS_Arms/Skeleton3D")
	var attachment: BoneAttachment3D = skeleton.get_node("Hand_R")
	var model: Node3D = attachment.get_node("MetalPipe_Hand_R")
	var illustrated: AnimatedSprite2D = player.get_node("HandViewmodel").hands
	check(not weapon.model_pivot.visible, "arms hidden before pipe pickup")
	player.inventory.add_item(&"metal_pipe")
	await process_frame
	await process_frame
	check(weapon.model_pivot.visible and not illustrated.visible, "equipping shows 3D arms and hides illustrated hands")
	check(pivot.position.y < scene_placement.origin.y and not weapon.try_swing(), "equip rises from below and blocks attacks")
	await create_timer(0.35).timeout
	check(pivot.transform.is_equal_approx(scene_placement), "equip finishes at the authored holding pose")
	check(attachment.bone_name == "Hand.R", "pipe follows right hand bone")
	var grip_transform := model.transform
	var start := model.global_transform
	animation.seek(1.0, true)
	await process_frame
	await process_frame
	check(not model.global_transform.is_equal_approx(start), "idle animation moves held pipe")
	check(model.transform.is_equal_approx(grip_transform), "idle preserves pipe grip offset")
	check(pivot.transform.is_equal_approx(scene_placement), "idle preserves edited scene placement without extra bob or roll")
	animation.seek(3.95, true)
	await create_timer(0.2).timeout
	check(animation.is_playing() and animation.current_animation_position < 1.0, "four-second idle wraps and continues")
	check(animation.has_animation(&"pipe_swings/swing_downswing") and animation.has_animation(&"pipe_swings/swing_bat"),
		"both two-handed swings are loaded onto the arms")
	var shoulder_before := skeleton.get_bone_global_pose(skeleton.find_bone("UpperArm.R")).origin
	var hand_before := skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R"))
	check(weapon.try_swing(), "arms setup allows pipe attack")
	await create_timer(0.25).timeout
	var box := (model as MeshInstance3D).get_aabb()
	var length_axis := Vector3.ZERO
	length_axis[box.get_longest_axis_index()] = 1.0
	var slid := model.position - grip_transform.origin
	check(model.transform.basis.is_equal_approx(grip_transform.basis) and slid.length() > 0.15
		and absf(slid.normalized().dot((grip_transform.basis * length_axis).normalized())) > 0.99,
		"two-handed swing slides the pipe along its length through the hands")
	check(animation.current_animation == &"pipe_swings/swing_downswing", "attack plays the two-handed downswing")
	check(pivot.transform.is_equal_approx(scene_placement), "attack keeps the viewmodel root fixed")
	check(not skeleton.get_bone_global_pose(skeleton.find_bone("Hand.R")).is_equal_approx(hand_before), "swing moves the hand bones")
	check(skeleton.get_bone_global_pose(skeleton.find_bone("UpperArm.R")).origin.distance_to(shoulder_before) < 0.08,
		"the shoulders only move with the upper body's lean and turn")
	await create_timer(0.6).timeout
	check(pivot.transform.is_equal_approx(scene_placement), "completed swing returns to exact scene placement")
	check(animation.current_animation == &"Holding_Idle", "attack recovers to holding idle")
	check(model.transform.is_equal_approx(grip_transform), "completed swing returns the pipe to its one-handed grip")
	weapon.set_equipped(false)
	await process_frame
	await process_frame
	check(pivot.visible and not illustrated.visible and pivot.position.y < scene_placement.origin.y, "holster lowers the arms before hiding them")
	check(not weapon.try_swing(), "lowering blocks attacks")
	await create_timer(0.3).timeout
	await process_frame
	check(not weapon.model_pivot.visible and illustrated.visible, "holstering restores illustrated hands")
	check(animation.speed_scale == 0.0, "holstered idle pauses")
	weapon.set_equipped(true)
	player.freeze()
	await process_frame
	await process_frame
	check(not weapon.model_pivot.visible, "freeze hides arms and pipe together")
	player.unfreeze()
	await create_timer(0.35).timeout
	await process_frame
	await process_frame
	check(weapon.model_pivot.visible and animation.speed_scale == 1.0, "unfreeze resumes equipped arms idle")
	weapon.set_equipped(false)
	await create_timer(0.1).timeout
	var reversing_from := pivot.position
	weapon.set_equipped(true)
	check(pivot.position.is_equal_approx(reversing_from), "re-equipping mid-lower does not snap the pose")
	await create_timer(0.35).timeout
	check(pivot.transform.is_equal_approx(scene_placement), "reversed transition returns to held pose")
	player.queue_free()
	await process_frame
	print("pipe_hands_smoke: %d failures" % failures)
	quit(1 if failures else 0)
