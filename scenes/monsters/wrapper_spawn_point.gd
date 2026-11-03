extends Marker3D
## A persistent Wrapper instance, active only while the player is near its post.

@export_range(1.0, 100.0, 1.0, "suffix:m") var activation_distance: float = 32.0

@onready var wrapper: CharacterBody3D = $Wrapper


func _process(_delta: float) -> void:
	if bool(wrapper.get("dead")):
		return
	var player := wrapper.get("player") as FirstPersonPlayer
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer
		wrapper.set("player", player)
	wrapper.set("enabled", is_instance_valid(player) and not player.is_frozen
		and global_position.distance_to(player.global_position) <= activation_distance)
