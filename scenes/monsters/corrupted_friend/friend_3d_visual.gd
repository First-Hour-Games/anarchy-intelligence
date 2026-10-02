class_name CorruptedFriendVisual
extends Node3D
## Keeps the enemy controller independent from the imported animated model.
## Both the previous bear and original sprite remain designer-tunable fallbacks.

const GAMEPLAY_TO_MODEL := {
	"dormant": "idle",
	"activate": "idle",
	"alert": "idle",
	"search": "idle",
	"walk": "walk",
	"chase": "run",
	"windup": "windup",
	"attack": "attack",
	"hit": "hit",
	"dead": "death",
}
const LOOPING_MODEL_CLIPS := [&"idle", &"walk", &"run"]

@export var use_3d_model: bool = true:
	set(value):
		use_3d_model = value
		if is_node_ready():
			_apply_visual_mode()

@export var use_previous_bear: bool = false:
	set(value):
		use_previous_bear = value
		if is_node_ready():
			_apply_visual_mode()

@onready var model: Node3D = $Model
@onready var previous_bear: Node3D = $PreviousBear
@onready var sprite_fallback: Node3D = $SpriteFallback

var animation_player: AnimationPlayer
var clip: String = "dormant"


func _ready() -> void:
	animation_player = _find_animation_player(model)
	if animation_player:
		_configure_animation_loops()
	else:
		push_warning("Watching Yeti has no AnimationPlayer; using the previous bear.")
		use_previous_bear = true
	_apply_visual_mode()
	play(clip, true)


func play(next_clip: String, restart: bool = false) -> void:
	var changed := next_clip != clip
	clip = next_clip
	if use_3d_model and not use_previous_bear and animation_player:
		var model_clip: StringName = StringName(GAMEPLAY_TO_MODEL.get(clip, "idle"))
		if not animation_player.has_animation(model_clip):
			push_warning("Missing Watching Yeti animation: %s" % model_clip)
			return
		if changed or restart or animation_player.current_animation != model_clip:
			animation_player.play(model_clip, 0.12)
	elif not use_3d_model and sprite_fallback.has_method("play"):
		sprite_fallback.play(clip)


func set_use_3d_model(enabled: bool) -> void:
	use_3d_model = enabled and animation_player != null


func set_use_previous_bear(enabled: bool) -> void:
	use_previous_bear = enabled


func get_available_model_clips() -> PackedStringArray:
	return animation_player.get_animation_list() if animation_player else PackedStringArray()


func _apply_visual_mode() -> void:
	var model_active := use_3d_model and not use_previous_bear
	var bear_active := use_3d_model and use_previous_bear
	model.visible = model_active
	model.process_mode = Node.PROCESS_MODE_INHERIT if model_active else Node.PROCESS_MODE_DISABLED
	previous_bear.visible = bear_active
	previous_bear.process_mode = Node.PROCESS_MODE_INHERIT if bear_active else Node.PROCESS_MODE_DISABLED
	sprite_fallback.visible = not use_3d_model
	sprite_fallback.process_mode = Node.PROCESS_MODE_DISABLED if use_3d_model else Node.PROCESS_MODE_INHERIT
	play(clip, true)


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
