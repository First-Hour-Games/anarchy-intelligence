extends NavigationRegion3D

## Bakes a navmesh at runtime from a curated set of structural sibling nodes
## (ground, roads, buildings) instead of requiring a hand-baked mesh to be
## committed and kept in sync every time the level layout changes.
##
## Deliberately scoped to structural geometry only, not the whole scene: once
## the map's decorative tree/prop count grew into the hundreds, baking from
## every mesh instance pushed total source geometry past Godot's navmesh
## crash-prevention threshold and silently produced an empty (0-polygon)
## navmesh instead of erroring loudly. Trees/props aren't load-bearing for
## pathing correctness the way building footprints are, so they're excluded.

@export var geometry_root_paths: Array[NodePath] = [
	NodePath("../GroundCollision"),
	NodePath("../Roads"),
	NodePath("../Buildings"),
]
@export var agent_radius := 0.4
@export var agent_height := 2.0
@export var agent_max_climb := 0.375
@export var agent_max_slope_degrees := 46.0
@export var cell_size := 0.2
@export var cell_height := 0.125
@export var cache_navigation: bool = true
const CACHE_PATH := "user://town_navigation_v4.res"
@export var cache_path: String = CACHE_PATH
## Optional local bounds keep small encounters from baking an entire outdoor map.
@export var baking_bounds := AABB()
var cache_reused: bool = false


func _ready() -> void:
	# Let deferred structural setup, CSG collision and surface alignment settle
	# before collecting geometry. This also makes the cache signature stable.
	for i in 3:
		await get_tree().physics_frame
	_bake()


func _geometry_root(path: NodePath) -> Node:
	return get_node_or_null(path)


func _bake() -> void:
	var map := get_navigation_map()
	NavigationServer3D.map_set_cell_size(map, cell_size)
	NavigationServer3D.map_set_cell_height(map, cell_height)
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = agent_radius
	nav_mesh.agent_height = agent_height
	nav_mesh.agent_max_climb = agent_max_climb
	nav_mesh.agent_max_slope = agent_max_slope_degrees
	nav_mesh.cell_size = cell_size
	nav_mesh.cell_height = cell_height
	nav_mesh.edge_max_error = 0.75
	nav_mesh.filter_baking_aabb = baking_bounds
	# Match the actual open doorways and floors used by physics. Imported showcase
	# meshes include closed doors even where the gameplay collision removes them.
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav_mesh.geometry_source_group_name = &"town_navigation_source"

	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	var source_roots: Array[Node] = []
	for path in geometry_root_paths:
		var root := _geometry_root(path)
		if root == null:
			push_warning("Navigation baker could not find geometry root at %s." % path)
			continue
		root.add_to_group(&"town_navigation_source")
		source_roots.append(root)
	if source_roots.is_empty():
		return
	# Parse once in the map's shared coordinate frame. Parsing each root
	# separately strips that root's transform (notably ground height/offset).
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geometry, get_parent())
	for source_root in source_roots:
		source_root.remove_from_group(&"town_navigation_source")
	var signature := str([hash(source_geometry.get_vertices()), hash(source_geometry.get_indices()), agent_radius, agent_height, agent_max_climb, agent_max_slope_degrees, cell_size, cell_height, nav_mesh.edge_max_error])
	if baking_bounds.has_volume():
		signature += str(baking_bounds)
	if cache_navigation and ResourceLoader.exists(cache_path):
		var cached := ResourceLoader.load(cache_path, "NavigationMesh", ResourceLoader.CACHE_MODE_IGNORE) as NavigationMesh
		if cached != null and cached.get_meta("source_signature", "") == signature:
			cache_reused = true
			navigation_mesh = cached
			return

	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geometry)
	if cache_navigation:
		nav_mesh.set_meta("source_signature", signature)
		ResourceSaver.save(nav_mesh, cache_path)
	navigation_mesh = nav_mesh
