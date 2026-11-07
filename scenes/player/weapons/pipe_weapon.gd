extends Node3D
## Camera-held defensive pipe. Every enemy hit stuns and pushes back the enemy.

signal swung
signal hit_landed(target: Node3D)

const STAMINA_COST_FRACTION := 0.25
## Two-handed swings built for these arms by tools/blender/build_pipe_swings.py. Each clip's "impact"
## metadata is when the pipe passes through the hit.
const SWINGS: AnimationLibrary = preload("res://models/player/pipe_swings.tres")
const SWING_LIBRARY := &"pipe_swings"
## How long either side of the impact a swing can land.
const HIT_WINDOW := 0.07
const EQUIP_DURATION := 0.3
const HOLSTER_DURATION := 0.24
const LOWERED_OFFSET := Vector3(0.0, -1.25, 0.0)
const SWING_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/weapons/metalPipe/metal_tube_whoosh_01.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_whoosh_02.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_whoosh_03.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_whoosh_04.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_whoosh_05.ogg"),
]
## Played instead of the whoosh when the pipe connects with an enemy.
const HIT_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/weapons/metalPipe/metal_tube_hit_with_whoosh_01.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_hit_with_whoosh_02.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_hit_with_whoosh_03.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_hit_with_whoosh_04.ogg"),
	preload("res://sounds/weapons/metalPipe/metal_tube_hit_with_whoosh_05.ogg"),
]
## Where each sound peaks, in seconds (measured from the files): the whoosh's rush, the hit's
## clang. A swing's sound starts so that this lands on the clip's impact.
const SWING_SOUND_PEAKS: Array[float] = [0.06, 0.07, 0.08, 0.11, 0.09]
const HIT_SOUND_PEAKS: Array[float] = [0.14, 0.11, 0.15, 0.16, 0.15]
## The swing decides whoosh or hit this long before its impact: longer than any sound's lead-in.
const SOUND_DECISION_LEAD := 0.18
## A hit sound still waiting on its target this close to the impact turns back into a whoosh.
const CLANG_CANCEL_LEAD := 0.03

@export_range(0.5, 3.0, 0.1) var reach: float = 1.8
@export_range(0.1, 3.0, 0.05) var swing_cooldown: float = 1.4
@export_range(0.0, 6.0, 0.1) var knockback_speed: float = 2.5
## The swing from models/player/pipe_swings.tres: swing_downswing, or swing_bat.
@export var swing_clip: StringName = &"swing_downswing"

var equipped := false
var _player: FirstPersonPlayer
var _camera: Camera3D
var _had_pipe := false
var _cooldown := 0.0
var _swing_time := -1.0
var _hit_applied := false
var _last_swing_sound := -1
var _last_hit_sound := -1
## This swing's sound: whether it has been chosen, whether it is a hit, and when it starts.
var _sound_chosen := false
var _sound_is_hit := false
var _sound_due := -1.0
var _enemy_hit := false
var _presentation := 0.0
var _swing_name: StringName
var _swing: Animation
var _pipe: MeshInstance3D
var _pipe_grip: Vector3
@onready var model_pivot: Node3D = $ModelPivot
@onready var _held_position: Vector3 = model_pivot.position
@onready var swing_audio: AudioStreamPlayer = $SwingAudio
@onready var idle_animation: AnimationPlayer = $ModelPivot/Arms/AnimationPlayer

func _ready() -> void:
	_camera = get_parent() as Camera3D
	_player = get_node("../../..") as FirstPersonPlayer
	add_to_group(&"held_weapons")
	_setup_hands()
	_bind_inventory.call_deferred()
	for geometry in model_pivot.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = 2
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _setup_hands() -> void:
	# The Blender-authored pipe is bone-parented in the GLB, including its grip offset.
	idle_animation.get_animation(&"Holding_Idle").loop_mode = Animation.LOOP_LINEAR
	idle_animation.add_animation_library(SWING_LIBRARY, SWINGS)
	_swing_name = StringName("%s/%s" % [SWING_LIBRARY, swing_clip])
	_swing = idle_animation.get_animation(_swing_name)
	idle_animation.play(&"Holding_Idle")
	idle_animation.advance(0.0)
	_pipe = $ModelPivot/Arms/FPS_Arms/Skeleton3D/Hand_R/MetalPipe_Hand_R
	_pipe.material_override = preload("res://models/props/weapons/pipe_metal_material.tres")
	_pipe_grip = _pipe.position

func _bind_inventory() -> void:
	_player.inventory.inventory_changed.connect(_inventory_changed)
	_inventory_changed()

func _inventory_changed() -> void:
	var has_pipe := _player.inventory.has_item(&"metal_pipe")
	if has_pipe != _had_pipe:
		_had_pipe = has_pipe
		set_equipped(has_pipe)

func set_equipped(value: bool) -> void:
	_had_pipe = is_instance_valid(_player) and _player.inventory.has_item(&"metal_pipe")
	equipped = value and is_instance_valid(_player) and _player.inventory.has_item(&"metal_pipe")
	if equipped and is_inside_tree():
		# One weapon in hand at a time: taking up the pipe puts any other away.
		for weapon in get_tree().get_nodes_in_group(&"held_weapons"):
			if weapon != self and bool(weapon.get("equipped")):
				weapon.set_equipped(false)
	else:
		_swing_time = -1.0

func can_swing() -> bool:
	var health := _player.get_node_or_null("CombatHealth")
	return equipped and _presentation >= 1.0 and _player.inventory.has_item(&"metal_pipe") and not _player.is_frozen \
		and not get_tree().paused and not _camera.top_level and not _player.is_hidden() \
		and not _player.inventory.is_open \
		and _player.stamina >= _player.max_stamina * STAMINA_COST_FRACTION \
		and (health == null or not bool(health.get("is_dead"))) and _cooldown <= 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"weapon_attack") and not event.is_echo() and try_swing():
		get_viewport().set_input_as_handled()

func try_swing() -> bool:
	if not can_swing():
		return false
	if not _player.try_spend_stamina(_player.max_stamina * STAMINA_COST_FRACTION):
		return false
	_cooldown = swing_cooldown
	_swing_time = 0.0
	_hit_applied = false
	_enemy_hit = false
	_sound_chosen = false
	_sound_due = -1.0
	if idle_animation.current_animation == _swing_name:
		idle_animation.seek(0.0, true)
	swung.emit()
	return true

func _impact() -> float:
	return float(_swing.get_meta(&"impact"))

## Picks this swing's sound just before the impact: a hit if an enemy is in reach, else a whoosh,
## and queues it so its peak lands on the impact.
func _choose_swing_sound() -> void:
	_sound_chosen = true
	var aimed := _aim()
	if not aimed.is_empty() and (aimed.collider as Object).has_method("take_melee_hit"):
		_queue_hit_sound()
	else:
		_queue_whoosh()

func _queue_whoosh() -> void:
	_sound_is_hit = false
	_last_swing_sound = _next_variant(_last_swing_sound, SWING_SOUNDS.size())
	swing_audio.stream = SWING_SOUNDS[_last_swing_sound]
	_sound_due = _impact() - SWING_SOUND_PEAKS[_last_swing_sound]

func _queue_hit_sound() -> void:
	_sound_is_hit = true
	_last_hit_sound = _next_variant(_last_hit_sound, HIT_SOUNDS.size())
	swing_audio.stream = HIT_SOUNDS[_last_hit_sound]
	_sound_due = _impact() - HIT_SOUND_PEAKS[_last_hit_sound]

## Starts the queued sound when it is due, or straight away part-way in if it is already late,
## so its peak still lands on the impact.
func _update_swing_sound() -> void:
	if _sound_due < 0.0 or _swing_time < _sound_due:
		return
	var into := _swing_time - _sound_due
	_sound_due = -1.0
	swing_audio.play(into if into > 0.02 else 0.0)

## An enemy stepped in after the sound was chosen: the clang takes over, timed to the impact.
func _switch_to_hit_sound() -> void:
	var due := _sound_due
	_queue_hit_sound()
	if due < 0.0:
		# The whoosh is already playing; the hit picks up where its clang will still land on time.
		_sound_due = minf(_sound_due, _swing_time)
	_update_swing_sound()

## A random variant, never the same one twice in a row.
func _next_variant(last: int, count: int) -> int:
	if last < 0:
		return randi_range(0, count - 1)
	return (last + randi_range(1, count - 1)) % count

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _player.is_frozen or _camera.top_level or not equipped:
		_swing_time = -1.0
	if _swing_time >= 0.0:
		_swing_time += delta
		if not _sound_chosen and _swing_time >= _impact() - SOUND_DECISION_LEAD:
			_choose_swing_sound()
		if absf(_swing_time - _impact()) <= HIT_WINDOW and not _hit_applied:
			_strike()
		# The enemy got away before the clang: it whooshes past instead.
		if _sound_is_hit and not _enemy_hit and _swing_time >= _impact() - CLANG_CANCEL_LEAD:
			var heard := swing_audio.get_playback_position() if swing_audio.playing else 0.0
			_queue_whoosh()
			_sound_due = -1.0
			swing_audio.play(minf(heard, SWING_SOUND_PEAKS[_last_swing_sound]))
		_update_swing_sound()
		if _swing_time >= _swing.length:
			_swing_time = -1.0

## The first thing the swing would hit, as a ray result, or empty.
func _aim() -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for offset: Vector2 in [Vector2.ZERO, Vector2(-0.12, 0), Vector2(0.12, 0), Vector2(0, -0.12), Vector2(0, 0.12)]:
		var origin := _camera.global_position
		var end := origin - _camera.global_basis.z * reach + _camera.global_basis.x * offset.x + _camera.global_basis.y * offset.y
		var query := PhysicsRayQueryParameters3D.create(origin, end)
		query.exclude = [_player.get_rid()]
		var result := _player.get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty() and origin.distance_to(result.position) < nearest_distance:
			nearest = result
			nearest_distance = origin.distance_to(result.position)
	return nearest

func _strike() -> void:
	var nearest := _aim()
	if nearest.is_empty():
		return
	_hit_applied = true
	var target := nearest.collider as Node3D
	if target != null and target.has_method("take_melee_hit"):
		target.take_melee_hit(_player.global_position, randf_range(1.5, 2.5), knockback_speed)
		_enemy_hit = true
		if not _sound_is_hit:
			_switch_to_hit_sound()
		hit_landed.emit(target)

func _process(delta: float) -> void:
	var concealed := _player.is_frozen or _camera.top_level or _player.is_hidden()
	if concealed:
		_presentation = 0.0
	else:
		var duration := EQUIP_DURATION if equipped else HOLSTER_DURATION
		_presentation = move_toward(_presentation, 1.0 if equipped else 0.0, delta / duration)
	model_pivot.position = _held_position + LOWERED_OFFSET * (1.0 - smoothstep(0.0, 1.0, _presentation))
	model_pivot.visible = not concealed and _presentation > 0.0
	# Attack motion belongs to the skeleton; the camera-mounted rig never swings.
	var clip: StringName = _swing_name if _swing_time >= 0.0 else &"Holding_Idle"
	if idle_animation.current_animation != clip:
		idle_animation.play(clip, 0.05)
	idle_animation.speed_scale = 1.0 if model_pivot.visible else 0.0
	if _swing_time < 0.0:
		# Only a swing slides the pipe through the hands; one cut short must not leave it slid.
		_pipe.position = _pipe_grip
