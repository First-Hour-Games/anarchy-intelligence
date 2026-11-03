extends Area3D
## Activates the existing Wrapper enemy for the generator ambush after key collection.

signal popout_started

@export_node_path("CharacterBody3D") var wrapper_path: NodePath = NodePath("../Wrapper")
@export_node_path("Node3D") var marker_path: NodePath = NodePath("../WrapperPopout")
@export_node_path("Node3D") var first_appearance_path: NodePath = NodePath("../WrapperCutscene")
@export_node_path("Node3D") var gate_path: NodePath = NodePath("../GasStation/MetalFenceGate")
@export var required_key: StringName = &"fence_key"
@export var face_player := true
## Movement speed after this ambush activates, including saved/streamed encounters.
@export_range(0.1, 10.0, 0.1) var ambush_movement_speed: float = 1.4

## Generic save/streaming restoration also resumes an activated enemy.
var has_played := false:
	set(value):
		has_played = value
		if value and is_node_ready():
			_activate_enemy.call_deferred()
var is_playing := false
var _activated := false
var _wrapper: CharacterBody3D
var _marker: Node3D
var _first_appearance: Node3D
var _waiting_player: FirstPersonPlayer
var _collision_layer: int = 1
var _collision_mask: int = 1

func _ready() -> void:
	add_to_group("streaming_one_shot")
	_wrapper = get_node_or_null(wrapper_path) as CharacterBody3D
	_marker = get_node_or_null(marker_path) as Node3D
	_first_appearance = get_node_or_null(first_appearance_path) as Node3D
	set_physics_process(false)
	if _wrapper == null or _marker == null or _first_appearance == null:
		push_warning("Wrapper ambush needs its actor, marker, and first appearance.")
		return
	_collision_layer = _wrapper.collision_layer if _wrapper.collision_layer != 0 else 1
	_collision_mask = _wrapper.collision_mask if _wrapper.collision_mask != 0 else 1
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if has_played:
		_activate_enemy.call_deferred()

func _on_body_entered(body: Node3D) -> void:
	if has_played or not body is FirstPersonPlayer:
		return
	_waiting_player = body
	set_physics_process(true)
	_try_activate()

func _on_body_exited(body: Node3D) -> void:
	if body == _waiting_player:
		_waiting_player = null
		set_physics_process(false)

func _physics_process(_delta: float) -> void:
	_try_activate()

func _try_activate() -> void:
	if has_played or not is_instance_valid(_waiting_player) or _waiting_player.is_frozen:
		return
	if bool(_first_appearance.get("is_playing")):
		return
	var gate := get_node_or_null(gate_path)
	var used_key := gate != null and not bool(gate.get("is_locked"))
	if not _waiting_player.has_item(required_key) and not used_key:
		return
	has_played = true
	# Live zone activation reveals the enemy immediately. The setter's deferred
	# call remains for save restoration and is ignored once already activated.
	_activate_enemy()
	# A fresh reveal gets the cue; save/streaming activation stays silent.
	if _activated:
		var appearance_audio := _wrapper.get_node_or_null("AppearanceAudio") as AudioStreamPlayer
		if appearance_audio != null:
			appearance_audio.play()
	set_physics_process(false)

func _activate_enemy() -> void:
	if _activated or not has_played or not is_instance_valid(_wrapper) or not is_instance_valid(_marker):
		return
	var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if player == null:
		return
	_activated = true
	is_playing = true
	# The window walk must never take control of the activated enemy later.
	_first_appearance.set("has_played", true)
	# A Wrapper killed before this save stays where it fell.
	if bool(_wrapper.get("dead")):
		return
	var actor_scale := _wrapper.global_basis.get_scale()
	var spawn_transform := Transform3D(_marker.global_basis.orthonormalized().scaled(actor_scale), _marker.global_position)
	_wrapper.call("set_post", spawn_transform)
	if face_player:
		var focus := Vector3(player.global_position.x, _wrapper.global_position.y, player.global_position.z)
		if focus.distance_squared_to(_wrapper.global_position) > 0.001:
			_wrapper.look_at(focus, Vector3.UP, bool(_first_appearance.get("model_faces_positive_z")))
	_wrapper.set("player", player)
	_wrapper.set("freeze_when_watched", false)
	_wrapper.set("movement_speed", ambush_movement_speed)
	_wrapper.set("suspended", false)
	_wrapper.set("enabled", true)
	_wrapper.set("attack_cooldown", 0.0)
	_wrapper.collision_layer = _collision_layer
	_wrapper.collision_mask = _collision_mask
	_wrapper.process_mode = Node.PROCESS_MODE_INHERIT
	_wrapper.set_process(true)
	_wrapper.set_physics_process(true)
	_wrapper.reset_physics_interpolation()
	_wrapper.show()
	popout_started.emit()
