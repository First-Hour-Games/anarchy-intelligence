extends SceneTree
## Save screen music: opening the file screen fades saveLoop.ogg in on the Music bus and dips
## music that was already playing; closing fades the loop out, brings that music back and frees
## the screen without eating input while it fades.

var failures: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		print("FAIL: " + message)
		failures += 1

func _init() -> void:
	print("--- Running Save Slot Music Smoke Test ---")
	call_deferred("_run")

func _run() -> void:
	var bgm := AudioStreamPlayer.new()
	bgm.stream = load("res://music/nearTown.ogg") as AudioStream
	bgm.bus = &"Music"
	bgm.volume_db = -4.0
	root.add_child(bgm)
	bgm.play()
	await process_frame

	var choose := func(_slot: int) -> bool: return false
	var screen := SaveSlotScreen.open(root, SaveSlotScreen.Mode.SAVE, choose, true)
	await process_frame
	var music: AudioStreamPlayer = screen.get("_music_player")
	check(music != null and music.playing, "save loop starts playing when the screen opens")
	if music == null:
		quit(1)
		return
	check(music.stream.resource_path == "" and (music.stream as AudioStreamOggVorbis).loop, "save loop is a looping copy of saveLoop.ogg")
	check(music.bus == &"Music", "save loop plays on the Music bus")
	check(music.volume_db < -40.0, "save loop starts quiet")
	await create_timer(screen.music_fade_in + 0.3, true, false, true).timeout
	check(is_equal_approx(music.volume_db, screen.music_volume_db), "save loop fades in to music_volume_db")
	check(bgm.volume_db < -60.0, "music already playing dips out under the save loop")
	check(paused, "saving from a gem pauses the game")

	screen.close()
	await process_frame
	check(not paused, "closing unpauses the game")
	check(is_instance_valid(screen) and not screen.visible, "screen hides at once and stays to fade the music")
	await create_timer(screen.music_fade_out + 0.3, true, false, true).timeout
	check(not is_instance_valid(screen), "screen frees itself after the fade out")
	check(is_equal_approx(bgm.volume_db, -4.0), "ducked music returns to its volume")

	bgm.queue_free()
	await process_frame
	quit(1 if failures else 0)
