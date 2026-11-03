extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	print(("PASS: " if condition else "FAIL: ") + message)
	if not condition:
		failures += 1


func frames(count: int = 4) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _run() -> void:
	var scene: PackedScene = load("res://scenes/chapters/main/residence_area.tscn")
	var town := scene.instantiate()
	# Keep this check on the authored town street without loading the forest/foliage.
	town.get_node("ForestStreamConnection").free()
	town.get_node("Foliage").free()
	# A second spawn point, added the way a designer would, must get the town map too.
	var extra_spawn: Marker3D = (load("res://scenes/monsters/wrapper_spawn_point.tscn") as PackedScene).instantiate()
	extra_spawn.name = "ExtraWrapperSpawn"
	town.add_child(extra_spawn)
	extra_spawn.position = town.get_node("WrapperTestSpawn").position + Vector3(20, 0, 0)
	root.add_child(town)
	current_scene = town
	var player := town.get_node("Player") as FirstPersonPlayer
	player.unfreeze()
	player.set_physics_process(false)
	var spawn := town.get_node("WrapperTestSpawn") as Marker3D
	var wrapper: CharacterBody3D = spawn.get_node("Wrapper")
	var navigation: NavigationRegion3D = town.get_node("ResidenceEnemyNavigation")
	await frames(8)
	check(town.find_children("*", "Marker3D", true, false).filter(func(node): return node.scene_file_path.ends_with("wrapper_spawn_point.tscn")).size() == 2,
		"town has its authored spawn point plus the added one")
	check(wrapper.enabled and wrapper.roaming and wrapper.roam_state == wrapper.RoamState.WANDERING,
		"Wrapper roams with no activation-distance cutoff while the player is far away")
	check(navigation.navigation_mesh != null and navigation.navigation_mesh.get_polygon_count() > 0,
		"residential street has a nonempty navigation mesh")
	check(navigation.get_navigation_map() != navigation.get_world_3d().navigation_map
		and wrapper.get_node("NavigationAgent3D").get_navigation_map() == navigation.get_navigation_map(),
		"town enemy uses an isolated map so forest navigation cannot overlap it")
	check(extra_spawn.get_node("Wrapper/NavigationAgent3D").get_navigation_map() == navigation.get_navigation_map(),
		"an added spawn point uses the town map without being named in code")
	extra_spawn.free()
	check(wrapper.spawn.origin.is_equal_approx(spawn.global_position) and wrapper.home.is_equal_approx(spawn.global_position),
		"enemy post and home match the editable marker")

	player.global_position = spawn.global_position + Vector3(8, 0.1, 0)
	player.look_at(player.global_position + Vector3.RIGHT)
	player.head.rotation = Vector3.ZERO
	await frames(6)
	check(wrapper.enabled and not wrapper.freeze_when_watched, "street Wrapper does not freeze when watched")
	check(wrapper.roam_state == wrapper.RoamState.WANDERING, "a silent player standing near it is not detected")
	player.velocity = Vector3(3.2, 0, 0)
	await frames(2)
	check(wrapper.roam_state == wrapper.RoamState.HUNTING, "a player walking nearby is heard and hunted")
	player.velocity = Vector3.ZERO
	player.look_at(Vector3(wrapper.global_position.x, player.global_position.y, wrapper.global_position.z))
	player.head.look_at(wrapper.global_position + Vector3.UP * 1.4)
	await frames(4)
	check(wrapper.is_watched_by_player(), "player can see the street Wrapper")
	var start := wrapper.global_position
	await frames(60)
	check(Vector2(wrapper.global_position.x - start.x, wrapper.global_position.z - start.z).length() > 0.3,
		"hunting Wrapper keeps coming while watched")
	player.is_frozen = true
	await frames()
	check(not wrapper.enabled, "inspection or frozen player suspends the encounter")
	player.unfreeze()
	player.set_physics_process(false)
	player.look_at(player.global_position + Vector3.RIGHT)
	player.head.rotation = Vector3.ZERO
	var health := player.get_node("CombatHealth")
	var initial_health: float = health.health
	var deadline := Time.get_ticks_msec() + 14000
	while health.health >= initial_health and Time.get_ticks_msec() < deadline:
		await physics_frame
	check(health.health < initial_health, "Wrapper reaches and damages the player through existing combat")
	player.global_position = spawn.global_position + Vector3(40, 0.1, 0)
	await frames()
	check(wrapper.enabled and wrapper.roam_state == wrapper.RoamState.HUNTING, "running out of range does not cut a hunt off at once")
	player.global_position = spawn.global_position + Vector3(8, 0.1, 0)
	await frames()
	for i in wrapper.hits_to_kill:
		wrapper.take_melee_hit(player.global_position, 0.1, 1.0)
	check(wrapper.dead, "test Wrapper can be killed with the pipe")
	var save := root.get_node("SaveGame")
	var state: Dictionary = save._capture_section(town)
	check(state.dead_story_mobs.has("WrapperTestSpawn/Wrapper"), "save captures the persistent enemy path")
	var restored := scene.instantiate()
	save._restore_section(restored, state)
	var corpse: Node = restored.get_node("WrapperTestSpawn/Wrapper")
	check(not corpse._pending_corpse.is_empty(), "load queues the saved corpse before the town enters the tree")
	restored.set_meta("streamed_section", true)
	for shared_name in root.get_node("WorldStreaming").SHARED_NAMES:
		var duplicate := restored.get_node_or_null(NodePath(shared_name))
		if duplicate != null:
			duplicate.free()
	restored.get_node("Foliage").free()
	restored.get_node("ForestStreamConnection").free()
	root.add_child(restored)
	await frames(8)
	check(corpse.dead and not corpse.enabled, "streamed town restores its corpse without reactivating it")
	var restored_nav: NavigationRegion3D = restored.get_node("ResidenceEnemyNavigation")
	check(restored_nav.navigation_mesh != null and restored_nav.navigation_mesh.get_polygon_count() > 0,
		"town navigation also bakes after shared terrain and player are stripped for streaming")
	restored.queue_free()
	root.get_node("WorldStreaming")._save_state(town)
	var streaming_state: Dictionary = root.get_node("WorldStreaming")._states[town.scene_file_path]
	check(streaming_state.dead_story_mobs.has(NodePath("WrapperTestSpawn/Wrapper")), "streaming preserves the killed Wrapper")
	town.queue_free()
	await process_frame
	print("Residence Wrapper spawn: %d failures" % failures)
	quit(1 if failures else 0)
