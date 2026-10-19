extends SceneTree

var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failures += 1

func run() -> void:
	var graphics := root.get_node("GraphicsSettings")
	var saved_preset: int = graphics.preset
	var had_config := FileAccess.file_exists(graphics.SETTINGS_PATH)
	var saved_config := FileAccess.get_file_as_bytes(graphics.SETTINGS_PATH) if had_config else PackedByteArray()
	graphics.set_preset(2, false)
	var scene := Node3D.new()
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.volumetric_fog_enabled = true
	environment.glow_enabled = true
	environment.ssao_enabled = true
	environment.fog_enabled = true
	environment.fog_density = 0.02
	world.environment = environment
	scene.add_child(world)
	var light := SpotLight3D.new()
	light.shadow_enabled = true
	scene.add_child(light)
	var unshadowed := OmniLight3D.new()
	scene.add_child(unshadowed)
	root.add_child(scene)
	await process_frame
	var original_scale: float = root.scaling_3d_scale
	var original_atlas: int = root.positional_shadow_atlas_size
	graphics.set_preset(0, false)
	check(is_equal_approx(root.scaling_3d_scale, original_scale * 0.5), "Low halves 3D resolution")
	check(not light.shadow_enabled and not environment.glow_enabled and not environment.volumetric_fog_enabled and not environment.ssao_enabled, "Low disables shadows and expensive effects")
	check(environment.fog_enabled and is_equal_approx(environment.fog_density, 0.02), "Authored distance fog is preserved")
	var late_light := SpotLight3D.new()
	late_light.shadow_enabled = true
	scene.add_child(late_light)
	var viewport := SubViewport.new()
	scene.add_child(viewport)
	await process_frame
	check(not late_light.shadow_enabled and is_equal_approx(viewport.scaling_3d_scale, 0.5), "New lights and portal viewports inherit selected quality")
	graphics.set_preset(1, false)
	check(is_equal_approx(root.scaling_3d_scale, original_scale * 0.75) and light.shadow_enabled and environment.glow_enabled and not environment.volumetric_fog_enabled, "Medium restores shadows and bloom with reduced resolution")
	graphics.set_preset(2, false)
	check(is_equal_approx(root.scaling_3d_scale, original_scale) and root.positional_shadow_atlas_size == original_atlas, "High restores viewport settings")
	check(environment.volumetric_fog_enabled and environment.ssao_enabled and late_light.shadow_enabled and not unshadowed.shadow_enabled, "High restores authored effects without enabling unused shadows")
	var menu := (load("res://scenes/mainMenu/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	menu.input_ready_at = 0
	menu._open_options()
	menu.selected_index = 2
	var left := InputEventKey.new()
	left.keycode = KEY_LEFT
	left.pressed = true
	menu._input(left)
	check(graphics.preset == 1 and menu.graphics_label.text.contains("Medium"), "Main menu arrow changes preset and label")
	var pause_menu := root.get_node("PauseMenu")
	pause_menu._open_options()
	check(pause_menu._labels[2].text.contains("Medium") and pause_menu._labels[3].text == "Back", "Pause menu shares selected preset and retains Back")
	pause_menu.selected_index = 2
	paused = true
	pause_menu._adjust_volume(-10)
	check(graphics.preset == 0 and not light.shadow_enabled, "Graphics apply while gameplay is paused")
	pause_menu._toggle_graphics_step()
	check(graphics.preset == 1 and menu.graphics_label.text.contains("Medium"), "Click cycling synchronizes both menus")
	graphics.preset = 2
	graphics.load_settings()
	check(graphics.preset == 1, "Preset survives settings reload")
	var config := ConfigFile.new()
	config.set_value("graphics", "preset", "invalid")
	config.save(graphics.SETTINGS_PATH)
	graphics.load_settings()
	check(graphics.preset == 2, "Malformed saved preset falls back to High")
	paused = false
	graphics.set_preset(saved_preset, false)
	if had_config:
		var file := FileAccess.open(graphics.SETTINGS_PATH, FileAccess.WRITE)
		file.store_buffer(saved_config)
		file.close()
	else:
		DirAccess.remove_absolute(graphics.SETTINGS_PATH)
	menu.queue_free()
	scene.queue_free()
	await process_frame
	print("Graphics settings failures: ", failures)
	quit(1 if failures else 0)
