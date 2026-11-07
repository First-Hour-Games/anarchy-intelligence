class_name RiggedMetalGate
extends Node3D
## Uses the imported armature's gate bone, with a matching moving physics body.

signal opened
signal closed
signal unlocked_with_key(player: Node3D)

@export_category("Gate Motion")
@export_range(10.0, 120.0, 1.0) var open_angle_degrees: float = 95.0
@export_range(0.1, 3.0, 0.05) var swing_duration: float = 2.2
@export var open_away_from_player: bool = true
@export var starts_open: bool = false
@export var stay_open: bool = false
@export var gate_bone_name: StringName = &"Bone.001_01"

@export_category("Lock")
@export_range(1.0, 8.0, 0.5) var locked_shake_degrees: float = 3.0
@export var starts_locked: bool = true
@export var required_key: StringName = &"fence_key"
@export_multiline var locked_dialogue: String = "The fence gate is secured with a lock. I need a key."
@export var choice_balloon_scene: PackedScene = preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")

@export_category("Gate Audio")
@export var locked_sound: AudioStream = preload("res://sounds/chapters/main/foley_metal_fence_hit_multiple_01.ogg")
@export var movement_sound: AudioStream = preload("res://sounds/chapters/main/metal_small_gate_movement_w_rattle_wav.ogg")
@export_range(-40.0, 10.0, 0.5) var locked_sound_volume_db: float = 0.0
@export_range(-40.0, 10.0, 0.5) var movement_sound_volume_db: float = 0.0
@export_range(1.0, 50.0, 0.5) var sound_max_distance: float = 25.0
@export var sound_bus: StringName = &"Master"

var is_open: bool = false
var is_locked: bool = true
var is_moving: bool = false
var _skeleton: Skeleton3D
var _bone: int = -1
var _closed_bone_rotation: Quaternion
var _closed_bone_transform: Transform3D
var _closed_prompt_position: Vector3
var _angle: float = 0.0
var _motion: Tween
var _target_angle: float = 0.0
var _pending_save_state: Dictionary = {}
## The player being asked whether to use the key, while the Yes/No choice is open.
var _asking_player: Node3D

@onready var leaf_body: AnimatableBody3D = $GateLeafCollision
@onready var interactable: InteractableBlock3D = $Interactable
@onready var locked_audio_player: AudioStreamPlayer3D = get_node_or_null("LockedAudio") as AudioStreamPlayer3D
@onready var movement_audio_player: AudioStreamPlayer3D = get_node_or_null("MovementAudio") as AudioStreamPlayer3D

func _ready() -> void:
	is_locked = starts_locked and not starts_open
	_setup_audio()
	_skeleton = $Model.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		push_error("Metal gate has no imported skeleton.")
		interactable.disable()
		return
	_bone = _skeleton.find_bone(gate_bone_name)
	if _bone < 0:
		push_error("Metal gate is missing its gate bone: " + String(gate_bone_name))
		interactable.disable()
		return
	var animator := $Model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator != null:
		animator.stop()
	_skeleton.reset_bone_poses()
	_closed_bone_rotation = _skeleton.get_bone_pose_rotation(_bone)
	_closed_bone_transform = global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)
	_closed_prompt_position = interactable.position
	leaf_body.sync_to_physics = false
	interactable.triggered.connect(toggle)
	is_open = starts_open
	_target_angle = deg_to_rad(open_angle_degrees) if starts_open else 0.0
	_set_angle(_target_angle)
	interactable.is_enabled = not (stay_open and is_open)
	if not _pending_save_state.is_empty():
		restore_save_state(_pending_save_state)
		_pending_save_state = {}

func _setup_audio() -> void:
	if locked_audio_player == null:
		locked_audio_player = get_node_or_null("LockedAudio") as AudioStreamPlayer3D
	if locked_audio_player == null:
		locked_audio_player = AudioStreamPlayer3D.new()
		locked_audio_player.name = "LockedAudio"
		locked_audio_player.position = Vector3(0.7, 1.4, 0.0)
		add_child(locked_audio_player)
	if locked_sound != null:
		locked_audio_player.stream = locked_sound
	locked_audio_player.volume_db = locked_sound_volume_db
	locked_audio_player.max_distance = sound_max_distance
	locked_audio_player.bus = sound_bus

	if movement_audio_player == null:
		movement_audio_player = get_node_or_null("MovementAudio") as AudioStreamPlayer3D
	if movement_audio_player == null:
		movement_audio_player = AudioStreamPlayer3D.new()
		movement_audio_player.name = "MovementAudio"
		movement_audio_player.position = Vector3(0.0, 1.5, 0.0)
		add_child(movement_audio_player)
	if movement_sound != null:
		movement_audio_player.stream = movement_sound
	movement_audio_player.volume_db = movement_sound_volume_db
	movement_audio_player.max_distance = sound_max_distance
	movement_audio_player.bus = sound_bus

func toggle(player: Node3D = null) -> void:
	if is_moving or _bone < 0 or (stay_open and is_open):
		return
	if is_locked:
		var inventory := _inventory(player)
		if inventory == null or not inventory.has_item(required_key):
			interactable.single_line_dialogue = locked_dialogue
			_shake_locked(player)
			return
		interactable.single_line_dialogue = ""
		_ask_to_use_key(player)
		return
	interactable.single_line_dialogue = ""
	_swing(player)

## Asks "Open with <key>?" before using the key; No leaves the gate locked and asks again next time.
func _ask_to_use_key(player: Node3D) -> void:
	var item := ItemDatabase.get_item(required_key)
	var key_name := item.name if item != null and not item.name.is_empty() else String(required_key).capitalize()
	var text := "~ start\nOpen with %s?\n- Yes\n\tdo open_with_key()\n- No\n=> END" % key_name
	var resource: DialogueResource = Engine.get_singleton("DialogueManager").create_resource_from_text(text)
	var balloon := choice_balloon_scene.instantiate()
	if balloon.get("freeze_player") != null:
		balloon.set("freeze_player", true)
	var scene := get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	scene.add_child(balloon)
	_asking_player = player
	interactable.is_enabled = false
	if balloon.has_signal("dialogue_finished"):
		balloon.connect("dialogue_finished", _on_choice_closed, CONNECT_ONE_SHOT)
	balloon.start(resource, "start", [self])

## The Yes answer: uses up the key, unlocks the gate and opens it.
func open_with_key() -> void:
	var inventory := _inventory(_asking_player)
	if not is_locked or inventory == null or not inventory.remove_one(required_key):
		return
	is_locked = false
	_swing(_asking_player)
	unlocked_with_key.emit(_asking_player)

func _on_choice_closed() -> void:
	_asking_player = null
	if not is_moving:
		interactable.is_enabled = not (stay_open and is_open)

func _inventory(player: Node3D) -> PlayerInventory:
	return player.get_node_or_null("InventoryHUD") as PlayerInventory if is_instance_valid(player) else null

func _swing(player: Node3D) -> void:
	var target := 0.0
	if not is_open:
		var direction := 1.0
		if open_away_from_player and is_instance_valid(player):
			direction = 1.0 if to_local(player.global_position).z >= 0.0 else -1.0
		target = deg_to_rad(open_angle_degrees) * direction
	_swing_to(target)

## Start closed while the destination is paused, then swing as it is revealed.
func play_arrival_open(angle: float) -> void:
	if _bone < 0:
		return
	restore_save_state({"locked": false})
	_swing_to(angle)

func _swing_to(target: float) -> void:
	_play_movement_sound()
	is_moving = true
	_target_angle = target
	interactable.is_enabled = false
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_method(_set_angle, _angle, target, swing_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.finished.connect(func() -> void:
		is_open = not is_zero_approx(target)
		is_moving = false
		interactable.is_enabled = not (stay_open and is_open)
		if is_open:
			opened.emit()
		else:
			closed.emit()
	)

func _shake_locked(player: Node3D) -> void:
	_play_locked_sound()
	var direction := 1.0
	if is_instance_valid(player):
		direction = 1.0 if to_local(player.global_position).z >= 0.0 else -1.0
	var shake_angle := deg_to_rad(locked_shake_degrees) * direction
	is_moving = true
	_target_angle = 0.0
	interactable.is_enabled = false
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_method(_set_angle, 0.0, shake_angle, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.tween_method(_set_angle, shake_angle, -shake_angle * 0.35, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_method(_set_angle, -shake_angle * 0.35, shake_angle * 0.15, 0.08)
	_motion.tween_method(_set_angle, shake_angle * 0.15, 0.0, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion.finished.connect(func() -> void:
		_set_angle(0.0)
		is_moving = false
		interactable.is_enabled = true
	)

func _play_locked_sound() -> void:
	if is_instance_valid(locked_audio_player) and locked_audio_player.stream != null:
		locked_audio_player.play()

func _play_movement_sound() -> void:
	if is_instance_valid(movement_audio_player) and movement_audio_player.stream != null:
		movement_audio_player.play()

func _set_angle(angle: float) -> void:
	_angle = angle
	_skeleton.set_bone_pose_rotation(_bone, _closed_bone_rotation * Quaternion(Vector3.UP, angle))
	var bone_transform := global_transform.affine_inverse() * _skeleton.global_transform * _skeleton.get_bone_global_pose(_bone)
	var delta := bone_transform * _closed_bone_transform.affine_inverse()
	leaf_body.transform = Transform3D(delta.basis.orthonormalized(), delta.origin)
	interactable.position = delta * _closed_prompt_position

func _exit_tree() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()

func get_save_state() -> Dictionary:
	var saved_angle := _target_angle if is_moving else _angle
	return {"locked": is_locked, "angle": saved_angle}

func restore_save_state(state: Dictionary) -> void:
	if _bone < 0:
		_pending_save_state = state.duplicate()
		return
	if _motion != null and _motion.is_valid():
		_motion.kill()
	is_locked = bool(state.get("locked", starts_locked))
	var saved_angle := float(state.get("angle", 0.0))
	if is_locked:
		saved_angle = 0.0
	_set_angle(saved_angle)
	_target_angle = saved_angle
	is_open = not is_zero_approx(saved_angle)
	is_moving = false
	interactable.is_enabled = not (stay_open and is_open)
	interactable.single_line_dialogue = ""
