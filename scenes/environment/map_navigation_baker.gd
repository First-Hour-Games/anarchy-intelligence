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
	NodePath("../GroundPlane"),
	NodePath("../Roads"),
	NodePath("../Buildings"),
]
@export var agent_radius := 0.45
@export var agent_height := 2.0
@export var agent_max_climb := 0.35
@export var agent_max_slope_degrees := 46.0
@export var cell_size := 0.25
@export var cell_height := 0.25


func _ready() -> void:
	# Wait a frame so sibling nodes that queue their own call_deferred setup
	# (e.g. the neighborhood decorator's scatter pass) have run first and are
	# included as obstacles.
	await get_tree().process_frame
	_bake()


func _bake() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.agent_radius = agent_radius
	nav_mesh.agent_height = agent_height
	nav_mesh.agent_max_climb = agent_max_climb
	nav_mesh.agent_max_slope = agent_max_slope_degrees
	nav_mesh.cell_size = cell_size
	nav_mesh.cell_height = cell_height
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_MESH_INSTANCES

	var source_geometry := NavigationMeshSourceGeometryData3D.new()
	var found_any := false
	for path in geometry_root_paths:
		var root := get_node_or_null(path)
		if root == null:
			push_warning("Navigation baker could not find geometry root at %s." % path)
			continue
		found_any = true
		NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geometry, root)
	if not found_any:
		return

	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geometry)
	navigation_mesh = nav_mesh
