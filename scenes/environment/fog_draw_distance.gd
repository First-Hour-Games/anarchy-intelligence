extends Node
## Stops drawing the town's small, low things where the camera fog hides them. The player's camera fog
## (shaders/distance_fog.gdshader, on the player's DistanceFog quad) paints everything further off than its
## fog_distance, 70 m, one flat colour, so a car, bush, bin or fence beyond that is drawn for nothing. Each such
## object gets a visibility range ending at draw_distance.
## Only low objects: past the fog an object still shows where its outline stands against the sky near the
## horizon, and only one reaching well above eye height can do that. Only small ones: a range is measured from
## an object's centre, so a long one could vanish while its near end is still in sight.
## It covers everything under its parent (the map), including what scripts build or stream in later, except the
## player's own meshes, objects with a range or a level of detail of their own, and objects marked to be seen from
## far (meta keep_far).
## The world map draws the town from a camera high above, so while it is open the ranges are off
## (set_overhead_view, called from world_map.gd).

## The node's group, which the world map calls.
const GROUP := &"fog_draw_distance"
## The objects given a range here.
const RANGED := &"fog_draw_distance_ranged"

## Distance from the camera, in metres, past which a small, low object is not drawn: past the camera fog's
## 70 m, with room for the object's own size.
@export var draw_distance: float = 90.0
## Objects whose longest side is at least this long, in metres, keep drawing.
@export var max_size: float = 40.0
## Objects whose top is higher than this above the ground (the town lies at y = 0), in metres, keep drawing:
## from eye height, a top this low at draw_distance stands no more than a degree and a half above the horizon,
## where the fog covers the sky almost as fully as the ground.
@export var max_top: float = 4.0

var _overhead := false


func _ready() -> void:
	add_to_group(GROUP)
	get_tree().node_added.connect(_on_node_added)
	_limit_all.call_deferred()


func _limit_all() -> void:
	for node: Node in get_parent().find_children("*", "GeometryInstance3D", true, false):
		limit(node as GeometryInstance3D)


func _on_node_added(node: Node) -> void:
	if node is GeometryInstance3D:
		# After the object's own scene has placed it in _ready.
		_limit_id.call_deferred(node.get_instance_id())


func _limit_id(id: int) -> void:
	if is_instance_id_valid(id):
		limit(instance_from_id(id) as GeometryInstance3D)


## Gives one object its draw distance, unless it is not the map's, is the player's, has a range already, is too
## big or too tall, or must be seen from far.
func limit(geometry: GeometryInstance3D) -> void:
	if geometry == null or not geometry.is_inside_tree() or not get_parent().is_ancestor_of(geometry):
		return
	if geometry.is_in_group(RANGED) or geometry.has_meta(&"keep_far"):
		return
	# Its own range, or a level of detail (shown from some distance, or in place of a parent): left as it is.
	if geometry.visibility_range_end > 0.0 or geometry.visibility_range_begin > 0.0 or not geometry.visibility_parent.is_empty():
		return
	for player: Node in get_tree().get_nodes_in_group(&"player"):
		if player.is_ancestor_of(geometry):
			return
	var box := geometry.global_transform * geometry.get_aabb()
	if box.size[box.get_longest_axis_index()] >= max_size or box.end.y > max_top:
		return
	geometry.add_to_group(RANGED)
	geometry.visibility_range_end = 0.0 if _overhead else draw_distance


## Switches the ranges off while the town is seen from high above (the world map), and back on after.
func set_overhead_view(active: bool) -> void:
	_overhead = active
	for node: Node in get_tree().get_nodes_in_group(RANGED):
		(node as GeometryInstance3D).visibility_range_end = 0.0 if active else draw_distance
