extends Interactable3D

const PickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

@export var brochure_visual: Node3D = null
@onready var hotspot: InspectionHotspot3D = get_parent() as InspectionHotspot3D
@onready var inspection: InspectableView3D = hotspot.get_parent() as InspectableView3D


func _ready() -> void:
	super._ready()
	if is_instance_valid(brochure_visual):
		hotspot.global_position = brochure_visual.global_position


func get_prompt_world_position() -> Vector3:
	return brochure_visual.global_position if is_instance_valid(brochure_visual) else global_position


func can_interact(interactor: Node3D) -> bool:
	var player := interactor as FirstPersonPlayer
	if player == null or inspection.is_inspecting or not hotspot.can_activate() or player.has_item(&"map"):
		return false
	if is_instance_valid(PickupScreen.instance) and PickupScreen.instance.is_active:
		return false
	var direction := player.camera.global_position.direction_to(get_prompt_world_position())
	return super.can_interact(interactor) and direction.dot(-player.camera.global_basis.z) > 0.94


func interact(interactor: Node3D) -> void:
	if not can_interact(interactor):
		return
	var player := interactor as FirstPersonPlayer
	hotspot.activate()
	player.inventory.add_item(&"map")
	player.freeze()
	PickupScreen.show_pickup(&"map", func() -> void:
		if is_instance_valid(player):
			player.unfreeze()
	)
