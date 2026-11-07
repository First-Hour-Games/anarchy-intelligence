extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as FirstPersonPlayer
	world.add_child(player)
	player.set_physics_process(false)
	var health := Node.new()
	health.name = "CombatHealth"
	health.set_script(load("res://scenes/player/combat_health.gd"))
	player.add_child(health)
	var enemy := Node3D.new()
	world.add_child(enemy)
	enemy.position = Vector3(0, 0, -2)
	var audio: AudioStreamPlayer = health.impact_audio
	var pool := audio.stream as AudioStreamRandomizer
	check(pool != null and pool.streams_count == 9, "all nine punch clips are in the randomizer")
	check(pool.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS, "random selection avoids consecutive repeats")
	for i in pool.streams_count:
		var sound := pool.get_stream(i) as AudioStreamOggVorbis
		check(sound != null and not sound.loop and sound.get_length() > 0.0, "impact %d loads and plays once" % (i + 1))
	check(audio.bus == &"Effects" and not audio.playing, "impact player uses Effects and starts silent")
	health.take_damage(10.0, enemy)
	check(audio.playing and health.health == 90.0, "accepted enemy hit plays an impact")
	audio.stop()
	health.take_damage(10.0, enemy)
	check(not audio.playing and health.health == 90.0, "immunity blocks damage and impact sound together")
	health.immunity = 0.0
	health.take_damage(0.0, enemy)
	health.take_damage(-10.0, enemy)
	check(not audio.playing and health.health == 90.0, "zero or negative damage stays silent")
	health.take_damage(10.0)
	check(not audio.playing and health.health == 80.0, "damage without an enemy does not play a punch")
	health.immunity = 0.0
	health.take_damage(health.max_health, enemy)
	check(audio.playing and health.is_dead and health.death_scare != null, "lethal hit plays an impact alongside the knockdown")
	audio.stop()
	health.immunity = 0.0
	health.take_damage(10.0, enemy)
	check(not audio.playing, "further hits after death stay silent")
	health.respawn()
	check(health.impact_audio == audio and not health.is_dead, "retry reuses the single impact player")
	world.queue_free()
	await process_frame
	print("Player impact audio: %d failures" % failures)
	quit(1 if failures else 0)
