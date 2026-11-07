extends Area3D
## Road exit that restores the player's state before the new scene is revealed.
@export_file("*.tscn") var destination_scene: String
@export var destination_spawn: NodePath = NodePath("ForestEntranceSpawn")
@export var gate_path: NodePath
## Use matching scene coordinates when both map sections share the same layout.
@export var preserve_relative_position := false
@export var pursuer_path: NodePath
@export var pursuer_navigation_path: NodePath
@export_range(1.0, 30.0, 0.5, "suffix:m") var pursuer_transfer_radius := 12.0
var transitioning := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not gate_path.is_empty():
		var gate := get_node_or_null(gate_path)
		if gate == null or not gate.get("is_open"):
			return
	_start_transition(body)


func _on_gate_opened() -> void:
	_start_transition(get_tree().get_first_node_in_group("player") as Node3D)


func _on_gate_unlocked_with_key(body: Node3D) -> void:
	# The confirmation dialogue still owns the player freeze on this frame.
	_start_transition(body, true)


func _start_transition(body: Node3D, allow_frozen: bool = false) -> void:
	if transitioning or not body is FirstPersonPlayer or get_tree().paused:
		return
	if body.is_frozen and not allow_frozen:
		return
	transitioning = true
	_transition.call_deferred(body)


func _transition(player: FirstPersonPlayer) -> void:
	var source_scene := get_tree().current_scene as Node3D
	var source_parent := get_parent()
	var was_monitoring := monitoring
	var arrival_transform := player.global_transform
	if source_scene != null:
		arrival_transform = source_scene.global_transform.affine_inverse() * player.global_transform
	var health := player.get_node_or_null("CombatHealth")
	var view := {
		"head": player.head.transform,
		"camera": player.camera.transform,
		"daze": health.get("daze") if health != null else 0.0,
	}
	var state := SaveGame._capture_player(player)
	var ambience := source_scene.get_node_or_null("NightAmbience") as AudioStreamPlayer if source_scene != null else null
	var ambience_position := ambience.get_playback_position() if ambience != null and ambience.playing else -1.0
	var gate := get_node_or_null(gate_path) as RiggedMetalGate if not gate_path.is_empty() else null
	var gate_state := gate.get_save_state() if gate != null else {}
	var arrival_gate := source_scene.get_path_to(gate) if gate != null and source_scene != null else NodePath()
	var pursuer := _get_pursuer(player)
	var pursuer_parent := pursuer.get_parent() if pursuer != null else null
	monitoring = false
	# Keep the arrival callback alive across scene replacement.
	reparent(get_tree().root)
	if pursuer != null:
		pursuer.reparent(self)
		pursuer.set("player", null)
	var restore := _restore_arrival.bind(state, arrival_transform, view, arrival_gate, gate_state, pursuer, ambience_position)
	var error := await SceneLoader.change_to(destination_scene, restore)
	if error == OK:
		queue_free()
		return
	if pursuer != null:
		pursuer.reparent(pursuer_parent)
		pursuer.set("player", player)
	reparent(source_parent)
	monitoring = was_monitoring
	transitioning = false


func _get_pursuer(player: FirstPersonPlayer) -> CharacterBody3D:
	if pursuer_path.is_empty() or player.is_hidden():
		return null
	var pursuer := get_node_or_null(pursuer_path) as CharacterBody3D
	if pursuer != null and pursuer.get("player") == player and pursuer.get("enabled") and not pursuer.get("suspended") \
			and pursuer.is_visible_in_tree() and pursuer.call("is_hunting") \
			and pursuer.global_position.distance_squared_to(player.global_position) <= pursuer_transfer_radius * pursuer_transfer_radius:
		return pursuer
	return null


func _restore_arrival(scene: Node, state: Dictionary, arrival_transform: Transform3D, view: Dictionary, arrival_gate: NodePath, gate_state: Dictionary, pursuer: CharacterBody3D, ambience_position: float) -> void:
	# Let the destination player's deferred spawn snap finish before replacing its pose.
	await get_tree().process_frame
	var ambience := scene.get_node_or_null("NightAmbience") as AudioStreamPlayer
	if ambience != null and ambience_position >= 0.0:
		ambience.play(ambience_position)
	if not arrival_gate.is_empty():
		var gate := scene.get_node_or_null(arrival_gate) as RiggedMetalGate
		if gate != null:
			gate.play_arrival_open(float(gate_state["angle"]))
	var next_player := scene.get_node_or_null("Player") as FirstPersonPlayer
	if next_player != null:
		var spawn := scene.get_node_or_null(destination_spawn) as Node3D
		if preserve_relative_position and scene is Node3D:
			next_player.global_transform = scene.global_transform * arrival_transform
			next_player.head.transform = view.head
			next_player.camera.transform = view.camera
		elif spawn != null:
			next_player.global_transform = spawn.global_transform
		SaveGame._restore_player(next_player, state)
		next_player.velocity = Vector3.ZERO
		var health := next_player.get_node_or_null("CombatHealth")
		if health != null:
			health.set("spawn", next_player.global_transform)
			if preserve_relative_position:
				health.set("daze", view.daze)
		next_player.reset_physics_interpolation()
		if pursuer != null:
			pursuer.reparent(scene)
			var navigation := scene.get_node_or_null(pursuer_navigation_path) as NavigationRegion3D
			var nav_map := navigation.get_navigation_map() if navigation != null else pursuer.get_world_3d().navigation_map
			pursuer.call("continue_pursuit", next_player, nav_map)
