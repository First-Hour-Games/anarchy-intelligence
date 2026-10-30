extends Node3D


func _ready() -> void:
	# Match Starting Forest's runtime ambient light while keeping editor lighting editable.
	if has_meta("streamed_section"):
		return
	var world_environment := $WorldEnvironment as WorldEnvironment
	world_environment.environment = world_environment.environment.duplicate() as Environment
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color.BLACK
