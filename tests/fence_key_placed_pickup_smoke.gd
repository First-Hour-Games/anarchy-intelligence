extends SceneTree

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1


func run() -> void:
	var forest: Variant = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	root.add_child(forest)
	current_scene = forest
	forest.get_node("IntroFadeCanvas").hide()
	var key: Node3D = forest.get_node("FenceKey")
	check(key is InventoryPickup, "authored fence key is the interactive pickup scene")
	if not key is InventoryPickup:
		quit(1)
		return
	check(key.is_in_group("interactable"), "placed key is registered with the interaction system")
	var key_transform := key.transform
	var player: FirstPersonPlayer = forest.player
	player.unfreeze()
	player.set_physics_process(false)
	var focus: Vector3 = key.get_prompt_world_position()
	player.global_position = Vector3(focus.x + 1.0, 0.2, focus.z)
	player.look_at(Vector3(focus.x, player.global_position.y, focus.z), Vector3.UP)
	player.head.look_at(focus, Vector3.UP)
	player.reset_physics_interpolation()
	await physics_frame
	await physics_frame
	var detector: InteractionDetector = player.get_node("InteractionDetector")
	detector._process(0.0)
	check(key.can_interact(player), "placed key is reachable from beside its authored position")
	check(detector.current_interactable == key, "real player detector selects the placed fence key")
	check(player.get_node("HandViewmodel").interaction_prompt_should_show, "key displays the interaction prompt")
	check(detector.try_interact(), "real detector interaction activates key pickup")
	check(player.has_item(PlayerInventory.FENCE_KEY_ITEM), "pickup puts the fence key in inventory")
	var pickup_screen := root.get_node("ItemPickupScreen")
	check(pickup_screen.is_active and pickup_screen._current_item.id == &"fence_key", "pickup opens the fence key inspection screen")
	await create_timer(0.4).timeout
	pickup_screen.close()
	await create_timer(0.4).timeout
	check(not forest.has_node("FenceKey"), "collected key disappears from the actual forest scene")
	check(not player.is_frozen, "closing inspection returns player control")
	var saves := root.get_node("SaveGame")
	var state: Dictionary = saves._capture_section(forest)
	check(not state.inventory_pickups_present.has("FenceKey"), "save state records the placed key as collected")
	var restored: Node3D = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	saves._restore_section(restored, state)
	check(restored.get_node("FenceKey").is_queued_for_deletion(), "save restore removes the collected key")
	check(restored.get_node("FenceKey").transform.is_equal_approx(key_transform), "pickup replacement preserves authored placement")
	restored.free()
	current_scene = null
	scene_changed.emit()
	forest.queue_free()
	await process_frame
	print("Placed fence key pickup: %d failures" % failures)
	quit(1 if failures else 0)
