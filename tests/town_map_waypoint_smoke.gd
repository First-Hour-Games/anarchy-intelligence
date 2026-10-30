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
	check(display.map_texture != null and display.map_texture.resource_path.ends_with("cicely_town_map.png"), "WorldMapOverlay uses the supplied PDF artwork")

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
	check(display.image_reference_size == Vector2(2376, 1836), "Calibration uses the original artwork resolution regardless of import size")

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

	# Test 4: Preserve the original coordinate mapping. The illustrated welcome
	# center is not a reliable survey anchor for the current forest layout.
	display.set_map_open(true)
	var panel_rect := display._calculate_panel_rect()
	check(panel_rect.size.x > 100.0 and panel_rect.size.y > 100.0, "Panel rect properly sized on screen")
	display._map_rect = Rect2(Vector2.ZERO, display.image_reference_size)
	var locations := [
		{"world": Vector2.ZERO, "pixel": Vector2(1137.893,229.696)},
		{"world": Vector2(100,0), "pixel": Vector2(1481.259,229.696)},
	]
	for location: Dictionary in locations:
		var map_pixel: Vector2 = display._world_to_map(location.world)
		check(map_pixel.distance_to(location.pixel) < 2.0, "Original map coordinates remain unchanged")
	var start := display._world_to_map(Vector2(0,10))
	var midpoint := display._world_to_map(Vector2(50,10))
	var end := display._world_to_map(Vector2(100,10))
	check(midpoint.distance_to((start + end) * 0.5) < 2.0, "Player movement maps consistently without landmark-based distortion")
	var original_texture := display.map_texture
	var world_position := Vector2(148,55)
	var before_resize := display._world_to_map(world_position)
	display.map_texture = ImageTexture.create_from_image(Image.create(512, 396, false, Image.FORMAT_RGBA8))
	check(display._world_to_map(world_position) == before_resize, "Reducing texture resolution does not shift the player marker")
	display.map_texture = original_texture
	display._map_rect = panel_rect

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
