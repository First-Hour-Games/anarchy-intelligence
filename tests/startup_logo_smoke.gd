extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var startup = load("res://scenes/mainMenu/startup.tscn").instantiate()
	startup.logo_fade_duration = 0.1
	startup.logo_hold_duration = 0.2
	startup.menu_fade_duration = 0.2
	root.add_child(startup)
	current_scene = startup
	assert(is_zero_approx(startup.logo.modulate.a))
	await create_timer(0.18).timeout
	assert(startup.logo.modulate.a > 0.9)
	assert(current_scene == startup)
	await create_timer(0.55).timeout
	assert(current_scene.scene_file_path == "res://scenes/mainMenu/menu.tscn")
	assert(not is_instance_valid(startup))
	assert(current_scene.music_player.playing)
	print("PASS: Studio logo fades in first, then fades into main menu")
	quit()

