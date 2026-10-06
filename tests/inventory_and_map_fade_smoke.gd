extends SceneTree

var failures: int = 0


func check(value: bool, words: String) -> void:
	print(("PASS: " if value else "FAIL: ") + words)
	if not value:
		failures += 1


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	print("--- Running Inventory & Map Fade Transition Smoke Test ---")

	var packed_player := load("res://scenes/player/player.tscn") as PackedScene
	check(packed_player != null, "Loaded player.tscn")

	var player := packed_player.instantiate() as FirstPersonPlayer
	root.add_child(player)
	await process_frame

	var inventory := player.inventory as PlayerInventory
	check(is_instance_valid(inventory), "Player inventory instantiated")
	check(inventory.layer == 96, "Inventory layer is 96 (below CRTOverlay at layer 100)")

	# Check black gutters exist
	var right_gutter := inventory.find_child("RightGutter", true, false) as ColorRect
	var left_gutter := inventory.find_child("LeftGutter", true, false) as ColorRect
	check(is_instance_valid(right_gutter) and is_instance_valid(left_gutter), "Inventory has black gutters outside 4:3 frame")

	# Test Inventory activation fade
	check(not inventory.is_open, "Inventory is initially closed")
	inventory.set_open(true)
	check(inventory.is_open, "Inventory is open")
	check(inventory._fade_rect.visible, "Inventory fade rect is visible at start of entry transition")

	# Wait for entry fade to complete (0.12s + 0.12s = 0.24s; wait 0.3s)
	var timer := create_timer(0.3)
	await timer.timeout

	check(not inventory._fade_rect.visible, "Inventory fade rect is hidden after entry transition completes")
	check(is_equal_approx(inventory._frame.modulate.a, 1.0), "Inventory content is fully visible after entry fade")

	# Test Inventory exit fade
	inventory.set_open(false)
	check(not inventory.is_open, "Inventory closed state updated immediately")
	check(inventory._fade_rect.visible, "Inventory fade rect is visible during exit transition")

	# Wait for exit fade to complete
	var exit_timer := create_timer(0.3)
	await exit_timer.timeout

	check(not inventory._fade_rect.visible, "Inventory fade rect is hidden after exit transition completes")
	check(not inventory._overlay.visible, "Inventory overlay is hidden after exit")

	# Test WorldMap activation and exit fade
	var packed_map := load("res://scenes/ui/world_map/world_map.tscn") as PackedScene
	check(packed_map != null, "Loaded world_map.tscn")

	var world_map := packed_map.instantiate() as CanvasLayer
	root.add_child(world_map)
	await process_frame

	check(world_map.layer == 50, "WorldMap layer is 50 (below CRTOverlay at layer 100)")
	var display := world_map.get_node("Display") as WorldMapOverlay
	check(is_instance_valid(display), "WorldMapOverlay display node found")
	display.pause_while_open = false

	# Test Map activation fade
	display.set_map_open(true)
	check(display.is_map_open(), "World map is open")
	check(display._fade_rect.visible, "World map fade rect is visible at start of entry transition")

	# Wait for entry fade to complete
	var map_timer := create_timer(0.3)
	await map_timer.timeout

	check(not display._fade_rect.visible, "World map fade rect is hidden after entry transition completes")
	check(display._fade_phase == 0, "World map fade phase is 0 (completed)")

	# Test Map exit fade
	display.set_map_open(false)
	check(not display.is_map_open(), "World map closed state updated immediately")
	check(display._fade_rect.visible, "World map fade rect is visible during exit transition")

	# Wait for exit fade to complete
	var map_exit_timer := create_timer(0.3)
	await map_exit_timer.timeout

	check(not display._fade_rect.visible, "World map fade rect is hidden after exit transition completes")
	check(not display.visible, "World map display is hidden after exit")

	player.queue_free()
	world_map.queue_free()

	print("--- Inventory & Map Fade Checks Complete ---")
	if failures == 0:
		print("ALL PASS")
		quit(0)
	else:
		print("FAILED with %d failures" % failures)
		quit(1)
