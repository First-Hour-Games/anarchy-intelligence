@tool
extends Node3D
class_name ProceduralTreeGenerator

## Comprehensive Procedural Tree Generator and Manager for outdoor forest environments.
## Provides one-click Inspector buttons to fill in empty clearings, regenerate all tree
## MultiMeshes, and prune trees against buildings, parking lots, roads, and vehicles.

signal trees_generated(total_instances: int, filled_count: int, pruned_count: int)
signal trees_cleared()

@export_group("Editor Actions")
## Click this checkbox in the Godot Inspector to fill in the empty clearing (where Welcome Center / buildings were previously located) and prune all colliding trees.
@export var click_to_fill_clearing_and_prune_now: bool = false:
	set(val):
		if val:
			fill_clearing_and_prune()
			click_to_fill_clearing_and_prune_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to fill in ALL sparse gaps across the entire forest and prune all colliding trees.
@export var click_to_fill_all_gaps_and_prune_now: bool = false:
	set(val):
		if val:
			fill_all_and_prune()
			click_to_fill_all_gaps_and_prune_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to regenerate ALL tree MultiMeshes from scratch across all placement zones.
@export var click_to_regenerate_all_now: bool = false:
	set(val):
		if val:
			regenerate_all_trees()
			click_to_regenerate_all_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to prune only (removes trees colliding with buildings/roads, facing downward, or clashing).
@export var click_to_prune_now: bool = false:
	set(val):
		if val:
			prune_all_trees()
			click_to_prune_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to clear all tree instances from all managed tree MultiMeshes.
@export var click_to_clear_now: bool = false:
	set(val):
		if val:
			clear_all_trees()
			click_to_clear_now = false
			notify_property_list_changed()


@export_group("Tree Spacing & Placement")
## Random offset within each grid cell: 0 gives a regular grid, 1 uses the whole cell.
@export_range(0.0, 1.0, 0.01) var scatter_strength: float = 0.8

## Fraction of candidate cells populated. Lower values produce a sparser forest.
@export_range(0.0, 1.0, 0.01) var placement_density: float = 1.0

## Minimum horizontal distance (in meters) between any two trees to avoid visual overlap.
@export_range(1.0, 10.0, 0.1) var min_tree_distance: float = 2.8

## Grid step spacing (in meters) used when sampling candidate locations for trees.
@export_range(2.0, 15.0, 0.2) var grid_step: float = 4.8

## Target ground elevation Y for spawned tree instances.
@export var ground_y: float = -0.008

## Random seed for reproducible procedural tree generation.
@export var random_seed: int = 1337


@export_group("Vacated Clearing Zone")
## X bounds for the vacated clearing zone to fill (covers the old Welcome Center & Parking area).
@export var clearing_x_range: Vector2 = Vector2(-350.0, -180.0)

## Z bounds for the vacated clearing zone to fill.
@export var clearing_z_range: Vector2 = Vector2(-28.0, 5.0)


@export_group("Exclusion Zones & Margins")
## Extra padding/margin (in meters) around building and parking bounds.
@export_range(0.0, 10.0, 0.1) var exclusion_margin: float = 1.5

## Additional road safety margin (in meters) along roads to keep shoulders clear.
@export_range(0.0, 10.0, 0.1) var road_exclusion_margin: float = 2.0

## Specific nodes whose bounding boxes will be excluded. If empty, automatically discovers landmarks.
@export var exclusion_nodes: Array[NodePath] = []

## Additional manual bounding boxes (in global coordinates) to exclude trees from.
@export var manual_exclusion_boxes: Array[AABB] = []

## If true, automatically discovers scene landmarks (welcome center, parking lot, main road, car, gas station).
@export var auto_detect_landmarks: bool = true


@export_group("Placement Volumes")
## Placement volumes: MeshInstance3D (BoxMesh) or MapBoundaryZone3D nodes.
## Multiple entries form a union. Boundary zones respect position, rotation and scale;
## their volume must intersect Ground Y. Paths are relative to this generator.
## If empty, auto-discovers children matching TreePlacement*.
@export var custom_placement_nodes: Array[NodePath] = []

## Optional area override node (e.g. GroundPlane) if no TreePlacement volumes are found.
@export var custom_area_node: NodePath

## Default fallback area size in meters (X = width, Y = depth in Z axis) if no TreePlacement or custom_area_node is found.
@export var fallback_area_size: Vector2 = Vector2(700.0, 150.0)

## Positional offset for the fallback area.
@export var fallback_area_offset: Vector3 = Vector3(25.0, 0.0, -10.0)


## Priority MultiMesh name that takes precedence during deduplication (e.g. "treeMulti9").
@export var top_priority_node_name: String = "treeMulti9"


# Known default scale ranges per tree node type
const DEFAULT_SCALE_RANGES: Dictionary = {
	"treemulti2": Vector2(1.7, 2.3),
	"treemulti7": Vector2(1.1, 1.8),
	"treemulti3": Vector2(1.7, 2.7),
	"treemulti4": Vector2(1.4, 2.5),
	"treemulti8": Vector2(1.3, 2.7),
	"treemulti5": Vector2(1.2, 1.8),
	"treemulti9": Vector2(2.0, 4.0),
	"treemulti10": Vector2(3.0, 4.8),
	"treemulti11": Vector2(3.2, 4.7),
	"treemulti12": Vector2(3.8, 4.2),
	"treemulti6": Vector2(1.1, 1.9),
	"treemulti": Vector2(1.2, 1.3)
}

@export_group("Tree Scale & Rotation")
## Uniform world-space scale ranges per MultiMesh node name (case insensitive).
## Each instance independently samples its tree type's range. Add other node names as needed.
@export var tree_scale_ranges: Dictionary[String, Vector2] = {
	"treemulti2": Vector2(1.7, 2.3),
	"treemulti7": Vector2(1.1, 1.8),
	"treemulti3": Vector2(1.7, 2.7),
	"treemulti4": Vector2(1.4, 2.5),
	"treemulti8": Vector2(1.3, 2.7),
	"treemulti5": Vector2(1.2, 1.8),
	"treemulti9": Vector2(2.0, 4.0),
	"treemulti10": Vector2(3.0, 4.8),
	"treemulti11": Vector2(3.2, 4.7),
	"treemulti12": Vector2(3.8, 4.2),
	"treemulti6": Vector2(1.1, 1.9),
	"treemulti": Vector2(1.2, 1.3)
}
## Scale range for tree types with no configured range.
@export var fallback_scale_range: Vector2 = Vector2(1.8, 2.6)
## Multiplies every tree type's scale range.
@export_range(0.01, 10.0, 0.01, "or_greater") var tree_scale_multiplier: float = 1.0
## Random rotation range in degrees around the world vertical axis. Equal endpoints give fixed rotation.
@export var yaw_range_degrees: Vector2 = Vector2(0.0, 360.0)
## Applies configured scale and yaw to existing trees while preserving positions. Does not prune or scatter.
@export var click_to_randomize_existing_variation_now: bool = false:
	set(val):
		if val:
			randomize_existing_tree_variation()
			click_to_randomize_existing_variation_now = false
			notify_property_list_changed()


func randomize_existing_tree_variation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	var nodes := _collect_tree_multimeshes()
	_sort_tree_nodes_by_priority(nodes)
	for node in nodes:
		var mm := node.multimesh
		if not mm or mm.transform_format != MultiMesh.TRANSFORM_3D:
			continue
		var world := _get_node_global_xform(node)
		for i in range(mm.instance_count):
			var instance := mm.get_instance_transform(i)
			instance.basis = world.basis.inverse() * _sample_tree_basis(node, rng)
			mm.set_instance_transform(i, instance)
		mm.emit_changed()


func _sample_tree_basis(node: MultiMeshInstance3D, rng: RandomNumberGenerator) -> Basis:
	var model_up := get_mesh_up_vector(node.multimesh.mesh)
	var scale_range := _get_scale_range(node)
	var scale_value := rng.randf_range(scale_range.x, scale_range.y)
	var q_up := Quaternion(model_up, Vector3.UP) if model_up != Vector3.UP else Quaternion.IDENTITY
	var yaw := rng.randf_range(minf(yaw_range_degrees.x, yaw_range_degrees.y), maxf(yaw_range_degrees.x, yaw_range_degrees.y))
	return Basis(Quaternion(Vector3.UP, deg_to_rad(yaw)) * q_up).scaled(Vector3.ONE * scale_value)


func _ready() -> void:
	pass


## Fills the empty clearing where the Welcome Center was moved from, preserving valid existing trees and pruning collisions.
func fill_clearing_and_prune() -> Dictionary:
	return _execute_fill_and_prune(true)


## Fills all sparse gaps across all placement volumes, preserving valid existing trees and pruning collisions.
func fill_all_and_prune() -> Dictionary:
	return _execute_fill_and_prune(false)


## Alias for compatibility with external caller scripts.
func fill_and_prune_trees() -> Dictionary:
	return fill_clearing_and_prune()


## Clears all managed tree MultiMeshes and regenerates the entire forest from scratch across all placement zones.
func regenerate_all_trees() -> Dictionary:
	var tree_nodes := _collect_tree_multimeshes()
	if tree_nodes.is_empty():
		printerr("[ProceduralTreeGenerator] No tree MultiMesh nodes found.")
		return {}

	for node in tree_nodes:
		if node.multimesh:
			node.multimesh.instance_count = 0
			node.multimesh.buffer = PackedFloat32Array()
			node.multimesh.emit_changed()

	return _execute_fill_and_prune(false)


## Prunes all trees against exclusion zones, downward facing orientation, and inter-tree collisions without adding new trees.
func prune_all_trees() -> Dictionary:
	var tree_nodes := _collect_tree_multimeshes()
	if tree_nodes.is_empty():
		return {}

	var exclusion_boxes := get_all_exclusion_aabbs()
	var obb_zones := get_exclusion_zones()
	var min_dist_sq := min_tree_distance * min_tree_distance

	_sort_tree_nodes_by_priority(tree_nodes)

	var initial_total := 0
	var kept_total := 0
	var pruned_total := 0
	var accepted_positions: Array[Vector3] = []

	for node in tree_nodes:
		var mm := node.multimesh
		if not mm or mm.instance_count == 0:
			continue
		var buf := mm.buffer
		if buf.is_empty():
			continue

		var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
		var stride: int = 12 if is_3d else 8
		if mm.use_colors: stride += 4
		if mm.use_custom_data: stride += 4

		var count := mm.instance_count
		initial_total += count
		var node_xform := _get_node_global_xform(node)
		var model_up := get_mesh_up_vector(mm.mesh)
		var new_buf := PackedFloat32Array()
		var node_kept := 0

		for i in range(count):
			var base := i * stride

			# 1. Orientation check
			if is_3d:
				var local_dir := Vector3(
					buf[base + 0] * model_up.x + buf[base + 1] * model_up.y + buf[base + 2] * model_up.z,
					buf[base + 4] * model_up.x + buf[base + 5] * model_up.y + buf[base + 6] * model_up.z,
					buf[base + 8] * model_up.x + buf[base + 9] * model_up.y + buf[base + 10] * model_up.z
				)
				var world_dir := node_xform.basis * local_dir
				if world_dir.y < -0.05:
					pruned_total += 1
					continue

			var local_orig := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
			var gpos := node_xform * local_orig

			# 2. OBB zones check
			var is_rejected := false
			for zone in obb_zones:
				if zone.is_point_inside(gpos):
					is_rejected = true
					break
			if is_rejected:
				pruned_total += 1
				continue

			# 3. AABB exclusion check
			for box in exclusion_boxes:
				if _is_point_inside_aabb(gpos, box, exclusion_margin):
					is_rejected = true
					break
			if is_rejected:
				pruned_total += 1
				continue

			# 4. Collision with prior accepted trees
			for prev in accepted_positions:
				var dx: float = gpos.x - prev.x
				var dz: float = gpos.z - prev.z
				if (dx * dx + dz * dz) < min_dist_sq:
					is_rejected = true
					break
			if is_rejected:
				pruned_total += 1
				continue

			# Accept instance
			accepted_positions.append(gpos)
			node_kept += 1
			kept_total += 1
			for s in range(stride):
				new_buf.append(buf[base + s])

		mm.instance_count = node_kept
		mm.buffer = new_buf
		mm.emit_changed()

	print("[ProceduralTreeGenerator] Pruning complete: Initial: %d, Kept: %d, Pruned: %d" % [initial_total, kept_total, pruned_total])
	return {
		"initial_total": initial_total,
		"kept_total": kept_total,
		"pruned_total": pruned_total,
		"final_total": kept_total
	}


## Clears all instances from all managed tree MultiMeshes.
func clear_all_trees() -> void:
	var tree_nodes := _collect_tree_multimeshes()
	for node in tree_nodes:
		if node.multimesh:
			node.multimesh.instance_count = 0
			node.multimesh.buffer = PackedFloat32Array()
			node.multimesh.emit_changed()
	trees_cleared.emit()
	print("[ProceduralTreeGenerator] All tree MultiMeshes cleared.")


## Internal core generator logic.
func _execute_fill_and_prune(clearing_only: bool) -> Dictionary:
	var start_time: int = Time.get_ticks_msec()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var tree_nodes := _collect_tree_multimeshes()
	if tree_nodes.is_empty():
		printerr("[ProceduralTreeGenerator] No tree MultiMesh nodes found to process.")
		return {}

	_sort_tree_nodes_by_priority(tree_nodes)

	var exclusion_boxes := get_all_exclusion_aabbs()
	var obb_zones := get_exclusion_zones()
	var min_dist_sq := min_tree_distance * min_tree_distance

	# Spatial grid for fast distance lookup
	var grid: Dictionary = {} # Vector2i -> Array[Vector3]
	var accepted_buffers: Dictionary = {} # MultiMeshInstance3D -> PackedFloat32Array

	var initial_total := 0
	var kept_total := 0
	var pruned_total := 0

	# --- Pass 1: Prune existing trees and retain non-colliding instances ---
	for node in tree_nodes:
		accepted_buffers[node] = PackedFloat32Array()
		var mm := node.multimesh
		if not mm or mm.instance_count == 0:
			continue
		var buf := mm.buffer
		if buf.is_empty():
			continue

		var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
		var stride: int = 12 if is_3d else 8
		if mm.use_colors: stride += 4
		if mm.use_custom_data: stride += 4

		var count := mm.instance_count
		initial_total += count
		var node_xform := _get_node_global_xform(node)
		var model_up := get_mesh_up_vector(mm.mesh)

		for i in range(count):
			var base := i * stride

			# 1. Orientation check
			if is_3d:
				var local_dir := Vector3(
					buf[base + 0] * model_up.x + buf[base + 1] * model_up.y + buf[base + 2] * model_up.z,
					buf[base + 4] * model_up.x + buf[base + 5] * model_up.y + buf[base + 6] * model_up.z,
					buf[base + 8] * model_up.x + buf[base + 9] * model_up.y + buf[base + 10] * model_up.z
				)
				var world_dir := node_xform.basis * local_dir
				if world_dir.y < -0.05:
					pruned_total += 1
					continue

			var local_orig := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
			var gpos := node_xform * local_orig

			# 2. OBB zones check
			var is_rejected := false
			for zone in obb_zones:
				if zone.is_point_inside(gpos):
					is_rejected = true
					break
			if is_rejected:
				pruned_total += 1
				continue

			# 3. AABB exclusion check
			for box in exclusion_boxes:
				if _is_point_inside_aabb(gpos, box, exclusion_margin):
					is_rejected = true
					break
			if is_rejected:
				pruned_total += 1
				continue

			# 4. Distance check against already accepted trees
			if _is_too_close_to_grid(gpos, grid, min_dist_sq, min_tree_distance):
				pruned_total += 1
				continue

			# Instance accepted
			_add_point_to_grid(gpos, grid, min_tree_distance)
			var node_buf: PackedFloat32Array = accepted_buffers[node]
			for s in range(stride):
				node_buf.append(buf[base + s])
			accepted_buffers[node] = node_buf
			kept_total += 1

	# --- Pass 2: Fill empty areas across placement volumes ---
	var placement_rects := _collect_placement_rects(clearing_only)
	var placement_zones := _collect_boundary_placement_zones()
	var filled_total := 0

	# Distribute filling candidates across main diverse tree MultiMeshes
	var fill_pool: Array[MultiMeshInstance3D] = []
	for node in tree_nodes:
		var lname := node.name.to_lower()
		if lname in ["treemulti3", "treemulti8", "treemulti9", "treemulti5", "treemulti6", "treemulti2"]:
			fill_pool.append(node)
	if fill_pool.is_empty():
		fill_pool = tree_nodes

	var pool_idx := 0
	var step: float = maxf(grid_step, min_tree_distance * 1.2)

	for rect in placement_rects:
		var x_count := int(rect.size.x / step)
		var z_count := int(rect.size.y / step)
		if x_count <= 0 or z_count <= 0:
			continue

		for xi in range(x_count):
			for zi in range(z_count):
				if placement_density < 1.0 and rng.randf() >= clampf(placement_density, 0.0, 1.0):
					continue
				# Jitter within cell
				var jitter := clampf(scatter_strength, 0.0, 1.0) * 0.5
				var px := rect.position.x + (float(xi) + rng.randf_range(0.5 - jitter, 0.5 + jitter)) * step
				var pz := rect.position.y + (float(zi) + rng.randf_range(0.5 - jitter, 0.5 + jitter)) * step

				if clearing_only:
					if px < clearing_x_range.x or px > clearing_x_range.y or pz < clearing_z_range.x or pz > clearing_z_range.y:
						continue

				var pt := Vector3(px, ground_y, pz)
				if not _is_inside_configured_placement(pt, placement_zones):
					continue

				# Check OBB exclusion
				var excluded := false
				for zone in obb_zones:
					if zone.is_point_inside(pt):
						excluded = true
						break
				if excluded:
					continue

				# Check AABB exclusion
				for box in exclusion_boxes:
					if _is_point_inside_aabb(pt, box, exclusion_margin):
						excluded = true
						break
				if excluded:
					continue

				# Check distance against spatial grid
				if _is_too_close_to_grid(pt, grid, min_dist_sq, min_tree_distance):
					continue

				# Accept candidate tree!
				_add_point_to_grid(pt, grid, min_tree_distance)
				var target_node := fill_pool[pool_idx % fill_pool.size()]
				pool_idx += 1

				var basis := _sample_tree_basis(target_node, rng)

				# Transform into target node local coordinates
				var node_xform := _get_node_global_xform(target_node)
				var local_origin := node_xform.affine_inverse() * pt
				var local_basis := node_xform.basis.inverse() * basis

				var target_buf: PackedFloat32Array = accepted_buffers[target_node]
				target_buf.append(local_basis.x.x); target_buf.append(local_basis.y.x); target_buf.append(local_basis.z.x); target_buf.append(local_origin.x)
				target_buf.append(local_basis.x.y); target_buf.append(local_basis.y.y); target_buf.append(local_basis.z.y); target_buf.append(local_origin.y)
				target_buf.append(local_basis.x.z); target_buf.append(local_basis.y.z); target_buf.append(local_basis.z.z); target_buf.append(local_origin.z)
				accepted_buffers[target_node] = target_buf
				filled_total += 1

	# --- Pass 3: Apply updated buffers to MultiMeshes ---
	var final_total := 0
	for node in tree_nodes:
		var buf: PackedFloat32Array = accepted_buffers[node]
		var new_count := int(buf.size() / 12)
		node.multimesh.instance_count = new_count
		node.multimesh.buffer = buf
		node.multimesh.emit_changed()
		final_total += new_count

	var elapsed := Time.get_ticks_msec() - start_time
	print("[ProceduralTreeGenerator] Generation Complete in %d ms!" % elapsed)
	print("  Initial: %d | Pruned: %d | Kept: %d | Newly Filled: %d | Final Total: %d" % [
		initial_total, pruned_total, kept_total, filled_total, final_total
	])

	trees_generated.emit(final_total, filled_total, pruned_total)

	return {
		"initial_total": initial_total,
		"pruned_total": pruned_total,
		"kept_total": kept_total,
		"filled_total": filled_total,
		"final_total": final_total,
		"elapsed_ms": elapsed
	}


## Collects all MultiMeshInstance3D nodes to manage.
func _collect_tree_multimeshes() -> Array[MultiMeshInstance3D]:
	var results: Array[MultiMeshInstance3D] = []
	var search_root: Node = self
	if _count_tree_children(search_root) == 0 and get_parent() != null:
		search_root = get_parent()

	for child in search_root.get_children():
		if child is MultiMeshInstance3D:
			var lname := child.name.to_lower()
			if lname.contains("tree") or lname.begins_with("treemulti"):
				if not results.has(child):
					results.append(child as MultiMeshInstance3D)
	return results


func _count_tree_children(n: Node) -> int:
	var c := 0
	for child in n.get_children():
		if child is MultiMeshInstance3D and (child.name.to_lower().contains("tree") or child.name.begins_with("treemulti")):
			c += 1
	return c


func _collect_boundary_placement_zones() -> Array[MapBoundaryZone3D]:
	var zones: Array[MapBoundaryZone3D] = []
	for path in custom_placement_nodes:
		var zone := get_node_or_null(path) as MapBoundaryZone3D
		if zone and not zones.has(zone):
			zones.append(zone)
	return zones


func _is_inside_configured_placement(point: Vector3, zones: Array[MapBoundaryZone3D]) -> bool:
	if zones.is_empty():
		return true
	for zone in zones:
		var world := _get_node_global_xform(zone)
		if is_zero_approx(world.basis.determinant()):
			continue
		var local := world.affine_inverse() * point
		var half := zone.size.abs() * 0.5
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z:
			return true
	# Mixed configurations may also contain legacy BoxMesh placement rectangles.
	for path in custom_placement_nodes:
		var mesh_node := get_node_or_null(path) as MeshInstance3D
		if mesh_node and mesh_node.mesh is BoxMesh:
			var center := _get_node_global_xform(mesh_node).origin
			var half: Vector3 = mesh_node.mesh.size * 0.5
			if absf(point.x - center.x) <= half.x and absf(point.z - center.z) <= half.z:
				return true
	return false


## Collects candidate rectangles. Oriented boundary volumes are checked before accepting candidates.
func _collect_placement_rects(clearing_only: bool) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var nodes: Array[MeshInstance3D] = []

	if not custom_placement_nodes.is_empty():
		for path in custom_placement_nodes:
			var zone := get_node_or_null(path) as MapBoundaryZone3D
			if zone:
				var zone_size := zone.size.abs()
				var bounds := _get_node_global_xform(zone) * AABB(-zone_size * 0.5, zone_size)
				var rect := Rect2(bounds.position.x, bounds.position.z, bounds.size.x, bounds.size.z)
				if clearing_only:
					rect = rect.intersection(Rect2(clearing_x_range.x, clearing_z_range.x, clearing_x_range.y - clearing_x_range.x, clearing_z_range.y - clearing_z_range.x))
				if rect.has_area() and ground_y >= bounds.position.y and ground_y <= bounds.end.y:
					rects.append(rect)
				continue
			var n := get_node_or_null(path) as MeshInstance3D
			if n and not nodes.has(n):
				nodes.append(n)
	else:
		var search_root: Node = self
		if not _has_placement_child(search_root) and get_parent() != null:
			search_root = get_parent()

		for child in search_root.get_children():
			if child is MeshInstance3D and child.name.begins_with("TreePlacement"):
				nodes.append(child as MeshInstance3D)

	for mi in nodes:
		if mi.mesh is BoxMesh:
			var bm := mi.mesh as BoxMesh
			var gpos := _get_node_global_xform(mi).origin
			var half_x := bm.size.x * 0.5
			var half_z := bm.size.z * 0.5
			var min_x := gpos.x - half_x
			var max_x := gpos.x + half_x
			var min_z := gpos.z - half_z
			var max_z := gpos.z + half_z

			# Expand TreePlacement2 to span across entire clearing gap if applicable
			if mi.name == "TreePlacement2" and min_x > -300.0:
				min_x = -350.0

			if clearing_only:
				# Clip rect to clearing zone
				min_x = maxf(min_x, clearing_x_range.x)
				max_x = minf(max_x, clearing_x_range.y)
				min_z = maxf(min_z, clearing_z_range.x)
				max_z = minf(max_z, clearing_z_range.y)
				if min_x >= max_x or min_z >= max_z:
					continue

			rects.append(Rect2(min_x, min_z, max_x - min_x, max_z - min_z))

	if rects.is_empty() and custom_placement_nodes.is_empty():
		var fb_rect := _calculate_fallback_rect()
		var min_x := fb_rect.position.x
		var max_x := fb_rect.end.x
		var min_z := fb_rect.position.y
		var max_z := fb_rect.end.y
		if clearing_only:
			min_x = maxf(min_x, clearing_x_range.x)
			max_x = minf(max_x, clearing_x_range.y)
			min_z = maxf(min_z, clearing_z_range.x)
			max_z = minf(max_z, clearing_z_range.y)
		if min_x < max_x and min_z < max_z:
			rects.append(Rect2(min_x, min_z, max_x - min_x, max_z - min_z))

	return rects


func _calculate_fallback_rect() -> Rect2:
	if not custom_area_node.is_empty():
		var area_node := get_node_or_null(custom_area_node) as Node3D
		if is_instance_valid(area_node):
			var box := _calculate_node_world_aabb(area_node)
			if box.size.length_squared() > 0.01:
				return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

	var search_root := _get_scene_root()
	if is_instance_valid(search_root):
		var ground := search_root.get_node_or_null("GroundPlane") as Node3D
		if is_instance_valid(ground):
			var box := _calculate_node_world_aabb(ground)
			if box.size.length_squared() > 0.01:
				return Rect2(box.position.x, box.position.z, box.size.x, box.size.z)

	return Rect2(
		fallback_area_offset.x - fallback_area_size.x * 0.5,
		fallback_area_offset.z - fallback_area_size.y * 0.5,
		fallback_area_size.x,
		fallback_area_size.y
	)


func _has_placement_child(n: Node) -> bool:
	for child in n.get_children():
		if child is MeshInstance3D and child.name.begins_with("TreePlacement"):
			return true
	return false


## Collects all active exclusion AABBs in world coordinates.
func get_all_exclusion_aabbs() -> Array[AABB]:
	var aabbs: Array[AABB] = []

	for box in manual_exclusion_boxes:
		aabbs.append(box)

	var targets: Array[Node3D] = []

	# 1. Configured exclusion_nodes
	for path in exclusion_nodes:
		var target := get_node_or_null(path) as Node3D
		if target and not targets.has(target):
			targets.append(target)

	# 2. Auto-detect landmarks from scene root
	if auto_detect_landmarks:
		var root := _get_scene_root()
		if root:
			_find_landmarks(root, targets)

	# 3. Collect from building_exclusion and foliage_exclusion groups
	if is_inside_tree():
		for g in [&"building_exclusion", &"foliage_exclusion"]:
			for gnode in get_tree().get_nodes_in_group(g):
				if gnode is Node3D and not targets.has(gnode):
					targets.append(gnode as Node3D)

	# Calculate world AABB for each target
	for target in targets:
		var box := _calculate_node_world_aabb(target)
		if box.size.length_squared() > 0.01:
			var pad := road_exclusion_margin if target.name.to_lower().contains("road") else exclusion_margin
			aabbs.append(box.grow(pad))

	return aabbs


## Collects all active oriented exclusion zones (TreeExclusionZone3D).
func get_exclusion_zones() -> Array[Node3D]:
	var zones: Array[Node3D] = []
	if is_inside_tree():
		for gnode in get_tree().get_nodes_in_group(&"tree_exclusion_zone"):
			if gnode is Node3D and gnode.has_method(&"is_point_inside") and not zones.has(gnode):
				zones.append(gnode as Node3D)
	return zones


func _find_landmarks(node: Node, results: Array[Node3D]) -> void:
	if not is_instance_valid(node):
		return
	var lname := node.name.to_lower()
	if lname.contains("welcomecenter") or lname.contains("visitorcenter") or \
	   lname.contains("parkinglot") or lname.contains("mainroad") or \
	   lname.contains("gasstation") or lname.contains("toyotacrown"):
		if node is Node3D and not results.has(node):
			results.append(node as Node3D)
	for child in node.get_children():
		_find_landmarks(child, results)


## Returns the active scene root.
func _get_scene_root() -> Node:
	if Engine.is_editor_hint() and is_inside_tree():
		var edited := get_tree().edited_scene_root
		if is_instance_valid(edited):
			return edited
	var curr: Node = self
	var tree_root: Node = get_tree().get_root() if is_inside_tree() else null
	while curr.get_parent() != null and curr.get_parent() != tree_root:
		curr = curr.get_parent()
	return curr


## Computes the world AABB of a Node3D by aggregating all descendant leaf shapes.
func _calculate_node_world_aabb(node: Node3D) -> AABB:
	if not is_instance_valid(node):
		return AABB()

	if node.has_method(&"get_exclusion_aabb"):
		return node.call(&"get_exclusion_aabb")
	if node.has_method(&"get_world_aabb"):
		return node.call(&"get_world_aabb")

	var leaf_local := _get_leaf_local_aabb(node)
	var combined := AABB()
	var has_bounds := false

	if leaf_local.size.length_squared() > 0.001:
		combined = _get_node_global_xform(node) * leaf_local
		has_bounds = true

	for child in node.get_children():
		if child is Node3D:
			var child_world := _calculate_node_world_aabb(child as Node3D)
			if child_world.size.length_squared() > 0.001:
				if not has_bounds:
					combined = child_world
					has_bounds = true
				else:
					combined = combined.merge(child_world)
	return combined


func _get_leaf_local_aabb(node: Node3D) -> AABB:
	if node.has_method(&"get_local_aabb"):
		return node.call(&"get_local_aabb")
	if node is MeshInstance3D and node.mesh:
		return node.mesh.get_aabb()
	if node is CollisionShape3D and node.shape:
		return _shape_to_aabb(node.shape)
	if node is CSGShape3D:
		return _csg_to_aabb(node)
	return AABB()


func _shape_to_aabb(shape: Shape3D) -> AABB:
	if shape is BoxShape3D:
		return AABB(-shape.size * 0.5, shape.size)
	if shape is SphereShape3D:
		var r: float = shape.radius
		return AABB(Vector3(-r, -r, -r), Vector3(r * 2.0, r * 2.0, r * 2.0))
	if shape is CylinderShape3D or shape is CapsuleShape3D:
		var r: float = shape.radius
		var h: float = shape.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(r * 2.0, h, r * 2.0))
	if shape is ConvexPolygonShape3D:
		return _points_to_aabb(shape.points)
	if shape is ConcavePolygonShape3D:
		return _points_to_aabb(shape.get_faces())
	return AABB()


func _points_to_aabb(pts: PackedVector3Array) -> AABB:
	if pts.is_empty():
		return AABB()
	var aabb := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		aabb = aabb.expand(pts[i])
	return aabb


func _csg_to_aabb(csg: CSGShape3D) -> AABB:
	if csg is CSGBox3D:
		return AABB(-csg.size * 0.5, csg.size)
	var meshes := csg.get_meshes()
	if meshes.size() > 1 and meshes[1] is Mesh:
		return (meshes[1] as Mesh).get_aabb()
	return AABB()


func _is_point_inside_aabb(pt: Vector3, box: AABB, pad: float) -> bool:
	return pt.x >= (box.position.x - pad) and pt.x <= (box.end.x + pad) and \
		   pt.z >= (box.position.z - pad) and pt.z <= (box.end.z + pad) and \
		   pt.y >= (box.position.y - 1.5) and pt.y <= (box.end.y + 1.5)


func _is_too_close_to_grid(pt: Vector3, grid: Dictionary, min_dist_sq: float, cell_size: float) -> bool:
	var cx := int(floor(pt.x / cell_size))
	var cz := int(floor(pt.z / cell_size))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var key := Vector2i(cx + dx, cz + dz)
			if grid.has(key):
				var cell_pts: Array = grid[key]
				for existing in cell_pts:
					var ex: float = pt.x - existing.x
					var ez: float = pt.z - existing.z
					if (ex * ex + ez * ez) < min_dist_sq:
						return true
	return false


func _add_point_to_grid(pt: Vector3, grid: Dictionary, cell_size: float) -> void:
	var cx := int(floor(pt.x / cell_size))
	var cz := int(floor(pt.z / cell_size))
	var key := Vector2i(cx, cz)
	if not grid.has(key):
		grid[key] = []
	grid[key].append(pt)


## Calculates the local mesh up vector based on bounding box extents.
func get_mesh_up_vector(m: Mesh) -> Vector3:
	if not m:
		return Vector3.UP
	var aabb := m.get_aabb()
	if aabb.size.z > aabb.size.y and aabb.size.z > aabb.size.x:
		return Vector3(0, 0, -1) if aabb.position.z < 0.0 else Vector3(0, 0, 1)
	else:
		return Vector3(0, 1, 0) if aabb.end.y > abs(aabb.position.y) else Vector3(0, -1, 0)


## Determines scale variation range for a given MultiMesh node.
func _get_scale_range(node: MultiMeshInstance3D) -> Vector2:
	var lname := node.name.to_lower()
	var configured := fallback_scale_range
	for key in tree_scale_ranges:
		if key.to_lower() == lname:
			configured = tree_scale_ranges[key]
			break
	var multiplier := maxf(tree_scale_multiplier, 0.01)
	return Vector2(maxf(minf(configured.x, configured.y), 0.01), maxf(maxf(configured.x, configured.y), 0.01)) * multiplier


func _sort_tree_nodes_by_priority(nodes: Array[MultiMeshInstance3D]) -> void:
	nodes.sort_custom(func(a: MultiMeshInstance3D, b: MultiMeshInstance3D) -> bool:
		var pa := _get_tree_priority(a.name)
		var pb := _get_tree_priority(b.name)
		return pa < pb if pa != pb else a.name < b.name
	)


func _get_tree_priority(node_name: String) -> int:
	if node_name == top_priority_node_name:
		return -1
	var regex := RegEx.new()
	regex.compile("(\\d+)")
	var m := regex.search(node_name)
	return m.get_string().to_int() if m else 1


## Robust global transform retrieval that functions accurately in-editor, in-game, and in headless SceneTree states.
func _get_node_global_xform(node: Node3D) -> Transform3D:
	if not is_instance_valid(node):
		return Transform3D.IDENTITY
	if node.is_inside_tree():
		return node.global_transform
	var xform := node.transform
	var curr: Node = node.get_parent()
	while curr != null and curr is Node3D:
		xform = (curr as Node3D).transform * xform
		curr = curr.get_parent()
	return xform
