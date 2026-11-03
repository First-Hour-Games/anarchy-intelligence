extends AudioStreamPlayer3D
## A positional loop emitted by the floating gem when the player is nearby.

@export_range(1.0, 40.0, 0.5) var start_distance: float = 12.0
@export_range(1.0, 50.0, 0.5) var stop_distance: float = 14.0
@export_range(-40.0, 0.0, 0.5) var song_volume_db: float = -8.0
@export_range(0.05, 5.0, 0.05) var fade_in_seconds: float = 0.8
@export_range(0.05, 5.0, 0.05) var fade_out_seconds: float = 1.2

var _player: FirstPersonPlayer
var _near := false
var _level := 0.0

func _ready() -> void:
	add_to_group("save_gem_proximity_music")
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		(stream as AudioStreamOggVorbis).loop = true
	volume_db = -80.0
	stop()

func _process(delta: float) -> void:
	if get_tree().has_group("save_slot_screen"):
		stop_for_save_screen()
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	var distance := global_position.distance_to(_player.global_position) if is_instance_valid(_player) else INF
	var outer := maxf(stop_distance, start_distance + 0.5)
	max_distance = outer
	if not is_visible_in_tree() or distance >= outer:
		_near = false
	elif distance <= start_distance:
		_near = true
	var target := db_to_linear(song_volume_db) if _near else 0.0
	if _near and not playing and stream != null:
		play()
	var duration := fade_in_seconds if target > _level else fade_out_seconds
	_level = move_toward(_level, target, db_to_linear(song_volume_db) * delta / maxf(duration, 0.05))
	volume_db = linear_to_db(_level) if _level > 0.0001 else -80.0
	if not _near and _level <= 0.0001 and playing:
		stop()

func stop_for_save_screen() -> void:
	stop()
	_near = false
	_level = 0.0
	volume_db = -80.0
