extends "res://scenes/environment/map_navigation_baker.gd"
## Keep town paths separate from the forest's broad outdoor navigation mesh.

var _town_map: RID


func _ready() -> void:
	_town_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_town_map, cell_size)
	NavigationServer3D.map_set_cell_height(_town_map, cell_height)
	NavigationServer3D.map_set_active(_town_map, true)
	set_navigation_map(_town_map)
	var agent := get_node("../WrapperTestSpawn/Wrapper/NavigationAgent3D") as NavigationAgent3D
	agent.set_navigation_map(_town_map)
	super._ready()


func _exit_tree() -> void:
	if _town_map.is_valid():
		NavigationServer3D.free_rid(_town_map)
