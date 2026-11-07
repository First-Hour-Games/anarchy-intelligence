extends SceneTree

# Renders a scene and saves a PNG for visual review. Run WITHOUT --headless:
#   Godot_console.exe --path . --script res://tools/capture_scene.gd -- --scene res://scenes/chapters/main/map.tscn
# Options (after the bare --):
#   --scene <res://...tscn>   scene to instantiate (required)
#   --out <path>              PNG path; defaults to ../captures/<scene>[_<tag>].png beside the repo
#   --tag <text>              suffix for the default file name, e.g. "before" or "after"
#   --frames <n>              frames to wait before capture so fog, lights, and fades settle (default 90)
#   --size <WxH>              window size (default 1280x720)
#   --camera <NodePath>       use an existing Camera3D, relative to the scene root
#   --pos <x,y,z>             spawn a camera at this global position...
#   --look <x,y,z>            ...looking at this point (default: 1 m ahead along -Z)
#   --fov <degrees>           field of view for a spawned camera (default 75)
#   --quality <0|1|2>         GraphicsSettings preset: Low, Medium, High (not persisted)
#   --hide-ui                 hide every CanvasLayer so only the 3D world is captured
#   --flashlight              attach a spotlight to the camera, roughly like the player's flashlight
#   --inspect                 disable fog and raise ambient light to review layout (not the in-game look)

var options: Dictionary = {}


func _initialize() -> void:
	run.call_deferred()


func parse_options() -> void:
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		var key := args[index]
		if not key.begins_with("--"):
			index += 1
			continue
		var name := key.trim_prefix("--")
		if index + 1 < args.size() and not args[index + 1].begins_with("--"):
			options[name] = args[index + 1]
			index += 2
		else:
			options[name] = true
			index += 1


func parse_vector(text: String) -> Vector3:
	var parts := text.split(",")
	if parts.size() != 3:
		push_error("Expected x,y,z but got: " + text)
		return Vector3.ZERO
	return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())


# Re-applied every frame because scene scripts and GraphicsSettings may reset the environment.
func apply_inspection_lighting(camera: Camera3D) -> void:
	var environments: Array[Environment] = []
	for world_environment in root.find_children("*", "WorldEnvironment", true, false):
		environments.append((world_environment as WorldEnvironment).environment)
	if camera and camera.environment:
		environments.append(camera.environment)
	for environment in environments:
		if environment == null:
			continue
		environment.fog_enabled = false
		environment.volumetric_fog_enabled = false
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.85, 0.85, 0.85)
		environment.ambient_light_energy = 1.2
	for fog_volume in root.find_children("*", "FogVolume", true, false):
		(fog_volume as FogVolume).visible = false


func fail(message: String) -> void:
	printerr("CAPTURE FAILED: " + message)
	quit(1)


func run() -> void:
	parse_options()
	if DisplayServer.get_name() == "headless":
		fail("the headless display server cannot render; run without --headless")
		return
	var scene_path := str(options.get("scene", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		fail("missing or unknown --scene: " + scene_path)
		return

	var size_parts := str(options.get("size", "1280x720")).split("x")
	var window_size := Vector2i(size_parts[0].to_int(), size_parts[1].to_int())
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	root.size = window_size

	var graphics := root.get_node_or_null("GraphicsSettings")
	if options.has("quality") and graphics:
		graphics.set_preset(str(options["quality"]).to_int(), false)

	var packed := load(scene_path) as PackedScene
	if packed == null:
		fail("could not load " + scene_path)
		return
	var instance := packed.instantiate()
	# Captures must never read or overwrite the player's story save.
	for node in instance.find_children("*", "", true, false):
		if "persist_progress" in node:
			node.set("persist_progress", false)
	root.add_child(instance)
	current_scene = instance

	var camera: Camera3D
	if options.has("camera"):
		camera = instance.get_node_or_null(NodePath(str(options["camera"]))) as Camera3D
		if camera == null:
			fail("no Camera3D at " + str(options["camera"]))
			return
	elif options.has("pos"):
		camera = Camera3D.new()
		camera.name = "CaptureCamera"
		camera.fov = float(str(options.get("fov", "75")))
		camera.far = 1000.0
		instance.add_child(camera)
		var position := parse_vector(str(options["pos"]))
		camera.global_position = position
		var target := parse_vector(str(options["look"])) if options.has("look") else position + Vector3.FORWARD
		camera.look_at(target, Vector3.UP if absf(position.direction_to(target).y) < 0.99 else Vector3.FORWARD)

	var flashlight: SpotLight3D
	if options.has("flashlight"):
		flashlight = SpotLight3D.new()
		flashlight.name = "CaptureFlashlight"
		flashlight.spot_range = 25.0
		flashlight.spot_angle = 30.0
		flashlight.light_energy = 4.0
		flashlight.shadow_enabled = true
		instance.add_child(flashlight)

	var frames := int(str(options.get("frames", "90")))
	for frame in frames:
		if camera:
			camera.make_current()
		if options.has("hide-ui"):
			for layer in root.find_children("*", "CanvasLayer", true, false):
				(layer as CanvasLayer).visible = false
		var active_camera := root.get_camera_3d()
		if flashlight and active_camera:
			flashlight.global_transform = active_camera.global_transform
		if options.has("inspect"):
			apply_inspection_lighting(active_camera)
		await process_frame
	await RenderingServer.frame_post_draw

	var out_path := str(options.get("out", ""))
	if out_path.is_empty():
		var file_name := scene_path.get_file().get_basename()
		if options.has("tag"):
			file_name += "_" + str(options["tag"])
		out_path = ProjectSettings.globalize_path("res://").path_join("../captures").simplify_path().path_join(file_name + ".png")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())
	var error := root.get_texture().get_image().save_png(out_path)
	if error != OK:
		fail("could not write %s (error %d)" % [out_path, error])
		return
	var active := root.get_camera_3d()
	print("CAPTURED " + out_path)
	if active:
		print("CAMERA %s at %s facing %s" % [active.get_path(), active.global_position, -active.global_basis.z])
	quit(0)
