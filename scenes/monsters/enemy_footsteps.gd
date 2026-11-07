extends AudioStreamPlayer3D
## Distance-driven steps: blocked movement, falling and teleports never add steps.

const SURFACES = preload("res://scenes/player/footstep_surfaces.gd")
@export_range(0.2, 2.0, 0.05) var step_distance := 0.85

var _previous_position := Vector3.ZERO
var _distance := 0.0
var _last_sound: AudioStream
@onready var actor := get_parent() as CharacterBody3D

func _ready() -> void:
	process_physics_priority = 10
	volume_db = -12.0
	max_db = -10.0
	unit_size = 4.0
	max_distance = 22.0
	bus = &"Outside"
	_previous_position = actor.global_position

func _physics_process(delta: float) -> void:
	var motion := actor.global_position - _previous_position
	_previous_position = actor.global_position
	var distance := Vector2(motion.x, motion.z).length()
	var shape := actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not actor.is_visible_in_tree() or (shape != null and shape.disabled):
		_distance = 0.0
		stop()
		return
	if delta <= 0.0 or not actor.is_physics_processing() or not actor.is_on_floor() \
			or distance < delta * 0.08 or distance > maxf(0.5, delta * 8.0):
		_distance = 0.0
		return
	_distance += distance
	if _distance >= step_distance:
		_distance = fmod(_distance, step_distance)
		_play_step(distance / delta)

func _play_step(speed: float) -> void:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.3,
		actor.global_position + Vector3.DOWN * 1.0, actor.collision_mask, [actor.get_rid()])
	var hit := actor.get_world_3d().direct_space_state.intersect_ray(query)
	var surface := SURFACES.classify(hit.get("collider") as Node)
	if surface in [&"asphalt", &"stone"]:
		surface = &"concrete"
	elif surface == &"road":
		surface = &"gravel"
	var sounds: Array = SURFACES.BANKS.get(surface, SURFACES.BANKS[&"dirt"]).duplicate()
	if sounds.size() > 1:
		sounds.erase(_last_sound)
	stream = sounds.pick_random()
	_last_sound = stream
	# Lower the timbre gently; cadence follows distance rather than stretching every sample to a full stride.
	pitch_scale = clampf(0.72 + speed * 0.1, 0.75, 1.1)
	play()
