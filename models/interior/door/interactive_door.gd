class_name InteractiveDoor
extends Node3D

signal opened(interactor: Node3D)

@export_category("Door Motion")
@export_range(1.0, 179.0, 1.0) var open_angle_degrees: float = 92.0
@export_range(0.05, 5.0, 0.05) var open_duration: float = 0.8
@export var hinge_on_left: bool = true
@export var open_away_from_interactor: bool = true
@export var can_close: bool = true

@export_category("Door Audio")
@export var opening_sound: AudioStream
@export_range(-40.0, 6.0, 0.5) var opening_sound_volume_db := 0.0
@export_range(1.0, 30.0, 0.5) var opening_sound_max_distance := 12.0

@export_category("Interaction")
@export_range(0.5, 10.0, 0.1) var interaction_distance: float = 2.2
@export_multiline var interaction_message: String = "Interacted with the tutorial door."

const DOOR_LEAF_NAME := "Wooden Door_007"

var is_open := false
var _is_animating := false
var _hinge: AnimatableBody3D
var _door_leaf: MeshInstance3D
var _door_collision: CollisionShape3D
var _interactable: Interactable3D
var _opening_audio: AudioStreamPlayer3D
var _closed_rotation_y := 0.0
var _open_rotation_y := 0.0
var _door_center_local := Vector3.ZERO
var _motion_tween: Tween


func _ready() -> void:
	_door_leaf = find_child(DOOR_LEAF_NAME, true, false) as MeshInstance3D
	if not is_instance_valid(_door_leaf) or _door_leaf.mesh == null:
		push_error("InteractiveDoor could not find the door leaf mesh: %s" % DOOR_LEAF_NAME)
		return

	var door_bounds := _get_mesh_bounds_in_door_space(_door_leaf)
	_door_center_local = door_bounds.get_center()
	_create_hinge(door_bounds)
	_create_door_collision(door_bounds)
	_create_opening_audio()
	_create_interactable()


func toggle(interactor: Node3D = null) -> void:
	if _is_animating or not is_instance_valid(_hinge):
		return

	if is_open:
		if not can_close:
			return
		_animate_to(_closed_rotation_y, false)
		return

	if not is_open:
		opened.emit(interactor)
	if is_instance_valid(_opening_audio):
		_opening_audio.play()
	if not can_close and is_instance_valid(_interactable):
		_interactable.remove_from_group(&"interactable")
	_open_rotation_y = _get_open_angle(interactor)
	_animate_to(_open_rotation_y, true)


func _create_hinge(door_bounds: AABB) -> void:
	_hinge = AnimatableBody3D.new()
	_hinge.name = "HingePivot"
	# Avoid basis decomposition drift when this door is instanced with non-uniform scale.
	# Transform changes still update the physics body, but no physics interpolation is applied.
	_hinge.sync_to_physics = false
	_hinge.collision_layer = 1
	_hinge.collision_mask = 1
	var hinge_x := door_bounds.end.x if not hinge_on_left else door_bounds.position.x
	_hinge.position = Vector3(hinge_x, _door_center_local.y, _door_center_local.z)
	add_child(_hinge)

	_door_leaf.reparent(_hinge, true)
	_closed_rotation_y = _hinge.rotation.y


func _create_door_collision(door_bounds: AABB) -> void:
	_door_collision = CollisionShape3D.new()
	_door_collision.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = door_bounds.size
	_door_collision.shape = box
	_door_collision.position = _door_center_local - _hinge.position
	_hinge.add_child(_door_collision)


func _create_opening_audio() -> void:
	if opening_sound == null:
		return

	_opening_audio = AudioStreamPlayer3D.new()
	_opening_audio.name = "OpeningSound"
	_opening_audio.stream = opening_sound
	_opening_audio.volume_db = opening_sound_volume_db
	_opening_audio.max_distance = opening_sound_max_distance
	_opening_audio.position = _door_center_local
	add_child(_opening_audio)


func _create_interactable() -> void:
	_interactable = Interactable3D.new()
	_interactable.name = "Interactable"
	_interactable.interaction_distance = interaction_distance
	_interactable.interaction_message = interaction_message
	_interactable.interacted.connect(_on_interacted)
	add_child(_interactable)
	_interactable.visual_target_path = _interactable.get_path_to(_door_leaf)


func _on_interacted(interactor: Node3D) -> void:
	toggle(interactor)


func _get_open_angle(interactor: Node3D) -> float:
	var direction := 1.0
	if open_away_from_interactor and is_instance_valid(interactor):
		var interactor_local := to_local(interactor.global_position)
		direction = 1.0 if interactor_local.z >= _door_center_local.z else -1.0
	elif not hinge_on_left:
		direction = -1.0
	return _closed_rotation_y + deg_to_rad(open_angle_degrees) * direction


func _animate_to(target_rotation_y: float, opening: bool) -> void:
	if _motion_tween and _motion_tween.is_valid():
		_motion_tween.kill()
	if not opening and is_instance_valid(_door_collision):
		_door_collision.set_deferred("disabled", false)

	_is_animating = true
	_motion_tween = create_tween()
	_motion_tween.set_trans(Tween.TRANS_SINE)
	_motion_tween.set_ease(Tween.EASE_IN_OUT)
	_motion_tween.tween_property(_hinge, "rotation:y", target_rotation_y, open_duration)
	_motion_tween.finished.connect(func() -> void:
		is_open = opening
		_is_animating = false
		if is_instance_valid(_door_collision):
			_door_collision.set_deferred("disabled", opening)
	)


func _get_mesh_bounds_in_door_space(mesh_instance: MeshInstance3D) -> AABB:
	var mesh_transform := global_transform.affine_inverse() * mesh_instance.global_transform
	var mesh_aabb := mesh_instance.get_aabb()
	var has_point := false
	var bounds_min := Vector3.ZERO
	var bounds_max := Vector3.ZERO

	for x_index in 2:
		for y_index in 2:
			for z_index in 2:
				var corner := mesh_aabb.position + Vector3(
					mesh_aabb.size.x * x_index,
					mesh_aabb.size.y * y_index,
					mesh_aabb.size.z * z_index
				)
				var point := mesh_transform * corner
				if not has_point:
					bounds_min = point
					bounds_max = point
					has_point = true
				else:
					bounds_min = bounds_min.min(point)
					bounds_max = bounds_max.max(point)

	return AABB(bounds_min, bounds_max - bounds_min)
