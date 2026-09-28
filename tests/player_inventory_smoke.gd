extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_player := load("res://scenes/player/player.tscn") as PackedScene
	var packed_pickup := load("res://scenes/items/flashlight_pickup.tscn") as PackedScene
	var player := packed_player.instantiate() as FirstPersonPlayer
	var pickup := packed_pickup.instantiate() as FlashlightPickup
	root.add_child(player)
	root.add_child(pickup)
	pickup.global_position = player.global_position
	await process_frame

	var inventory := player.inventory
	var preview_viewport := inventory.get_node("ItemPreview") as SubViewport
	var preview_pivot := inventory.get_node("ItemPreview/ModelPivot") as Node3D
	var slot_1_preview := inventory.get_node("InventoryBar/Slots/Slot1/Margin/Content/Preview") as TextureRect
	var slot_2_preview := inventory.get_node("InventoryBar/Slots/Slot2/Margin/Content/Preview") as TextureRect
	var stamina_hud := player.get_node("HandViewmodel/AspectRatioContainer/Content/StaminaHUD") as Control
	var passed := inventory != null and inventory.get_selected_item() == PlayerInventory.EMPTY_ITEM
	passed = passed and inventory.get_item(0) == PlayerInventory.EMPTY_ITEM
	passed = passed and inventory.get_item(1) == PlayerInventory.EMPTY_ITEM
	passed = passed and preview_viewport.own_world_3d and preview_viewport.size == Vector2i(128, 96)
	passed = passed and preview_pivot.scale.is_equal_approx(Vector3.ONE * 2.0)
	passed = passed and slot_1_preview.texture != null and not slot_1_preview.visible
	passed = passed and slot_2_preview.texture != null and not slot_2_preview.visible
	passed = passed and is_equal_approx(stamina_hud.offset_top, -158.0)
	passed = passed and pickup.can_interact(player)

	pickup.interact(player)
	passed = passed and inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM)
	passed = passed and inventory.get_selected_item() == PlayerInventory.FLASHLIGHT_ITEM
	passed = passed and slot_1_preview.visible and not slot_2_preview.visible
	passed = passed and pickup.is_queued_for_deletion()

	inventory.select_slot(1)
	passed = passed and inventory.selected_slot_index == 1
	inventory.select_relative(1)
	passed = passed and inventory.selected_slot_index == 0
	passed = passed and not inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)

	var has_slot_1_binding := false
	var has_slot_2_binding := false
	for input_event in InputMap.action_get_events("inventory_slot_1"):
		if input_event is InputEventKey and input_event.physical_keycode == KEY_1:
			has_slot_1_binding = true
	for input_event in InputMap.action_get_events("inventory_slot_2"):
		if input_event is InputEventKey and input_event.physical_keycode == KEY_2:
			has_slot_2_binding = true
	passed = passed and has_slot_1_binding and has_slot_2_binding

	print("PASS player inventory" if passed else "FAIL player inventory")
	player.queue_free()
	quit(0 if passed else 1)
