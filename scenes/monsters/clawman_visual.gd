extends Node3D

@export var static_pose_fallback: bool = false
var animation_player: AnimationPlayer
var clip: String = "idle"
const CLIPS := {"idle": "Idle_ClawGroom", "walk": "Walk_Shamble", "run": "Chase_Run", "windup": "Scream_Alert", "attack": "Attack_Slam", "hit": "Scream_Alert", "death": "Idle_ClawGroom"}

func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		animation_player = players[0] as AnimationPlayer
		for name: StringName in animation_player.get_animation_list():
			animation_player.get_animation(name).loop_mode = Animation.LOOP_LINEAR if str(name).ends_with("Idle_ClawGroom") or str(name).ends_with("Walk_Shamble") or str(name).ends_with("Chase_Run") else Animation.LOOP_NONE
	play("idle")

func resolve_clip(next: String) -> StringName:
	if animation_player != null:
		for name: StringName in animation_player.get_animation_list():
			if str(name).ends_with(CLIPS.get(next, "Idle_ClawGroom")):
				return name
	return &""

func play(next: String) -> void:
	clip = next
	if static_pose_fallback or animation_player == null:
		return
	var name := resolve_clip(next)
	if name != &"" and animation_player.current_animation != name:
		animation_player.play(name, 0.15)
