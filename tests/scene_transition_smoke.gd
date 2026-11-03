extends SceneTree


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var source := Node3D.new()
	root.add_child(source)
	current_scene = source
	var player := load("res://scenes/player/player.tscn").instantiate() as FirstPersonPlayer
	player.name = "Player"
	source.add_child(player)
	player.position = Vector3(128, 0.15, 69)
	player.rotation.y = 0.7
	player.head.rotation.x = -0.2
	var departure := player.transform
	player.inventory.add_item(&"map")
	player.inventory.add_item(&"flashlight")
	player.inventory.select_slot(1)
	player.flashlight.set_enabled(true)
	player.jump_enabled = true
	var zone := Area3D.new()
	zone.set_script(load("res://scenes/zones/scene_transition_zone.gd"))
	zone.destination_scene = "res://scenes/chapters/main/residence_area.tscn"
	zone.preserve_relative_position = true
	zone.fade_out_seconds = 0.01
	zone.fade_in_seconds = 0.01
	source.add_child(zone)
	var non_player := Node3D.new()
	zone.call("_on_body_entered", non_player)
	non_player.free()
	assert(not zone.transitioning)
	zone.call("_on_body_entered", player)
	zone.call("_on_body_entered", player)
	for frame in range(1000):
		await create_timer(0.01, true).timeout
		if not is_instance_valid(zone):
			break
	assert(not is_instance_valid(zone), "Transition must finish and remove its overlay")
	assert(not paused)
	assert(current_scene.scene_file_path.ends_with("residence_area.tscn"))
	assert(not is_instance_valid(source))
	var arrived := current_scene.get_node("Player") as FirstPersonPlayer
	assert(arrived.inventory.has_item(&"map"))
	assert(arrived.inventory.has_item(&"flashlight"))
	assert(arrived.inventory.selected_slot_index == 1)
	assert(arrived.flashlight.is_enabled())
	assert(arrived.jump_enabled)
	assert(current_scene.has_node("AspectRatioBars/AspectRatioContainer/Control"))
	assert(current_scene.has_node("CRTOverlay/AspectRatioContainer/Content/Filter"))
	var map_display := current_scene.get_node("WorldMap/Display") as WorldMapOverlay
	assert(map_display.get("_player") == arrived)
	map_display.set_map_open(true, false)
	assert(map_display.is_map_open() and paused)
	map_display.set_map_open(false, false)
	assert(not map_display.is_map_open() and not paused)
	assert(arrived.position.distance_to(departure.origin) < 0.5)
	assert(arrived.basis.is_equal_approx(departure.basis))
	assert(is_equal_approx(arrived.head.rotation.x, -0.2))
	print("PASS: transition, duplicate trigger guard, old scene unload, spawn and player state")
	current_scene.queue_free()
	current_scene = null
	await process_frame
	quit()
