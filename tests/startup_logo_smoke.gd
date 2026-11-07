extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var startup = load("res://scenes/mainMenu/startup.tscn").instantiate()
	startup.logo_fade_duration = 0.1
	startup.logo_hold_duration = 0.2
	startup.menu_fade_duration = 1.0
	root.add_child(startup)
	current_scene = startup
	assert(is_zero_approx(startup.logo.modulate.a))
	await create_timer(0.18).timeout
	assert(startup.logo.modulate.a > 0.9)
	assert(current_scene == startup)
	while current_scene == startup:
		await process_frame
	assert(current_scene.scene_file_path == "res://scenes/mainMenu/menu.tscn")
	var menu: Node = current_scene
	assert(not menu.music_player.playing, "Menu music must stay stopped when the reveal begins")
	startup._menu_reveal_tween.pause()
	startup._menu_reveal_tween.custom_step(0.4)
	assert(startup.black.modulate.a > 0.0 and startup.black.modulate.a < 1.0)
	assert(not menu.music_player.playing, "Menu music must stay stopped midway through the fade")
	startup._menu_reveal_tween.play()
	await startup.tree_exited
	await process_frame
	assert(not is_instance_valid(startup))
	assert(current_scene.music_player.playing)
	assert(current_scene.music_player.get_playback_position() < 0.2, "Music starts from the beginning after the fade")
	print("PASS: Main menu music starts only after its reveal tween completes")
	menu.queue_free()
	await process_frame
	var direct_menu: Node = load("res://scenes/mainMenu/menu.tscn").instantiate()
	root.add_child(direct_menu)
	assert(direct_menu.music_player.playing, "A directly opened, already-visible menu starts its music normally")
	direct_menu.queue_free()
	await process_frame
	print("PASS: Direct menu entry retains normal music playback")
	quit()

