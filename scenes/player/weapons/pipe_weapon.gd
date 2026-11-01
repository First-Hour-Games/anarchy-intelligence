extends Node3D
## Camera-held defensive pipe. A swing interrupts and pushes back the first body hit.

signal swung
signal hit_landed(target: Node3D)

const STAMINA_COST_FRACTION := 0.25

@export_range(0.5, 3.0, 0.1) var reach: float = 1.8
@export_range(0.1, 3.0, 0.05) var swing_cooldown: float = 0.8
@export_range(0.1, 3.0, 0.1) var stagger_duration: float = 1.0
@export_range(0.0, 6.0, 0.1) var knockback_speed: float = 2.5
@export var held_position := Vector3(0.28, -0.3, -0.5)
@export var held_rotation_degrees := Vector3(-18, -12, -20)

var equipped := false
var _player: FirstPersonPlayer
var _camera: Camera3D
var _had_pipe := false
var _cooldown := 0.0
var _swing_time := -1.0
var _hit_applied := false
var _phase := 0.0
@onready var model_pivot: Node3D = $ModelPivot

func _ready() -> void:
	_camera = get_parent() as Camera3D
	_player = get_node("../../..") as FirstPersonPlayer
	_bind_inventory.call_deferred()
	for geometry in model_pivot.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = 2
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

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
	if not equipped:
		_swing_time = -1.0
	model_pivot.visible = equipped and not _player.is_frozen and not _camera.top_level

func can_swing() -> bool:
	var health := _player.get_node_or_null("CombatHealth")
	return equipped and _player.inventory.has_item(&"metal_pipe") and not _player.is_frozen \
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
	swung.emit()
	return true

func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if _player.is_frozen or _camera.top_level or not equipped:
		_swing_time = -1.0
	if _swing_time >= 0.0:
		_swing_time += delta
		if _swing_time >= 0.14 and _swing_time <= 0.32 and not _hit_applied:
			_strike()
		if _swing_time >= 0.55:
			_swing_time = -1.0

func _strike() -> void:
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
	if nearest.is_empty():
		return
	_hit_applied = true
	var target := nearest.collider as Node3D
	if target != null and target.has_method("take_melee_hit"):
		target.take_melee_hit(_player.global_position, stagger_duration, knockback_speed)
		hit_landed.emit(target)

func _process(delta: float) -> void:
	model_pivot.visible = equipped and not _player.is_frozen and not _camera.top_level and not _player.is_hidden()
	if not model_pivot.visible:
		return
	_phase += delta * (1.5 + Vector2(_player.velocity.x, _player.velocity.z).length())
	var swing := sin(clampf((_swing_time - 0.06) / 0.49, 0.0, 1.0) * PI) if _swing_time >= 0.0 else 0.0
	model_pivot.position = held_position + Vector3(-0.36 * swing, sin(_phase) * 0.006 + 0.08 * swing, -0.12 * swing)
	model_pivot.rotation_degrees = held_rotation_degrees + Vector3(-65, 35, 60) * swing
