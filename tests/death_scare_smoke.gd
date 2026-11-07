extends SceneTree
## The death knockdown in the real map, for each killer: the view falls from the gameplay
## camera's exact transform, tumbles away from the attacker, lies down, blacks out, then the
## phone game over appears; TRY AGAIN restores everything. Non-lethal hits are unchanged.
var failures: int = 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, label: String) -> void:
	print(("PASS " if condition else "FAIL ") + label)
	if not condition:
		failures += 1

func rigs() -> int:
	return root.find_children("DeathFallRig", "RigidBody3D", true, false).size()

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
	var scare_script: GDScript = load("res://scenes/ui/death_scare.gd")

	# An ordinary hit keeps its daze and starts no knockdown.
	health.immunity = 0.0
	health.take_damage(20.0, map.get_node("Wrapper"))
	check(not health.is_dead and health.death_scare == null and health.daze > 0.0 and not player.is_frozen, "A non-lethal hit only dazes")
	health.health = health.max_health
	health.daze = 0.0
	health._apply_daze()

	for entity: String in ["Wrapper", "Clawman", "THE_RIDGEBACK"]:
		var attacker := map.get_node(entity) as Node3D
		player.rotation.y = 1.7
		var view: Transform3D = player.camera.global_transform
		var layers := player.collision_layer
		health.immunity = 0.0
		health.take_damage(health.max_health, attacker)
		var scare = health.death_scare
		check(health.is_dead and player.is_frozen, entity + " killing hit freezes the player")
		check(scare != null and scare.rig != null and rigs() == 1, entity + " starts exactly one fall rig")
		if scare == null or scare.rig == null:
			continue
		check(scare.rig.global_transform.origin.is_equal_approx(view.origin) and scare.rig.global_basis.is_equal_approx(view.basis.orthonormalized()),
				entity + " fall starts at the gameplay camera's exact transform")
		check(scare.camera.current and scare.camera.get_world_3d() == player.get_world_3d(), entity + " falls in the real level")
		check((scare.camera.cull_mask & 2) == 0, entity + " fallen view leaves the held items out")
		check(player.collision_layer == 0, entity + " the standing body is out of the way while down")
		check(map.get_node("CRTOverlay").visible and map.get_node("AspectRatioBars").visible and not player.get_node("HandViewmodel").visible,
				entity + " keeps the CRT and bars and hides the HUD")
		check(scare.audio != null and scare.audio.bus == &"Effects" and scare.audio.playing, entity + " plays its kill sound")
		check(scare.tinnitus.playing, entity + " starts the pulsating tone with the fall")
		check(attacker.process_mode == Node.PROCESS_MODE_DISABLED and scare.attacker_visual.process_mode == Node.PROCESS_MODE_ALWAYS,
				entity + " stops but keeps its lunge animating")
		var from_attacker := Vector2(view.origin.x - attacker.global_position.x, view.origin.z - attacker.global_position.z).length()
		await create_timer(0.7).timeout
		var now: Vector3 = scare.rig.global_position
		check(Vector2(now.x - attacker.global_position.x, now.z - attacker.global_position.z).length() > from_attacker + 0.3,
				entity + " knocks the view back away from the attacker")
		check(now.y < view.origin.y - 0.3, entity + " the view falls toward the ground")
		await create_timer(2.6).timeout
		check(scare.settled and health.game_over == null and scare.blackout.color.a < 0.5, entity + " stays down a few seconds before the blackout")
		check(scare.rig.global_position.y > view.origin.y - scare_script.MAX_DROP, entity + " never falls through the level")
		check(scare.tinnitus.playing, entity + " plays the pulsating tone while the view blurs")
		var tone_level: float = scare.tinnitus.volume_db
		await create_timer(0.9).timeout
		check(scare.blackout.color.a > 0.0 and scare.tinnitus.playing and scare.tinnitus.volume_db < tone_level,
				entity + " fades the tone with the blackout")
		await create_timer(1.1).timeout
		var game_over = health.game_over
		check(game_over != null and scare.blackout.color.a >= 1.0 and not scare.audio.playing and not scare.tinnitus.playing,
				entity + " stops both sounds when the phone game over appears")
		if game_over == null:
			continue
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
		check(player.collision_layer == layers and rigs() == 0, entity + " retry restores collision and removes the rig")
		check(attacker.process_mode != Node.PROCESS_MODE_DISABLED, entity + " retry restores enemy processing")
		check(player.camera.current and player.get_node("HandViewmodel").visible, entity + " retry restores the gameplay camera and HUD")
	map.queue_free()
	save_game.save_dir = original_dir
	await process_frame
	print("Death scare failures: ", failures)
	quit(1 if failures else 0)
