class_name InteractionDetector extends Node

@onready var player: FirstPersonPlayer = get_parent() as FirstPersonPlayer
@onready var camera: Camera3D = player.get_node("Head/Camera3D") as Camera3D
@onready var viewmodel: HandViewmodel = player.get_node("HandViewmodel") as HandViewmodel

var current_interactable: Interactable3D


func _process(_delta: float) -> void:
	current_interactable = _find_nearest_interactable()
	_update_prompt()


func try_interact() -> bool:
	if not is_instance_valid(current_interactable):
		return false
	if not current_interactable.can_interact(player):
		return false
	current_interactable.interact(player)
	return true


func _find_nearest_interactable() -> Interactable3D:
	var nearest: Interactable3D
	var nearest_distance := INF
	for candidate in get_tree().get_nodes_in_group(&"interactable"):
		var interactable := candidate as Interactable3D
		if not is_instance_valid(interactable) or not interactable.can_interact(player):
			continue
		var prompt_world_position := interactable.get_prompt_world_position()
		if camera.is_position_behind(prompt_world_position):
			continue
		if not _get_gameplay_screen_rect().has_point(camera.unproject_position(prompt_world_position)):
			continue
		var distance := player.global_position.distance_to(prompt_world_position)
		if distance < nearest_distance:
			nearest = interactable
			nearest_distance = distance
	return nearest


func _update_prompt() -> void:
	if not is_instance_valid(current_interactable):
		viewmodel.set_interaction_prompt(false)
		return

	var prompt_world_position := current_interactable.get_prompt_world_position()
	if camera.is_position_behind(prompt_world_position):
		viewmodel.set_interaction_prompt(false)
		return

	var screen_position := camera.unproject_position(prompt_world_position)
	if not _get_gameplay_screen_rect().has_point(screen_position):
		viewmodel.set_interaction_prompt(false)
		return

	viewmodel.set_interaction_prompt(true, screen_position)


func _get_gameplay_screen_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var content_size := Vector2(
		minf(viewport_size.x, viewport_size.y * 4.0 / 3.0),
		minf(viewport_size.y, viewport_size.x * 3.0 / 4.0)
	)
	return Rect2((viewport_size - content_size) * 0.5, content_size)
