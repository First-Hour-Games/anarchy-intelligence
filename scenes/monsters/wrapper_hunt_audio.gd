extends AudioStreamPlayer
## A proximity music layer for the active Wrapper, independent of camera direction.

@export_range(1.0, 50.0, 0.5) var start_distance: float = 16.0
@export_range(1.0, 60.0, 0.5) var stop_distance: float = 20.0
@export_range(0.0, 20.0, 0.5) var full_volume_distance: float = 5.0
@export_range(-40.0, 0.0, 0.5) var hunt_volume_db: float = -8.0
@export_range(0.05, 5.0, 0.05) var fade_in_seconds: float = 0.6
@export_range(0.05, 5.0, 0.05) var fade_out_seconds: float = 1.2

var _near := false
var _level := 0.0

func _ready() -> void:
	# Make looping local to this player rather than changing the imported resource.
	if stream is AudioStreamMP3:
		stream = stream.duplicate()
		(stream as AudioStreamMP3).loop = true
	volume_db = -80.0
	stop()

func _process(delta: float) -> void:
	var wrapper := get_parent() as CharacterBody3D
	var player: FirstPersonPlayer = wrapper.get("player") as FirstPersonPlayer
	var active := bool(wrapper.get("enabled")) and not bool(wrapper.get("suspended")) \
		and wrapper.is_visible_in_tree() and is_instance_valid(player) and not player.is_frozen
	var distance := wrapper.global_position.distance_to(player.global_position) if is_instance_valid(player) else INF
	var outer := maxf(stop_distance, start_distance + 0.5)
	if not active or distance >= outer:
		_near = false
	elif distance <= start_distance:
		_near = true
	var target := 0.0
	if _near:
		var intensity := clampf((outer - distance) / maxf(outer - full_volume_distance, 0.1), 0.0, 1.0)
		target = db_to_linear(hunt_volume_db) * intensity
		if not playing and stream != null:
			play()
	var duration := fade_in_seconds if target > _level else fade_out_seconds
	_level = move_toward(_level, target, db_to_linear(hunt_volume_db) * delta / maxf(duration, 0.05))
	volume_db = linear_to_db(_level) if _level > 0.0001 else -80.0
	if not _near and _level <= 0.0001 and playing:
		stop()
