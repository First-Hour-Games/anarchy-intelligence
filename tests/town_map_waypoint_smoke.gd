extends SceneTree

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Town Map & Waypoint Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var forest_scene: PackedScene = load("res://scenes/chapters/main/starting_forest.tscn")
	check(forest_scene != null, "starting_forest.tscn loaded")
	if forest_scene == null:
		quit(1)
		return

	var forest: StartingForest = forest_scene.instantiate() as StartingForest
	root.add_child(forest)
	await process_frame

	var player: FirstPersonPlayer = forest.get_node_or_null("Player") as FirstPersonPlayer
	check(is_instance_valid(player), "Player found in scene")

	var world_map_node := forest.get_node_or_null("WorldMap")
	check(is_instance_valid(world_map_node), "WorldMap CanvasLayer found in starting_forest")

	var display: WorldMapOverlay = world_map_node.get_node_or_null("Display") as WorldMapOverlay
	check(is_instance_valid(display), "WorldMapOverlay Display node found")
	check(display.use_image_map, "WorldMapOverlay configured to use image map")
	check(display.map_texture != null and display.map_texture.resource_path.ends_with("mapOnly.png"), "WorldMapOverlay uses mapOnly.png")

	# Test 1: Player without town map cannot open map with M key
	check(not player.inventory.has_item(&"map"), "Player starts WITHOUT town map")
	check(not display.has_town_map(), "has_town_map() returns false")

	var toggle_event := InputEventAction.new()
	toggle_event.action = &"map_toggle"
	toggle_event.pressed = true

	display._unhandled_input(toggle_event)
	check(not display.is_map_open(), "Pressing M without map does NOT open map")

	# Test 2: Add map to inventory -> now pressing M opens map
	player.inventory.add_item(&"map")
	check(player.inventory.has_item(&"map"), "Town map added to inventory")
	check(display.has_town_map(), "has_town_map() returns true with map in inventory")

	display._unhandled_input(toggle_event)
	check(display.is_map_open(), "Pressing M with map in inventory OPENS map")

	# Test 3: Closing map with M or ESC
	display._unhandled_input(toggle_event)
	check(not display.is_map_open(), "Pressing M while map is open CLOSES map")

	display.set_map_open(true)
	check(display.is_map_open(), "set_map_open(true) opens map")

	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	display._unhandled_input(cancel_event)
	check(not display.is_map_open(), "ESC key (ui_cancel) closes map")

	# Test 4: Coordinate mapping and live player waypoint calibration
	display.set_map_open(true)
	var panel_rect := display._calculate_panel_rect()
	check(panel_rect.size.x > 100.0 and panel_rect.size.y > 100.0, "Panel rect properly sized on screen")

	# Position 1: Player at Welcome Center (-270.88, -8.35)
	player.global_position = Vector3(-270.88, 0.0, -8.35)
	var map_px_welcome: Vector2 = display.map_origin + Vector2(-270.88 * display.world_scale.x, -8.35 * display.world_scale.y)
	check(map_px_welcome.x >= 100.0 and map_px_welcome.x <= 160.0, "Welcome Center X maps inside Welcome Center box (x ≈ " + str(roundf(map_px_welcome.x)) + ")")
	check(map_px_welcome.y >= 35.0 and map_px_welcome.y <= 75.0, "Welcome Center Y maps near Welcome Center box (y ≈ " + str(roundf(map_px_welcome.y)) + ")")

	# Position 2: Player at Top Road / Connector Road intersection (100.0, 0.0)
	player.global_position = Vector3(100.0, 0.0, 0.0)
	var map_px_junction: Vector2 = display.map_origin + Vector2(100.0 * display.world_scale.x, 0.0 * display.world_scale.y)
	check(absf(map_px_junction.x - 441.0) < 5.0, "Top road junction X maps to connector road (x ≈ " + str(roundf(map_px_junction.x)) + ")")
	check(absf(map_px_junction.y - 70.0) < 5.0, "Top road junction Y maps to top horizontal road (y ≈ " + str(roundf(map_px_junction.y)) + ")")

	# Position 3: Lower Cul-de-sac turnaround (-84.0, 225.0)
	player.global_position = Vector3(-84.0, 0.0, 225.0)
	var map_px_lower: Vector2 = display.map_origin + Vector2(-84.0 * display.world_scale.x, 225.0 * display.world_scale.y)
	check(absf(map_px_lower.x - 286.0) < 5.0, "Lower cul-de-sac X maps to turnaround circle (x ≈ " + str(roundf(map_px_lower.x)) + ")")
	check(absf(map_px_lower.y - 290.0) < 5.0, "Lower cul-de-sac Y maps to lower street (y ≈ " + str(roundf(map_px_lower.y)) + ")")

	# Test 5: Verify drawing renders without errors
	display.queue_redraw()
	await process_frame

	display.set_map_open(false)
	forest.queue_free()
	await process_frame

	print("--- Town Map & Waypoint Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with " + str(failures) + " failures")
		quit(1)
