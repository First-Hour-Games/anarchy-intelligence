extends SceneTree

var failures := 0


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func check_navigation(player: AudioStreamPlayer, context: String) -> void:
	check(is_equal_approx(player.volume_db, -10.0), context + " uses shared navigation volume")
	check(player.bus == &"Effects", context + " follows Effects volume")
	check(player.process_mode == Node.PROCESS_MODE_ALWAYS, context + " works while paused")


func run() -> void:
	var pause_menu := root.get_node("PauseMenu")
	check_navigation(pause_menu._move_sfx_player, "Pause move")
	check_navigation(pause_menu._click_sfx_player, "Pause click")
	check(pause_menu._pause_sfx_player.bus == &"Effects", "Pause opening follows Effects volume")
	var screens: Array[Node] = []
	for path in ["res://scenes/mainMenu/menu.tscn", "res://scenes/ui/balloon/balloon.tscn", "res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn"]:
		var screen: Node = load(path).instantiate()
		root.add_child(screen)
		screens.append(screen)
		var suffix := "Player" if path.contains("mainMenu") else ""
		check_navigation(screen.get_node("MoveSfx" + suffix), path + " move")
		check_navigation(screen.get_node("ClickSfx" + suffix), path + " click")
	var menu_music: AudioStreamPlayer = screens[0].get_node("MusicPlayer")
	check(menu_music.bus == &"Music" and is_equal_approx(menu_music.volume_db, -6.498775), "Menu music retains its separate volume")
	var pickup := root.get_node("ItemPickupScreen")
	var item := ItemData.new()
	pickup._play_pickup_sound(item)
	check_navigation(pickup._sfx_player, "Pickup fallback")
	item.pickup_sound = AudioStreamWAV.new()
	pickup._play_pickup_sound(item)
	check(is_equal_approx(pickup._sfx_player.volume_db, -6.0), "Custom pickup retains its own mix level")
	var choose := func(_slot: int) -> bool: return false
	var save_screen: Variant = load("res://scenes/ui/save_slots/save_slot_screen.gd").open(root, 0, choose, true)
	check_navigation(save_screen._move_player, "Save move")
	check_navigation(save_screen._click_player, "Save click")
	save_screen._move_player.play()
	await create_timer(0.05, true).timeout
	check(paused and save_screen._move_player.get_playback_position() > 0.0, "Save navigation playback advances while game is paused")
	var effects_index := AudioServer.get_bus_index("Effects")
	var old_volume := AudioServer.get_bus_volume_db(effects_index)
	var old_mute := AudioServer.is_bus_mute(effects_index)
	pause_menu._set_volume(0.0, "Effects")
	check(AudioServer.is_bus_mute(effects_index), "Effects mute covers every shared UI player")
	check(AudioServer.get_bus_send(effects_index) == &"Master", "UI also follows Master volume")
	AudioServer.set_bus_volume_db(effects_index, old_volume)
	AudioServer.set_bus_mute(effects_index, old_mute)
	save_screen.close()
	await create_timer(save_screen.music_fade_out + 0.1, true).timeout
	for screen in screens:
		screen.queue_free()
	await process_frame
	print("ui_audio_consistency_smoke: ", "OK" if failures == 0 else "FAILED")
	quit(0 if failures == 0 else 1)
