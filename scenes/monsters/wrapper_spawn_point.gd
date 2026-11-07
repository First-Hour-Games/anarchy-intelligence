extends Marker3D
## A persistent roaming Wrapper. It wanders round this marker, hunts a player it hears and walks
## back here once they escape (see story_entity.gd, Roaming). It is never switched off by
## distance, so a hunt or a walk home always finishes; it only pauses while the player is frozen
## (reading, inspecting, dialogue). Its navigation map comes from the area's enemy navigation.

@onready var wrapper: CharacterBody3D = $Wrapper


func _process(_delta: float) -> void:
	if bool(wrapper.get("dead")):
		return
	var player := wrapper.get("player") as FirstPersonPlayer
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer
		wrapper.set("player", player)
	wrapper.set("enabled", is_instance_valid(player) and not player.is_frozen)
