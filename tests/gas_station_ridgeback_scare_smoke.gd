extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var forest := load("res://scenes/chapters/main/starting_forest.tscn").instantiate() as StartingForest
	forest.auto_start_fade = false
	root.add_child(forest)
	await create_timer(0.5).timeout
	var scare := forest.get_node("GasStationRidgebackScare")
	assert(not scare.ridge.visible)
	assert(not scare.ridge.is_physics_processing())
	scare.pickup.interact(forest.player)
	assert(forest.player.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM))
	assert(scare.armed)
	var screen = load("res://scenes/ui/item_pickup/item_pickup_screen.gd").instance
	assert(screen.is_active and screen._current_item.id == PlayerInventory.FLASHLIGHT_ITEM)
	assert(forest.player.is_frozen)
	screen.close()
	await create_timer(0.4).timeout
	assert(not screen.is_active)
	assert(forest.player.flashlight.is_enabled(), "Reward confirmation must switch on the equipped flashlight")
	forest.player.unfreeze()
	await physics_frame
	assert(not scare.rushing, "Pickup alone must not reveal Ridgeback")
	forest.player.rotation.y += PI
	await physics_frame
	await physics_frame
	assert(scare.revealed and scare.ridge.visible)
	assert(not scare.rushing)
	assert(scare.ridge.visual.clip == "dormant")
	# Move to unobstructed ground to verify gaze timing independent of shop walls.
	forest.player.global_position = Vector3(0, 1, 0)
	scare.ridge.global_position = Vector3(0, 1, -4)
	forest.player.camera.look_at(scare.ridge.global_position + Vector3.UP * 1.4)
	scare.stare_duration = 0.6
	await create_timer(0.2).timeout
	assert(not scare.rushing, "Must idle while being watched before charging")
	forest.player.camera.rotate_y(PI)
	await physics_frame
	await physics_frame
	assert(is_zero_approx(scare.stare_time), "Looking away resets the stare")
	forest.player.camera.look_at(scare.ridge.global_position + Vector3.UP * 1.4)
	await create_timer(0.8).timeout
	assert(scare.rushing)
	assert(scare.ridge.visual.clip == "chase")
	assert(scare.ridge.visual.animation_player.current_animation == "ManThing_CHASE")
	# Move player to the attacker to verify contact blackout.
	forest.player.global_position = scare.ridge.global_position
	await physics_frame
	await physics_frame
	assert(scare.finished)
	var audio := scare.get_node("RidgebackContactSound") as AudioStreamPlayer
	assert(audio.playing)
	assert(audio.bus == &"Reverb" and is_equal_approx(audio.volume_db, 3.0))
	assert(audio.stream.resource_path.ends_with("wrapper_kill.wav"))
	scare._blackout()
	assert(scare.find_children("RidgebackContactSound*", "AudioStreamPlayer", false, false).size() == 1)
	assert(forest.player.is_frozen)
	var layer := scare.get_node("RidgebackBlackout") as CanvasLayer
	assert(layer.layer == 128)
	assert((layer.get_child(0) as ColorRect).color == Color.BLACK)
	print("PASS: Hidden Ridgeback waits for flashlight and turn, runs, and blacks out on contact")
	forest.queue_free()
	await process_frame
	quit()
