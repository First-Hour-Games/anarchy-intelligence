extends Area3D
## Stops the Wrapper buildup when the player reaches the save-point area.

@export_node_path("Node3D") var music_controller_path: NodePath
@export_range(0.1, 10.0, 0.1) var fade_duration: float = 2.5

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body is FirstPersonPlayer:
		return
	var controller := get_node_or_null(music_controller_path)
	if is_instance_valid(controller) and controller.has_method("fade_out_buildup_music"):
		controller.fade_out_buildup_music(fade_duration)
