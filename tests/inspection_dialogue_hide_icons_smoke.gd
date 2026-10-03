extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Running Inspection Dialogue Hide Icons Smoke Test ---")
	var view_script := load("res://scenes/interaction/inspection_view.gd")
	if view_script == null:
		push_error("Failed to load inspection_view.gd")
		quit(1)
		return

	var view: InspectableView3D = InspectableView3D.new()
	var marker := Marker3D.new()
	marker.name = "CameraAnchor"
	view.add_child(marker)
	view.camera_anchor = marker

	var hotspot := InspectionHotspot3D.new()
	hotspot.hotspot_id = "test_hotspot"
	hotspot.single_line_dialogue = "Testing hiding icons during dialogue."
	view.add_child(hotspot)

	root.add_child(view)

	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var player := player_scene.instantiate() as FirstPersonPlayer
	root.add_child(player)

	# Start inspection mode
	view.start_inspection(player)
	while view._is_transitioning:
		await process_frame

	assert(view.is_inspecting, "Should be in inspection mode")
	assert(view._dots_canvas.visible, "Dots canvas should be visible before dialogue")
	assert(view._prompt_canvas.visible, "Prompt canvas should be visible before dialogue")
	print("PASS: Icons and prompt are visible initially in inspection mode")

	# Trigger hotspot dialogue
	view._on_hotspot_clicked(hotspot)
	await process_frame
	await process_frame

	assert(view._active_dialogue_balloon != null, "Active dialogue balloon should exist")
	assert(not view._dots_canvas.visible, "Dots canvas MUST BE HIDDEN while dialogue is active")
	assert(not view._prompt_canvas.visible, "Prompt canvas MUST BE HIDDEN while dialogue is active")
	print("PASS: All icons and prompt are hidden while dialogue is active")

	# Simulate dialogue finishing
	var balloon = view._active_dialogue_balloon
	balloon.queue_free()
	await process_frame
	await process_frame

	assert(view.is_inspecting, "Should still be in inspection mode after dialogue")
	assert(view._dots_canvas.visible, "Dots canvas MUST BE RESTORED after dialogue finishes")
	assert(view._prompt_canvas.visible, "Prompt canvas MUST BE RESTORED after dialogue finishes")
	print("PASS: All icons and prompt are restored after dialogue finishes")

	# Exit inspection
	view.exit_inspection()
	while view._is_transitioning:
		await process_frame

	assert(not view.is_inspecting, "Inspection mode exited successfully")
	print("--- All Inspection Dialogue Hide Icons Tests Passed! ---")
	view.queue_free()
	player.queue_free()
	quit(0)
