class_name RiggedMetalGate
extends Node3D
## Uses the imported armature's gate bone, with a matching moving physics body.

signal opened
signal closed

@export_category("Gate Motion")
@export_range(10.0, 120.0, 1.0) var open_angle_degrees: float = 95.0
@export_range(0.1, 3.0, 0.05) var swing_duration: float = 0.9
@export var open_away_from_player: bool = true
@export var gate_bone_name: StringName = &"Bone.001_01"

@export_category("Lock")
@export var starts_locked: bool = true
@export var required_key: StringName = &"fence_key"
@export_multiline var locked_dialogue: String = "The fence gate is secured with a lock. I need a key."

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

@onready var leaf_body: AnimatableBody3D = $GateLeafCollision
@onready var interactable: InteractableBlock3D = $Interactable

func _ready() -> void:
	is_locked = starts_locked
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
	_set_angle(0.0)
	if not _pending_save_state.is_empty():
		restore_save_state(_pending_save_state)
		_pending_save_state = {}

func toggle(player: Node3D = null) -> void:
	if is_moving or _bone < 0:
		return
	if is_locked:
		var inventory := player.get_node_or_null("InventoryHUD") as PlayerInventory if is_instance_valid(player) else null
		if inventory == null or not inventory.remove_one(required_key):
			interactable.single_line_dialogue = locked_dialogue
			return
		is_locked = false
	interactable.single_line_dialogue = ""
	var opening := not is_open
	var target := 0.0
	if opening:
		var direction := 1.0
		if open_away_from_player and is_instance_valid(player):
			direction = 1.0 if to_local(player.global_position).z >= 0.0 else -1.0
		target = deg_to_rad(open_angle_degrees) * direction
	is_moving = true
	_target_angle = target
	interactable.is_enabled = false
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_method(_set_angle, _angle, target, swing_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_motion.finished.connect(func() -> void:
		is_open = opening
		is_moving = false
		interactable.is_enabled = true
		if is_open:
			opened.emit()
		else:
			closed.emit()
	)

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
	interactable.is_enabled = true
	interactable.single_line_dialogue = ""
