class_name WatchingBearVisual
extends Node3D
## PSX bear presentation with lightweight procedural motion. The source remains
## free of third-party animation data while walking and watching still read.

@export var use_3d_model: bool = true:
	set(value):
		use_3d_model = value
		if is_node_ready():
			_apply_visual_mode()

@onready var model: Node3D = $Model
@onready var sprite_fallback: Node3D = $SpriteFallback

var clip: String = "dormant"
var motion_time: float = 0.0
var model_rest_position: Vector3
var model_rest_rotation: Vector3


func _ready() -> void:
	model_rest_position = model.position
	model_rest_rotation = model.rotation
	_apply_visual_mode()
	play(clip, true)


func _process(delta: float) -> void:
	if not use_3d_model:
		return
	motion_time += delta
	var vertical_offset := 0.0
	var roll := 0.0
	var pitch := 0.0
	if clip in ["walk", "chase"]:
		vertical_offset = absf(sin(motion_time * 7.0)) * 0.045
		roll = sin(motion_time * 7.0) * 0.025
		pitch = sin(motion_time * 3.5) * 0.012
	elif clip in ["alert", "dormant", "activate", "search"]:
		vertical_offset = sin(motion_time * 1.7) * 0.009
		roll = sin(motion_time * 0.85) * 0.006
	model.position = model_rest_position + Vector3.UP * vertical_offset
	model.rotation = model_rest_rotation + Vector3(pitch, 0.0, roll)


func play(next_clip: String, _restart: bool = false) -> void:
	if next_clip != clip:
		motion_time = 0.0
	clip = next_clip
	if not use_3d_model and sprite_fallback.has_method("play"):
		sprite_fallback.play(clip)


func set_use_3d_model(enabled: bool) -> void:
	use_3d_model = enabled


func get_available_model_clips() -> PackedStringArray:
	return PackedStringArray()


func _apply_visual_mode() -> void:
	model.visible = use_3d_model
	model.process_mode = Node.PROCESS_MODE_INHERIT if use_3d_model else Node.PROCESS_MODE_DISABLED
	sprite_fallback.visible = not use_3d_model
	sprite_fallback.process_mode = Node.PROCESS_MODE_DISABLED if use_3d_model else Node.PROCESS_MODE_INHERIT
	if not use_3d_model:
		model.position = model_rest_position
		model.rotation = model_rest_rotation

