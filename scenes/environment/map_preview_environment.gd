@tool
extends WorldEnvironment

## Keeps the playable horror environment intact while offering a bright editor view.

@export var preview_active_in_editor: bool = true:
	set(value):
		preview_active_in_editor = value
		if is_inside_tree():
			call_deferred("_apply_environment")

@export var gameplay_environment: Environment
@export var editor_environment: Environment
@export_node_path("DirectionalLight3D") var preview_light_path: NodePath


func _ready() -> void:
	_apply_environment()


func _apply_environment() -> void:
	var use_editor_preview := Engine.is_editor_hint() and preview_active_in_editor
	if use_editor_preview and editor_environment:
		environment = editor_environment
	elif gameplay_environment:
		environment = gameplay_environment

	var preview_light := get_node_or_null(preview_light_path) as DirectionalLight3D
	if preview_light:
		preview_light.visible = use_editor_preview
