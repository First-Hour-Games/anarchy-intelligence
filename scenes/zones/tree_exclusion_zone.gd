@tool
class_name TreeExclusionZone3D extends Node3D

## A universal, reusable 3D zone for clearing tree MultiMesh instances.
## Place anywhere in a level, adjust size and orientation, and it will prune any
## tree instances that fall inside its oriented bounding box (OBB).
## Works both automatically on scene start and directly in the Godot Editor.

signal trees_pruned(zone: TreeExclusionZone3D, removed_count: int)

@export_group("Zone Bounds")
## Dimensions (width X, height Y, depth Z) of the exclusion volume in meters.
@export var size: Vector3 = Vector3(15.0, 10.0, 15.0):
	set(val):
		size = val
		_update_preview()

## Extra padding/margin around the exclusion box (in meters).
@export_range(0.0, 10.0, 0.1) var margin: float = 0.5

## Color used for the editor translucent box preview.
@export var zone_color: Color = Color(0.9, 0.25, 0.2, 0.3):
	set(val):
		zone_color = val
		_update_preview()

## Whether to render the translucent preview box in the Godot editor.
@export var show_in_editor: bool = true:
	set(val):
		show_in_editor = val
		_update_preview()

## If true, keeps the translucent preview box visible in-game for visual debugging.
@export var show_in_game_debug: bool = false:
	set(val):
		show_in_game_debug = val
		_update_preview()

@export_group("Pruning Settings")
## If true, automatically prunes tree MultiMeshes when this zone enters the scene tree at runtime.
@export var auto_prune_on_ready: bool = true

## If true, only targets MultiMeshInstance3D nodes identified as trees (via name keywords or is_tree_node).
## If false, prunes any MultiMeshInstance3D found within target scope.
@export var filter_trees_only: bool = true

## Substrings used to identify tree MultiMesh nodes (case-insensitive).
@export var tree_name_keywords: Array[String] = [
	"tree", "treemulti", "pine", "birch", "oak", "wood", "spruce", "fir", "willow", "palm", "foliage_tree"
]

## If true, also registers this zone with ProceduralGrassGenerator and foliage exclusion
## so grass is cleared inside this zone as well.
@export var exclude_grass: bool = false:
	set(val):
		exclude_grass = val
		_update_groups()

@export_group("Target Scope")
## Specific MultiMeshInstance3D nodes or parent containers to prune.
## If empty, automatically searches from the active scene root or search_root_path.
@export var target_nodes: Array[NodePath] = []

## Optional node path to limit auto-search scope (e.g. "Foliage" node). If empty, searches the scene root.
@export var search_root_path: NodePath = NodePath("")

@export_group("Editor Actions")
## Click this checkbox in the Godot Inspector to prune matching trees immediately in the editor.
@export var click_to_prune_now: bool = false:
	set(val):
		if val:
			var res := prune_trees()
			var rem: int = res.get("total_instances_removed", 0)
			var mod: int = res.get("modified_nodes", 0)
			print("[TreeExclusionZone3D] '%s': Pruned %d tree instances across %d MultiMesh nodes." % [name, rem, mod])
			click_to_prune_now = false
			notify_property_list_changed()

## Click this checkbox in the Godot Inspector to prune trees across ALL TreeExclusionZone3D nodes in the active scene.
@export var click_to_prune_all_zones: bool = false:
	set(val):
		if val:
			var res := prune_all_zones()
			var grand_total: int = res.get("grand_total_removed", 0)
			var total_z: int = res.get("total_zones", 0)
			print("[TreeExclusionZone3D] Pruned %d total instances across %d exclusion zones." % [grand_total, total_z])
			click_to_prune_all_zones = false
			notify_property_list_changed()


var _editor_mesh_instance: MeshInstance3D = null


func _ready() -> void:
	_update_groups()

	if Engine.is_editor_hint():
		_update_preview()
		return

	# Runtime behavior
	if show_in_game_debug:
		_update_preview()
	else:
		_cleanup_preview()

	if auto_prune_on_ready:
		prune_trees()


func _exit_tree() -> void:
	if Engine.is_editor_hint() and is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null


## Updates group membership based on configuration.
func _update_groups() -> void:
	if not is_inside_tree():
		return

	if not is_in_group(&"tree_exclusion_zone"):
		add_to_group(&"tree_exclusion_zone")

	if exclude_grass:
		if not is_in_group(&"building_exclusion"):
			add_to_group(&"building_exclusion")
		if not is_in_group(&"foliage_exclusion"):
			add_to_group(&"foliage_exclusion")
	else:
		if is_in_group(&"building_exclusion"):
			remove_from_group(&"building_exclusion")
		if is_in_group(&"foliage_exclusion"):
			remove_from_group(&"foliage_exclusion")


## Checks whether a global 3D point lies inside this zone's oriented bounding box (OBB).
## Respects zone translation, rotation, and scale.
func is_point_inside(global_pos: Vector3) -> bool:
	var local_pos := to_local(global_pos)
	var half_size := size * 0.5
	var s := global_transform.basis.get_scale()
	var mx: float = (margin / s.x) if absf(s.x) > 0.0001 else margin
	var my: float = (margin / s.y) if absf(s.y) > 0.0001 else margin
	var mz: float = (margin / s.z) if absf(s.z) > 0.0001 else margin

	return absf(local_pos.x) <= (half_size.x + mx) and \
		   absf(local_pos.y) <= (half_size.y + my) and \
		   absf(local_pos.z) <= (half_size.z + mz)


## Returns this zone's local AABB.
func get_local_aabb() -> AABB:
	return AABB(-size * 0.5, size)


## Returns this zone's axis-aligned bounding box transformed into world coordinates.
func get_exclusion_aabb() -> AABB:
	return global_transform * get_local_aabb()


## Prunes tree MultiMeshes within this zone's bounds.
## Returns a Dictionary with pruning statistics.
func prune_trees(custom_root: Node = null) -> Dictionary:
	var candidates := _collect_target_multimeshes(custom_root)
	var total_removed := 0
	var modified_nodes := 0
	var node_details: Dictionary = {}

	for mmi in candidates:
		if not is_instance_valid(mmi) or mmi.multimesh == null:
			continue

		if filter_trees_only and not _is_tree_multimesh(mmi):
			continue

		var removed := _prune_multimesh(mmi)
		if removed > 0:
			total_removed += removed
			modified_nodes += 1
			node_details[mmi.name] = removed

	trees_pruned.emit(self, total_removed)

	return {
		"zone_name": name,
		"total_scanned_nodes": candidates.size(),
		"modified_nodes": modified_nodes,
		"total_instances_removed": total_removed,
		"details": node_details
	}


## Prunes trees across all TreeExclusionZone3D nodes in the active scene tree.
func prune_all_zones() -> Dictionary:
	var scene_root := _get_scene_root()
	return TreeExclusionZone3D.prune_all_zones_in_tree(scene_root)


## Static helper to prune all TreeExclusionZone3D zones found in a node hierarchy or scene tree.
static func prune_all_zones_in_tree(tree_or_scene: Node) -> Dictionary:
	var total_zones := 0
	var grand_total_removed := 0
	var zone_results: Dictionary = {}

	if not is_instance_valid(tree_or_scene):
		return {"total_zones": 0, "grand_total_removed": 0, "zone_results": zone_results}

	var zones: Array[Node] = []
	if tree_or_scene.get_tree() != null:
		zones = tree_or_scene.get_tree().get_nodes_in_group(&"tree_exclusion_zone")

	if zones.is_empty():
		_find_zones_recursive(tree_or_scene, zones)

	for z in zones:
		if z is TreeExclusionZone3D:
			total_zones += 1
			var res: Dictionary = (z as TreeExclusionZone3D).prune_trees(tree_or_scene)
			var rem: int = res.get("total_instances_removed", 0)
			grand_total_removed += rem
			zone_results[z.name] = res

	return {
		"total_zones": total_zones,
		"grand_total_removed": grand_total_removed,
		"zone_results": zone_results
	}


static func _find_zones_recursive(node: Node, out_zones: Array[Node]) -> void:
	if not is_instance_valid(node):
		return
	if node is TreeExclusionZone3D and not out_zones.has(node):
		out_zones.append(node)
	for child in node.get_children():
		_find_zones_recursive(child, out_zones)


## Gathers candidate MultiMeshInstance3D nodes based on configuration.
func _collect_target_multimeshes(custom_root: Node = null) -> Array[MultiMeshInstance3D]:
	var results: Array[MultiMeshInstance3D] = []

	# 1. Explicit target_nodes configured
	if not target_nodes.is_empty():
		for path in target_nodes:
			var target := get_node_or_null(path)
			if not is_instance_valid(target):
				continue
			if target is MultiMeshInstance3D:
				if not results.has(target):
					results.append(target as MultiMeshInstance3D)
			else:
				_collect_multimeshes_recursive(target, results)
		return results

	# 2. Search under custom_root if specified
	if is_instance_valid(custom_root):
		_collect_multimeshes_recursive(custom_root, results)
		return results

	# 3. Search under search_root_path if specified
	if not search_root_path.is_empty():
		var s_node := get_node_or_null(search_root_path)
		if is_instance_valid(s_node):
			_collect_multimeshes_recursive(s_node, results)
			return results

	# 4. Search active scene root
	var scene_root := _get_scene_root()
	if is_instance_valid(scene_root):
		_collect_multimeshes_recursive(scene_root, results)

	return results


func _collect_multimeshes_recursive(node: Node, out_array: Array[MultiMeshInstance3D]) -> void:
	if not is_instance_valid(node):
		return
	if node is MultiMeshInstance3D and node.multimesh != null:
		if not out_array.has(node):
			out_array.append(node as MultiMeshInstance3D)
	for child in node.get_children():
		_collect_multimeshes_recursive(child, out_array)


## Tests if a MultiMeshInstance3D qualifies as a tree node.
func _is_tree_multimesh(mmi: MultiMeshInstance3D) -> bool:
	if not is_instance_valid(mmi):
		return false

	if mmi.has_method(&"is_tree_node") and mmi.call(&"is_tree_node"):
		return true

	var node_name_lower := mmi.name.to_lower()
	for kw in tree_name_keywords:
		var kw_clean := kw.strip_edges().to_lower()
		if not kw_clean.is_empty() and node_name_lower.contains(kw_clean):
			return true

	if is_instance_valid(mmi.multimesh) and is_instance_valid(mmi.multimesh.mesh):
		var mesh_name_lower := mmi.multimesh.mesh.resource_name.to_lower()
		for kw in tree_name_keywords:
			var kw_clean := kw.strip_edges().to_lower()
			if not kw_clean.is_empty() and mesh_name_lower.contains(kw_clean):
				return true

	return false


## Prunes instances inside this zone from a single MultiMeshInstance3D.
## Returns number of removed instances.
func _prune_multimesh(mmi: MultiMeshInstance3D) -> int:
	if not is_instance_valid(mmi):
		return 0
	var mm: MultiMesh = mmi.multimesh
	if not is_instance_valid(mm) or mm.instance_count == 0:
		return 0

	var buf: PackedFloat32Array = mm.buffer
	if buf.is_empty():
		return 0

	var is_3d: bool = (mm.transform_format == MultiMesh.TRANSFORM_3D)
	var stride: int = 12 if is_3d else 8
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4

	var count: int = mm.instance_count
	if buf.size() < count * stride:
		return 0

	var new_buf := PackedFloat32Array()
	var removed_count: int = 0
	var kept_count: int = 0
	var mmi_xform := mmi.global_transform

	for i in range(count):
		var base: int = i * stride
		var local_pos := Vector3(buf[base + 3], buf[base + 7], buf[base + 11]) if is_3d else Vector3(buf[base + 2], buf[base + 5], 0.0)
		var global_pos := mmi_xform * local_pos

		if is_point_inside(global_pos):
			removed_count += 1
		else:
			kept_count += 1
			for s in range(stride):
				new_buf.append(buf[base + s])

	if removed_count > 0:
		mm.instance_count = kept_count
		mm.buffer = new_buf
		mm.emit_changed()

	return removed_count


## Returns the active scene root (in editor or runtime).
func _get_scene_root() -> Node:
	if Engine.is_editor_hint():
		var edited := get_tree().edited_scene_root if is_inside_tree() else null
		if is_instance_valid(edited):
			return edited
	var curr: Node = self
	var tree_root: Node = get_tree().get_root() if is_inside_tree() else null
	while curr.get_parent() != null and curr.get_parent() != tree_root:
		curr = curr.get_parent()
	if curr == self and curr.get_parent() == tree_root:
		return tree_root
	return curr


## Updates the editor translucent box preview.
func _update_preview() -> void:
	var should_show: bool = (Engine.is_editor_hint() and show_in_editor) or (not Engine.is_editor_hint() and show_in_game_debug)

	if not should_show:
		if is_instance_valid(_editor_mesh_instance):
			_editor_mesh_instance.visible = false
		return

	if not is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance = get_node_or_null("_ZoneBoxPreview") as MeshInstance3D
		if not is_instance_valid(_editor_mesh_instance):
			_editor_mesh_instance = MeshInstance3D.new()
			_editor_mesh_instance.name = "_ZoneBoxPreview"
			_editor_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(_editor_mesh_instance)

	var box_mesh: BoxMesh
	if _editor_mesh_instance.mesh is BoxMesh:
		box_mesh = _editor_mesh_instance.mesh as BoxMesh
	else:
		box_mesh = BoxMesh.new()
		_editor_mesh_instance.mesh = box_mesh

	box_mesh.size = size

	var mat: StandardMaterial3D
	if box_mesh.material is StandardMaterial3D:
		mat = box_mesh.material as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		box_mesh.material = mat

	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = zone_color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_editor_mesh_instance.visible = true


## Cleans up preview mesh instance at runtime.
func _cleanup_preview() -> void:
	if is_instance_valid(_editor_mesh_instance):
		_editor_mesh_instance.queue_free()
		_editor_mesh_instance = null
	var existing := get_node_or_null("_ZoneBoxPreview")
	if is_instance_valid(existing):
		existing.queue_free()
