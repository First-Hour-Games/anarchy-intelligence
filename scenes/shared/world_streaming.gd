extends Node
## Streams the two aligned outdoor sections without replacing the player or world.
signal section_loaded(path: String)
signal section_activated(path: String)
signal section_unloaded(path: String)
signal loading_failed(path: String)

const FOREST := "res://scenes/chapters/main/starting_forest.tscn"
const RESIDENCE := "res://scenes/chapters/main/residence_area.tscn"
const SHARED_NAMES := ["Player", "WorldEnvironment", "GroundPlane", "StaticBody3D",
	"Streets", "Streets2", "DirectionalLight3D", "AspectRatioBars", "CRTOverlay",
	"WorldMap", "NightAmbience", "VisitorBGM", "WelcomingHikeBGM"]

var active_section: Node3D
var shared_nodes: Dictionary = {}
var seam_position := Vector3(126.8, 0, 69)
var preload_distance := 140.0
var unload_distance := 180.0
var crossing_hysteresis := 3.0
var _sections: Dictionary = {}
var _ready_frames: Dictionary = {}
var _states: Dictionary = {}
var _pickup_paths: Dictionary = {}
var _pending := ""
var _failed := ""
var _road_bounds: Array[AABB] = []
var _obstacle_bounds: Array[AABB] = []
var _exclusion_zones: Array[Dictionary] = []
var _section_exclusion_zones: Dictionary = {}
var avoid_tree_canopy_overlap := true
var preserve_authored_tree_spacing := true
var _foliage_filter = preload("res://scenes/environment/streamed_foliage_filter.gd").new()
var _refresh_pending := false

func _ready() -> void:
	get_tree().scene_changed.connect(_on_scene_changed)
	set_process(false)

func register_section(section: Node3D, connection: Node3D) -> void:
	if section.has_meta("streamed_section") or get_tree().current_scene != section:
		return
	if active_section == section:
		return
	_reset()
	active_section = section
	seam_position = connection.global_position
	preload_distance = connection.preload_distance
	unload_distance = connection.unload_distance
	crossing_hysteresis = connection.crossing_hysteresis
	avoid_tree_canopy_overlap = connection.avoid_tree_canopy_overlap
	preserve_authored_tree_spacing = connection.preserve_authored_tree_spacing
	_sections[section.scene_file_path] = section
	_remember_pickups(section)
	_cache_road_bounds(section)
	_cache_foliage_obstacles(section)
	_watch_generators(section)
	for node_name in SHARED_NAMES:
		var node := section.get_node_or_null(NodePath(node_name))
		if node != null:
			shared_nodes[node_name] = node
			if node is AudioStreamPlayer:
				_hold_audio(node)
	_partition_trees(section)
	set_process(true)

func _process(_delta: float) -> void:
	if not is_instance_valid(active_section) or get_tree().current_scene != active_section:
		_reset()
		return
	if get_tree().paused:
		return
	var player := shared_nodes.get("Player") as FirstPersonPlayer
	if not is_instance_valid(player):
		return
	_poll_load()
	var offset := player.global_position - seam_position
	var distance := Vector2(offset.x, offset.z).length()
	var active_path := active_section.scene_file_path
	var neighbor_path := RESIDENCE if active_path == FOREST else FOREST
	# Keep unloading outside the preload radius, even with older Inspector overrides.
	var release_distance := maxf(unload_distance, preload_distance + crossing_hysteresis)
	if distance > release_distance:
		_failed = ""
	if distance <= preload_distance and not _sections.has(neighbor_path) and _pending.is_empty() and _failed != neighbor_path:
		_request(neighbor_path)
	var wants_residence := offset.z > crossing_hysteresis
	var wants_forest := offset.z < -crossing_hysteresis
	if _sections.has(neighbor_path) and Engine.get_physics_frames() >= int(_ready_frames.get(neighbor_path, 0)):
		if not player.is_frozen and ((active_path == FOREST and wants_residence) or (active_path == RESIDENCE and wants_forest)):
			_activate(neighbor_path)
	# Use the same distance measure for loading and unloading, with a retention band.
	for path: String in _sections.keys():
		if path == active_section.scene_file_path:
			continue
		if distance > release_distance:
			_unload(path)

func _request(path: String) -> void:
	var error := ResourceLoader.load_threaded_request(path, "PackedScene", false)
	if error != OK:
		_failed = path
		loading_failed.emit(path)
		push_warning("Cannot stream section: %s (%s)" % [path, error_string(error)])
		return
	_pending = path

func _poll_load() -> void:
	if _pending.is_empty():
		return
	var status := ResourceLoader.load_threaded_get_status(_pending)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var path := _pending
	_pending = ""
	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_failed = path
		loading_failed.emit(path)
		push_warning("Section streaming failed: " + path)
		return
	var packed := ResourceLoader.load_threaded_get(path) as PackedScene
	var section := packed.instantiate() as Node3D
	section.set_meta("streamed_section", true)
	_remember_pickups(section)
	# Read roads before shared copies are removed from the incoming section.
	_cache_road_bounds(section)
	_cache_foliage_obstacles(section)
	_watch_generators(section)
	# Strip duplicates before _ready runs, so no second player, camera, UI or terrain enters the world.
	for node_name in SHARED_NAMES:
		var duplicate := section.get_node_or_null(NodePath(node_name))
		if duplicate != null:
			if duplicate is AudioStreamPlayer and not shared_nodes.has(node_name):
				# Direct residence entry has no forest ambience yet.
				section.remove_child(duplicate)
				duplicate.owner = null
				add_child(duplicate)
				shared_nodes[node_name] = duplicate
			else:
				duplicate.free()
	for node_name in ["IntroFadeCanvas", "BottomDialogueBalloon"]:
		var intro := section.get_node_or_null(NodePath(node_name))
		if intro != null:
			intro.free()
	_restore_state(section)
	get_tree().root.add_child(section)
	_sections[path] = section
	_refresh_foliage()
	# Allow broadphase registration before a crossing can make this the active map.
	_ready_frames[path] = Engine.get_physics_frames() + 2
	section_loaded.emit(path)

func _activate(path: String) -> void:
	var destination: Node3D = _sections[path]
	for node: Node in shared_nodes.values():
		if is_instance_valid(node) and not node is AudioStreamPlayer:
			node.reparent(destination)
	var player := shared_nodes.get("Player") as FirstPersonPlayer
	if is_instance_valid(player):
		player.camera.make_current()
	active_section = destination
	get_tree().current_scene = destination
	# Notify existing debug/menu consumers of the active section without freeing either map.
	get_tree().scene_changed.emit()
	section_activated.emit(path)

func _hold_audio(audio: AudioStreamPlayer) -> void:
	# Audio remains under the manager, so crossing never restarts its output stream.
	var playing := audio.playing
	var playback := audio.get_playback_position()
	audio.reparent(self)
	if playing:
		audio.play(playback)

func _unload(path: String) -> void:
	var section: Node3D = _sections[path]
	_save_state(section)
	_sections.erase(path)
	_ready_frames.erase(path)
	section.queue_free()
	_schedule_foliage_refresh()
	section_unloaded.emit(path)

func _remember_pickups(section: Node3D) -> void:
	var paths: Dictionary = {}
	for node in section.find_children("*", "FlashlightPickup", true, false):
		var visual: Node = node.get_node_or_null(node.visual_target_path)
		paths[section.get_path_to(node)] = section.get_path_to(visual) if visual != null else NodePath()
	_pickup_paths[section.scene_file_path] = paths

func _save_state(section: Node3D) -> void:
	var state := {"interactables": {}, "removed_pickups": [], "hidden_visuals": []}
	for node in section.find_children("*", "InteractableBlock3D", true, false):
		state.interactables[section.get_path_to(node)] = node.is_enabled
	var pickup_paths: Dictionary = _pickup_paths.get(section.scene_file_path, {})
	for path: NodePath in pickup_paths:
		if not section.has_node(path):
			state.removed_pickups.append(path)
			if not pickup_paths[path].is_empty():
				state.hidden_visuals.append(pickup_paths[path])
	if section.scene_file_path == FOREST:
		state["hike_started"] = section.get("_has_switched_music")
	_states[section.scene_file_path] = state

func _restore_state(section: Node3D) -> void:
	var state: Dictionary = _states.get(section.scene_file_path, {})
	for path: NodePath in state.get("interactables", {}):
		var node := section.get_node_or_null(path)
		if node != null:
			node.is_enabled = state.interactables[path]
	for path: NodePath in state.get("removed_pickups", []):
		var node := section.get_node_or_null(path)
		if node != null:
			node.free()
	for path: NodePath in state.get("hidden_visuals", []):
		var visual := section.get_node_or_null(path) as Node3D
		if visual != null:
			visual.hide()
	if section.scene_file_path == FOREST:
		section.set("_has_switched_music", state.get("hike_started", false))

func _partition_trees(section: Node3D) -> void:
	var sections: Array = _sections.values() if not _sections.is_empty() else [section]
	_foliage_filter.apply(sections, FOREST, seam_position.z, _road_bounds, _obstacle_bounds, _exclusion_zones, avoid_tree_canopy_overlap, preserve_authored_tree_spacing)

func _refresh_foliage() -> void:
	_refresh_pending = false
	if not _sections.is_empty():
		_foliage_filter.apply(_sections.values(), FOREST, seam_position.z, _road_bounds, _obstacle_bounds, _exclusion_zones, avoid_tree_canopy_overlap, preserve_authored_tree_spacing)

func _schedule_foliage_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_refresh_foliage.call_deferred()

func _watch_generators(section: Node3D) -> void:
	for generator in section.find_children("*", "ProceduralGrassGenerator", true, false):
		generator.grass_generated.connect(_on_grass_generated.bind(generator))
		generator.grass_cleared.connect(_on_foliage_edited.bind(generator))
	for generator in section.find_children("*", "ProceduralTreeGenerator", true, false):
		generator.trees_generated.connect(_on_trees_generated.bind(generator))
		generator.trees_cleared.connect(_on_foliage_edited.bind(generator))
		generator.tree_variation_changed.connect(_on_foliage_edited.bind(generator))

func _on_foliage_edited(generator: Node) -> void:
	_foliage_filter.forget(generator)
	_schedule_foliage_refresh()

func _on_grass_generated(_stats: Dictionary, generator: Node) -> void:
	_foliage_filter.forget(generator)
	_schedule_foliage_refresh()

func _on_trees_generated(_total: int, _filled: int, _pruned: int, generator: Node) -> void:
	_foliage_filter.forget(generator)
	_schedule_foliage_refresh()

func _cache_foliage_obstacles(section: Node3D) -> void:
	var helper := ProceduralTreeGenerator.new()
	var targets: Array[Node3D] = []
	var section_zones: Array[Dictionary] = []
	helper._find_landmarks(section, targets)
	for node in section.find_children("*", "Node3D", true, false):
		if node is TreeExclusionZone3D:
			var world := helper._get_node_global_xform(node)
			section_zones.append({"inverse": world.affine_inverse(), "bounds": AABB(-node.size * 0.5, node.size).grow(node.margin), "grass": node.exclude_grass or not node.filter_trees_only})
			continue
		if node is StaticBody3D:
			if node.name == "LotCollision":
				# Lawn boxes are walkable terrain. Compound fence bodies must use
				# their individual runs so their empty yard is not a solid obstacle.
				if not String(node.get_parent().name).ends_with("_Lawn"):
					for shape in node.get_children():
						if shape is CollisionShape3D:
							targets.append(shape)
				continue
			# Shared terrain is walkable ground, not a foliage obstacle.
			if node.get_parent() == section and node.name == "StaticBody3D":
				continue
			var ancestor: Node = node
			var ground := false
			while ancestor != section and ancestor != null:
				if ancestor.name == "GroundPlane":
					ground = true
				ancestor = ancestor.get_parent()
			if not ground:
				targets.append(node)
		if node.is_in_group("building_exclusion") or node.is_in_group("foliage_exclusion"):
			targets.append(node)
		if node is ProceduralTreeGenerator or node is ProceduralGrassGenerator or node is MultiMeshExclusionFilter:
			for box: AABB in node.manual_exclusion_boxes:
				if not _obstacle_bounds.has(box):
					_obstacle_bounds.append(box)
			for path: NodePath in node.exclusion_nodes:
				var target := node.get_node_or_null(path) as Node3D
				if target != null and not target is TreeExclusionZone3D:
					targets.append(target)
	for target in targets:
		var bounds := helper._calculate_node_world_aabb(target)
		if bounds.size.length_squared() > 0.01 and not _obstacle_bounds.has(bounds):
			_obstacle_bounds.append(bounds)
	# Keep known clearings after unloading, but replace that section's snapshot on reload.
	# Store only value data so the cache does not retain scene nodes or resources.
	_section_exclusion_zones[section.scene_file_path] = section_zones
	_exclusion_zones.clear()
	for zones: Array in _section_exclusion_zones.values():
		_exclusion_zones.append_array(zones)
	helper.free()

func _cache_road_bounds(section: Node3D) -> void:
	var helper := ProceduralTreeGenerator.new()
	for road_group in ["Streets", "Streets2", "ResidentialStreet", "ParkingLot"]:
		var roads := section.get_node_or_null(NodePath(road_group))
		if roads == null:
			continue
		if road_group == "ParkingLot":
			var parking_bounds := helper._calculate_node_world_aabb(roads).grow(2.0)
			if not _road_bounds.has(parking_bounds):
				_road_bounds.append(parking_bounds)
		for road in roads.find_children("*", "CSGShape3D", true, false):
			if road.name != "MainRoad" and road.name != "Turnaround":
				continue
			var bounds := helper._calculate_node_world_aabb(road)
			if bounds.size.length_squared() > 0.01:
				# Retain road footprints after their duplicate scene nodes are stripped.
				bounds = bounds.grow(2.0)
				if not _road_bounds.has(bounds):
					_road_bounds.append(bounds)
	helper.free()

func _on_scene_changed() -> void:
	if is_instance_valid(active_section) and get_tree().current_scene == active_section:
		return
	_reset()

func _reset() -> void:
	for section in _sections.values():
		if is_instance_valid(section) and section != get_tree().current_scene and not section.is_queued_for_deletion():
			section.queue_free()
	_sections.clear()
	_ready_frames.clear()
	_road_bounds.clear()
	_obstacle_bounds.clear()
	_exclusion_zones.clear()
	_section_exclusion_zones.clear()
	_foliage_filter.sources.clear()
	_refresh_pending = false
	for node in shared_nodes.values():
		if is_instance_valid(node) and node.get_parent() == self:
			node.queue_free()
	shared_nodes.clear()
	_states.clear()
	_pickup_paths.clear()
	active_section = null
	_failed = ""
	# A request already running must still be retrieved when finished.
	if not _pending.is_empty():
		_discard_request(_pending)
		_pending = ""
	set_process(false)

func _discard_request(path: String) -> void:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
		ResourceLoader.load_threaded_get(path)
