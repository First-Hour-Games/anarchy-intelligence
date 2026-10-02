extends Interactable3D

@export var document_id: StringName
@export var title: String
@export_multiline var body: String

func can_interact(interactor: Node3D) -> bool:
	if not super.can_interact(interactor):
		return false
	var camera := interactor.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, global_position + Vector3.UP * 0.05)
	if interactor is CollisionObject3D:
		ray.exclude = [(interactor as CollisionObject3D).get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func get_prompt_world_position() -> Vector3:
	return global_position

func interact(interactor: Node3D) -> void:
	var story := get_tree().get_first_node_in_group("opening_story")
	if story != null:
		story.open_document(document_id, title, body)
	interacted.emit(interactor)
