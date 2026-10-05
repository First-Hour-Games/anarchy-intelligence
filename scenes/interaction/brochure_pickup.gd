extends Interactable3D

const PickupScreen = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

@export var brochure_visual: Node3D = null
@export var inspection: InspectableView3D = null
@onready var hotspot: Node3D = get_parent() as Node3D


func _ready() -> void:
	super._ready()
	if inspection == null:
		var p: Node = get_parent()
		while p != null:
			if p is InspectableView3D:
				inspection = p as InspectableView3D
				break
			for child in p.get_children():
				if child is InspectableView3D:
					inspection = child as InspectableView3D
					break
			if inspection != null:
				break
			p = p.get_parent()

	if is_instance_valid(brochure_visual) and is_instance_valid(hotspot):
		hotspot.global_position = brochure_visual.global_position


func get_prompt_world_position() -> Vector3:
	return brochure_visual.global_position if is_instance_valid(brochure_visual) else global_position


func can_interact(interactor: Node3D) -> bool:
	var player := interactor as FirstPersonPlayer
	if player == null or (is_instance_valid(inspection) and inspection.is_inspecting) or player.has_item(&"map"):
		return false
	if is_instance_valid(hotspot) and hotspot is InspectionHotspot3D and not (hotspot as InspectionHotspot3D).can_activate():
		return false
	if is_instance_valid(PickupScreen.instance) and PickupScreen.instance.is_active:
		return false
	var direction := player.camera.global_position.direction_to(get_prompt_world_position())
	return super.can_interact(interactor) and direction.dot(-player.camera.global_basis.z) > 0.94


func interact(interactor: Node3D) -> void:
	if not can_interact(interactor):
		return
	var player := interactor as FirstPersonPlayer
	if is_instance_valid(hotspot) and hotspot is InspectionHotspot3D:
		(hotspot as InspectionHotspot3D).activate()
	player.inventory.add_item(&"map")
	player.freeze()
	PickupScreen.show_pickup(&"map", func() -> void:
		if is_instance_valid(player):
			player.unfreeze()
	)
