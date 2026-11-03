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
	check(attachment.bone_name == "Hand.R", "pipe follows right hand bone")
	var grip_transform := model.transform
	var start := model.global_transform
	animation.seek(1.0, true)
	await process_frame
	await process_frame
	check(not model.global_transform.is_equal_approx(start), "idle animation moves held pipe")
	check(model.transform.is_equal_approx(grip_transform), "idle preserves pipe grip offset")
	animation.seek(3.95, true)
	await create_timer(0.2).timeout
	check(animation.is_playing() and animation.current_animation_position < 1.0, "four-second idle wraps and continues")
	check(weapon.try_swing(), "arms setup allows pipe attack")
	await create_timer(0.25).timeout
	check(model.transform.is_equal_approx(grip_transform), "swing preserves pipe grip offset")
	weapon.set_equipped(false)
	await process_frame
	await process_frame
	check(not weapon.model_pivot.visible and illustrated.visible, "holstering restores illustrated hands")
	check(animation.speed_scale == 0.0, "holstered idle pauses")
	weapon.set_equipped(true)
	player.freeze()
	await process_frame
	await process_frame
	check(not weapon.model_pivot.visible, "freeze hides arms and pipe together")
	player.unfreeze()
	await process_frame
	await process_frame
	check(weapon.model_pivot.visible and animation.speed_scale == 1.0, "unfreeze resumes equipped arms idle")
	player.queue_free()
	await process_frame
	print("pipe_hands_smoke: %d failures" % failures)
	quit(1 if failures else 0)
