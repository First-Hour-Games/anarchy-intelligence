extends Node3D

## Draws a full-color copy of the tutorial door over the monochrome tutorial world.
## Layer order: world < door pass (18) < aspect bars (19) < player UI (20) < CRT (100).

const DOOR_OVERLAY_LAYER := 18
const INTRO_FADE_LAYER := 200

@export_category("Intro Fade")
@export_range(0.0, 10.0, 0.1) var intro_black_hold_seconds := 2.0
@export_range(0.1, 10.0, 0.1) var intro_fade_duration := 4.0
@export_range(0.1, 10.0, 0.1) var door_color_fade_duration := 5.0

@export_category("Intro Light")
@export var intro_light_path: NodePath
@export_range(0.0, 16.0, 0.05) var intro_light_start_energy := 0.3
@export_range(0.0, 16.0, 0.05) var intro_light_end_energy := 0.9
@export_range(0.0, 10.0, 0.1) var intro_light_extra_duration := 1.0

@export_category("Tutorial Music")
@export_range(1.0, 15.0, 0.5) var tutorial_music_fade_duration := 7.5
@export_range(-30.0, 0.0, 0.5) var tutorial_music_volume_db := -7.0

@export_category("Tutorial Labels")
@export_range(0.1, 5.0, 0.1) var tutorial_label_fade_duration := 1.5
@export_range(0.5, 10.0, 0.1) var tutorial_label_hide_distance := 2.2
@export_range(0.1, 5.0, 0.1) var tutorial_label_fade_out_duration := 1.5

@onready var _source_door: Node3D = $Door3
@onready var _source_camera: Camera3D = $Player/Head/Camera3D
@onready var _source_environment: WorldEnvironment = $WorldEnvironment
@onready var _player: CharacterBody3D = $Player
@onready var _move_label: TextureRect = $TutorialOverlay/AspectRatioContainer/Content/MoveLabel
@onready var _look_label: TextureRect = $TutorialOverlay/AspectRatioContainer/Content/LookLabel
@onready var _music_player: AudioStreamPlayer = $TutorialMusic

var _door_viewport: SubViewport
var _door_camera: Camera3D
var _door_copy: Node3D
var _door_texture: TextureRect
var _intro_fade: ColorRect
var _intro_light: OmniLight3D
var _player_was_physics_processing := true
var _player_was_processing_unhandled_input := true
var _tutorial_label_tween: Tween
var _music_fade_tween: Tween
var _tutorial_labels_can_hide := false
var _tutorial_labels_are_hiding := false


func _ready() -> void:
	_intro_light = _find_intro_light()
	if is_instance_valid(_intro_light):
		_intro_light.light_energy = intro_light_start_energy
	_create_color_viewport()
	get_viewport().size_changed.connect(_resize_color_viewport)
	_resize_color_viewport()
	_sync_color_pass()
	_create_intro_fade()
	_lock_player()
	_play_intro_fade()


func _process(_delta: float) -> void:
	_sync_color_pass()
	_update_tutorial_label_proximity()


func _create_color_viewport() -> void:
	_door_viewport = SubViewport.new()
	_door_viewport.name = "DoorColorViewport"
	_door_viewport.own_world_3d = true
	_door_viewport.transparent_bg = true
	_door_viewport.handle_input_locally = false
	_door_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_door_viewport)

	var color_environment_node := WorldEnvironment.new()
	color_environment_node.name = "DoorColorEnvironment"
	color_environment_node.environment = _make_color_environment()
	_door_viewport.add_child(color_environment_node)

	_door_camera = Camera3D.new()
	_door_camera.name = "DoorCamera"
	_door_camera.current = true
	_door_viewport.add_child(_door_camera)

	_door_copy = _source_door.duplicate()
	_door_copy.name = "DoorColorCopy"
	_strip_gameplay_from_color_copy(_door_copy)
	_door_copy.process_mode = Node.PROCESS_MODE_DISABLED
	_door_viewport.add_child(_door_copy)

	var overlay := CanvasLayer.new()
	overlay.name = "DoorColorOverlay"
	overlay.layer = DOOR_OVERLAY_LAYER
	add_child(overlay)

	_door_texture = TextureRect.new()
	_door_texture.name = "DoorTexture"
	_door_texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_door_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_door_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_door_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_door_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_door_texture.texture = _door_viewport.get_texture()
	_door_texture.modulate.a = 0.0
	overlay.add_child(_door_texture)


func _create_intro_fade() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = "IntroFadeOverlay"
	overlay.layer = INTRO_FADE_LAYER
	add_child(overlay)

	_intro_fade = ColorRect.new()
	_intro_fade.name = "Blackout"
	_intro_fade.color = Color.BLACK
	_intro_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(_intro_fade)
	_intro_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _lock_player() -> void:
	_player_was_physics_processing = _player.is_physics_processing()
	_player_was_processing_unhandled_input = _player.is_processing_unhandled_input()
	_player.velocity = Vector3.ZERO
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)


func _play_intro_fade() -> void:
	await get_tree().create_timer(intro_black_hold_seconds).timeout
	if not is_instance_valid(_intro_fade):
		return
	_start_tutorial_music()
	_start_intro_light_fade()

	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(_intro_fade, "color:a", 0.0, intro_fade_duration)
	await fade_tween.finished

	_intro_fade.get_parent().queue_free()
	
	var door_tween := create_tween()
	door_tween.set_trans(Tween.TRANS_SINE)
	door_tween.set_ease(Tween.EASE_IN_OUT)
	door_tween.tween_property(_door_texture, "modulate:a", 1.0, door_color_fade_duration)
	await door_tween.finished
	
	_unlock_player()
	_fade_in_tutorial_labels()


func _find_intro_light() -> OmniLight3D:
	if not intro_light_path.is_empty():
		var configured_light := get_node_or_null(intro_light_path) as OmniLight3D
		if is_instance_valid(configured_light):
			return configured_light

	var lights := find_children("*", "OmniLight3D", true, false)
	return lights[0] as OmniLight3D if not lights.is_empty() else null


func _start_intro_light_fade() -> void:
	if not is_instance_valid(_intro_light):
		return

	var light_tween := create_tween()
	light_tween.set_trans(Tween.TRANS_SINE)
	light_tween.set_ease(Tween.EASE_IN_OUT)
	light_tween.tween_property(
		_intro_light,
		"light_energy",
		intro_light_end_energy,
		intro_fade_duration + intro_light_extra_duration
	)


func _start_tutorial_music() -> void:
	if not is_instance_valid(_music_player) or _music_player.stream == null:
		return

	_music_player.volume_db = -80.0
	_music_player.play()
	_music_fade_tween = create_tween()
	_music_fade_tween.set_trans(Tween.TRANS_SINE)
	_music_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_music_fade_tween.tween_property(
		_music_player,
		"volume_db",
		tutorial_music_volume_db,
		tutorial_music_fade_duration
	)


func _fade_in_tutorial_labels() -> void:
	_tutorial_labels_can_hide = true
	_tutorial_label_tween = create_tween()
	_tutorial_label_tween.set_parallel(true)
	_tutorial_label_tween.set_trans(Tween.TRANS_SINE)
	_tutorial_label_tween.set_ease(Tween.EASE_IN_OUT)
	_tutorial_label_tween.tween_property(_move_label, "modulate:a", 1.0, tutorial_label_fade_duration)
	_tutorial_label_tween.tween_property(_look_label, "modulate:a", 1.0, tutorial_label_fade_duration)


func _update_tutorial_label_proximity() -> void:
	if not _tutorial_labels_can_hide or _tutorial_labels_are_hiding:
		return

	var player_position := Vector2(_player.global_position.x, _player.global_position.z)
	var door_position := Vector2(_source_door.global_position.x, _source_door.global_position.z)
	if player_position.distance_to(door_position) > tutorial_label_hide_distance:
		return

	_tutorial_labels_are_hiding = true
	if _tutorial_label_tween and _tutorial_label_tween.is_valid():
		_tutorial_label_tween.kill()

	_tutorial_label_tween = create_tween()
	_tutorial_label_tween.set_parallel(true)
	_tutorial_label_tween.set_trans(Tween.TRANS_SINE)
	_tutorial_label_tween.set_ease(Tween.EASE_IN_OUT)
	_tutorial_label_tween.tween_property(_move_label, "modulate:a", 0.0, tutorial_label_fade_out_duration)
	_tutorial_label_tween.tween_property(_look_label, "modulate:a", 0.0, tutorial_label_fade_out_duration)


func _unlock_player() -> void:
	if not is_instance_valid(_player):
		return
	_player.set_physics_process(_player_was_physics_processing)
	_player.set_process_unhandled_input(_player_was_processing_unhandled_input)


func _make_color_environment() -> Environment:
	var environment: Environment
	if _source_environment.environment:
		environment = _source_environment.environment.duplicate()
	else:
		environment = Environment.new()

	# Preserve the tutorial's brightness and contrast while restoring saturation.
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.0
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.background_energy_multiplier = 0.0
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	return environment


func _resize_color_viewport() -> void:
	var visible_size := get_viewport().get_visible_rect().size
	_door_viewport.size = Vector2i(
		maxi(2, roundi(visible_size.x)),
		maxi(2, roundi(visible_size.y))
	)


func _sync_color_pass() -> void:
	if not is_instance_valid(_source_camera) or not is_instance_valid(_source_door):
		return

	_door_camera.global_transform = _source_camera.global_transform
	_door_camera.projection = _source_camera.projection
	_door_camera.fov = _source_camera.fov
	_door_camera.size = _source_camera.size
	_door_camera.frustum_offset = _source_camera.frustum_offset
	_door_camera.near = _source_camera.near
	_door_camera.far = _source_camera.far
	_door_camera.keep_aspect = _source_camera.keep_aspect
	_door_camera.h_offset = _source_camera.h_offset
	_door_camera.v_offset = _source_camera.v_offset
	_door_copy.global_transform = _source_door.global_transform
	_sync_node3d_transforms(_source_door, _door_copy)


func _strip_gameplay_from_color_copy(node: Node) -> void:
	if node is CollisionObject3D:
		var collision_object := node as CollisionObject3D
		collision_object.collision_layer = 0
		collision_object.collision_mask = 0
	if node is AnimatableBody3D:
		(node as AnimatableBody3D).sync_to_physics = false
	if node.get_script() != null:
		node.set_script(null)
	for child in node.get_children():
		_strip_gameplay_from_color_copy(child)


func _sync_node3d_transforms(source: Node, copy: Node) -> void:
	for source_child in source.get_children():
		var copy_child := copy.get_node_or_null(NodePath(str(source_child.name)))
		if not is_instance_valid(copy_child):
			continue
		if source_child is Node3D and copy_child is Node3D:
			(copy_child as Node3D).transform = (source_child as Node3D).transform
		_sync_node3d_transforms(source_child, copy_child)
