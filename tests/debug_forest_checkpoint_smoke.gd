extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
		return
	print("PASS: ", message)

func run_checks() -> void:
	var forest_scene := load("res://scenes/chapters/main/starting_forest.tscn") as PackedScene
	check(forest_scene != null, "forest scene loads")
	for after_climb in [false, true]:
		var forest := forest_scene.instantiate() as StartingForest
		# Tree generation is unrelated to checkpoint state or road collision.
		var foliage := forest.get_node_or_null("Foliage")
		if foliage != null:
			foliage.free()
		root.add_child(forest)
		current_scene = forest
		await forest.debug_jump_to_log(after_climb)
		var player := forest.player
		var barrier := forest.get_node("Interactables/BarrierTree") as InteractableBlock3D
		var destination := barrier.get_climb_over_teleport_node()
		check(player.has_item(&"map"), "checkpoint grants town map")
		check(not player.is_frozen and player.velocity.is_zero_approx(), "player control restored and velocity cleared")
		check(forest.get("_has_faded"), "opening cinematic skipped")
		if after_climb:
			var offset := player.global_position - destination.global_position
			check(Vector2(offset.x, offset.z).length() < 0.01, "after-log checkpoint uses actual climb destination")
			check(forest.get("_has_switched_music"), "climb switches hiking music")
			check(forest.welcoming_hike_bgm.playing and not forest.visitor_bgm.playing, "hiking audio active and visitor music stopped")
			check(forest.get("_is_fog_active"), "climb fog activated")
			check(not barrier.get("_is_climbing_over") and not player.has_meta("is_climbing_over"), "climb locks and fade cleaned up")
		else:
			var direction := destination.global_position - barrier.global_position
			direction.y = 0.0
			var offset := player.global_position - barrier.global_position
			check(Vector2(offset.x, offset.z).length() < barrier.interaction_distance, "before-log checkpoint is within interaction range")
			check(offset.dot(direction) < 0.0, "before-log checkpoint is on approach side")
			check(not forest.get("_has_switched_music"), "before-log checkpoint preserves pre-climb state")
			check(not forest.call("_is_player_past_barrier"), "before-log position does not trigger post-climb fog")
		current_scene = null
		forest.queue_free()
		await process_frame
	quit()
