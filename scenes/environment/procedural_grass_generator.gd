@tool
extends Node3D
class_name ProceduralGrassGenerator

## Procedural Grass Generator for outdoor environments.
## Generates low grass and tall grass MultiMeshes with organic distribution,
## terrain height snapping, and strict exclusion of buildings, roads, and parking lots.

@export_group("Meshes")
## Mesh used for the low grass layer. Defaults to models/foliage/grass1.tres.
@export var low_grass_mesh: Mesh = preload("res://models/foliage/grass1.tres")

## Mesh used for the tall grass layer. Defaults to models/foliage/tallgrass1.tres.
@export var tall_grass_mesh: Mesh = preload("res://models/foliage/tallgrass1.tres")

## Base pitch rotation in degrees applied to raw mesh models (Blender GLTF models often need -90° around X).
@export var base_mesh_pitch_deg: float = -90.0

@export_group("Spawn Area")
## Size of the spawning rectangle in meters (X = width, Y = depth in Z axis).
@export var area_size: Vector2 = Vector2(300.0, 200.0)

## Positional offset from this generator's global position.
@export var area_center_offset: Vector3 = Vector3.ZERO

## Optional node whose bounding box will override area_size and center (e.g. GroundPlane).
@export var custom_area_node: NodePath

@export_group("Grass Counts")
## Number of low grass instances to spawn across the area.
@export_range(0, 10000, 10) var low_grass_count: int = 1500

## Number of tall grass instances to spawn across the area.
@export_range(0, 5000, 10) var tall_grass_count: int = 400

## Random seed for reproducible procedural generation.
@export var random_seed: int = 1337

@export_group("Tall Grass Clustering")
## If true, tall grass spawns in natural clusters/patches using FastNoiseLite rather than uniform noise.
@export var enable_tall_grass_clustering: bool = true

## Frequency of the clustering noise (lower = larger, broader grass patches).
@export_range(0.001, 0.2, 0.001) var cluster_noise_frequency: float = 0.02

## Noise threshold required to allow tall grass to spawn (-1.0 to 1.0).
@export_range(-1.0, 1.0, 0.05) var cluster_threshold: float = 0.05

@export_group("Scale & Variation")
## Minimum scale multiplier for low grass.
@export var low_grass_scale_min: float = 3.0

## Maximum scale multiplier for low grass.
@export var low_grass_scale_max: float = 5.0

## Minimum scale multiplier for tall grass.
@export var tall_grass_scale_min: float = 2.2

## Maximum scale multiplier for tall grass.
@export var tall_grass_scale_max: float = 2.6

## Multiplier applied to Y axis scale for additional height control.
@export var height_scale_multiplier: float = 1.0

## If true, applies random rotation (0 to 360 degrees) around the vertical Y axis.
@export var random_y_rotation: bool = true

## Maximum random organic tilt away from vertical in degrees.
@export_range(0.0, 20.0, 0.5) var random_tilt_max_deg: float = 4.0

@export_group("Ground Snapping")
## If true, casts physics rays downwards to detect exact terrain elevation.
@export var snap_to_ground: bool = true

## Height above the sample point where raycast begins.
@export var ray_start_height: float = 30.0

## Total downward distance for the snapping raycast.
@export var ray_length: float = 80.0

## Physics collision mask for ground snapping.
@export_flags_3d_physics var ground_collision_mask: int = 1

## Default ground Y elevation used when raycast does not hit or physics is inactive.
@export var fallback_ground_y: float = 0.0

## Maximum ground slope in degrees where grass is allowed to spawn (avoids vertical cliffs).
@export_range(0.0, 89.0, 1.0) var max_slope_deg: float = 42.0

## If true, tilts grass to match the ground surface normal.
@export var align_to_slope: bool = false

@export_group("Exclusion Zones")
## Automatically detects scene landmarks (Visitor Center, Roads, Parking Lots, Barrier Trees) to exclude.
@export var auto_detect_landmarks: bool = true

## Explicit nodes whose bounds will be excluded from spawning grass.
@export var exclusion_nodes: Array[NodePath] = []

## Manual bounding boxes in global coordinates to exclude.
@export var manual_exclusion_boxes: Array[AABB] = []

## Safety margin padding in meters around exclusion zones.
@export var exclusion_margin: float = 1.5

## Reject candidate points if the ground collider has metadata 'surface' set to paved materials (concrete, asphalt, wood).
@export var reject_paved_surfaces: bool = true

@export_group("Rendering & LOD")
## Shadow casting setting for the generated MultiMeshes.
@export var cast_shadows: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

## Distance in meters where grass MultiMeshes begin fading out (0 = disabled).
## For map-spanning MultiMeshes, keep at 0.0 to prevent Godot from culling all map grass when the camera is far from the node origin.
@export var visibility_range_end: float = 0.0

## Distance fade mode for rendering optimization (0 = disabled).
@export var visibility_range_fade_mode: GeometryInstance3D.VisibilityRangeFadeMode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

## Optional target MultiMeshInstance3D for low grass. If empty, creates/manages LowGrassMultiMesh child.
@export var low_grass_node_path: NodePath

## Optional target MultiMeshInstance3D for tall grass. If empty, creates/manages TallGrassMultiMesh child.
@export var tall_grass_node_path: NodePath

@export_group("Editor & Runtime")
## If true, generates grass on _ready() if not already populated or if forced.
@export var generate_on_ready: bool = true

## If true, regenerates grass on _ready() even if instances are already baked in the scene.
@export var force_regenerate_on_ready: bool = false

## Click this checkbox in the Inspector to generate/regenerate grass immediately.
@export var click_to_generate_now: bool = false:
	set(val):
		if val:
			generate_grass()
			click_to_generate_now = false
			notify_property_list_changed()

## Click this checkbox in the Inspector to clear all grass instances.
@export var click_to_clear_now: bool = false:
	set(val):
		if val:
			clear_grass()
			click_to_clear_now = false
			notify_property_list_changed()


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if generate_on_ready:
		var low_inst := get_low_grass_node()
		var tall_inst := get_tall_grass_node()
		var has_instances: bool = (low_inst and low_inst.multimesh and low_inst.multimesh.instance_count > 0) or \
								  (tall_inst and tall_inst.multimesh and tall_inst.multimesh.instance_count > 0)
		if force_regenerate_on_ready or not has_instances:
			generate_grass()


## Clears all generated instances.
func clear_grass() -> void:
	var low_inst := get_low_grass_node()
	if low_inst:
		low_inst.custom_aabb = AABB()
		if low_inst.multimesh:
			low_inst.multimesh.instance_count = 0
			low_inst.multimesh.buffer = PackedFloat32Array()

	var tall_inst := get_tall_grass_node()
	if tall_inst:
		tall_inst.custom_aabb = AABB()
		if tall_inst.multimesh:
			tall_inst.multimesh.instance_count = 0
			tall_inst.multimesh.buffer = PackedFloat32Array()

	print("[ProceduralGrassGenerator] Grass instances cleared.")


## Main generation entry point.
## Generates both low grass and tall grass layers and populates their MultiMeshes.
func generate_grass() -> Dictionary:
	var start_time: int = Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	# Setup noise generator for tall grass clustering
	var noise: FastNoiseLite = null
	if enable_tall_grass_clustering:
		noise = FastNoiseLite.new()
		noise.seed = random_seed
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = cluster_noise_frequency
		noise.fractal_octaves = 2

	# 1. Determine spawn area rectangle
	var area_rect: Rect2 = _calculate_spawn_bounds()

	# 2. Collect all active exclusion AABBs
	var exclusion_aabbs: Array[AABB] = get_exclusion_aabbs()
	print("[ProceduralGrassGenerator] Collected %d exclusion AABBs (margin=%.1fm)" % [exclusion_aabbs.size(), exclusion_margin])

	# 3. Retrieve or create child MultiMeshInstance3D nodes
	var low_node := _setup_multimesh_node(get_low_grass_node(), "LowGrassMultiMesh", low_grass_mesh)
	var tall_node := _setup_multimesh_node(get_tall_grass_node(), "TallGrassMultiMesh", tall_grass_mesh)

	# 4. Generate Low Grass layer
	var low_buffer := PackedFloat32Array()
	var low_count_generated := 0
	if low_grass_count > 0 and low_grass_mesh:
		low_count_generated = _generate_layer(
			low_grass_count,
			area_rect,
			low_node,
			low_grass_scale_min,
			low_grass_scale_max,
			exclusion_aabbs,
			rng,
			null, # No clustering noise for base low grass
			0.0,
			low_buffer
		)
		low_node.multimesh.instance_count = low_count_generated
		low_node.multimesh.buffer = low_buffer

	# 5. Generate Tall Grass layer
	var tall_buffer := PackedFloat32Array()
	var tall_count_generated := 0
	if tall_grass_count > 0 and tall_grass_mesh:
		tall_count_generated = _generate_layer(
			tall_grass_count,
			area_rect,
			tall_node,
			tall_grass_scale_min,
			tall_grass_scale_max,
			exclusion_aabbs,
			rng,
			noise if enable_tall_grass_clustering else null,
			cluster_threshold,
			tall_buffer
		)
		tall_node.multimesh.instance_count = tall_count_generated
		tall_node.multimesh.buffer = tall_buffer

	var elapsed: int = Time.get_ticks_msec() - start_time
	print("[ProceduralGrassGenerator] Done in %d ms! Low grass: %d, Tall grass: %d" % [elapsed, low_count_generated, tall_count_generated])

	return {
		"low_grass_count": low_count_generated,
		"tall_grass_count": tall_count_generated,
		"exclusion_aabbs_count": exclusion_aabbs.size(),
		"elapsed_ms": elapsed
	}


## Generates a single foliage layer into target_node's MultiMesh buffer.
func _generate_layer(
	target_count: int,
	area_rect: Rect2,
	target_node: MultiMeshInstance3D,
	scale_min: float,
	scale_max: float,
	exclusion_aabbs: Array[AABB],
	rng: RandomNumberGenerator,
	cluster_noise: FastNoiseLite,
	noise_threshold: float,
	out_buffer: PackedFloat32Array
) -> int:
	var accepted_count := 0
	var attempts := 0
	var max_attempts: int = target_count * 6

	var min_local := Vector3(INF, INF, INF)
	var max_local := Vector3(-INF, -INF, -INF)

	var direct_state: PhysicsDirectSpaceState3D = null
	if snap_to_ground and is_inside_tree():
		var world_3d := get_world_3d()
		if world_3d:
			direct_state = world_3d.direct_space_state

	var node_inv_xf: Transform3D = target_node.global_transform.affine_inverse()
	var base_pitch_rad: float = deg_to_rad(base_mesh_pitch_deg)

	# Jittered grid partitioning for even map coverage
	var grid_cols: int = int(ceil(sqrt(float(target_count) * (area_rect.size.x / max(area_rect.size.y, 1.0)))))
	grid_cols = max(grid_cols, 1)
	var grid_rows: int = int(ceil(float(target_count) / float(grid_cols)))
	grid_rows = max(grid_rows, 1)

	var cell_w: float = area_rect.size.x / float(grid_cols)
	var cell_h: float = area_rect.size.y / float(grid_rows)

	var cell_indices: Array[int] = []
	var total_cells: int = grid_cols * grid_rows
	cell_indices.resize(total_cells)
	for ci in range(total_cells):
		cell_indices[ci] = ci

	# Shuffle cell indices for uniform distribution
	for i in range(total_cells - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = cell_indices[i]
		cell_indices[i] = cell_indices[j]
		cell_indices[j] = tmp

	var current_cell_ptr := 0

	while accepted_count < target_count and attempts < max_attempts:
		attempts += 1

		# Pick position with cell jitter
		var candidate_x: float = 0.0
		var candidate_z: float = 0.0

		if current_cell_ptr < total_cells:
			var c_idx: int = cell_indices[current_cell_ptr]
			current_cell_ptr += 1
			var col: int = c_idx % grid_cols
			var row: int = c_idx / grid_cols
			candidate_x = area_rect.position.x + (float(col) + rng.randf()) * cell_w
			candidate_z = area_rect.position.y + (float(row) + rng.randf()) * cell_h
		else:
			# Fallback if target count > cells or retrying skipped cells
			candidate_x = rng.randf_range(area_rect.position.x, area_rect.end.x)
			candidate_z = rng.randf_range(area_rect.position.y, area_rect.end.y)

		# 1. Tall grass cluster noise check
		if cluster_noise:
			var n_val: float = cluster_noise.get_noise_2d(candidate_x, candidate_z)
			if n_val < noise_threshold:
				continue

		# 2. Check exclusion AABBs
		var candidate_test_pt := Vector3(candidate_x, fallback_ground_y, candidate_z)
		if _is_point_in_exclusion_aabbs(candidate_test_pt, exclusion_aabbs):
			continue

		# 3. Ground elevation and normal snapping
		var ground_pos := Vector3(candidate_x, fallback_ground_y, candidate_z)
		var ground_normal := Vector3.UP
		var hit_rejected := false

		if direct_state:
			var ray_from := Vector3(candidate_x, candidate_test_pt.y + ray_start_height, candidate_z)
			var ray_to := Vector3(candidate_x, candidate_test_pt.y + ray_start_height - ray_length, candidate_z)
			var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, ground_collision_mask)
			var hit := direct_state.intersect_ray(query)

			if not hit.is_empty():
				ground_pos = hit.position
				ground_normal = hit.normal

				# Slope check
				var slope_deg := rad_to_deg(ground_normal.angle_to(Vector3.UP))
				if slope_deg > max_slope_deg:
					hit_rejected = true

				# Paved surface / metadata check
				if reject_paved_surfaces and hit.has("collider") and is_instance_valid(hit.collider):
					var col_obj: Object = hit.collider
					var s_meta := ""
					if col_obj.has_meta("surface"):
						s_meta = str(col_obj.get_meta("surface")).to_lower()
					if s_meta == "concrete" or s_meta == "asphalt" or s_meta == "wood":
						hit_rejected = true
					elif col_obj is Node:
						var c_name := (col_obj as Node).name.to_lower()
						if c_name.contains("road") or c_name.contains("parking") or c_name.contains("visitor") or c_name.contains("welcome"):
							hit_rejected = true

				# Second AABB check using exact hit Y
				if not hit_rejected and _is_point_in_exclusion_aabbs(ground_pos, exclusion_aabbs):
					hit_rejected = true
			else:
				# Snapping requested but ray hit nothing: skip point to avoid floating grass
				continue

		if hit_rejected:
			continue

		# 4. Construct organic instance transform
		var scale_factor: float = rng.randf_range(scale_min, scale_max)
		var scale_vec := Vector3(scale_factor, scale_factor * height_scale_multiplier, scale_factor)

		var yaw_rad: float = rng.randf_range(0.0, TAU) if random_y_rotation else 0.0

		var inst_basis := Basis()

		if align_to_slope and ground_normal.dot(Vector3.UP) < 0.999:
			var slope_axis := Vector3.UP.cross(ground_normal).normalized()
			var slope_angle := Vector3.UP.angle_to(ground_normal)
			inst_basis = Basis(slope_axis, slope_angle) * inst_basis

		# Yaw rotation around Up
		inst_basis = inst_basis.rotated(Vector3.UP, yaw_rad)

		# Small organic tilt
		if random_tilt_max_deg > 0.01:
			var tilt_angle: float = deg_to_rad(rng.randf_range(0.0, random_tilt_max_deg))
			var tilt_dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
			if tilt_dir.length_squared() > 0.01:
				inst_basis = inst_basis.rotated(tilt_dir, tilt_angle)

		# Base mesh pitch (Blender model orientation fix)
		inst_basis = inst_basis.rotated(Vector3.RIGHT, base_pitch_rad)

		# Scale
		inst_basis = inst_basis.scaled(scale_vec)

		var world_xf := Transform3D(inst_basis, ground_pos)
		var local_xf: Transform3D = node_inv_xf * world_xf

		# Pack 12 floats row-major into MultiMesh buffer
		_pack_transform_3d(local_xf, out_buffer)
		min_local = min_local.min(local_xf.origin)
		max_local = max_local.max(local_xf.origin)
		accepted_count += 1

	# Update custom_aabb on target_node so Godot's frustum culling knows the full grass extents
	if accepted_count > 0:
		var pad := Vector3(scale_max * 2.0, scale_max * 2.0, scale_max * 2.0)
		target_node.custom_aabb = AABB(min_local - pad, (max_local - min_local) + pad * 2.0)
	else:
		target_node.custom_aabb = AABB()

	return accepted_count


## Packs a Transform3D into 12 floats matching Godot MultiMesh.TRANSFORM_3D buffer layout.
func _pack_transform_3d(t: Transform3D, buf: PackedFloat32Array) -> void:
	# Row 0: basis.x.x, basis.y.x, basis.z.x, origin.x
	buf.append(t.basis.x.x)
	buf.append(t.basis.y.x)
	buf.append(t.basis.z.x)
	buf.append(t.origin.x)

	# Row 1: basis.x.y, basis.y.y, basis.z.y, origin.y
	buf.append(t.basis.x.y)
	buf.append(t.basis.y.y)
	buf.append(t.basis.z.y)
	buf.append(t.origin.y)

	# Row 2: basis.x.z, basis.y.z, basis.z.z, origin.z
	buf.append(t.basis.x.z)
	buf.append(t.basis.y.z)
	buf.append(t.basis.z.z)
	buf.append(t.origin.z)


## Checks if a point falls within any of the exclusion AABBs (including margin padding).
func is_point_excluded(pt: Vector3) -> bool:
	return _is_point_in_exclusion_aabbs(pt, get_exclusion_aabbs())


func _is_point_in_exclusion_aabbs(pt: Vector3, aabbs: Array[AABB]) -> bool:
	var pad: float = exclusion_margin
	for box in aabbs:
		if pt.x >= (box.position.x - pad) and pt.x <= (box.end.x + pad) and \
		   pt.z >= (box.position.z - pad) and pt.z <= (box.end.z + pad) and \
		   pt.y >= (box.position.y - 2.5) and pt.y <= (box.end.y + 2.5):
			return true
	return false


## Collects all active exclusion AABBs in world coordinates.
func get_exclusion_aabbs() -> Array[AABB]:
	var result: Array[AABB] = []

	# 1. Manual exclusion boxes
	for box in manual_exclusion_boxes:
		if box.size.length_squared() > 0.01:
			result.append(box)

	var targets: Array[Node3D] = []

	# 2. Configured exclusion_nodes
	for path in exclusion_nodes:
		var target := get_node_or_null(path) as Node3D
		if target and not targets.has(target):
			targets.append(target)

	# 3. Scene landmark search (Visitor Center, Roads, Parking Lots, Barrier Trees)
	if auto_detect_landmarks:
		var scene_root := _get_scene_root()
		if scene_root:
			_find_landmarks(scene_root, targets)

		# Also check groups
		if is_inside_tree():
			var tree := get_tree()
			for g in [&"building_exclusion", &"road_exclusion", &"foliage_exclusion"]:
				for gnode in tree.get_nodes_in_group(g):
					if gnode is Node3D and not targets.has(gnode):
						targets.append(gnode as Node3D)

	# 4. Extract individual leaf shape AABBs from all target nodes
	for target in targets:
		_extract_node_aabbs(target, result)

	return result


## Searches node hierarchy for landmark names.
func _find_landmarks(node: Node, results: Array[Node3D]) -> void:
	if not is_instance_valid(node):
		return
	var lname := node.name.to_lower()
	if lname.contains("welcomecenter") or lname.contains("visitorcenter") or \
	   lname.contains("parkinglot") or lname.contains("parking") or \
	   lname.contains("mainroad") or lname.contains("road") or lname.contains("streets") or \
	   lname.contains("barriertree") or lname.contains("building"):
		if node is Node3D and not results.has(node):
			results.append(node as Node3D)

	for child in node.get_children():
		_find_landmarks(child, results)


## Extracts individual world AABBs from leaf geometry nodes under a target.
func _extract_node_aabbs(node: Node3D, out_aabbs: Array[AABB]) -> void:
	if not is_instance_valid(node):
		return

	# If node itself is a geometric leaf shape
	var has_direct_shape := false
	var local_aabb := AABB()

	if node.has_method(&"get_local_aabb"):
		local_aabb = node.call(&"get_local_aabb")
		has_direct_shape = true
	elif node is MeshInstance3D and node.mesh:
		local_aabb = node.mesh.get_aabb()
		has_direct_shape = true
	elif node is CSGShape3D:
		local_aabb = _csg_shape_to_aabb(node)
		has_direct_shape = true
	elif node is CollisionShape3D and node.shape:
		local_aabb = _collision_shape_to_aabb(node.shape)
		has_direct_shape = true

	if has_direct_shape and local_aabb.size.length_squared() > 0.01:
		var world_aabb := node.global_transform * local_aabb
		out_aabbs.append(world_aabb)

	# Recurse children to collect sub-meshes or sub-shapes (e.g. within Streets or ParkingLot)
	for child in node.get_children():
		if child is Node3D:
			_extract_node_aabbs(child as Node3D, out_aabbs)


func _collision_shape_to_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size * 0.5, shape.size)
	if shape is SphereShape3D:
		var r: float = shape.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	if shape is CylinderShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is CapsuleShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is ConvexPolygonShape3D:
		return _points_to_aabb(shape.points)
	if shape is ConcavePolygonShape3D:
		return _points_to_aabb(shape.get_faces())
	return AABB()


func _csg_shape_to_aabb(csg: CSGShape3D) -> AABB:
	if csg is CSGBox3D:
		return AABB(-csg.size * 0.5, csg.size)
	if csg is CSGSphere3D:
		var r: float = csg.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	if csg is CSGCylinder3D:
		var r: float = csg.radius
		var h: float = csg.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if csg is CSGPolygon3D:
		var poly: PackedVector2Array = csg.polygon
		if not poly.is_empty():
			var min_p := poly[0]
			var max_p := poly[0]
			for p in poly:
				min_p.x = min(min_p.x, p.x)
				min_p.y = min(min_p.y, p.y)
				max_p.x = max(max_p.x, p.x)
				max_p.y = max(max_p.y, p.y)
			var d: float = csg.depth
			return AABB(Vector3(min_p.x, min_p.y, -d * 0.5), Vector3(max_p.x - min_p.x, max_p.y - min_p.y, d))
	var meshes := csg.get_meshes()
	if meshes.size() > 1 and meshes[1] is Mesh:
		return (meshes[1] as Mesh).get_aabb()
	return AABB()


func _points_to_aabb(pts: PackedVector3Array) -> AABB:
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		aabb = aabb.expand(pts[i])
	return aabb


## Calculates the 2D bounding rectangle in world XZ for grass spawning.
func _calculate_spawn_bounds() -> Rect2:
	if not custom_area_node.is_empty():
		var target := get_node_or_null(custom_area_node) as Node3D
		if target:
			var target_aabbs: Array[AABB] = []
			_extract_node_aabbs(target, target_aabbs)
			if not target_aabbs.is_empty():
				var combined := target_aabbs[0]
				for k in range(1, target_aabbs.size()):
					combined = combined.merge(target_aabbs[k])
				return Rect2(Vector2(combined.position.x, combined.position.z), Vector2(combined.size.x, combined.size.z))

	var center := global_position + area_center_offset
	var half_w := area_size.x * 0.5
	var half_d := area_size.y * 0.5
	return Rect2(Vector2(center.x - half_w, center.z - half_d), area_size)


## Finds or sets up a MultiMeshInstance3D child node with proper settings.
func _setup_multimesh_node(existing: MultiMeshInstance3D, default_name: String, mesh_res: Mesh) -> MultiMeshInstance3D:
	var node: MultiMeshInstance3D = existing
	if not node:
		node = get_node_or_null(default_name) as MultiMeshInstance3D
	if not node:
		node = MultiMeshInstance3D.new()
		node.name = default_name
		add_child(node)
		if Engine.is_editor_hint() and is_inside_tree():
			var sroot := _get_scene_root()
			if sroot:
				node.owner = sroot

	node.cast_shadow = cast_shadows
	node.visibility_range_end = visibility_range_end
	node.visibility_range_fade_mode = visibility_range_fade_mode

	# Ensure material uses Alpha Scissor so depth-based post-process fog renders accurately
	if mesh_res and mesh_res.get_surface_count() > 0:
		var mat := mesh_res.surface_get_material(0)
		if mat is StandardMaterial3D:
			var std_mat := mat as StandardMaterial3D
			if std_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS or std_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA:
				std_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				std_mat.alpha_scissor_threshold = 0.5

	if not node.multimesh:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh_res
		node.multimesh = mm
	else:
		if node.multimesh.mesh != mesh_res:
			node.multimesh.mesh = mesh_res
		if node.multimesh.transform_format != MultiMesh.TRANSFORM_3D:
			node.multimesh.transform_format = MultiMesh.TRANSFORM_3D

	return node


func get_low_grass_node() -> MultiMeshInstance3D:
	if not low_grass_node_path.is_empty():
		return get_node_or_null(low_grass_node_path) as MultiMeshInstance3D
	return get_node_or_null("LowGrassMultiMesh") as MultiMeshInstance3D


func get_tall_grass_node() -> MultiMeshInstance3D:
	if not tall_grass_node_path.is_empty():
		return get_node_or_null(tall_grass_node_path) as MultiMeshInstance3D
	return get_node_or_null("TallGrassMultiMesh") as MultiMeshInstance3D


func _get_scene_root() -> Node:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	if Engine.is_editor_hint():
		return tree.edited_scene_root if tree.edited_scene_root else get_parent()
	return tree.current_scene if tree.current_scene else get_parent()
