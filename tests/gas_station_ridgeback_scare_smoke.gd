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
	await physics_frame
	assert(not scare.rushing, "Pickup alone must not reveal Ridgeback")
	forest.player.rotation.y += PI
	await physics_frame
	await physics_frame
	assert(scare.rushing and scare.ridge.visible)
	assert(scare.ridge.visual.clip == "chase")
	assert(scare.ridge.visual.animation_player.current_animation == "ManThing_CHASE")
	# Move player to the attacker to verify contact blackout.
	forest.player.global_position = scare.ridge.global_position
	await physics_frame
	await physics_frame
	assert(scare.finished)
	assert(forest.player.is_frozen)
	var layer := scare.get_node("RidgebackBlackout") as CanvasLayer
	assert(layer.layer == 128)
	assert((layer.get_child(0) as ColorRect).color == Color.BLACK)
	print("PASS: Hidden Ridgeback waits for flashlight and turn, runs, and blacks out on contact")
	forest.queue_free()
	await process_frame
	quit()
