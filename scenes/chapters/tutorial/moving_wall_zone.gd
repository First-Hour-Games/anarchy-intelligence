class_name MovingWallZone
extends Area3D

## Trigger zone that smoothly tweens MovingWall from its starting position (-46.033 Z)
## to its target position (-82.144 Z) over the drag sound's duration when the player enters for the first time.
## After movement completes, displays a run/sprint instruction until the player holds Shift to run,
## which hides itself after 2-3 seconds.

signal wall_move_started(wall: Node3D, target_z: float, duration: float)
signal wall_move_completed(wall: Node3D, final_z: float)
signal instruction_shown(control: Control)
signal instruction_hidden(control: Control)

@export_group("Wall Reference")
## The wall Node3D to move. If left null, automatically searches for a sibling or child named "MovingWall".
@export var moving_wall: Node3D

@export_group("Movement Settings")
## Target Z coordinate in the wall's local transform.
@export var target_z: float = -82.144
## Default / starting Z coordinate for the wall.
@export var default_z: float = -46.033
## If true, ensures the wall starts at default_z when the scene loads.
@export var reset_to_default_on_ready: bool = true
## Fallback tween duration in seconds when the drag sound has no valid length.
@export_range(0.5, 20.0, 0.1) var duration: float = 4.5
## Tween transition type for smooth motion.
@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
## Tween easing type.
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export_group("Wall Audio")
@export var drag_sound: AudioStreamMP3 = preload("res://sounds/chapters/intro/doorDrag.mp3")
@export var bang_sound: AudioStreamMP3 = preload("res://sounds/chapters/intro/doorBang.mp3")
@export var wall_audio_bus: StringName = &"Reverb"
@export_range(5.0, 100.0, 1.0) var wall_audio_max_distance: float = 55.0
@export_range(1.0, 50.0, 1.0) var wall_audio_unit_size: float = 15.0
@export_range(-30.0, 6.0, 0.5) var drag_volume_db: float = -4.0
@export_range(-30.0, 6.0, 0.5) var bang_volume_db: float = 3.0

@export_group("Trigger Settings")
## Whether this trigger should only activate once.
@export var trigger_once: bool = true
## If true, only player bodies trigger the movement.
@export var only_player: bool = true

@export_group("Run Instruction")
## The UI Control to display as the run instruction (defaults to finding RunLabel).
@export var run_instruction: Control
## Text to display in the instruction's RichTextLabel.
@export var instruction_text: String = "Hold to run"
## Duration in seconds to fade in the run instruction.
@export_range(0.1, 5.0, 0.1) var instruction_fade_in_duration: float = 1.5
## Delay in seconds after the player runs before fading out (delay + fade_out = 2-3 seconds).
@export_range(0.0, 5.0, 0.1) var instruction_hide_delay: float = 1.0
## Duration in seconds to fade out the run instruction.
@export_range(0.1, 5.0, 0.1) var instruction_fade_out_duration: float = 1.5

var _has_triggered: bool = false
var _active_tween: Tween
var _instruction_tween: Tween
var _cached_player: Node = null
var _is_showing_instruction: bool = false
var _has_run: bool = false
var _drag_audio: AudioStreamPlayer3D
var _bang_audio: AudioStreamPlayer3D


func _prepare_wall_audio() -> void:
	if not is_instance_valid(_drag_audio):
		_drag_audio = _create_wall_audio("WallDragAudio", drag_sound, drag_volume_db, true)
	if not is_instance_valid(_bang_audio):
		_bang_audio = _create_wall_audio("WallBangAudio", bang_sound, bang_volume_db, false)


func _create_wall_audio(audio_name: String, sound: AudioStreamMP3, volume: float, looping: bool) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = audio_name
	if sound:
		var local_stream := sound.duplicate() as AudioStreamMP3
		local_stream.loop = looping
		player.stream = local_stream
	player.bus = wall_audio_bus
	player.max_distance = wall_audio_max_distance
	player.unit_size = wall_audio_unit_size
	player.volume_db = volume
	moving_wall.add_child(player)
	player.position = Vector3(0.0, 1.0, 0.0)
	return player


func _stop_wall_audio() -> void:
	if is_instance_valid(_drag_audio):
		_drag_audio.stop()
	if is_instance_valid(_bang_audio):
		_bang_audio.stop()


func _ready() -> void:
	# Resolve moving wall reference if not explicitly assigned
	if not is_instance_valid(moving_wall):
		moving_wall = _find_moving_wall()

	if is_instance_valid(moving_wall) and reset_to_default_on_ready:
		moving_wall.position.z = default_z

	# Resolve run instruction reference if not explicitly assigned
	if not is_instance_valid(run_instruction):
		run_instruction = _find_run_instruction()

	if is_instance_valid(run_instruction):
		if not _is_showing_instruction:
			run_instruction.modulate.a = 0.0
			run_instruction.visible = false
		var rich_label := run_instruction.find_child("RichTextLabel", true, false) as RichTextLabel
		if is_instance_valid(rich_label) and not instruction_text.is_empty():
			rich_label.text = "[font_size=64][font=res://fonts/JainiPurva.ttf]%s[/font][/font_size]" % instruction_text

	body_entered.connect(_on_body_entered)

	# Check if player is already inside the zone upon loading
	_check_initial_overlap.call_deferred()


func _process(_delta: float) -> void:
	if _is_showing_instruction and not _has_run:
		if _check_player_running():
			_on_player_ran()


func _find_moving_wall() -> Node3D:
	if has_node("../MovingWall"):
		return get_node("../MovingWall") as Node3D
	if has_node("MovingWall"):
		return get_node("MovingWall") as Node3D
	var parent_node := get_parent()
	if is_instance_valid(parent_node):
		var sibling := parent_node.find_child("MovingWall", false, false) as Node3D
		if is_instance_valid(sibling):
			return sibling
	if is_inside_tree() and get_tree().current_scene:
		var scene_wall := get_tree().current_scene.find_child("MovingWall", true, false) as Node3D
		if is_instance_valid(scene_wall):
			return scene_wall
	return null


func _find_run_instruction() -> Control:
	var candidate_paths := [
		NodePath("../../TutorialOverlay/AspectRatioContainer/Content/RunLabel"),
		NodePath("../TutorialOverlay/AspectRatioContainer/Content/RunLabel"),
		NodePath("RunLabel")
	]
	for path in candidate_paths:
		if has_node(path):
			return get_node(path) as Control
	if is_inside_tree() and get_tree().current_scene:
		var found := get_tree().current_scene.find_child("RunLabel", true, false) as Control
		if is_instance_valid(found):
			return found
	return null


func _check_initial_overlap() -> void:
	if _has_triggered:
		return
	for body in get_overlapping_bodies():
		if _is_valid_trigger_body(body):
			_cached_player = body
			trigger()
			break


func _on_body_entered(body: Node3D) -> void:
	if _has_triggered and trigger_once:
		return
	if not _is_valid_trigger_body(body):
		return

	_cached_player = body
	trigger()


func _is_valid_trigger_body(body: Node) -> bool:
	if not is_instance_valid(body):
		return false
	if not only_player:
		return true

	if body.is_in_group(&"player") or body.is_in_group("player"):
		return true
	if body is FirstPersonPlayer:
		return true
	if body.name == "Player":
		return true
	return false


func trigger() -> void:
	if _has_triggered and trigger_once:
		return

	_has_triggered = true

	if not is_instance_valid(moving_wall):
		moving_wall = _find_moving_wall()

	if not is_instance_valid(moving_wall):
		push_warning("[MovingWallZone] Cannot trigger: moving_wall is null.")
		return

	if trigger_once:
		set_deferred("monitoring", false)

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_prepare_wall_audio()
	_stop_wall_audio()
	var move_duration := duration
	if _drag_audio.stream and _drag_audio.stream.get_length() > 0.0:
		move_duration = _drag_audio.stream.get_length()
	_drag_audio.play()

	_active_tween = create_tween()
	_active_tween.set_trans(transition_type)
	_active_tween.set_ease(ease_type)
	_active_tween.tween_property(moving_wall, "position:z", target_z, move_duration)

	wall_move_started.emit(moving_wall, target_z, move_duration)

	_active_tween.finished.connect(func():
		if is_instance_valid(_drag_audio):
			_drag_audio.stop()
		if is_instance_valid(_bang_audio):
			_bang_audio.play()
		_set_player_sprint_enabled(true)
		wall_move_completed.emit(moving_wall, moving_wall.position.z)
		_show_instruction()
	)


func _set_player_sprint_enabled(enabled: bool) -> void:
	var player := get_node_or_null("../../Player") as FirstPersonPlayer
	if is_instance_valid(player):
		player.sprint_enabled = enabled
		if not enabled:
			player.is_sprinting = false


func _show_instruction() -> void:
	if not is_instance_valid(run_instruction):
		run_instruction = _find_run_instruction()

	if not is_instance_valid(run_instruction):
		return

	if not is_instance_valid(_cached_player) and is_inside_tree() and get_tree().current_scene:
		_cached_player = get_tree().current_scene.find_child("Player", true, false)

	run_instruction.visible = true
	run_instruction.modulate.a = 0.0

	if _instruction_tween and _instruction_tween.is_valid():
		_instruction_tween.kill()

	_instruction_tween = create_tween()
	_instruction_tween.set_trans(transition_type)
	_instruction_tween.set_ease(ease_type)
	_instruction_tween.tween_property(run_instruction, "modulate:a", 1.0, instruction_fade_in_duration)

	_is_showing_instruction = true
	_has_run = false
	instruction_shown.emit(run_instruction)


func _check_player_running() -> bool:
	if is_instance_valid(_cached_player):
		if "is_sprinting" in _cached_player:
			return _cached_player.is_sprinting
	if Input.is_key_pressed(KEY_SHIFT):
		return true
	if InputMap.has_action("sprint") and Input.is_action_pressed("sprint"):
		return true
	return false


func _on_player_ran() -> void:
	if _has_run:
		return
	_has_run = true
	_start_hide_instruction()


func _start_hide_instruction() -> void:
	if not is_instance_valid(run_instruction):
		return

	if _instruction_tween and _instruction_tween.is_valid():
		_instruction_tween.kill()

	_instruction_tween = create_tween()
	_instruction_tween.set_trans(transition_type)
	_instruction_tween.set_ease(ease_type)
	if run_instruction.modulate.a < 1.0:
		_instruction_tween.tween_property(run_instruction, "modulate:a", 1.0, 0.3)
	if instruction_hide_delay > 0.0:
		_instruction_tween.tween_interval(instruction_hide_delay)
	_instruction_tween.tween_property(run_instruction, "modulate:a", 0.0, instruction_fade_out_duration)
	_instruction_tween.finished.connect(func():
		_is_showing_instruction = false
		if is_instance_valid(run_instruction):
			run_instruction.visible = false
		instruction_hidden.emit(run_instruction)
	)


func has_triggered() -> bool:
	return _has_triggered


func is_moving() -> bool:
	return _active_tween != null and _active_tween.is_valid() and _active_tween.is_running()


func is_instruction_showing() -> bool:
	return _is_showing_instruction


func reset() -> void:
	_set_player_sprint_enabled(false)
	_stop_wall_audio()
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if _instruction_tween and _instruction_tween.is_valid():
		_instruction_tween.kill()
	_has_triggered = false
	_is_showing_instruction = false
	_has_run = false
	if is_instance_valid(moving_wall):
		moving_wall.position.z = default_z
	if is_instance_valid(run_instruction):
		run_instruction.modulate.a = 0.0
		run_instruction.visible = false
	monitoring = true
