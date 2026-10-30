extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func mesh_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var initialized := false
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var world: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bounds = bounds.merge(world) if initialized else world
		initialized = true
	assert(initialized, "Expected model geometry")
	return bounds

func footprint(bounds: AABB) -> Rect2:
	return Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))

func run() -> void:
	var menu := root.get_node("DebugMenu")
	var streaming := root.get_node("WorldStreaming")
	menu.call("_jump_to_checkpoint", "gas_station")
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if current_scene is StartingForest and streaming._sections.has(streaming.RESIDENCE):
			break
	assert(current_scene is StartingForest, "Dev checkpoint must load the forest")
	assert(streaming._sections.has(streaming.RESIDENCE), "Residence must be preloaded for the clearance check")
	var forest := current_scene as StartingForest
	forest.player.set_physics_process(false)
	var residence: Node3D = streaming._sections[streaming.RESIDENCE]
	var station := forest.get_node("GasStation") as Node3D
	var station_area := footprint(mesh_bounds(station)).grow(2.0)
	var lots := 0
	for lot in residence.find_children("*", "Node3D", true, false):
		if not lot.scene_file_path.begins_with("res://models/buildings/neighborhood_lots/"):
			continue
		var area := footprint(mesh_bounds(lot))
		assert(not station_area.intersects(area), "Residential lot overlaps the gas-station frontage")
		assert(area.position.y > streaming.seam_position.z, "Residential lot must stay on the residence side of the seam")
		print("PASS: streamed ", lot.name, " clears station; lot=", area, " station=", station_area)
		lots += 1
	assert(lots > 0, "Expected a placed house to test")
	if "--capture" in OS.get_cmdline_user_args():
		forest.player.global_position = Vector3(147, 0.15, 31)
		forest.player.rotation.y = PI * 0.5
		forest.player.head.rotation = Vector3.ZERO
		for frame in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/station_frontage_clear.png")
	current_scene = null
	scene_changed.emit()
	forest.queue_free()
	await process_frame
	print("Gas-station residential clearance: PASS")
	quit()
