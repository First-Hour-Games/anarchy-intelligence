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
	source.add_child(zone)
	var non_player := Node3D.new()
	zone.call("_on_body_entered", non_player)
	non_player.free()
	assert(not zone.transitioning)
	zone.call("_on_body_entered", player)
	zone.call("_on_body_entered", player)
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(zone) and Time.get_ticks_msec() < deadline:
		await process_frame
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
	await check_gate_handoff()
	quit()


func check_gate_handoff() -> void:
	assert(change_scene_to_file("res://scenes/chapters/main/starting_forest.tscn") == OK)
	await scene_changed
	var forest := current_scene
	var player := forest.get_node("Player") as FirstPersonPlayer
	forest.finish_fade_immediately()
	var forest_ambience := forest.get_node("NightAmbience") as AudioStreamPlayer
	forest_ambience.play(10.0)
	player.unfreeze()
	player.set_physics_process(false)
	player.global_position = Vector3(135, 0.15, 62.9)
	player.rotation.y = 0.81
	player.head.rotation.x = -0.29
	player.camera.position += Vector3(0.01, -0.02, 0)
	player.camera.rotation.z = 0.04
	var gate: Variant = forest.get_node("GasStation/MetalFenceGate")
	var zone: Variant = forest.get_node("ResidenceTransitionZone")
	var clearing: Variant = forest.get_node("GasStationVegetationExclusion")
	for mesh: MultiMeshInstance3D in forest.get_node("Foliage").find_children("*", "MultiMeshInstance3D", true, false):
		if mesh.multimesh == null:
			continue
		for index in mesh.multimesh.instance_count:
			var position := mesh.global_transform * mesh.multimesh.get_instance_transform(index).origin
			assert(not clearing.is_point_inside(position), "Gas station clearing contains foliage from " + mesh.name)
	var wrapper: Variant = forest.get_node("Wrapper")
	assert(zone._get_pursuer(player) == null, "An inactive Wrapper stays in the forest")
	forest.get_node("WrapperPopoutZone").set("has_played", true)
	await process_frame
	wrapper.set_physics_process(false)
	wrapper.global_position = player.global_position + Vector3(20, 0, 0)
	assert(zone._get_pursuer(player) == null, "The Wrapper cannot follow from outside the transfer radius")
	wrapper.global_position = Vector3(137, 0.2, 62.9)
	wrapper.hits_taken = 2
	assert(zone._get_pursuer(player) == wrapper, "A nearby pursuing Wrapper qualifies for the handoff")
	var wrapper_departure: Transform3D = wrapper.global_transform
	var station_transform: Transform3D = gate.get_parent().transform
	var yard_transforms := {}
	for prop in ["GasEntrance", "WarehouseBuilding", "CopCarSedan", "Van", "freelanderSUV", "Fence20", "GeneratorUnit2", "CargoContainer2", "Pallet2After"]:
		yard_transforms[prop] = forest.get_node(prop).global_transform
	var fence_transform: Transform3D = forest.get_node("GasStation/Fence1").transform
	var approach_transforms := {}
	for prop in ["GasStation/CSGPolygon3D2", "StationApproach/Sketchfab_Scene9", "StationApproach/ConcretePipePile2", "StationApproach/Fence", "StationApproach/Fence2"]:
		approach_transforms[prop] = forest.get_node(prop).global_transform
	var suv_lights: Transform3D = forest.get_node("freelanderSUV/CarLights/SpotLight3D").global_transform
	zone._on_body_entered(player)
	assert(not zone.transitioning, "The locked gate must block the road trigger")
	assert(player.inventory.add_item(&"fence_key"))
	assert(player.inventory.add_item(&"metal_pipe"))
	var weapon: Variant = player.get_node("Head/Camera3D/PipeWeapon")
	weapon.set_equipped(false)
	player.get_node("CombatHealth").health = 70.0
	gate.toggle(player)
	var choice: Variant = forest.get_child(-1)
	var choice_deadline := Time.get_ticks_msec() + 5000
	while not choice.responses_menu.visible and Time.get_ticks_msec() < choice_deadline:
		await process_frame
	assert(choice.responses_menu.visible and choice.dialogue_line.responses.size() == 2)
	choice._on_responses_menu_response_selected(choice.dialogue_line.responses[0])
	var loader := root.get_node("SceneLoader")
	var loading_deadline := Time.get_ticks_msec() + 500
	while not loader.is_loading() and Time.get_ticks_msec() < loading_deadline:
		await process_frame
	assert(loader.is_loading() and gate.is_moving and not gate.is_open, "Loading must start on Yes, before the gate swing finishes")
	var ambience_position := forest_ambience.get_playback_position()
	var ambience_stream := forest_ambience.stream
	var opened_gate_state: Dictionary = gate.get_save_state()
	var departure_transform := player.global_transform
	var departure_camera := player.camera.global_transform
	await process_frame
	var loading := root.get_node("SceneLoader/LoadingScreen")
	assert(paused and loading.get_child_count() == 1)
	var backdrop := loading.get_child(0) as ColorRect
	assert(backdrop.color == Color.BLACK and backdrop.get_global_rect() == root.get_visible_rect())
	assert(backdrop.get_child(-1).text == "LOADING...")
	if DisplayServer.get_name() != "headless":
		var snapshot := backdrop.get_child(0) as TextureRect
		assert(snapshot != null and snapshot.texture is ImageTexture, "The last rendered frame stays under the loading text")
	await scene_changed
	var arrived := current_scene.get_node("Player") as FirstPersonPlayer
	arrived.set_physics_process(false)
	var deadline := Time.get_ticks_msec() + 30000
	while is_instance_valid(zone) and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not is_instance_valid(zone) and not paused)
	assert(not is_instance_valid(forest))
	var town := current_scene
	assert(town.scene_file_path.ends_with("residence_area.tscn"))
	assert(town.get_node("GasStation").transform.is_equal_approx(station_transform))
	assert(town.get_node("GasStation/Fence1").transform.is_equal_approx(fence_transform))
	for prop in approach_transforms:
		assert(town.get_node(prop).global_transform.is_equal_approx(approach_transforms[prop]), prop + " must match Starting Forest")
	assert(town.get_node("GasStationYard/freelanderSUV/CarLights/SpotLight3D").global_transform.is_equal_approx(suv_lights))
	var arrival_gate: Variant = town.get_node("GasStation/MetalFenceGate")
	assert(arrival_gate.is_moving and not arrival_gate.is_open, "Residence reveals the gate while its opening swing is still in progress")
	assert(arrival_gate.get_save_state() == opened_gate_state)
	var gate_music := town.get_node("WayToResidenceMusic") as AudioStreamPlayer
	var gate_track := gate_music.stream as AudioStreamOggVorbis
	assert(gate_track != null and not gate_track.loop and not gate_music.playing, "The OGG cue waits for the player to exit")
	for prop in yard_transforms:
		var arrival_prop := town.get_node(NodePath("GasStationYard/" + prop)) as Node3D
		assert(arrival_prop.global_transform.is_equal_approx(yard_transforms[prop]), prop + " must match Starting Forest")
	assert(not town.has_node("GasStationYard/Sketchfab_Scene4"), "The yard must not respawn the pipe pickup")
	assert(root.get_node("WorldStreaming").active_section == null)
	assert(wrapper.get_parent() == town and wrapper.player == arrived and wrapper.hits_taken == 2)
	assert(wrapper.global_transform.is_equal_approx(wrapper_departure))
	var town_navigation := town.get_node("ResidenceEnemyNavigation") as NavigationRegion3D
	assert(wrapper.agent.get_navigation_map() == town_navigation.get_navigation_map())
	assert(arrived.global_transform.is_equal_approx(departure_transform), "Arrival pose %s differs from %s" % [arrived.global_transform, departure_transform])
	assert(arrived.camera.global_transform.is_equal_approx(departure_camera), "Arrival camera %s differs from %s" % [arrived.camera.global_transform, departure_camera])
	assert(arrived.has_item(&"metal_pipe") and not arrived.has_item(&"fence_key"))
	assert(not arrived.get_node("Head/Camera3D/PipeWeapon").equipped)
	assert(is_equal_approx(arrived.get_node("CombatHealth").health, 70.0))
	var town_ambience := town.get_node("NightAmbience") as AudioStreamPlayer
	assert(town_ambience.playing and town_ambience.stream == ambience_stream)
	await create_timer(0.15).timeout
	assert(ambience_position >= 10.0 and town_ambience.get_playback_position() >= ambience_position - 0.3,
		"Residence should resume the forest ambience from where it left off")
	await physics_frame
	var warehouse := town.get_node("StationApproach/Sketchfab_Scene9")
	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3(139, 1.0, 80), Vector3(145, 1.0, 80), 1)
	var space := arrived.get_world_3d().direct_space_state
	var wall_hit := space.intersect_ray(wall_ray)
	assert(not wall_hit.is_empty() and warehouse.is_ancestor_of(wall_hit.collider), "Warehouse walls have static collision")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.75
	var sweep := PhysicsShapeQueryParameters3D.new()
	sweep.shape = capsule
	sweep.transform.origin = wall_ray.from
	sweep.motion = wall_ray.to - wall_ray.from
	sweep.collision_mask = 1
	assert(space.cast_motion(sweep)[0] < 0.9, "A player-sized capsule cannot cross the warehouse wall")
	print("PASS: forest ambience resumes in Residence and the warehouse blocks a player-sized capsule")
	var gate_deadline := Time.get_ticks_msec() + 5000
	while arrival_gate.is_moving and Time.get_ticks_msec() < gate_deadline:
		await process_frame
	assert(arrival_gate.is_open and not arrival_gate.interactable.is_enabled)
	arrival_gate.toggle(arrived)
	assert(arrival_gate.is_open and not arrival_gate.is_moving, "The Residence gate stays open after another interaction")
	arrival_gate.restore_save_state(opened_gate_state)
	assert(arrival_gate.is_open and not arrival_gate.interactable.is_enabled)
	arrived.global_position.x = 131.5
	for i in 3:
		await physics_frame
	assert(gate_music.playing, "Walking out through the gate starts the Residence music")
	gate_music.stop()
	arrived.global_position.x = 135
	for i in 3:
		await physics_frame
	arrived.global_position.x = 131.5
	for i in 3:
		await physics_frame
	assert(not gate_music.playing, "Crossing the trigger again does not restart the cue")
	print("PASS: Residence gate exit plays the OGG cue once")
	arrived.global_position.x = 129
	wrapper.set_physics_process(true)
	var pursuit_deadline := Time.get_ticks_msec() + 7000
	while wrapper.global_position.x > 133 and Time.get_ticks_msec() < pursuit_deadline:
		await process_frame
	assert(wrapper.global_position.x <= 133,
		"The transferred Wrapper stalled at %s on its way to %s" % [wrapper.global_position, arrived.global_position])
	print("PASS: station foliage exclusion and same nearby Wrapper continuing its pursuit in Residence")
	print("PASS: Residence reveals the gate opening, preserves the player and camera pose, and keeps the gate open")
	current_scene = null
	town.queue_free()
	await process_frame
