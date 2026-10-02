@tool
class_name InspectableView3D extends Node3D

## Manages stationary inspection mode for an object with subtle cursor parallax sway,
## interactive 2D dot hotspots in screen space, and Backspace exit navigation.

signal inspection_started(player: FirstPersonPlayer)
signal inspection_ended(player: FirstPersonPlayer)

@export_category("Camera Framing")
## Marker3D or Node3D specifying where the inspection camera sits and looks.
@export var camera_anchor: Marker3D = null

@export_category("Cursor Parallax Sway")
@export var max_parallax_yaw_degrees: float = 3.2
@export var max_parallax_pitch_degrees: float = 2.0
@export var sway_smoothing: float = 8.0

@export_category("Controls")
@export var exit_key: Key = KEY_BACKSPACE
@export var dialogue_balloon_scene: PackedScene = preload("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn")

var is_inspecting: bool = false
var current_player: FirstPersonPlayer = null
var _original_cam_transform: Transform3D
var _hotspot_map: Dictionary = {} # InspectionHotspot3D -> InspectionDotButton
var _overlay_canvas: CanvasLayer = null
var _dots_container: Control = null
var _exit_prompt_label: Label = null
var _active_dialogue_balloon: CanvasLayer = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_build_overlay_ui()


func _build_overlay_ui() -> void:
	if is_instance_valid(_overlay_canvas):
		return

	_overlay_canvas = CanvasLayer.new()
	_overlay_canvas.layer = 95
	add_child(_overlay_canvas)

	var root_control := Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_canvas.add_child(root_control)

	_dots_container = Control.new()
	_dots_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dots_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_dots_container)

	# Bottom exit prompt
	_exit_prompt_label = Label.new()
	_exit_prompt_label.text = "[ Backspace ] Return"
	_exit_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_exit_prompt_label.offset_top = -65.0
	_exit_prompt_label.offset_bottom = -25.0
	_exit_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	_exit_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_exit_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_exit_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_exit_prompt_label.add_theme_font_size_override("font_size", 18)
	_exit_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root_control.add_child(_exit_prompt_label)

	_overlay_canvas.visible = false


func _get_camera_anchor() -> Marker3D:
	if is_instance_valid(camera_anchor):
		return camera_anchor
	if has_node("CameraAnchor"):
		return get_node("CameraAnchor") as Marker3D
	return null


func start_inspection(player: FirstPersonPlayer) -> void:
	var anchor := _get_camera_anchor()
	if is_inspecting or not is_instance_valid(player) or not is_instance_valid(anchor):
		return

	is_inspecting = true
	current_player = player

	# Freeze player movement, input, and footsteps
	current_player.freeze()

	# Instant cut camera to anchor using top_level so it's fully independent of Head
	_original_cam_transform = current_player.camera.transform
	current_player.camera.top_level = true
	var anchor_basis := anchor.global_basis.orthonormalized()
	current_player.camera.global_transform = Transform3D(anchor_basis, anchor.global_position)

	# Enable mouse cursor
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Prepare hotspots and overlay
	_refresh_hotspots()
	_overlay_canvas.visible = true

	inspection_started.emit(current_player)


func exit_inspection() -> void:
	if not is_inspecting:
		return

	is_inspecting = false

	# If a dialogue balloon is open, close it
	if is_instance_valid(_active_dialogue_balloon):
		_active_dialogue_balloon.queue_free()
		_active_dialogue_balloon = null

	# Hide overlay
	if is_instance_valid(_overlay_canvas):
		_overlay_canvas.visible = false

	# Instant cut camera back to player head
	if is_instance_valid(current_player) and is_instance_valid(current_player.camera):
		current_player.camera.top_level = false
		current_player.camera.transform = _original_cam_transform
		current_player.unfreeze()

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var departing_player := current_player
	current_player = null
	inspection_ended.emit(departing_player)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inspecting:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == exit_key:
		exit_inspection()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_inspecting or not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
		return

	_update_camera_parallax(delta)
	_update_hotspot_positions()


func _update_camera_parallax(delta: float) -> void:
	var anchor := _get_camera_anchor()
	if not is_instance_valid(anchor) or not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
		return

	var viewport := get_viewport()
	if viewport == null:
		return

	var vp_size := viewport.get_visible_rect().size
	var mouse_pos := viewport.get_mouse_position()

	# Normalized offset from center: -1.0 to +1.0
	var norm_x := clampf((mouse_pos.x / vp_size.x - 0.5) * 2.0, -1.0, 1.0)
	var norm_y := clampf((mouse_pos.y / vp_size.y - 0.5) * 2.0, -1.0, 1.0)

	var target_yaw := deg_to_rad(-norm_x * max_parallax_yaw_degrees)
	var target_pitch := deg_to_rad(-norm_y * max_parallax_pitch_degrees)

	var base_basis := anchor.global_basis.orthonormalized()
	var sway_basis := base_basis * Basis.from_euler(Vector3(target_pitch, target_yaw, 0.0))
	var blend := 1.0 - exp(-sway_smoothing * delta)

	current_player.camera.global_basis = current_player.camera.global_basis.slerp(sway_basis, blend)
	current_player.camera.global_position = anchor.global_position


func _refresh_hotspots() -> void:
	# Clear old buttons
	for btn in _hotspot_map.values():
		if is_instance_valid(btn):
			btn.queue_free()
	_hotspot_map.clear()

	# Collect all InspectionHotspot3D children
	var hotspots := _find_hotspots(self)
	for hotspot in hotspots:
		var btn := InspectionDotButton.new()
		btn.dot_color = hotspot.dot_color
		btn.glow_color = hotspot.glow_color
		btn.dot_radius = hotspot.dot_radius
		btn.glow_radius = hotspot.glow_radius
		btn.clicked.connect(_on_hotspot_clicked.bind(hotspot))
		_dots_container.add_child(btn)
		_hotspot_map[hotspot] = btn


func _find_hotspots(node: Node) -> Array[InspectionHotspot3D]:
	var results: Array[InspectionHotspot3D] = []
	for child in node.get_children():
		if child is InspectionHotspot3D:
			results.append(child)
		results.append_array(_find_hotspots(child))
	return results


func _update_hotspot_positions() -> void:
	if not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
		return

	var cam := current_player.camera
	for hotspot in _hotspot_map.keys():
		var btn: InspectionDotButton = _hotspot_map[hotspot]
		if not is_instance_valid(hotspot) or not is_instance_valid(btn):
			continue

		if not hotspot.is_enabled or (hotspot.trigger_once and hotspot.has_triggered):
			btn.visible = false
			continue

		if cam.is_position_behind(hotspot.global_position):
			btn.visible = false
			continue

		var screen_pos := cam.unproject_position(hotspot.global_position)
		btn.position = screen_pos - btn.size * 0.5
		btn.visible = true


func _on_hotspot_clicked(hotspot: InspectionHotspot3D) -> void:
	if not is_instance_valid(hotspot) or not hotspot.can_activate():
		return

	hotspot.activate()
	_play_hotspot_dialogue(hotspot)


func _play_hotspot_dialogue(hotspot: InspectionHotspot3D) -> void:
	var res_to_play: DialogueResource = hotspot.dialogue_resource
	var cue_to_play: String = hotspot.dialogue_cue

	# Single-line dialogue fallback if no resource
	if res_to_play == null and not hotspot.single_line_dialogue.strip_edges().is_empty():
		var dm := Engine.get_singleton("DialogueManager")
		if dm:
			var speaker := hotspot.speaker_name.strip_edges()
			if speaker.is_empty():
				speaker = "Thomas"
			var script_text := "~ start\n%s: %s\n=> END" % [speaker, hotspot.single_line_dialogue]
			res_to_play = dm.create_resource_from_text(script_text)
			cue_to_play = "start"

	if res_to_play == null:
		return

	if dialogue_balloon_scene == null:
		dialogue_balloon_scene = load("res://scenes/ui/dialogue_box/bottom_dialogue_balloon.tscn") as PackedScene

	if dialogue_balloon_scene == null:
		return

	# If previous dialogue is still active, clean it up first
	if is_instance_valid(_active_dialogue_balloon):
		_active_dialogue_balloon.queue_free()
		_active_dialogue_balloon = null

	var balloon := dialogue_balloon_scene.instantiate()
	# freeze_player must be false so the dialogue balloon does not alter player freeze state or mouse mode!
	if balloon.get("freeze_player") != null:
		balloon.set("freeze_player", false)

	var target_parent: Node = get_tree().current_scene if is_instance_valid(get_tree().current_scene) else get_tree().root
	target_parent.add_child(balloon)
	_active_dialogue_balloon = balloon

	# When dialogue ends, DO NOT exit inspection mode! Only Backspace exits.
	if balloon.has_signal("dialogue_finished"):
		balloon.connect("dialogue_finished", func() -> void:
			_active_dialogue_balloon = null
			# Ensure mouse stays visible for further inspection
			if is_inspecting:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		)

	if balloon.has_method("start"):
		balloon.call("start", res_to_play, cue_to_play)
