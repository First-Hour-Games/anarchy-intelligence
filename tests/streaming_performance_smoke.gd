extends SceneTree

var stream: Node
var failures := 0
var loads := 0
var unloads := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error(message)

func wait_for(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return predicate.call()

func on_loaded(_path: String) -> void:
	loads += 1
	for section: Node in stream._sections.values():
		for boundary: MapBoundaryZone3D in section.find_children("*", "MapBoundaryZone3D", true, false):
			boundary.is_enabled = false

func hold_position(player: Node3D, offset: Vector3) -> void:
	player.global_position = stream.seam_position + offset
	var previous_loads := loads
	var previous_unloads := unloads
	var deadline := Time.get_ticks_msec() + 300
	while Time.get_ticks_msec() < deadline:
		await process_frame
	check(loads == previous_loads and unloads == previous_unloads,
		"stationary offset %s does not reload or unload the neighbor" % offset)

func run() -> void:
	stream = root.get_node("WorldStreaming")
	stream.section_loaded.connect(on_loaded)
	stream.section_unloaded.connect(func(_path: String): unloads += 1)
	# Skip the opening cinematic so its asynchronous checkpoint teleport cannot
	# move the player during the stationary-position and crossing assertions.
	var forest: Node3D = load(stream.FOREST).instantiate()
	forest.auto_start_fade = false
	forest.delay_dialogue_until_fade = false
	forest.get_node("IntroFadeCanvas").free()
	forest.get_node("BottomDialogueBalloon").free()
	# Threshold probes deliberately leave the playable area. Disable boundary
	# dialogue only in this test so it cannot freeze or teleport the probe player.
	for boundary: MapBoundaryZone3D in forest.find_children("*", "MapBoundaryZone3D", true, false):
		boundary.is_enabled = false
	root.add_child(forest)
	current_scene = forest
	var player := forest.get_node("Player") as FirstPersonPlayer
	player.set_physics_process(false)
	player.unfreeze()
	player.global_position = stream.seam_position + Vector3(0, 0, -40)
	if not await wait_for(func(): return stream._sections.size() == 2):
		check(false, "initial sections loaded")
		quit(1)
		return
	var expected_zones: int = stream._exclusion_zones.size()
	check(expected_zones == 6, "all authored forest and residence clearing zones are cached")
	# Older scene overrides must also be safe when unload < preload.
	stream.unload_distance = 100.0
	await hold_position(player, Vector3(0, 0, -120))
	# Lateral distance must use the same metric for loading and unloading.
	await hold_position(player, Vector3(120, 0, -10))
	for cycle in 3:
		player.global_position = stream.seam_position + Vector3(0, 0, -160)
		check(await wait_for(func(): return not stream._sections.has(stream.RESIDENCE)), "residence unloads outside retention band, cycle %d" % cycle)
		player.global_position = stream.seam_position + Vector3(0, 0, -120)
		check(await wait_for(func(): return stream._sections.has(stream.RESIDENCE)), "return approach reloads residence, cycle %d" % cycle)
		await hold_position(player, Vector3(0, 0, -120))
		check(stream._exclusion_zones.size() == expected_zones, "zone count stays constant after reload, cycle %d" % cycle)
		check(stream._section_exclusion_zones.size() == 2, "cache has one snapshot per section, cycle %d" % cycle)
	# Confirm recaching replaces zone bounds rather than retaining obsolete values.
	var residence: Node3D = stream._sections[stream.RESIDENCE]
	var zone: TreeExclusionZone3D = residence.find_children("HouseVegetationExclusionZone", "Node3D", true, false)[0]
	var original_size := zone.size
	zone.size += Vector3(2, 0, 0)
	stream._cache_foliage_obstacles(residence)
	var found_updated := false
	for entry: Dictionary in stream._section_exclusion_zones[stream.RESIDENCE]:
		if entry.bounds.size.is_equal_approx(zone.size + Vector3.ONE * zone.margin * 2.0):
			found_updated = true
	check(found_updated and stream._exclusion_zones.size() == expected_zones, "recaching updates edited bounds without adding duplicates")
	zone.size = original_size
	stream._cache_foliage_obstacles(residence)
	player.global_position = stream.seam_position + Vector3(0, 0, 8)
	check(await wait_for(func(): return stream.active_section.scene_file_path == stream.RESIDENCE), "crossing activates residence")
	await hold_position(player, Vector3(0, 0, 120))
	player.global_position = stream.seam_position + Vector3(0, 0, 160)
	check(await wait_for(func(): return not stream._sections.has(stream.FOREST)), "forest unloads beyond retention band")
	player.global_position = stream.seam_position + Vector3(0, 0, 120)
	check(await wait_for(func(): return stream._sections.has(stream.FOREST)), "forest reloads on return approach")
	await hold_position(player, Vector3(0, 0, 120))
	check(stream._exclusion_zones.size() == expected_zones, "forest reload also keeps zone count constant")
	player.global_position = stream.seam_position + Vector3(0, 0, -8)
	check(await wait_for(func(): return stream.active_section.scene_file_path == stream.FOREST), "crossing back activates forest")
	var sections: Array = stream._sections.values().duplicate()
	current_scene = null
	scene_changed.emit()
	for section: Node in sections:
		if is_instance_valid(section) and not section.is_queued_for_deletion():
			section.queue_free()
	await process_frame
	check(stream._section_exclusion_zones.is_empty() and stream._exclusion_zones.is_empty(), "leaving the world clears both zone caches")
	print("Streaming performance smoke: %d failures" % failures)
	quit(1 if failures else 0)
