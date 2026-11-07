extends Area3D
## The padlock and chain the alt route puts on the yard gate in place of its key lock. No key opens it, but a
## shot breaks it: the chain and the padlock drop to the ground, the gate unlocks, and from then on it opens
## like any other. A gate that comes back unlocked (from a saved game, or as the forest streams back in)
## leaves its lock lying broken. The shotgun's pellets find it through take_shot, as they do anything they hit.

signal broken

@export_node_path("Node3D") var gate_path: NodePath
## The least a shot has to do to break it, so a stray pellet from the far end of the shotgun's range does not.
@export_range(0.0, 100.0, 1.0) var break_damage: float = 10.0
@export_range(0.1, 2.0, 0.05) var fall_duration: float = 0.45

var is_broken := false
var _gate: Node3D

@onready var padlock: Node3D = $Model/GatePadlock/Padlock
@onready var chain: Node3D = $Model/GatePadlock/Chain
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var break_audio: AudioStreamPlayer3D = $BreakAudio
@onready var land_audio: AudioStreamPlayer3D = $LandAudio

func _ready() -> void:
	_gate = get_node_or_null(gate_path) as Node3D
	if _gate == null:
		push_warning("The gate padlock has no gate to lock.")

func _physics_process(_delta: float) -> void:
	if not is_broken and is_instance_valid(_gate) and not bool(_gate.get("is_locked")):
		_break(false)

func take_shot(damage: float, _from: Vector3) -> void:
	if is_broken or damage < break_damage:
		return
	if is_instance_valid(_gate):
		_gate.set("is_locked", false)
	_break(true)

func _break(heard: bool) -> void:
	is_broken = true
	set_physics_process(false)
	collision.set_deferred("disabled", true)
	var ground := _ground_height()
	# The padlock tips over as it falls; the chain slides off and drops flat. Both land a little toward the
	# yard, clear of the gate's foot.
	for piece: Node3D in [chain, padlock]:
		var landed := piece.global_position + global_basis.z * (0.18 if piece == padlock else 0.1)
		landed.y = ground + (0.035 if piece == padlock else 0.006)
		var turned := piece.rotation + (Vector3(1.45, 0.6, 0.2) if piece == padlock else Vector3(0.0, 0.5, 0.0))
		if not heard:
			piece.global_position = landed
			piece.rotation = turned
			continue
		var fall := create_tween().set_parallel()
		fall.tween_property(piece, "global_position", landed, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fall.tween_property(piece, "rotation", turned, fall_duration)
		if piece == padlock:
			fall.chain().tween_callback(land_audio.play)
	if heard:
		break_audio.play()
	broken.emit()

func _ground_height() -> float:
	var from := global_position + global_basis.z * 0.2
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.0))
	return float(hit.position.y) if not hit.is_empty() else global_position.y - 1.0
