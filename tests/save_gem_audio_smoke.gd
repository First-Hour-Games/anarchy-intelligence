extends SceneTree

var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures += 1

func run() -> void:
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	root.add_child(player)
	player.set_physics_process(false)
	var gem: Variant = (load("res://scenes/interaction/save_gem.tscn") as PackedScene).instantiate()
	root.add_child(gem)
	gem.set_process(false)
	var song := gem.get_node("Model/ProximityMusic") as AudioStreamPlayer3D
	song.set_process(false)
	var source := load("res://music/saveInterlude.ogg") as AudioStreamOggVorbis
	check(song.stream is AudioStreamOggVorbis and song.stream.packet_sequence == source.packet_sequence, "save gem uses the converted Ogg Vorbis interlude")
	check(song.stream.loop and song.bus == &"Music", "interlude loops and follows the Music volume setting")
	check(song.get_parent() == gem.model and song.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE, "sound emits from the floating gem with 3D distance attenuation")
	player.global_position = Vector3(25, 0, 0)
	song._process(1.0)
	check(not song.playing, "distant player does not start gem music")
	player.global_position = Vector3(3, 0, 0)
	song._process(0.1)
	var starting_volume := song.volume_db
	check(song.playing, "approaching the gem starts playback")
	song._process(0.7)
	check(song.volume_db > starting_volume and is_equal_approx(song.volume_db, song.song_volume_db), "song gradually fades to its configured source volume")
	var old_origin: Vector3 = song.global_position
	gem._time += 1.0
	gem._update_float(0.2)
	check(not old_origin.is_equal_approx(song.global_position), "emitter moves with gem bobbing and rotation")
	song.seek(song.stream.get_length() - 0.05)
	await create_timer(0.2).timeout
	check(song.playing, "song continues across its loop boundary")
	player.global_position = Vector3(13, 0, 0)
	song._process(0.1)
	check(song.playing, "remaining near the boundary does not restart playback")
	player.global_position = Vector3(20, 0, 0)
	song._process(0.1)
	check(song.playing and song.volume_db < song.song_volume_db, "leaving begins a gradual fade")
	song._process(1.2)
	check(not song.playing, "faraway gem stops playback after fading")
	player.global_position = Vector3(3, 0, 0)
	song._process(0.8)
	check(song.playing, "returning to the gem starts its song again")
	gem.interact(player)
	var screen := get_first_node_in_group("save_slot_screen")
	check(screen != null and screen.get("_busy"), "real gem interaction begins the save-screen fade")
	check(not song.playing and song.volume_db <= -80.0, "interlude stops immediately before the screen fades in")
	song._process(1.0)
	check(not song.playing, "proximity updates cannot restart interlude under the save screen")
	check(screen.get("_music_player").playing, "save screen keeps its own saveLoop music")
	await screen.get("_transition_tween").finished
	check(not song.playing, "interlude stays stopped after save-screen fade-in completes")
	screen.close()
	await screen.closed
	song._process(1.0)
	check(not song.playing, "interlude stays stopped while menu music fades out")
	await screen.tree_exited
	song._process(0.1)
	check(song.playing and song.volume_db < song.song_volume_db, "interlude fades back in after the save screen fully closes")
	gem.queue_free()
	player.queue_free()
	await process_frame
	print("save_gem_audio_smoke: %d failures" % failures)
	quit(1 if failures else 0)
