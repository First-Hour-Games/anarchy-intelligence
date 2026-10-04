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
	check(display.map_texture.get_size() == Vector2(2376, 1836), "Final PDF map imported at full resolution")

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

	# Test 4: The waypoint follows the real road junction and turnaround positions.
	display.set_map_open(true)
	var panel_rect := display._calculate_panel_rect()
	check(panel_rect.size.x > 100.0 and panel_rect.size.y > 100.0, "Panel rect properly sized on screen")
	var road := forest.get_node("Streets/MainRoad") as Node3D
	var locations := [
		{"world": Vector2(-270, road.global_position.z), "pixel": Vector2(210.806, 229.696), "name": "Forest road near welcome center"},
		{"world": Vector2(100, road.global_position.z), "pixel": Vector2(1481.259, 229.696), "name": "Forest main road junction"},
	]
	for location: Dictionary in locations:
		var world: Vector2 = location["world"]
		var expected: Vector2 = location["pixel"]
		var map_pixel: Vector2 = display.map_origin + world * display.world_scale
		check(map_pixel.distance_to(expected) < 2.0, "Waypoint matches PDF artwork: " + location["name"])

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
