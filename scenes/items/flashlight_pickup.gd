class_name FlashlightPickup
extends Interactable3D

## World pickup that grants the player's held flashlight item.

const PickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

@export var pickup_dialogue_resource: DialogueResource
@export var pickup_dialogue_cue: String = "start"

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
	var visual_target := get_node_or_null(visual_target_path) as Node3D
	if is_instance_valid(visual_target):
		visual_target.hide()
	super.interact(interactor)
	var player := interactor as FirstPersonPlayer
	if is_instance_valid(player):
		var was_frozen := player.is_frozen
		var dialogue := pickup_dialogue_resource
		var dialogue_cue := pickup_dialogue_cue
		var balloon_scene := preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")
		player.freeze()
		PickupScreen.show_pickup(PlayerInventory.FLASHLIGHT_ITEM, func() -> void:
			if not is_instance_valid(player):
				return
			if is_instance_valid(player.flashlight):
				player.flashlight.set_enabled(true)
			if not was_frozen:
				player.unfreeze()
			if dialogue != null:
				var balloon := balloon_scene.instantiate() as BottomDialogueBalloon
				balloon.name = "FlashlightPickupDialogue"
				balloon.freeze_player = not was_frozen
				player.get_parent().add_child(balloon)
				balloon.start(dialogue, dialogue_cue)
		)
	queue_free()
