extends Node
## Fades the town's lamps with distance from the camera (Light3D distance fade). A lamp further off than
## fade_begin dims out over fade_length and is then not lit at all, and a shadowed lamp's shadow is drawn only
## within shadow_distance. Far lamps are deep in the fog, so near the player nothing changes, but the renderer
## stops lighting and shadowing the far ones.
## It covers every lamp under its parent (the map), including lamps that scripts build as the map loads, except
## the player's own lights, lamps that set their own fade, and lamps marked to reach far (meta keep_far, like the
## rooftop street's floodlights).

## Distance from the camera, in metres, at which a lamp starts to fade.
@export var fade_begin: float = 130.0
## Metres over which it fades out; past fade_begin + fade_length it is culled.
@export var fade_length: float = 50.0
## A shadowed lamp's shadow is drawn only this close to the camera.
@export var shadow_distance: float = 45.0


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_fade_all.call_deferred()


func _fade_all() -> void:
	for node: Node in get_parent().find_children("*", "Light3D", true, false):
		fade(node as Light3D)


func _on_node_added(node: Node) -> void:
	if node is Light3D:
		# After the lamp's own scene has set it up in _ready.
		_fade_id.call_deferred(node.get_instance_id())


func _fade_id(id: int) -> void:
	if is_instance_id_valid(id):
		fade(instance_from_id(id) as Light3D)


## Gives one lamp its distance fade, unless it is not the map's, is the player's, fades already, or must reach far.
func fade(light: Light3D) -> void:
	if light == null or light is DirectionalLight3D or not light.is_inside_tree() or not get_parent().is_ancestor_of(light):
		return
	if light.distance_fade_enabled or light.has_meta(&"keep_far"):
		return
	for player: Node in get_tree().get_nodes_in_group(&"player"):
		if player.is_ancestor_of(light):
			return
	light.distance_fade_enabled = true
	light.distance_fade_begin = fade_begin
	light.distance_fade_length = fade_length
	light.distance_fade_shadow = shadow_distance
