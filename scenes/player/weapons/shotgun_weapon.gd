extends Node3D
## Camera-held double-barrelled shotgun of the alt route. Each barrel fires once, the right one first; a
## shot sprays pellets from the middle of the view, and each target takes the summed damage of the
## pellets that reach it, through take_shot(damage, from) if it has one, else take_damage(damage). The
## reload clip breaks the gun open, loads both barrels from the spare shells and snaps it shut; it cannot
## fire while open. Each shot booms with one of a few blasts; the reload clicks, clatters and snaps where
## its clip says, and an empty gun clicks. Its crosshair (shotgun_crosshair.gd) rings the spread, kicks
## with each shot, dims while it cannot fire and marks the hits.

signal fired
signal shot_landed(target: Node, damage: float)

const ITEM := &"shotgun"
## First-person clips built for these arms by tools/blender/build_shotgun_clips.py. Its "mount" metadata
## is where the gun sits under the right hand; the fire clip's "shot" metadata is when it goes off, the
## reload clip's "loaded" when the shells are in.
const CLIPS: AnimationLibrary = preload("res://models/player/shotgun_clips.tres")
const CLIP_LIBRARY := &"shotgun"
const IDLE := &"shotgun/shotgun_idle"
const FIRE := &"shotgun/shotgun_fire"
const RELOAD := &"shotgun/shotgun_reload"
const GUN: PackedScene = preload("res://models/props/weapons/shotgun/shotgun.glb")
## The two shells the left hand carries to the breech while reloading.
const CARRIED_SHELLS: PackedScene = preload("res://models/props/weapons/shotgun/shell_pair.glb")
## The gun's action sounds (cut by tools/prepare_shotgun_audio.gd), by the names the reload clip's "sounds"
## metadata gives the moments they belong to; and where each peaks, in seconds into its file, so that it
## starts early enough for its click to land on that moment.
const ACTION_SOUNDS := {
	"break_open": preload("res://sounds/weapons/shotgun/shotgun_break_open.wav"),
	"shells_out": preload("res://sounds/weapons/shotgun/shotgun_shells_out.wav"),
	"shells_in": preload("res://sounds/weapons/shotgun/shotgun_shells_in.wav"),
	"snap_shut": preload("res://sounds/weapons/shotgun/shotgun_snap_shut.wav"),
}
const ACTION_SOUND_PEAKS := {"break_open": 0.039, "shells_out": 0.044, "shells_in": 0.164, "snap_shut": 0.065}
## The hammers falling on empty chambers.
const DRY_FIRE_SOUND: AudioStream = preload("res://sounds/weapons/shotgun/shotgun_dry_fire.wav")
const BARRELS := 2
const EQUIP_DURATION := 0.35
const HOLSTER_DURATION := 0.28
const LOWERED_OFFSET := Vector3(0.0, -1.25, 0.0)
const DRY_FIRE_SECONDS := 0.3
const FLASH_SECONDS := 0.06
## How much of the view's kick drifts back after a shot, and over how long.
const KICK_RETURN := 0.7
const KICK_RETURN_SECONDS := 0.25

@export_range(1, 16, 1) var pellets: int = 9
@export_range(0.5, 12.0, 0.5) var spread_degrees: float = 5.0
@export_range(5.0, 80.0, 1.0) var shot_range: float = 40.0
@export_range(1.0, 60.0, 1.0) var pellet_damage: float = 14.0
## Pellets do full damage out to this many metres, then less with distance.
@export_range(1.0, 40.0, 1.0) var falloff_start: float = 6.0
## The share of a pellet's damage left at the end of its range.
@export_range(0.0, 1.0, 0.05) var falloff_floor: float = 0.25
## Seconds after one barrel before the other can fire.
@export_range(0.1, 1.0, 0.05) var barrel_interval: float = 0.3
## Spare shells that come with the gun when it is picked up.
@export_range(0, 40, 1) var starting_reserve: int = 6
@export_range(0.0, 8.0, 0.1) var camera_kick_degrees: float = 3.5

var equipped := false
## Shells in the barrels, and spare shells carried.
var loaded := 0
var reserve := 0
var reloading := false
## View pitch still to drift back from recent shots, radians.
var _kick := 0.0
var _player: FirstPersonPlayer
var _camera: Camera3D
var _had_gun := false
var _busy := 0.0
var _shells_in_at := -1.0
## The reload's sounds still to come, soonest first: when each starts (seconds into the clip) and its name.
var _sound_cues: Array = []
var _presentation := 0.0
var _flash := 0.0
var _flash_muzzle: Node3D
var _gun: Node3D
var _muzzles: Array[Node3D] = []
var _chamber_shells: Node3D
var _chamber_seated: Vector3
var _hand_shells: Node3D
var _rng := RandomNumberGenerator.new()
@onready var model_pivot: Node3D = $ModelPivot
@onready var _held_position: Vector3 = model_pivot.position
@onready var arms_animation: AnimationPlayer = $ModelPivot/Arms/AnimationPlayer
@onready var shot_audio: AudioStreamPlayer = $ShotAudio
@onready var action_audio: AudioStreamPlayer = $ActionAudio
@onready var muzzle_light: OmniLight3D = $MuzzleLight
@onready var muzzle_flash: MeshInstance3D = $MuzzleFlash
@onready var shells_label: Label = $Hud/Frame/Content/Shells
@onready var crosshair: ShotgunCrosshair = $Hud/Crosshair

func _ready() -> void:
	_camera = get_parent() as Camera3D
	_player = get_node("../../..") as FirstPersonPlayer
	crosshair.camera = _camera
	crosshair.spread_degrees = spread_degrees
	add_to_group(&"held_weapons")
	_setup_arms()
	_bind_inventory.call_deferred()
	for geometry in model_pivot.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = 2
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_refresh_hud()

func _setup_arms() -> void:
	arms_animation.add_animation_library(CLIP_LIBRARY, CLIPS)
	var hand := $ModelPivot/Arms/FPS_Arms/Skeleton3D/Hand_R as BoneAttachment3D
	# These arms carry the shotgun, not the pipe the model was made with.
	var pipe := hand.get_node_or_null("MetalPipe_Hand_R")
	if pipe != null:
		pipe.free()
	_gun = GUN.instantiate() as Node3D
	_gun.name = "ShotgunModel"
	hand.add_child(_gun)
	_gun.transform = CLIPS.get_meta(&"mount")
	# The right barrel fires first, then the left.
	for marker: String in ["MuzzleRight", "MuzzleLeft"]:
		_muzzles.append(_gun.find_child(marker, true, false) as Node3D)
	_chamber_shells = _gun.find_child("ChamberShells", true, false) as Node3D
	_chamber_seated = _chamber_shells.position
	# The left hand needs somewhere to hold the shells it loads.
	var left_hand := BoneAttachment3D.new()
	left_hand.name = "Hand_L"
	left_hand.bone_name = "Hand.L"
	hand.get_parent().add_child(left_hand)
	_hand_shells = CARRIED_SHELLS.instantiate() as Node3D
	_hand_shells.name = "HandShells"
	left_hand.add_child(_hand_shells)
	_hand_shells.transform = CLIPS.get_meta(&"hand_shells_mount")
	_rest_shells()
	arms_animation.play(IDLE)
	arms_animation.advance(0.0)

## The shells as they are between reloads: seated in the chambers, none in the left hand.
func _rest_shells() -> void:
	_chamber_shells.position = _chamber_seated
	_chamber_shells.visible = true
	_hand_shells.visible = false

func _bind_inventory() -> void:
	_player.inventory.inventory_changed.connect(_inventory_changed)
	_inventory_changed()

func _inventory_changed() -> void:
	var has_gun := _player.inventory.has_item(ITEM)
	if has_gun and not _had_gun:
		# A newly found gun comes loaded, with a few spare shells.
		loaded = BARRELS
		reserve += starting_reserve
	if has_gun != _had_gun:
		_had_gun = has_gun
		set_equipped(has_gun)

func set_equipped(value: bool) -> void:
	_had_gun = is_instance_valid(_player) and _player.inventory.has_item(ITEM)
	equipped = value and _had_gun
	if equipped and is_inside_tree():
		# One weapon in hand at a time: taking up the shotgun puts any other away.
		for weapon in get_tree().get_nodes_in_group(&"held_weapons"):
			if weapon != self and bool(weapon.get("equipped")):
				weapon.set_equipped(false)
	elif not equipped:
		_cancel_reload()
	_refresh_hud()

## Adds spare shells, as from a box found on the way.
func add_shells(count: int) -> void:
	reserve += maxi(count, 0)
	_refresh_hud()

## Puts back the shells a saved game had: in the barrels and spare.
func restore_shells(in_barrels: int, spare: int) -> void:
	loaded = clampi(in_barrels, 0, BARRELS)
	reserve = maxi(spare, 0)
	_refresh_hud()

## Every shell it has, in the barrels and spare.
func shells_left() -> int:
	return loaded + reserve

func can_act() -> bool:
	var health := _player.get_node_or_null("CombatHealth")
	return equipped and _presentation >= 1.0 and _player.inventory.has_item(ITEM) and not _player.is_frozen \
		and not get_tree().paused and not _camera.top_level and not _player.is_hidden() \
		and not _player.inventory.is_open and (health == null or not bool(health.get("is_dead")))

func can_fire() -> bool:
	return can_act() and loaded > 0 and _busy <= 0.0 and not reloading

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"weapon_attack") and (try_fire() or _dry_fire()):
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"weapon_reload") and try_reload():
		get_viewport().set_input_as_handled()

func try_fire() -> bool:
	if not can_fire():
		return false
	_flash_muzzle = _muzzles[BARRELS - loaded]
	loaded -= 1
	_busy = barrel_interval
	arms_animation.play(FIRE, 0.03)
	arms_animation.seek(0.0, true)
	_shoot_pellets()
	crosshair.kick()
	_flash = FLASH_SECONDS
	# The view kicks up with the shot and drifts most of the way back.
	_player.head.rotation.x += deg_to_rad(camera_kick_degrees)
	_kick += deg_to_rad(camera_kick_degrees) * KICK_RETURN
	if shot_audio.stream != null:
		shot_audio.play()
	fired.emit()
	_refresh_hud()
	return true

func _dry_fire() -> bool:
	if not can_act() or loaded > 0 or _busy > 0.0 or reloading:
		return false
	_busy = DRY_FIRE_SECONDS
	_play_action_sound(DRY_FIRE_SOUND)
	return true

## Breaks the gun open and loads both barrels, as far as the spare shells go.
func try_reload() -> bool:
	if not can_act() or reloading or _busy > 0.0 or loaded >= BARRELS or reserve <= 0:
		return false
	reloading = true
	var clip := arms_animation.get_animation(RELOAD)
	_busy = clip.length
	_shells_in_at = float(clip.get_meta(&"loaded"))
	_sound_cues.clear()
	var sounds: Dictionary = clip.get_meta(&"sounds", {})
	for sound_name: String in sounds:
		if ACTION_SOUNDS.has(sound_name):
			_sound_cues.append([float(sounds[sound_name]) - float(ACTION_SOUND_PEAKS[sound_name]), sound_name])
	_sound_cues.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	arms_animation.play(RELOAD, 0.05)
	arms_animation.seek(0.0, true)
	return true

func _cancel_reload() -> void:
	reloading = false
	_shells_in_at = -1.0
	_sound_cues.clear()
	if is_instance_valid(_hand_shells):
		_rest_shells()
	if action_audio != null:
		action_audio.stop()

func _play_action_sound(stream: AudioStream) -> void:
	action_audio.stream = stream
	action_audio.play()

func _shoot_pellets() -> void:
	var space := _player.get_world_3d().direct_space_state
	var origin := _camera.global_position
	var basis := _camera.global_basis
	var damage_by_target: Dictionary = {}
	for pellet in pellets:
		# Spread evenly over a disc, so the pattern is dense in the middle and thins out.
		var radius := tan(deg_to_rad(spread_degrees)) * sqrt(_rng.randf())
		var angle := _rng.randf() * TAU
		var direction := (-basis.z + basis.x * radius * cos(angle) + basis.y * radius * sin(angle)).normalized()
		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * shot_range)
		query.exclude = [_player.get_rid()]
		query.collide_with_areas = true
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var receiver := _damage_receiver(hit.collider as Node)
		if receiver == null:
			continue
		var distance := origin.distance_to(hit.position)
		var share := 1.0 if distance <= falloff_start else lerpf(1.0, falloff_floor, (distance - falloff_start) / maxf(shot_range - falloff_start, 0.01))
		damage_by_target[receiver] = float(damage_by_target.get(receiver, 0.0)) + pellet_damage * share
	for receiver: Node in damage_by_target:
		var damage: float = damage_by_target[receiver]
		if receiver.has_method("take_shot"):
			receiver.take_shot(damage, origin)
		else:
			receiver.take_damage(damage)
		crosshair.mark_hit(_finished(receiver))
		shot_landed.emit(receiver, damage)

## Whether a target the pellets reached is finished: dead, or broken like the gate's padlock.
static func _finished(target: Node) -> bool:
	for flag: String in ["dead", "is_dead", "is_broken"]:
		if target.get(flag) == true:
			return true
	var health: Variant = target.get("health")
	return health is float and float(health) <= 0.0

## The node a pellet hurts: the collider, or the nearest ancestor that can take damage.
func _damage_receiver(collider: Node) -> Node:
	var node := collider
	for level in 4:
		if node == null:
			return null
		if node.has_method("take_shot") or node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null

func _physics_process(delta: float) -> void:
	if reloading and (_player.is_frozen or _camera.top_level or not equipped):
		_cancel_reload()
	_busy = maxf(_busy - delta, 0.0)
	if reloading:
		var clip_length := arms_animation.get_animation(RELOAD).length
		while not _sound_cues.is_empty() and clip_length - _busy >= float(_sound_cues[0][0]):
			_play_action_sound(ACTION_SOUNDS[_sound_cues.pop_front()[1]])
		if _shells_in_at >= 0.0 and clip_length - _busy >= _shells_in_at:
			var shells := mini(BARRELS - loaded, reserve)
			loaded += shells
			reserve -= shells
			_shells_in_at = -1.0
			_refresh_hud()
		if _busy <= 0.0:
			reloading = false
			_rest_shells()

func _process(delta: float) -> void:
	var concealed := _player.is_frozen or _camera.top_level or _player.is_hidden()
	if concealed:
		_presentation = 0.0
	else:
		var duration := EQUIP_DURATION if equipped else HOLSTER_DURATION
		_presentation = move_toward(_presentation, 1.0 if equipped else 0.0, delta / duration)
	model_pivot.position = _held_position + LOWERED_OFFSET * (1.0 - smoothstep(0.0, 1.0, _presentation))
	model_pivot.visible = not concealed and _presentation > 0.0
	$Hud.visible = model_pivot.visible
	crosshair.ready_to_fire = loaded > 0 and not reloading
	var playing: StringName = arms_animation.current_animation
	var clip: StringName = playing if (playing == FIRE or playing == RELOAD) and arms_animation.is_playing() else IDLE
	if playing != clip:
		arms_animation.play(clip, 0.1)
	arms_animation.speed_scale = 1.0 if model_pivot.visible else 0.0
	if _kick > 0.0:
		var recover := minf(_kick, delta * deg_to_rad(camera_kick_degrees) / KICK_RETURN_SECONDS)
		_kick -= recover
		_player.head.rotation.x -= recover
	_flash = maxf(_flash - delta, 0.0)
	var flashing := _flash > 0.0 and model_pivot.visible and is_instance_valid(_flash_muzzle)
	muzzle_light.visible = flashing
	muzzle_flash.visible = flashing
	if flashing:
		muzzle_light.global_position = _flash_muzzle.global_position
		muzzle_flash.global_position = _flash_muzzle.global_position - _camera.global_basis.z * 0.05
		muzzle_flash.rotation.z = _rng.randf() * TAU

func _refresh_hud() -> void:
	if is_instance_valid(shells_label):
		shells_label.text = "SHELLS  %d  |  %d" % [loaded, reserve]
