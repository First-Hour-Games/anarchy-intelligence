extends SceneTree
## Run with a real display (not --headless). Changes are temporary; saves are untouched.
## godot --path . --resolution 1280x800 --script tools/profile_graphics.gd -- --scene=tutorial --output=/tmp/tutorial_profile.json

var scene_name := "tutorial"
var output_path := "/tmp/graphics_profile.json"
var sample_seconds := 3.0
var quick := false
var requested_conditions: PackedStringArray = []
var tiling_materials: Dictionary = {}
var viewports: Array[Viewport] = []
var lights: Array[Light3D] = []
var environments: Array[Environment] = []
var multimeshes: Array[MultiMeshInstance3D] = []
var original_viewport_modes: Dictionary = {}
var original_visibility: Dictionary = {}
var results: Array[Dictionary] = []
var scene: Node
var graphics: Node

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--scene="):
			scene_name = argument.trim_prefix("--scene=")
		elif argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
		elif argument.begins_with("--conditions="):
			requested_conditions = argument.trim_prefix("--conditions=").split(",", false)
		elif argument == "--quick":
			quick = true
		elif argument.begins_with("--seconds="):
			sample_seconds = maxf(1.0, argument.trim_prefix("--seconds=").to_float())
	run.call_deferred()

func collect(node: Node) -> void:
	if node is Viewport:
		viewports.append(node)
		RenderingServer.viewport_set_measure_render_time(node.get_viewport_rid(), true)
		if node is SubViewport:
			original_viewport_modes[node] = node.render_target_update_mode
	if node is Light3D:
		lights.append(node)
	var environment: Environment
	if node is WorldEnvironment or node is Camera3D:
		environment = node.environment
	if environment != null and not environments.has(environment):
		environments.append(environment)
	if node is MultiMeshInstance3D:
		multimeshes.append(node)
		original_visibility[node] = node.visible
	if node is CanvasLayer and node.name == &"CRTOverlay":
		original_visibility[node] = node.visible
	if node is MeshInstance3D and node.name == &"DistanceFog":
		original_visibility[node] = node.visible
	if node is MeshInstance3D and node.mesh != null:
		var materials: Array[Material] = [node.material_override]
		for index in node.mesh.get_surface_count():
			materials.append(node.get_active_material(index))
		for material: Material in materials:
			if material is ShaderMaterial and not tiling_materials.has(material):
				for parameter in material.shader.get_shader_uniform_list():
					if parameter.name == "anti_repeat_strength":
						tiling_materials[material] = material.get_shader_parameter("anti_repeat_strength")
	for child in node.get_children():
		collect(child)

func restore() -> void:
	graphics.set_preset(2, false)
	for viewport: SubViewport in original_viewport_modes:
		viewport.render_target_update_mode = original_viewport_modes[viewport]
	for node: Node in original_visibility:
		node.visible = original_visibility[node]
	for viewport: Viewport in viewports:
		viewport.disable_3d = false
	for material: ShaderMaterial in tiling_materials:
		material.set_shader_parameter("anti_repeat_strength", tiling_materials[material])

func measure(label: String) -> void:
	# Allow shader/pipeline changes to settle before collecting frames.
	await create_timer(1.5).timeout
	var frames: Array[float] = []
	var gpu: Array[float] = []
	var render_cpu: Array[float] = []
	var process_cpu: Array[float] = []
	var physics_cpu: Array[float] = []
	var viewport_gpu: Dictionary = {}
	for viewport: Viewport in viewports:
		viewport_gpu[str(viewport.get_path())] = 0.0
	var draw_calls := 0.0
	var primitives := 0.0
	var start := Time.get_ticks_usec()
	var last := start
	while Time.get_ticks_usec() - start < sample_seconds * 1000000:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append((now - last) / 1000.0)
		last = now
		var gpu_total := 0.0
		var cpu_total := RenderingServer.get_frame_setup_time_cpu()
		for viewport: Viewport in viewports:
			if viewport is SubViewport and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
				continue
			var rid := viewport.get_viewport_rid()
			var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(rid)
			gpu_total += gpu_ms
			cpu_total += RenderingServer.viewport_get_measured_render_time_cpu(rid)
			viewport_gpu[str(viewport.get_path())] += gpu_ms
		gpu.append(gpu_total)
		render_cpu.append(cpu_total)
		process_cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		physics_cpu.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	frames.sort()
	for path: String in viewport_gpu:
		viewport_gpu[path] /= frames.size()
	var row := {
		"condition": label, "frames": frames.size(),
		"shadowed_lights": lights.filter(func(light: Light3D): return light.shadow_enabled).size(),
		"root_shadow_atlas": root.positional_shadow_atlas_size,
		"root_scale": root.scaling_3d_scale, "framebuffer_size": str(root.get_texture().get_size()),
		"fps": frames.size() * 1000000.0 / (last - start),
		"median_frame_ms": frames[frames.size() / 2],
		"p95_frame_ms": frames[mini(frames.size() - 1, int(frames.size() * 0.95))],
		"gpu_ms": average(gpu), "render_cpu_ms": average(render_cpu),
		"process_ms": average(process_cpu), "physics_ms": average(physics_cpu),
		"draw_calls": draw_calls / frames.size(), "primitives": primitives / frames.size(),
		"viewport_gpu_ms": viewport_gpu
	}
	results.append(row)
	print("PROFILE ", JSON.stringify(row))

func average(values: Array[float]) -> float:
	var sum := 0.0
	for value in values:
		sum += value
	return sum / maxi(1, values.size())

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("GPU profiling requires a real display. Remove --headless.")
		quit(1)
		return
	var scenes := {
		"tutorial": "res://scenes/chapters/tutorial/tutorial.tscn",
		"forest": "res://scenes/chapters/main/starting_forest.tscn"
	}
	if not scenes.has(scene_name):
		push_error("Use --scene=tutorial or --scene=forest")
		quit(1)
		return
	graphics = root.get_node("GraphicsSettings")
	graphics.set_preset(2, false)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	scene = (load(scenes[scene_name]) as PackedScene).instantiate()
	if scene_name == "forest":
		scene.delay_dialogue_until_fade = false
		scene.get_node("BottomDialogueBalloon").auto_start = false
	root.add_child(scene)
	current_scene = scene
	if scene_name == "forest":
		scene.delay_dialogue_until_fade = false
		scene.finish_fade_immediately()
	await create_timer(8.0).timeout
	var player := scene.get_node("Player")
	player.freeze()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	graphics.set_preset(2, false)
	collect(root)
	var viewport_info: Array[Dictionary] = []
	for viewport: Viewport in viewports:
		viewport_info.append({"path": str(viewport.get_path()), "size": str(viewport.get_visible_rect().size), "scale": viewport.scaling_3d_scale, "texture_size": str(viewport.get_texture().get_size()), "update_mode": viewport.render_target_update_mode if viewport is SubViewport else -1})
	var inventory := {
		"scene": scene_name, "godot": Engine.get_version_info().string,
		"renderer": RenderingServer.get_current_rendering_method(),
		"driver": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"viewports": viewport_info, "window_size": str(DisplayServer.window_get_size()), "screen_size": str(DisplayServer.screen_get_size()), "screen_scale": DisplayServer.screen_get_scale(), "lights": lights.size(),
		"shadowed_lights": lights.filter(func(light: Light3D): return light.shadow_enabled).size(),
		"multimesh_instances": 0, "node_count": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"sample_seconds": sample_seconds, "camera_transform": str(player.camera.global_transform), "note": "Standalone debug run; stationary spawn camera after warmup; player input frozen; editor and other apps remain open. Variants are temporary."
	}
	for mesh: MultiMeshInstance3D in multimeshes:
		if mesh.multimesh:
			inventory.multimesh_instances += mesh.multimesh.instance_count
	print("INVENTORY ", JSON.stringify(inventory))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output_path.get_basename() + ".png")
	var conditions: Array[String] = ["high", "resolution_50_only", "shadows_off_only", "volumetric_fog_off_only"]
	conditions.append("door_color_pass_off_only" if scene_name == "tutorial" else "multimesh_foliage_off_only")
	conditions.append_array(["crt_and_distance_fog_off_only", "anti_repeat_shaders_off_only", "low", "medium", "high_repeat"])
	if quick:
		conditions = ["high", "low", "medium", "high_repeat"]
	if not requested_conditions.is_empty():
		conditions.assign(requested_conditions)
	for condition: String in conditions:
		restore()
		match condition:
			"resolution_50_only":
				for viewport: Viewport in viewports:
					viewport.scaling_3d_scale = 0.5
			"shadows_off_only":
				for light: Light3D in lights:
					light.shadow_enabled = false
			"oversized_light_shadows_off_only":
				for light: Light3D in lights:
					for property in light.get_property_list():
						if property.name in ["area_range", "spot_range", "omni_range"] and float(light.get(property.name)) > 100.0:
							light.shadow_enabled = false
			"volumetric_fog_off_only":
				for environment: Environment in environments:
					environment.volumetric_fog_enabled = false
			"door_color_pass_off_only":
				scene.get_node("DoorColorViewport").render_target_update_mode = SubViewport.UPDATE_DISABLED
			"multimesh_foliage_off_only":
				for mesh: MultiMeshInstance3D in multimeshes:
					mesh.hide()
			"crt_and_distance_fog_off_only":
				for node: Node in original_visibility:
					if node.name == &"CRTOverlay" or node.name == &"DistanceFog":
						node.visible = false
			"anti_repeat_shaders_off_only":
				for material: ShaderMaterial in tiling_materials:
					material.set_shader_parameter("anti_repeat_strength", 0.0)
			"low":
				graphics.set_preset(0, false)
			"medium":
				graphics.set_preset(1, false)
		await measure(condition)
		if condition == "high_repeat":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output_path.get_basename() + "_high_repeat.png")
	restore()
	inventory["results"] = results
	inventory["gpu_timestamps_available"] = results.any(func(row: Dictionary): return row.gpu_ms > 0.0)
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write profile to " + output_path)
		quit(1)
		return
	file.store_string(JSON.stringify(inventory, "\t"))
	file.close()
	print("Saved profile: ", output_path)
	current_scene = null
	scene.queue_free()
	environments.clear()
	tiling_materials.clear()
	for index in 3:
		await process_frame
	quit()
