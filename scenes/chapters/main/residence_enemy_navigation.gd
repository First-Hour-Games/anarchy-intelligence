extends "res://scenes/environment/map_navigation_baker.gd"
## Keep town paths separate from the forest's broad outdoor navigation mesh. Every Wrapper spawn
## point in this area walks this map, so new spawn points need no setup.

const SPAWN_POINT_SCRIPT := preload("res://scenes/monsters/wrapper_spawn_point.gd")

var _town_map: RID


func _geometry_root(path: NodePath) -> Node:
	var local_root := super._geometry_root(path)
	if local_root != null or not get_parent().has_meta("streamed_section"):
		return local_root
	# The incoming Residence shares these colliders with the loaded section.
	var shared := WorldStreaming.shared_nodes
	if path == NodePath("../GroundPlane") and shared.has("StaticBody3D"):
		return shared["StaticBody3D"]
	return shared.get(String(path).trim_prefix("../"))


func _ready() -> void:
	_town_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_town_map, cell_size)
	NavigationServer3D.map_set_cell_height(_town_map, cell_height)
	NavigationServer3D.map_set_active(_town_map, true)
	set_navigation_map(_town_map)
	for agent in spawn_point_agents():
		agent.set_navigation_map(_town_map)
	super._ready()


## The navigation agents of every Wrapper spawn point in this area.
func spawn_point_agents() -> Array[NavigationAgent3D]:
	var agents: Array[NavigationAgent3D] = []
	for node: Node in get_parent().find_children("*", "Marker3D", true, false):
		if node.get_script() != SPAWN_POINT_SCRIPT:
			continue
		var agent := node.get_node_or_null("Wrapper/NavigationAgent3D") as NavigationAgent3D
		if agent != null:
			agents.append(agent)
	return agents


func _exit_tree() -> void:
	if _town_map.is_valid():
		NavigationServer3D.free_rid(_town_map)
