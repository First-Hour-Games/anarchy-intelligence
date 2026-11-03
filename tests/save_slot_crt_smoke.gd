extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(value: bool, label: String) -> void:
	print(("PASS " if value else "FAIL ") + label)
	if not value:
		failures += 1

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().is_empty():
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].path_join(name + ".png"))

func run() -> void:
	var screen_script: GDScript = load("res://scenes/ui/save_slots/save_slot_screen.gd")
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	root.add_child(overlay)
	var filter := ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var original := ShaderMaterial.new()
	original.shader = load("res://shaders/crt.gdshader") as Shader
	original.set_shader_parameter("crt_curve", 0.05)
	original.set_shader_parameter("crt_scan_line_color", 0.1)
	original.set_shader_parameter("aperture_grille_rate", 0.592)
	original.set_shader_parameter("rf_switch_esque_blur", 0.174)
	original.set_shader_parameter("white_noise_rate", 0.07)
	filter.material = original
	overlay.add_child(filter)
	var screen: Variant = screen_script.open(root, 0, func(_slot: int) -> bool: return false, true, true)
	check(screen.layer < overlay.layer, "save screen draws behind gameplay CRT")
	check(screen._crt_filter == filter and filter.material != original, "transition uses private copy of gameplay CRT")
	check(screen._busy and screen._content.modulate.a == 0.0, "files and input wait for transition")
	check(screen._transition_player.playing, "static transition sound starts while game is paused")
	check(screen._transition_player.stream.resource_path == "res://sounds/ui/staticSave.ogg", "transition uses converted staticSave OGG")
	check(not (screen._transition_player.stream as AudioStreamOggVorbis).loop, "transition sound does not loop")
	check(is_equal_approx(float(screen._crt_material.get_shader_parameter("white_noise_rate")), 0.85), "opening starts with strong static")
	check(is_equal_approx(float(original.get_shader_parameter("white_noise_rate")), 0.07), "shared CRT material remains unchanged")
	await capture("save_static")
	await create_timer(0.35, true).timeout
	var noise := float(screen._crt_material.get_shader_parameter("white_noise_rate"))
	check(noise < 0.85 and noise > 0.07, "static settles while paused game fades into save screen")
	check(screen._transition_player.playing and screen._transition_player.volume_db < screen.transition_volume_db, "static sound fades with visual static")
	check(screen._background_layers[1].modulate.a > 0.0 and screen._background_layers[1].modulate.a < 1.0, "blue background fades in during static decay")
	check(screen._content.modulate.a == 0.0, "files wait for blue background")
	await create_timer(0.8, true).timeout
	check(screen._busy and screen._transition_player.playing, "slower static transition continues beyond one second")
	await screen._transition_tween.finished
	check(not screen._busy and is_equal_approx(screen._content.modulate.a, 1.0), "files finish fading and input unlocks")
	check(not screen._transition_player.playing, "static sound stops when transition finishes")
	check(is_equal_approx(float(screen._crt_material.get_shader_parameter("white_noise_rate")), 0.07), "static returns to exact original level")
	await capture("save_normal")
	var closed_count := [0]
	screen.closed.connect(func() -> void: closed_count[0] += 1)
	screen.close()
	var exit_tween: Tween = screen._transition_tween
	screen.close()
	check(screen._transition_tween == exit_tween, "repeated close does not restart exit transition")
	check(screen.visible and paused and closed_count[0] == 0, "exit keeps screen visible and player paused until transition completes")
	check(screen._transition_player.playing and is_equal_approx(float(screen._crt_material.get_shader_parameter("white_noise_rate")), 0.85), "exit starts the same strong static and audio burst")
	await create_timer(0.35, true).timeout
	check(screen._content.modulate.a < 1.0 and screen._content.modulate.a > 0.0, "exit fades files away first")
	await create_timer(1.85, true).timeout
	check(screen._transition_player.playing, "random audio offset leaves enough sound near the end of exit")
	check(screen._background_layers[1].modulate.a < 1.0 and screen._background_layers[1].modulate.a > 0.0, "exit reveals gameplay through fading blue background")
	await exit_tween.finished
	check(filter.material == original and not paused, "closing restores gameplay CRT and unpauses")
	check(closed_count[0] == 1 and not screen.visible and not screen._transition_player.playing, "exit completes once and stops static after its fade")
	await create_timer(1.0, true).timeout
	screen = screen_script.open(root, 0, func(_slot: int) -> bool: return false, true, true)
	screen.close()
	check(paused and screen._transition_player.playing, "closing during entry starts exit while keeping gameplay paused")
	await screen._transition_tween.finished
	check(filter.material == original and not paused, "interrupted entry restores original CRT after exit finishes")
	await create_timer(1.0, true).timeout
	var offsets: Array[float] = []
	for sample in 12:
		screen = screen_script.open(root, 0, func(_slot: int) -> bool: return false, false, true)
		var offset: float = screen._transition_player.get_playback_position()
		var length: float = screen._transition_player.stream.get_length()
		check(offset >= 0.0 and offset + 2.6 <= length, "random start reserves full transition and end margin (%d)" % sample)
		offsets.append(offset)
		screen.queue_free()
		await process_frame
	check(offsets.max() - offsets.min() > 0.1, "static starts at different positions across openings")
	check(filter.material == original, "freeing during transition restores original CRT")
	overlay.queue_free()
	await process_frame
	screen = screen_script.open(root, 1, func(_slot: int) -> bool: return false)
	check(screen._crt_filter == null and screen._crt_material != null, "Load Game retains fallback CRT without gameplay overlay")
	check(not screen._busy and screen._content.modulate.a == 1.0, "non-transition Load Game opens normally")
	check(screen._transition_player == null, "non-transition Load Game does not play static burst")
	screen.close()
	await create_timer(1.0, true).timeout
	print("save_slot_crt_smoke: %s" % ("OK" if failures == 0 else "%d FAILURE(S)" % failures))
	quit(1 if failures else 0)
