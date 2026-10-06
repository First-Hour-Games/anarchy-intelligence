class_name GasStationEncounter
extends Node3D

## Death-scare framing with a surviving resolution; this never invokes the death UI.
signal phase_changed(phase_name: String)
signal finished

enum Phase { HIDDEN, RAISING, REVEAL, ATTACK, FLARE, RETREAT, OUTRO, END_CARD, COMPLETE }
const PICKUP := preload("res://scenes/items/counter_flashlight.tscn")

@export_category("Timing")
@export_range(0.1, 2.0, 0.05) var raise_seconds: float = 0.25
@export_range(0.05, 1.0, 0.01) var reveal_seconds: float = 0.12
@export_range(0.2, 2.0, 0.05) var attack_seconds: float = 1.28
@export_range(0.1, 1.0, 0.01) var flare_seconds: float = 0.16
@export_range(0.2, 2.0, 0.05) var retreat_seconds: float = 0.35
@export_category("Presentation")
@export_range(45.0, 85.0, 1.0) var closeup_fov: float = 62.0
@export_range(0.6, 1.5, 0.05) var closeup_distance: float = 0.85
@export_range(0.05, 2.0, 0.05) var closeup_beam_energy: float = 0.2
@export_range(0.0, 0.4, 0.01) var closeup_spill_energy: float = 0.03
@export var flare_energy: float = 22.0
@export var camera_flinch_degrees: float = 5.0
@export_category("Game Preview")
@export var trailer_enabled: bool = true

@onready var ridgeback: CorruptedFriend = $Ridgeback
@onready var hidden_mark: Marker3D = $HiddenPosition
@onready var reveal_mark: Marker3D = $RevealPosition
@onready var attack_mark: Marker3D = $AttackPosition
@onready var preview_mark: Marker3D = $PreviewPosition
@onready var roar: AudioStreamPlayer3D = $Roar
@onready var outro: GasStationTrailerOutro = $TrailerOutro

var phase: Phase = Phase.HIDDEN
var elapsed: float = 0.0
var player: FirstPersonPlayer
var _pickup: FlashlightPickup
var _pickup_pose: Transform3D
var _camera_pose: Transform3D
var _recovery_pose: Transform3D
var _camera_fov: float
var _camera_near: float
var _close_position: Vector3
var _beam_energy: float
var _spill_energy: float
var _animation_speed: float = 1.0
var _model_was_visible: bool
var _player_was_frozen: bool = false
var _owns_camera: bool = false
var _suspended_mobs: Dictionary = {}
var _hidden_layers: Array[CanvasLayer] = []
var _head_skeleton: Skeleton3D
var _head_bone: int = -1
var _flash_layer: CanvasLayer
var _flash: ColorRect

func _ready() -> void:
	add_to_group("gas_station_encounter")
	player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	_pickup = get_parent().get_node("Details/CounterFlashlight") as FlashlightPickup
	_pickup_pose = _pickup.transform
	_pickup.interacted.connect(begin)
	# Animate the real rig while this controller owns staging and input.
	ridgeback.set_physics_process(false)
	ridgeback.activation_enabled = false
	ridgeback.damage_enabled = false
	ridgeback.remove_from_group("corrupted_friend")
	(ridgeback.get_node("CollisionShape3D") as CollisionShape3D).disabled = true
	for node: Node in ridgeback.visual.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for bone in skeleton.get_bone_count():
			if "head" in skeleton.get_bone_name(bone).to_lower():
				_head_skeleton = skeleton
				_head_bone = bone
				break
		if _head_bone >= 0:
			break
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 111
	add_child(_flash_layer)
	_flash = ColorRect.new()
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1.0, 0.97, 0.88, 0.0)
	_flash_layer.add_child(_flash)
	_flash_layer.hide()
	_reset_actor()
	_check_owned_flashlight.call_deferred()

func _check_owned_flashlight() -> void:
	if phase == Phase.HIDDEN and is_instance_valid(player) and player.has_item(PlayerInventory.FLASHLIGHT_ITEM):
		phase = Phase.COMPLETE
		ridgeback.hide()
		if is_instance_valid(_pickup):
			_pickup.queue_free()

func begin(interactor: Node3D) -> void:
	if phase != Phase.HIDDEN or not interactor is FirstPersonPlayer:
		return
	player = interactor as FirstPersonPlayer
	_player_was_frozen = player.is_frozen
	_camera_pose = player.camera.transform
	_camera_fov = player.camera.fov
	_camera_near = player.camera.near
	_beam_energy = player.flashlight.beam.light_energy
	_spill_energy = player.flashlight.spill.light_energy
	_animation_speed = ridgeback.visual.animation_player.speed_scale
	_owns_camera = true
	player.freeze()
	player.flashlight.set_enabled(true)
	_model_was_visible = player.flashlight.model_pivot.visible
	for mob: Node in get_tree().get_nodes_in_group("corrupted_friend"):
		_suspended_mobs[mob] = mob.is_physics_processing()
		mob.set_physics_process(false)
	roar.volume_db = -8.0
	_set_phase(Phase.RAISING)

func _process(delta: float) -> void:
	if phase in [Phase.HIDDEN, Phase.END_CARD, Phase.COMPLETE]:
		return
	if not is_instance_valid(player):
		skip_encounter()
		return
	if phase == Phase.OUTRO:
		outro.advance(delta)
		if outro.flight_finished:
			_set_phase(Phase.END_CARD)
		return
	elapsed += delta
	var weight := clampf(elapsed / _duration(), 0.0, 1.0)
	match phase:
		Phase.RAISING:
			_aim_camera(weight)
		Phase.REVEAL:
			_close_view()
		Phase.ATTACK:
			ridgeback.position = reveal_mark.position.lerp(attack_mark.position, smoothstep(0.15, 0.5, weight))
			_close_view(sin(weight * PI) * camera_flinch_degrees)
		Phase.FLARE:
			player.flashlight.beam.light_energy = lerpf(flare_energy, _beam_energy, weight)
			_flash.color.a = 0.72 + sin(weight * PI) * 0.18
			_close_view(-sin(weight * PI) * camera_flinch_degrees * 0.5)
		Phase.RETREAT:
			if trailer_enabled:
				# Finish the source scream, then cut through black to the aerial shot.
				_flash.color = Color(1.0, 0.97, 0.88).lerp(Color.BLACK, weight)
				_flash.color.a = lerpf(0.72, 1.0, weight)
			else:
				player.camera.transform = _recovery_pose.interpolate_with(_camera_pose, smoothstep(0.0, 1.0, weight))
				player.camera.fov = lerpf(closeup_fov, _camera_fov, weight)
				_flash.color.a = 0.72 * (1.0 - weight)
				roar.volume_db = lerpf(-8.0, -40.0, weight)
	if elapsed >= _duration():
		if phase == Phase.RETREAT and not trailer_enabled:
			_set_phase(Phase.COMPLETE)
		else:
			_set_phase((int(phase) + 1) as Phase)

func _duration() -> float:
	match phase:
		Phase.RAISING: return raise_seconds
		Phase.REVEAL: return reveal_seconds
		Phase.ATTACK: return attack_seconds
		Phase.FLARE: return flare_seconds
		Phase.RETREAT:
			return maxf(0.01, roar.stream.get_length() - attack_seconds - flare_seconds) if trailer_enabled else retreat_seconds
	return 1.0

func _set_phase(next_phase: Phase) -> void:
	phase = next_phase
	elapsed = 0.0
	match phase:
		Phase.REVEAL:
			ridgeback.position = reveal_mark.position
			ridgeback.show()
			_face_player()
			var direction := player.camera.global_position - ridgeback.global_position
			direction.y = 0.0
			if direction.length_squared() < 0.01:
				direction = -player.global_basis.z
			_close_position = _head_position() + direction.normalized() * closeup_distance + Vector3.UP * 0.02
			player.camera.near = 0.03
			player.camera.fov = closeup_fov
			# A beam tuned for distant trees washes out a face less than a metre away.
			player.flashlight.beam.light_energy = closeup_beam_energy
			player.flashlight.spill.light_energy = closeup_spill_energy
			player.flashlight.model_pivot.hide()
			for node: Node in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
				var canvas := node as CanvasLayer
				if canvas != _flash_layer and canvas.visible:
					_hidden_layers.append(canvas)
					canvas.hide()
			_close_view()
		Phase.ATTACK:
			ridgeback.visual.play("attack", true)
			# Stretch the previous attack presentation by half a second, keeping its poses.
			ridgeback.visual.animation_player.speed_scale = 0.78 / attack_seconds
			roar.play()
		Phase.FLARE:
			player.flashlight.beam.light_energy = flare_energy
			_flash.color.a = 0.72
			_flash_layer.show()
		Phase.RETREAT:
			_recovery_pose = player.camera.transform
			ridgeback.hide()
			ridgeback.position = hidden_mark.position
		Phase.OUTRO:
			roar.stop()
			_flash_layer.hide()
			outro.begin()
		Phase.END_CARD:
			# Hold the preview's final logo until a developer resets or skips it.
			finished.emit()
		Phase.COMPLETE:
			ridgeback.hide()
			roar.stop()
			_restore_control()
			finished.emit()
	phase_changed.emit(Phase.keys()[phase])

func _head_position() -> Vector3:
	if is_instance_valid(_head_skeleton) and _head_bone >= 0:
		return _head_skeleton.global_transform * _head_skeleton.get_bone_global_pose(_head_bone).origin
	return ridgeback.global_position + Vector3.UP * 1.65

func _close_view(flinch: float = 0.0) -> void:
	# Use the player's existing camera so its fog and post-processing follow the shot.
	var face := _head_position()
	var camera := player.camera
	var position := _close_position
	position.y = face.y + 0.02
	camera.global_position = position
	camera.look_at(face)
	camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(flinch))

func _aim_camera(weight: float) -> void:
	var camera := player.camera
	var target := reveal_mark.global_position + Vector3.UP * 1.65
	var world_basis := Basis.looking_at(target - camera.global_position)
	var parent_basis := (camera.get_parent() as Node3D).global_basis
	camera.basis = _camera_pose.basis.slerp(parent_basis.inverse() * world_basis, weight)

func _face_player() -> void:
	var toward := player.global_position - ridgeback.global_position
	toward.y = 0.0
	ridgeback.global_rotation.y = atan2(-toward.x, -toward.z)

func _restore_control() -> void:
	if is_instance_valid(outro):
		outro.stop()
	if _owns_camera and is_instance_valid(player):
		player.camera.transform = _camera_pose
		player.camera.fov = _camera_fov
		player.camera.near = _camera_near
		player.flashlight.beam.light_energy = _beam_energy
		player.flashlight.spill.light_energy = _spill_energy
		player.flashlight.model_pivot.visible = _model_was_visible
		ridgeback.visual.animation_player.speed_scale = _animation_speed
		if not _player_was_frozen:
			player.unfreeze()
	_owns_camera = false
	for canvas: CanvasLayer in _hidden_layers:
		if is_instance_valid(canvas):
			canvas.show()
	_hidden_layers.clear()
	if is_instance_valid(_flash_layer):
		_flash_layer.hide()
	for mob: Node in _suspended_mobs:
		if is_instance_valid(mob):
			mob.set_physics_process(bool(_suspended_mobs[mob]))
	_suspended_mobs.clear()

func _reset_actor() -> void:
	ridgeback.position = hidden_mark.position
	ridgeback.rotation.y = PI
	# This staged apparition becomes visible only after the pickup, without an enclosure.
	ridgeback.hide()
	ridgeback.visual.play("dormant", true)

## Reset the local pickup/scare without resetting broader story progress.
func reset_encounter() -> void:
	_restore_control()
	roar.stop()
	phase = Phase.HIDDEN
	elapsed = 0.0
	_reset_actor()
	if is_instance_valid(player):
		player.flashlight.set_enabled(false)
		player.inventory.remove_item(PlayerInventory.FLASHLIGHT_ITEM)
	if not is_instance_valid(_pickup) or _pickup.is_queued_for_deletion():
		if is_instance_valid(_pickup):
			_pickup.get_parent().remove_child(_pickup)
		_pickup = PICKUP.instantiate() as FlashlightPickup
		_pickup.name = "CounterFlashlight"
		get_parent().get_node("Details").add_child(_pickup)
		_pickup.transform = _pickup_pose
		_pickup.interacted.connect(begin)
	phase_changed.emit("HIDDEN")

func preview_encounter() -> void:
	if not is_instance_valid(player):
		return
	var scene := get_tree().current_scene
	if scene is StartingForest:
		scene.finish_fade_immediately()
		if is_instance_valid(scene.opening_balloon):
			scene.opening_balloon._end_dialogue()
	reset_encounter()
	player.global_position = preview_mark.global_position
	player.velocity = Vector3.ZERO
	player.camera.look_at(reveal_mark.global_position + Vector3.UP * 1.4)
	player.unfreeze()
	_pickup.interact(player)

func skip_encounter() -> void:
	if is_instance_valid(player):
		player.inventory.add_item(PlayerInventory.FLASHLIGHT_ITEM)
		player.flashlight.set_enabled(true)
	if is_instance_valid(_pickup):
		_pickup.queue_free()
	_set_phase(Phase.COMPLETE)

func _exit_tree() -> void:
	_restore_control()
