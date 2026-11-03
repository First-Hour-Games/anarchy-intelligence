extends SceneTree
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func run() -> void:
	# No save files, so the phone game over offers TRY AGAIN; the real saves are never looked at.
	var save_game := root.get_node("SaveGame")
	var original_dir: String = save_game.save_dir
	save_game.save_dir = "user://test_death_scare_no_saves"
	var map := (load("res://scenes/chapters/main/map.tscn") as PackedScene).instantiate()
	map.get_node("OpeningStory").persist_progress = false
	root.add_child(map)
	current_scene = map
	await create_timer(1.0).timeout
	var player := map.get_node("Player") as FirstPersonPlayer
	var health := player.get_node("CombatHealth")
	for entity: String in ["Wrapper", "Clawman", "THE_RIDGEBACK"]:
		var attacker := map.get_node(entity) as Node3D
		player.rotation.y = 1.7
		health.immunity = 0.0
		health.take_damage(health.max_health, attacker)
		var scare = health.death_scare
		check(health.is_dead and player.is_frozen, entity + " killing hit freezes player")
		check(scare != null and scare.viewport == player.get_viewport() and scare.actor.get_world_3d() == player.get_world_3d(), entity + " retains the actual game world behind attacker")
		check(scare.actor != attacker.get_node("Visual"), entity + " preserves gameplay model")
		if entity == "Wrapper":
			check(is_equal_approx(scare.actor_mount.rotation.y, PI), "Wrapper facing correction is independent of imported animation")
		check(scare.audio.bus == &"Effects" and scare.audio.stream != null, entity + " plays credited sound through Effects")
		check(scare.audio.stream is AudioStreamWAV and scare.audio.playing and scare.audio.volume_db >= -3.0, entity + " starts normalized vocal immediately at audible level")
		check(scare.camera.current and scare.camera.position.z < 0, entity + " camera faces attacker regardless of player facing")
		check(map.get_node("CRTOverlay").visible and map.get_node("AspectRatioBars").visible,
				entity + " close-up stays inside the TV: the CRT and the side bars stay on")
		await create_timer(0.4).timeout
		if scare.head_skeleton != null:
			var face: Vector3 = scare.head_skeleton.global_transform * scare.head_skeleton.get_bone_global_pose(scare.head_bone).origin
			check((-scare.camera.global_basis.z).dot((face - scare.camera.global_position).normalized()) > 0.99, entity + " camera points at the face in world coordinates")
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://../scare-" + entity + ".png")
		await create_timer(1.4).timeout
		var game_over = health.game_over
		check(game_over != null and not scare.audio.playing, entity + " fades to the phone game over and stops scream")
		var respawned := {}
		game_over.try_again.connect(func() -> void: respawned["at"] = player.global_position)
		game_over.choose(0)
		for i in 180:
			if not health.is_dead:
				break
			await process_frame
		check(respawned.has("at") and (respawned["at"] as Vector3).distance_to(health.spawn.origin) < 0.01, entity + " retry restores checkpoint")
		await process_frame
		check(not health.is_dead and not player.is_frozen and health.death_scare == null, entity + " retry restores control")
		check(attacker.process_mode != Node.PROCESS_MODE_DISABLED, entity + " retry restores enemy processing")
		check(player.camera.current, entity + " retry restores gameplay camera")
	map.queue_free()
	save_game.save_dir = original_dir
	await process_frame
	print("Death scare failures: ", failures)
	quit(1 if failures else 0)
