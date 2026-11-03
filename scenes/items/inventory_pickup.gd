class_name InventoryPickup
extends Interactable3D
## Placeable inventory prop. The root is removed only after the item is accepted.

const PickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

@export var item_id: StringName = &"fence_key"
@export var show_pickup_screen: bool = true
var _picked_up: bool = false

func can_interact(interactor: Node3D) -> bool:
	var player := interactor as FirstPersonPlayer
	return not _picked_up and player != null and is_instance_valid(player.inventory) \
		and player.inventory.can_carry_more(item_id) and super.can_interact(interactor)

func interact(interactor: Node3D) -> void:
	var player := interactor as FirstPersonPlayer
	if player == null or not can_interact(player):
		return
	if not player.inventory.add_item(item_id):
		return
	_picked_up = true
	remove_from_group(&"interactable")
	hide()
	interacted.emit(player)
	if show_pickup_screen:
		var was_frozen := player.is_frozen
		player.freeze()
		PickupScreen.show_pickup(item_id, func() -> void:
			if is_instance_valid(player) and not was_frozen:
				player.unfreeze()
		)
	queue_free()
