class_name FlashlightPickup
extends Interactable3D

## World pickup that grants the player's held flashlight item.

var _picked_up: bool = false


func can_interact(interactor: Node3D) -> bool:
	return not _picked_up and super.can_interact(interactor)


func interact(interactor: Node3D) -> void:
	if _picked_up:
		return

	var inventory := interactor.get_node_or_null("InventoryHUD") as PlayerInventory
	if not is_instance_valid(inventory):
		return
	if not inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM):
		print("The inventory is full.")
		return

	_picked_up = true
	super.interact(interactor)
	queue_free()
