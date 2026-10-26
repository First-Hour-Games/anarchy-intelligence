class_name BottlePickup extends Interactable3D

## An empty bottle lying in the world that the player can collect to throw later.

const MODEL := preload("res://assets/local_licensed/clinic_medical/Med_12.glb")

@export var model_height: float = 0.22


func _ready() -> void:
	super._ready()
	interaction_distance = 2.2
	interaction_message = "Picked up an empty bottle."
	var visual := MODEL.instantiate() as Node3D
	visual.name = "Model"
	add_child(visual)
	PropSizing.fit_height(visual, model_height)


func get_prompt_world_position() -> Vector3:
	return global_position + Vector3.UP * model_height * 0.5


## Only offered when the player can carry another bottle and can see this one,
## so a refused bottle never steals the prompt from a nearby note.
func can_interact(interactor: Node3D) -> bool:
	var player := interactor as FirstPersonPlayer
	if player == null or not super.can_interact(interactor):
		return false
	if not is_instance_valid(player.inventory) or not player.inventory.can_carry_more(PlayerInventory.BOTTLE_ITEM):
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.camera.global_position, get_prompt_world_position())
	ray.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func interact(interactor: Node3D) -> void:
	var player := interactor as FirstPersonPlayer
	if player == null or not can_interact(player):
		return
	player.inventory.add_item(PlayerInventory.BOTTLE_ITEM)
	var story := get_tree().get_first_node_in_group("opening_story")
	if story != null:
		story.narrate_once("bottle_first", "An empty bottle. If I throw it (G), the noise might pull that thing away from me.")
	interacted.emit(interactor)
	queue_free()
