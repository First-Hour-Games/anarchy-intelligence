extends Node3D
## Adapts the imported Wrapper clips to the existing story enemy's animation API.

const CLIPS := {
	"idle": &"MonsterPSX_Rig|Idle_Watchful",
	"run": &"MonsterPSX_Rig|Walk_Nervous",
	"windup": &"MonsterPSX_Rig|Scream_lol",
	"attack": &"MonsterPSX_Rig|Attack_Lunge",
}
var animation_player: AnimationPlayer
var clip := "idle"


func _ready() -> void:
	var players := find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return
	animation_player = players[0] as AnimationPlayer
	if animation_player.has_animation_library(&"enemy"):
		return
	# Only this actor's combat library changes loop modes; the window walk stays separate.
	var library := AnimationLibrary.new()
	for key: String in CLIPS:
		if not animation_player.has_animation(CLIPS[key]):
			continue
		var animation := animation_player.get_animation(CLIPS[key]).duplicate() as Animation
		animation.loop_mode = Animation.LOOP_LINEAR if key in ["idle", "run"] else Animation.LOOP_NONE
		library.add_animation(key, animation)
	animation_player.add_animation_library(&"enemy", library)


func play(next_clip: String) -> void:
	clip = next_clip
	if animation_player == null or not animation_player.has_animation("enemy/" + clip):
		return
	if animation_player.current_animation != "enemy/" + clip:
		animation_player.play("enemy/" + clip, 0.12)
