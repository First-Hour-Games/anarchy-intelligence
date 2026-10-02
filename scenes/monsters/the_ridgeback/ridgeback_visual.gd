class_name RidgebackVisual
extends Node3D
## Maps the shared CorruptedFriend watcher AI's gameplay clip names onto The
## Ridgeback's own baked animations. There is only one presentation here (no
## sprite or legacy-model fallback like the bear/yeti have).

const GAMEPLAY_TO_MODEL := {
	"dormant": "ManThing_IDLE",
	"activate": "ManThing_IDLE",
	"alert": "ManThing_NOTICE",
	"search": "ManThing_IDLE",
	"walk": "ManThing_WALK",
	"chase": "ManThing_CHASE",
	"windup": "ManThing_NOTICE",
	"attack": "ManThing_ATTACK",
	"hit": "ManThing_NOTICE",
	"dead": "ManThing_IDLE",
}
const LOOPING_MODEL_CLIPS := [&"ManThing_IDLE", &"ManThing_WALK", &"ManThing_CHASE"]

@onready var model: Node3D = $Model

# Metres travelled per second at the original clip's cadence.
@export var walk_reference_speed: float = 1.4
@export var chase_reference_speed: float = 3.2

var animation_player: AnimationPlayer
var clip: String = "dormant"


func _ready() -> void:
	animation_player = _find_animation_player(model)
	if animation_player:
		_configure_animation_loops()
	else:
		push_warning("The Ridgeback model has no AnimationPlayer.")
	play(clip, true)


func play(next_clip: String, restart: bool = false) -> void:
	var changed := next_clip != clip
	clip = next_clip
	if not animation_player:
		return
	if clip not in ["walk", "chase"]:
		animation_player.speed_scale = 1.0
	var model_clip: StringName = StringName(GAMEPLAY_TO_MODEL.get(clip, "ManThing_IDLE"))
	if not animation_player.has_animation(model_clip):
		push_warning("Missing Ridgeback animation: %s" % model_clip)
		return
	if changed or restart or animation_player.current_animation != model_clip:
		animation_player.play(model_clip, 0.12)


func set_movement_speed(speed: float) -> void:
	if not animation_player or clip not in ["walk", "chase"]:
		return
	var reference := chase_reference_speed if clip == "chase" else walk_reference_speed
	# Use achieved movement, so pushing against a wall does not keep marching.
	animation_player.speed_scale = clampf(speed / maxf(reference, 0.01), 0.0, 4.0)


func get_available_model_clips() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()


func _configure_animation_loops() -> void:
	for animation_name: StringName in animation_player.get_animation_list():
		var animation := animation_player.get_animation(animation_name)
		animation.loop_mode = (
			Animation.LOOP_LINEAR
			if animation_name in LOOPING_MODEL_CLIPS
			else Animation.LOOP_NONE
		)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
