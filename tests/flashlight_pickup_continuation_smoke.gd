extends SceneTree

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func run() -> void:
	var forest: StartingForest = load("res://scenes/chapters/main/starting_forest.tscn").instantiate()
	forest.auto_start_fade = false
	forest.get_node("BottomDialogueBalloon").auto_start = false
	root.add_child(forest)
	await process_frame
	await physics_frame
	var player := forest.player
	var scare := forest.get_node("GasStationRidgebackScare")
	var world_flashlight := forest.get_node("FlashlightItem") as Node3D
	var pickup := world_flashlight.get_node("Pickup") as FlashlightPickup
	check(not scare.enabled and not scare.is_physics_processing(), "Demo pickup ambush is disabled by default")
	check(not scare.ridge.visible and not scare.ridge.is_physics_processing(), "Demo monster stays inactive")
	pickup.interact(player)
	var screen = load("res://scenes/ui/item_pickup/item_pickup_screen.gd").instance
	check(player.inventory.has_item(PlayerInventory.FLASHLIGHT_ITEM), "Pickup adds the flashlight to inventory")
	check(screen.is_active and player.is_frozen, "Pickup inspection opens and temporarily freezes the player")
	check(not world_flashlight.visible, "Collected world model and its lights are hidden without the scare")
	var preview := screen._model_pivot.get_child(0) as Node3D
	check(preview.scene_file_path == "res://scenes/items/flashlight_preview.tscn", "Pickup inspection uses the visual-only flashlight preview")
	check(preview.get_node("Model").scene_file_path == "res://models/props/flashlightItem.tscn", "Pickup preview displays the current flashlight model")
	check(not preview.is_in_group(&"interactable"), "Preview does not register a world pickup interaction")
	var inventory_preview := player.inventory.get_node("ItemPreview/ModelPivot/Flashlight")
	check(inventory_preview.scene_file_path == preview.scene_file_path, "Inventory and pickup share the same preview")
	await create_timer(0.4).timeout
	screen.close()
	await create_timer(0.4).timeout
	check(not screen.is_active and not player.is_frozen, "Confirming pickup returns control to the player")
	check(player.flashlight.is_enabled(), "Confirming pickup equips and switches on the flashlight")
	for turn in 4:
		player.rotation.y += PI
		await create_timer(0.15).timeout
	check(not scare.armed and not scare.revealed and not scare.rushing and not scare.finished, "Turning after pickup never arms the demo ambush")
	check(not scare.ridge.visible and scare.get_node_or_null("RidgebackBlackout") == null, "No monster reveal or demo-ending blackout occurs")
	check(not player.is_frozen, "Player remains free to continue the game")
	player.flashlight.toggle()
	check(not player.flashlight.is_enabled(), "Equipped flashlight still toggles normally")
	screen.queue_free()
	forest.queue_free()
	await process_frame
	quit(1 if failures else 0)
