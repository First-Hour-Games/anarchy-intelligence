class_name RidgebackVisual
extends Node3D
## Maps the shared CorruptedFriend watcher AI's gameplay clip names onto The Ridgeback's clips.
## The clips authored for it (tools/blender/ridgeback/clips.py) come in two sets, on all fours
## and standing; moving between the two plays fours_drop or fours_rise on the way. The creator's
## original ManThing_ clips stay in the model as a fallback. The car ambush (ridgeback_ambusher.gd)
## adds leaping over cars (leap, airborne, land), hiding behind them, peeking over them, perching on
## them and shrieking.

const FOURS := {
	"dormant": "idle",
	"activate": "fours_scream",
	"alert": "fours_lurk",
	"search": "idle",
	"walk": "fours_prowl",
	"chase": "fours_gallop",
	"windup": "fours_crouch",
	"attack": "fours_pounce",
	"hit": "fours_hit",
	"dead": "fours_death",
	"leap": "fours_leap",
	"airborne": "fours_air",
	"land": "fours_land",
	"hide": "fours_hide",
	"peek": "fours_peek",
	"perch": "fours_lurk",
	"shriek": "fours_shriek",
}
const STANDING := {
	"dormant": "idle",
	"activate": "scream",
	"alert": "watch",
	"search": "idle",
	"walk": "walk",
	"chase": "run",
	"windup": "windup",
	"attack": "attack",
	"hit": "hit",
	"dead": "death",
	"leap": "windup",
	"airborne": "run",
	"land": "idle",
	"hide": "watch",
	"peek": "watch",
	"perch": "watch",
	"shriek": "scream",
}
const ORIGINAL := {
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
	"leap": "ManThing_NOTICE",
	"airborne": "ManThing_CHASE",
	"land": "ManThing_IDLE",
	"hide": "ManThing_IDLE",
	"peek": "ManThing_NOTICE",
	"perch": "ManThing_IDLE",
	"shriek": "ManThing_NOTICE",
}
const LOOPING_MODEL_CLIPS := [&"idle", &"watch", &"walk", &"run", &"fours_lurk", &"fours_prowl", &"fours_gallop",
		&"fours_air", &"fours_hide", &"ManThing_IDLE", &"ManThing_WALK", &"ManThing_CHASE"]
## Clips that end on all fours; the rest end standing, or lying down.
const ON_ALL_FOURS := [&"fours_scream", &"fours_drop", &"fours_lurk", &"fours_prowl", &"fours_gallop",
		&"fours_crouch", &"fours_pounce", &"fours_hit", &"fours_leap", &"fours_air", &"fours_land", &"fours_hide",
		&"fours_peek", &"fours_shriek"]
const STANCE_CHANGES := [&"fours_drop", &"fours_rise"]
## Reactions that play on whichever footing it is on when they happen.
const FOOTED := ["hit", "dead"]
## Metres per second the feet cover at each authored locomotion clip's own cadence, at the model's own
## size (STALK_SPEED, SPRINT_SPEED, PROWL_SPEED and GALLOP_SPEED in tools/blender/ridgeback/clips.py).
const AUTHORED_SPEEDS := {&"walk": 1.106, &"run": 5.415, &"fours_prowl": 0.968, &"fours_gallop": 4.333}

@onready var model: Node3D = $Model

## Plays the clips authored for The Ridgeback; off falls back to the creator's original clips.
@export var use_authored_clips: bool = true
## Watches, walks, chases and strikes on all fours; off keeps it standing.
@export var four_legged: bool = true
# Metres travelled per second at the original clips' cadence.
@export var walk_reference_speed: float = 1.4
@export var chase_reference_speed: float = 3.2

var animation_player: AnimationPlayer
var clip: String = "dormant"
## The clip to play once fours_drop or fours_rise finishes.
var after_stance_change: StringName = &""


func _ready() -> void:
	animation_player = _find_animation_player(model)
	if animation_player:
		_configure_animation_loops()
		animation_player.animation_finished.connect(_on_animation_finished)
	else:
		push_warning("The Ridgeback model has no AnimationPlayer.")
	play(clip, true)


## restart plays the clip straight away, without a stance change first.
func play(next_clip: String, restart: bool = false) -> void:
	var changed := next_clip != clip
	clip = next_clip
	if not animation_player:
		return
	if clip not in ["walk", "chase"]:
		animation_player.speed_scale = 1.0
	var model_clip := model_clip_for(clip)
	if not animation_player.has_animation(model_clip):
		push_warning("Missing Ridgeback animation: %s" % model_clip)
		return
	if after_stance_change != &"" and not restart and model_clip in LOOPING_MODEL_CLIPS:
		# Mid drop or rise: a loop on the footing it is heading for waits for it; one on the footing it
		# is leaving settles back straight away. One-shots (hits, strikes, death) cut in.
		if (model_clip in ON_ALL_FOURS) == (after_stance_change in ON_ALL_FOURS):
			after_stance_change = model_clip
			return
		after_stance_change = &""
		animation_player.play(model_clip, 0.25)
		return
	if not (changed or restart or animation_player.current_animation != model_clip):
		return
	after_stance_change = &""
	_start(model_clip, restart)


func model_clip_for(gameplay_clip: String) -> StringName:
	var table: Dictionary = ORIGINAL
	if use_authored_clips:
		table = FOURS if four_legged else STANDING
		if four_legged and gameplay_clip in FOOTED:
			table = FOURS if _on_all_fours() else STANDING
	var model_clip := StringName(table.get(gameplay_clip, table["dormant"]))
	if animation_player and not animation_player.has_animation(model_clip):
		model_clip = StringName(ORIGINAL.get(gameplay_clip, ORIGINAL["dormant"]))
	return model_clip


## Whether it is on all fours now, or on its way down to them.
func _on_all_fours() -> bool:
	if after_stance_change != &"":
		return after_stance_change in ON_ALL_FOURS
	return animation_player != null and StringName(animation_player.assigned_animation) in ON_ALL_FOURS


func set_movement_speed(speed: float) -> void:
	if not animation_player or clip not in ["walk", "chase"] or after_stance_change != &"":
		return
	var model_clip := model_clip_for(clip)
	var reference := chase_reference_speed if clip == "chase" else walk_reference_speed
	if AUTHORED_SPEEDS.has(model_clip):
		# The model stands larger in some scenes; its stride grows with it.
		reference = AUTHORED_SPEEDS[model_clip] * model.global_basis.get_scale().y
	# Use achieved movement, so pushing against a wall does not keep marching.
	animation_player.speed_scale = clampf(speed / maxf(reference, 0.01), 0.0, 4.0)


func get_available_model_clips() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()


## Loops that start on the other footing from the current pose get there through fours_drop or
## fours_rise first; one-shots carry their own way in.
func _start(model_clip: StringName, restart: bool = false) -> void:
	var playing := animation_player.current_animation if animation_player.is_playing() else animation_player.assigned_animation
	if not restart and use_authored_clips and model_clip in LOOPING_MODEL_CLIPS and playing != &"":
		var on_all_fours := model_clip in ON_ALL_FOURS
		if on_all_fours != (StringName(playing) in ON_ALL_FOURS):
			after_stance_change = model_clip
			animation_player.speed_scale = 1.0
			animation_player.play(&"fours_drop" if on_all_fours else &"fours_rise", 0.12)
			return
	animation_player.play(model_clip, 0.12)


func _on_animation_finished(finished: StringName) -> void:
	if finished not in STANCE_CHANGES or after_stance_change == &"":
		return
	var next := after_stance_change
	after_stance_change = &""
	_start(next)


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
