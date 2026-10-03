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
const ItemPickupScreenScript = preload("res://scenes/ui/item_pickup/item_pickup_screen.gd")

@export_category("Blink Transition")
@export var blink_sound: AudioStream = preload("res://sounds/player/blink.mp3")
@export_range(-40.0, 6.0, 0.5) var blink_sound_volume_db: float = 0.0
@export var blink_sound_bus: StringName = &"Master"
@export var blink_close_duration: float = 0.16
@export var blink_hold_duration: float = 0.08
@export var blink_open_duration: float = 0.20

var is_inspecting: bool = false
var current_player: FirstPersonPlayer = null
var _original_cam_transform: Transform3D
var _hotspot_map: Dictionary = {} # InspectionHotspot3D -> InspectionDotButton
var _dots_canvas: CanvasLayer = null
var _prompt_canvas: CanvasLayer = null
var _dots_container: Control = null
var _exit_prompt_label: Label = null
var _active_dialogue_balloon: CanvasLayer = null
var _blink_canvas: CanvasLayer = null
var _top_eyelid: ColorRect = null
var _bottom_eyelid: ColorRect = null
var _blink_audio_player: AudioStreamPlayer = null
var _is_transitioning: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if blink_sound == null:
		blink_sound = preload("res://sounds/player/blink.mp3")
	_build_overlay_ui()
	_setup_audio()


func _build_overlay_ui() -> void:
	if is_instance_valid(_dots_canvas):
		return

	# Dots canvas rendered at layer 15 (strictly behind AspectRatioBars at layer 19)
	_dots_canvas = CanvasLayer.new()
	_dots_canvas.layer = 15
	add_child(_dots_canvas)

	_dots_container = Control.new()
	_dots_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dots_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots_canvas.add_child(_dots_container)

	# Prompt canvas rendered at layer 20 inside 4:3 safe area
	_prompt_canvas = CanvasLayer.new()
	_prompt_canvas.layer = 20
	add_child(_prompt_canvas)

	var arc := AspectRatioContainer.new()
	arc.ratio = 1.33333
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_canvas.add_child(arc)

	var prompt_content := Control.new()
	prompt_content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.add_child(prompt_content)

	# Bottom exit prompt inside 4:3 safe area
	_exit_prompt_label = Label.new()
	_exit_prompt_label.text = "[ Backspace ] Return"
	_exit_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_exit_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_exit_prompt_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_exit_prompt_label.offset_top = -55.0
	_exit_prompt_label.offset_bottom = -20.0
	_exit_prompt_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 0.8))
	_exit_prompt_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_exit_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_exit_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_exit_prompt_label.add_theme_font_size_override("font_size", 18)
	_exit_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_content.add_child(_exit_prompt_label)

	# Eyelid blink canvas rendered at layer 50
	_blink_canvas = CanvasLayer.new()
	_blink_canvas.layer = 50
	add_child(_blink_canvas)

	var blink_container := Control.new()
	blink_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blink_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blink_canvas.add_child(blink_container)

	_top_eyelid = ColorRect.new()
	_top_eyelid.color = Color.BLACK
	_top_eyelid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blink_container.add_child(_top_eyelid)

	_bottom_eyelid = ColorRect.new()
	_bottom_eyelid.color = Color.BLACK
	_bottom_eyelid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blink_container.add_child(_bottom_eyelid)

	_reset_eyelids()

	_dots_canvas.visible = false
	_prompt_canvas.visible = false
	_blink_canvas.visible = false


func _reset_eyelids() -> void:
	if is_instance_valid(_top_eyelid):
		_top_eyelid.anchor_left = 0.0
		_top_eyelid.anchor_right = 1.0
		_top_eyelid.anchor_top = 0.0
		_top_eyelid.anchor_bottom = 0.0
		_top_eyelid.offset_left = 0.0
		_top_eyelid.offset_right = 0.0
		_top_eyelid.offset_top = 0.0
		_top_eyelid.offset_bottom = 0.0
	if is_instance_valid(_bottom_eyelid):
		_bottom_eyelid.anchor_left = 0.0
		_bottom_eyelid.anchor_right = 1.0
		_bottom_eyelid.anchor_top = 1.0
		_bottom_eyelid.anchor_bottom = 1.0
		_bottom_eyelid.offset_left = 0.0
		_bottom_eyelid.offset_right = 0.0
		_bottom_eyelid.offset_top = 0.0
		_bottom_eyelid.offset_bottom = 0.0


func _setup_audio() -> void:
	if is_instance_valid(_blink_audio_player):
		return
	_blink_audio_player = AudioStreamPlayer.new()
	_blink_audio_player.name = "BlinkAudioPlayer"
	_blink_audio_player.bus = blink_sound_bus
	add_child(_blink_audio_player)


func _play_blink_sound() -> void:
	var sound: AudioStream = blink_sound
	if sound == null:
		sound = preload("res://sounds/player/blink.mp3")
	if sound == null:
		return
	if not is_instance_valid(_blink_audio_player):
		_setup_audio()
	if is_instance_valid(_blink_audio_player):
		_blink_audio_player.stream = sound
		_blink_audio_player.volume_db = blink_sound_volume_db
		_blink_audio_player.bus = blink_sound_bus
		_blink_audio_player.play()


func _play_blink_transition(on_blacked_out: Callable, on_complete: Callable = Callable()) -> void:
	_play_blink_sound()

	if not is_instance_valid(_blink_canvas) or not is_instance_valid(_top_eyelid) or not is_instance_valid(_bottom_eyelid):
		if on_blacked_out.is_valid():
			on_blacked_out.call()
		if on_complete.is_valid():
			on_complete.call()
		return

	_reset_eyelids()
	_blink_canvas.visible = true

	# 1. Close eyelids
	var close_tween := create_tween()
	close_tween.set_parallel(true)
	close_tween.tween_property(_top_eyelid, "anchor_bottom", 0.505, blink_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	close_tween.tween_property(_bottom_eyelid, "anchor_top", 0.495, blink_close_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await close_tween.finished

	if not is_inside_tree():
		return

	# 2. Hold on black for a brief moment
	if blink_hold_duration > 0.0:
		await get_tree().create_timer(blink_hold_duration, false).timeout
		if not is_inside_tree():
			return

	# 3. Instant cut while fully blacked out
	if on_blacked_out.is_valid():
		on_blacked_out.call()

	# 4. Open eyelids
	var open_tween := create_tween()
	open_tween.set_parallel(true)
	open_tween.tween_property(_top_eyelid, "anchor_bottom", 0.0, blink_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	open_tween.tween_property(_bottom_eyelid, "anchor_top", 1.0, blink_open_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await open_tween.finished

	if not is_inside_tree():
		return

	# 5. Finish
	_reset_eyelids()
	if is_instance_valid(_blink_canvas):
		_blink_canvas.visible = false

	if on_complete.is_valid():
		on_complete.call()


func _get_camera_anchor() -> Marker3D:
	if is_instance_valid(camera_anchor):
		return camera_anchor
	if has_node("CameraAnchor"):
		return get_node("CameraAnchor") as Marker3D
	return null


func start_inspection(player: FirstPersonPlayer) -> void:
	var anchor := _get_camera_anchor()
	if is_inspecting or _is_transitioning or not is_instance_valid(player) or not is_instance_valid(anchor):
		return

	_is_transitioning = true
	is_inspecting = true
	current_player = player

	# Freeze player movement, input, and footsteps immediately
	current_player.freeze()

	_play_blink_transition(
		func() -> void:
			if not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
				return
			var target_anchor := _get_camera_anchor()
			if not is_instance_valid(target_anchor):
				return

			# Instant cut camera to anchor using top_level so it's fully independent of Head
			_original_cam_transform = current_player.camera.transform
			current_player.camera.top_level = true
			var anchor_basis := target_anchor.global_basis.orthonormalized()
			current_player.camera.global_transform = Transform3D(anchor_basis, target_anchor.global_position)

			# Enable mouse cursor
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

			# Prepare hotspots and overlay
			_refresh_hotspots()
			if is_instance_valid(_dots_canvas):
				_dots_canvas.visible = true
			if is_instance_valid(_prompt_canvas):
				_prompt_canvas.visible = true

			inspection_started.emit(current_player),
		func() -> void:
			_is_transitioning = false
	)


func exit_inspection() -> void:
	if not is_inspecting or _is_transitioning:
		return

	_is_transitioning = true
	var departing_player := current_player

	_play_blink_transition(
		func() -> void:
			# If a dialogue balloon is open, close it
			if is_instance_valid(_active_dialogue_balloon):
				_active_dialogue_balloon.queue_free()
				_active_dialogue_balloon = null

			# Hide overlays
			if is_instance_valid(_dots_canvas):
				_dots_canvas.visible = false
			if is_instance_valid(_prompt_canvas):
				_prompt_canvas.visible = false

			# Instant cut camera back to player head
			if is_instance_valid(departing_player) and is_instance_valid(departing_player.camera):
				departing_player.camera.top_level = false
				departing_player.camera.transform = _original_cam_transform

			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			is_inspecting = false
			current_player = null,
		func() -> void:
			if is_instance_valid(departing_player):
				departing_player.unfreeze()
			_is_transitioning = false
			inspection_ended.emit(departing_player)
	)


func _unhandled_input(event: InputEvent) -> void:
	if not is_inspecting or _is_transitioning:
		return
	if is_instance_valid(ItemPickupScreenScript.instance) and ItemPickupScreenScript.instance.is_active:
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == exit_key:
		exit_inspection()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not is_inspecting or not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
		return
	if not current_player.camera.top_level:
		return
	if is_instance_valid(ItemPickupScreenScript.instance) and ItemPickupScreenScript.instance.is_active:
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


func _get_gameplay_screen_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return Rect2()
	var viewport_size := viewport.get_visible_rect().size
	var content_size := Vector2(
		minf(viewport_size.x, viewport_size.y * 4.0 / 3.0),
		minf(viewport_size.y, viewport_size.x * 3.0 / 4.0)
	)
	return Rect2((viewport_size - content_size) * 0.5, content_size)


func _update_hotspot_positions() -> void:
	if not is_instance_valid(current_player) or not is_instance_valid(current_player.camera):
		return

	if is_instance_valid(_active_dialogue_balloon):
		if is_instance_valid(_dots_canvas):
			_dots_canvas.visible = false
		return

	var cam := current_player.camera
	var safe_rect := _get_gameplay_screen_rect()

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
		if not safe_rect.has_point(screen_pos):
			btn.visible = false
			continue

		btn.position = screen_pos - btn.size * 0.5
		btn.visible = true


func _on_hotspot_clicked(hotspot: InspectionHotspot3D) -> void:
	if _is_transitioning or is_instance_valid(_active_dialogue_balloon) or not is_instance_valid(hotspot) or not hotspot.can_activate():
		return

	hotspot.activate()
	var has_dialogue: bool = hotspot.dialogue_resource != null or not hotspot.single_line_dialogue.strip_edges().is_empty()
	if has_dialogue:
		_play_hotspot_dialogue(hotspot)
	else:
		var is_pickup_spot: bool = hotspot.is_pickup or not hotspot.pickup_item_id.is_empty()
		if is_pickup_spot:
			var item_id: StringName = hotspot.pickup_item_id
			if item_id.is_empty():
				item_id = StringName(hotspot.hotspot_id)
			_trigger_hotspot_pickup(hotspot, item_id)


func _trigger_hotspot_pickup(hotspot: InspectionHotspot3D, item_id: StringName) -> void:
	if is_instance_valid(current_player) and is_instance_valid(current_player.inventory):
		current_player.inventory.add_item(item_id)

	if hotspot.trigger_once:
		hotspot.has_triggered = true
		if _hotspot_map.has(hotspot):
			var btn: InspectionDotButton = _hotspot_map[hotspot]
			if is_instance_valid(btn):
				btn.visible = false

	# Hide return prompt and hotspot icons while pickup screen is shown
	if is_instance_valid(_prompt_canvas):
		_prompt_canvas.visible = false
	if is_instance_valid(_dots_canvas):
		_dots_canvas.visible = false

	var on_pickup_closed := func() -> void:
		if is_inspecting and not _is_transitioning:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_instance_valid(_prompt_canvas):
				_prompt_canvas.visible = true
			if is_instance_valid(_dots_canvas):
				_dots_canvas.visible = true

	ItemPickupScreenScript.show_pickup(item_id, on_pickup_closed)


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

	# Hide return prompt and hotspot icons while dialogue is active
	if is_instance_valid(_prompt_canvas):
		_prompt_canvas.visible = false
	if is_instance_valid(_dots_canvas):
		_dots_canvas.visible = false

	# When dialogue ends, check if this hotspot grants an item pickup
	var on_dialogue_done := func() -> void:
		if _active_dialogue_balloon == balloon:
			_active_dialogue_balloon = null

		var is_pickup_spot: bool = hotspot.is_pickup or not hotspot.pickup_item_id.is_empty()
		if is_pickup_spot and is_inspecting and not _is_transitioning:
			var item_id: StringName = hotspot.pickup_item_id
			if item_id.is_empty():
				item_id = StringName(hotspot.hotspot_id)
			_trigger_hotspot_pickup(hotspot, item_id)
			return

		# Ensure mouse stays visible for further inspection and prompt/icons are restored
		if is_inspecting and not _is_transitioning:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			if is_instance_valid(_prompt_canvas):
				_prompt_canvas.visible = true
			if is_instance_valid(_dots_canvas):
				_dots_canvas.visible = true

	if balloon.has_signal("dialogue_finished"):
		balloon.connect("dialogue_finished", on_dialogue_done)
	balloon.tree_exited.connect(on_dialogue_done)

	if balloon.has_method("start"):
		balloon.call("start", res_to_play, cue_to_play)

