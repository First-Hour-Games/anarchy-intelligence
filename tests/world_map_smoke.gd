extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed_scene := load("res://scenes/ui/world_map/world_map.tscn") as PackedScene
	if packed_scene == null:
		push_error("World map scene could not be loaded")
		quit(1)
		return
	var main_map_scene := load("res://scenes/chapters/main/map.tscn") as PackedScene
	if main_map_scene == null:
		push_error("Main map scene could not be loaded")
		quit(1)
		return
	var main_map := main_map_scene.instantiate()
	var integration_present := main_map.has_node("WorldMap/Display")
	main_map.free()

	var gameplay_environment := Environment.new()
	var overhead_environment := Environment.new()
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	world_environment.set_script(load("res://scenes/environment/map_preview_environment.gd"))
	world_environment.set("gameplay_environment", gameplay_environment)
	world_environment.set("editor_environment", overhead_environment)
	root.add_child(world_environment)

	var overlay := packed_scene.instantiate()
	root.add_child(overlay)
	var display := overlay.get_node("Display")
	var map_viewport := overlay.get_node_or_null("MapViewport") as SubViewport
	var map_camera := overlay.get_node_or_null("MapViewport/TopCamera") as Camera3D
	var passed := (
		display != null
		and map_viewport != null
		and map_camera != null
		and map_camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and map_viewport.size == Vector2i(512, 340)
		and InputMap.has_action("map_toggle")
		and integration_present
	)
	if passed:
		display.pause_while_open = false
		display.set_map_open(true)
		await process_frame
		passed = (
			display.visible
			and display.is_map_open()
			and not paused
			and world_environment.environment == overhead_environment
			and map_viewport.render_target_update_mode == SubViewport.UPDATE_ALWAYS
		)
		display.set_map_open(false)
		passed = (
			passed
			and not display.visible
			and not display.is_map_open()
			and not paused
			and world_environment.environment == gameplay_environment
			and map_viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED
		)

		display.pause_while_open = true
		display.set_map_open(true)
		passed = passed and paused
		display.set_map_open(false)
		passed = passed and not paused

	print("PASS world map" if passed else "FAIL world map")
	overlay.queue_free()
	world_environment.queue_free()
	quit(0 if passed else 1)
