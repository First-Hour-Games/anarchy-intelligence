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
	player.unfreeze()
	var wrapper := (load("res://scenes/monsters/the_wrapper.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(wrapper)
	wrapper.set_physics_process(false)
	var audio := wrapper.get_node("HuntAudio") as AudioStreamPlayer
	audio.set_process(false)
	var source := load("res://sounds/entities/wrapper/wrapperHunt.mp3") as AudioStreamMP3
	check(audio.stream != source and audio.stream.loop and not source.loop, "hunt loops without mutating the imported MP3")
	player.global_position = Vector3(0, 0, 4)
	audio._process(1.0)
	check(not audio.playing, "hidden or inactive encounter stays silent")
	wrapper.set("enabled", true)
	audio._process(0.6)
	check(audio.playing and audio.bus == &"Music", "near active Wrapper starts the hunt loop on the music bus")
	var close_volume := audio.volume_db
	player.global_position.z = 17.0
	audio._process(1.2)
	check(audio.playing and audio.volume_db < close_volume, "moving away lowers volume and boundary hysteresis keeps the loop running")
	player.global_position.z = 22.0
	audio._process(0.1)
	check(audio.playing, "leaving range begins a fade instead of cutting the track")
	audio._process(1.2)
	check(not audio.playing, "leaving range stops the loop after fading")
	player.global_position.z = 4.0
	audio._process(0.6)
	audio.seek(maxf(audio.stream.get_length() - 0.05, 0.0))
	await create_timer(0.2).timeout
	check(audio.playing, "MP3 continues playing across the loop boundary")
	wrapper.set("suspended", true)
	audio._process(1.2)
	check(not audio.playing, "suspended encounter fades out")
	wrapper.set("suspended", false)
	audio._process(0.6)
	wrapper.hide()
	audio._process(1.2)
	check(not audio.playing, "hidden Wrapper fades out")
	wrapper.show()
	audio._process(0.6)
	player.freeze()
	audio._process(1.2)
	check(not audio.playing, "frozen player or death sequence fades out")
	wrapper.queue_free()
	player.queue_free()
	await process_frame
	print("wrapper_hunt_audio_smoke: %d failures" % failures)
	quit(1 if failures else 0)
