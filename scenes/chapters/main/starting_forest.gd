class_name StartingForest
extends Node3D

## Handles chapter entry for the starting forest:
## - Cinematic subtitle "five days later" fading in and out on black screen.
## - Full black screen fade out revealing the misty forest road.
## - Raised establishing camera holds, then descends into the player view.
## - Concurrent audio fade-in from 0 volume for all initial sound effects.
## - Cinematic handoff to opening dialogue and background music.

const SUBTITLE_FONT: FontFile = preload("res://fonts/HelveticaNeueCondensed.ttf")

@export_category("Intro Fade")
@export var auto_start_fade: bool = true
@export_range(0.5, 10.0, 0.05) var fade_duration: float = 3.75
@export_range(0.0, 3.0, 0.1) var initial_black_hold: float = 0.4
@export var delay_dialogue_until_fade: bool = true

@export_category("Intro Camera")
@export_range(0.0, 20.0, 0.1) var intro_camera_height: float = 5.0
@export_range(0.0, 10.0, 0.1) var intro_camera_hold_duration: float = 2.0
@export_range(0.1, 10.0, 0.1) var intro_camera_descent_duration: float = 3.0

@export_category("Intro Subtitle")
@export var show_intro_subtitle: bool = true
@export var subtitle_text: String = "five days later"
@export var subtitle_font: Font = SUBTITLE_FONT
@export var subtitle_font_size: int = 34
@export_range(0.1, 5.0, 0.1) var subtitle_fade_in_duration: float = 1.0
@export_range(0.5, 8.0, 0.1) var subtitle_hold_duration: float = 2.5
@export_range(0.1, 5.0, 0.1) var subtitle_fade_out_duration: float = 1.0
@export_range(0.0, 4.0, 0.1) var subtitle_pause_after: float = 0.5

@export_category("Audio Fade")
@export var initial_audio_players: Array[NodePath] = [
	NodePath("NightAmbience"),
	NodePath("toyotaCrownModel2/EngineLoop"),
	NodePath("freelanderSUV/EngineLoop"),
]

@export_category("Log Climb Music Transition")
@export var barrier_tree_node: NodePath = NodePath("Interactables/BarrierTree")
@export var welcoming_hike_stream: AudioStream = preload("res://music/welcomingHike.mp3")
@export_range(0.1, 10.0, 0.1) var music_fade_out_duration: float = 1.8
@export_range(0.1, 10.0, 0.1) var music_fade_in_duration: float = 2.4
@export_range(0.0, 5.0, 0.1) var music_fade_in_delay: float = 0.4
@export_range(-40.0, 6.0, 0.5) var welcoming_hike_volume_db: float = -12.0

@export_category("Log Fog Transition")
@export var fog_volume_node: NodePath = NodePath("FogVolume")
@export var fog_fade_in_duration: float = 2.5
@export var gas_station_fog_clear_duration: float = 6.0
@export var fog_size: Vector3 = Vector3(80.0, 8.0, 80.0)
@export var follow_player_y: bool = false
@export var fog_fixed_y: float = 2.0

@onready var player: FirstPersonPlayer = get_node_or_null("Player") as FirstPersonPlayer
@onready var opening_balloon: BottomDialogueBalloon = get_node_or_null("BottomDialogueBalloon") as BottomDialogueBalloon
@onready var visitor_bgm: AudioStreamPlayer = get_node_or_null("VisitorBGM") as AudioStreamPlayer
@onready var welcoming_hike_bgm: AudioStreamPlayer = get_node_or_null("WelcomingHikeBGM") as AudioStreamPlayer
@onready var fog_volume: FogVolume = get_node_or_null(fog_volume_node) as FogVolume

var _fade_canvas: CanvasLayer = null
var _black_screen: ColorRect = null
var subtitle_label: Label = null
var _fade_tween: Tween = null
var _is_fading: bool = false
var _has_faded: bool = false
var _target_volumes: Dictionary = {}
var _intro_camera: Camera3D
var _intro_camera_offset := 0.0
var _player_fog_was_visible := false
var _intro_ui_colors: Dictionary = {}
var _intro_ui_opacity := 1.0:
	set(value):
		_intro_ui_opacity = value
		for item in _intro_ui_colors:
			if is_instance_valid(item):
				var color: Color = _intro_ui_colors[item]
				color.a *= value
				item.modulate = color
var _has_switched_music: bool = false
var _music_transition_tween: Tween = null

var _is_fog_active: bool = false
var _fog_cleared_at_gas_station := false
var _fog_fade_tween: Tween = null
var _fog_target_density: float = 0.0
var _fog_material_instance: ShaderMaterial = null


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_setup_runtime_ambient_light()
	_ensure_player_on_floor()
	_setup_fade_ui()
	_setup_welcoming_hike_player()
	_setup_barrier_music_trigger()
	_setup_fog_volume()
	get_node("GasStation/FogClearArea").body_entered.connect(_on_gas_station_fog_clear_area_body_entered)
	_prepare_audio_players()

	if auto_start_fade:
		start_intro_fade()


func _setup_runtime_ambient_light() -> void:
	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		return
	# Keep the saved editor lighting separate from the runtime environment.
	world_environment.environment = world_environment.environment.duplicate() as Environment
	world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_environment.environment.ambient_light_color = Color.BLACK


func debug_jump_to_log(after_climb: bool = false) -> void:
	if not OS.is_debug_build():
		return
	var barrier := get_node_or_null(barrier_tree_node) as InteractableBlock3D
	if not is_instance_valid(player) or not is_instance_valid(barrier):
		push_warning("Forest debug checkpoint requires the player and BarrierTree.")
		return
	var destination := barrier.get_climb_over_teleport_node()
	if not is_instance_valid(destination):
		push_warning("Forest debug checkpoint requires ClimbOverTeleport.")
		return
	# Checkpoints bypass the opening cinematic and dialogue without starting them.
	delay_dialogue_until_fade = false
	finish_fade_immediately()
	if is_instance_valid(opening_balloon):
		opening_balloon.auto_start = false
		opening_balloon.hide()
		opening_balloon.queue_free()
		opening_balloon = null
	if is_instance_valid(player.inventory) and not player.has_item(&"map"):
		player.inventory.add_item(&"map")
	# Let the scene's deferred floor snap and collision registration finish first.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree() or not is_instance_valid(player) or not is_instance_valid(barrier):
		return
	if after_climb:
		var post_dialogue := barrier.trigger_post_teleport_dialogue
		barrier.trigger_post_teleport_dialogue = false
		barrier.climb_over_barrier(player)
		barrier.finish_climb_over_immediately()
		barrier.trigger_post_teleport_dialogue = post_dialogue
		finish_music_transition_immediately()
		finish_fog_transition_immediately()
	else:
		var direction := destination.global_position - barrier.global_position
		direction.y = 0.0
		direction = direction.normalized() if not direction.is_zero_approx() else Vector3.RIGHT
		player.global_position = barrier.global_position - direction * 3.0
		player.global_rotation.y = atan2(-direction.x, -direction.z)
		var head := player.get_node_or_null("Head") as Node3D
		if head != null:
			head.rotation.x = 0.0
		player.snap_to_ground()
	player.velocity = Vector3.ZERO
	player.unfreeze()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _ensure_player_on_floor() -> void:
	if not is_instance_valid(player):
		return
	if player.has_method(&"snap_to_ground"):
		player.snap_to_ground()
	_snap_player_deferred.call_deferred()


func _snap_player_deferred() -> void:
	if is_instance_valid(player) and is_inside_tree():
		await get_tree().physics_frame
		if is_instance_valid(player) and player.has_method(&"snap_to_ground"):
			player.snap_to_ground()


func _process(_delta: float) -> void:
	_update_intro_camera()
	if _is_fog_active:
		_update_fog_position()
	elif is_instance_valid(player) and _is_player_past_barrier():
		activate_fog()


func _is_player_past_barrier() -> bool:
	if not is_instance_valid(player):
		return false
	var barrier: Node3D = get_node_or_null(barrier_tree_node) as Node3D
	if not is_instance_valid(barrier):
		barrier = find_child("BarrierTree", true, false) as Node3D
	if is_instance_valid(barrier):
		if barrier.has_method("get_climb_over_teleport_node"):
			var destination := barrier.call("get_climb_over_teleport_node") as Node3D
			if is_instance_valid(destination):
				var direction := destination.global_position - barrier.global_position
				direction.y = 0.0
				if not direction.is_zero_approx():
					return (player.global_position - barrier.global_position).dot(direction.normalized()) > 2.0
		return player.global_position.x > (barrier.global_position.x + 2.0)
	return player.global_position.x > -95.0



func _setup_fade_ui() -> void:
	_fade_canvas = get_node_or_null("IntroFadeCanvas") as CanvasLayer
	if not is_instance_valid(_fade_canvas):
		_fade_canvas = CanvasLayer.new()
		_fade_canvas.name = "IntroFadeCanvas"
		_fade_canvas.layer = 105
		add_child(_fade_canvas)

	_black_screen = _fade_canvas.get_node_or_null("BlackScreen") as ColorRect
	if not is_instance_valid(_black_screen):
		_black_screen = ColorRect.new()
		_black_screen.name = "BlackScreen"
		_black_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_canvas.add_child(_black_screen)

	_black_screen.color = Color(0, 0, 0, 1.0)

	subtitle_label = _fade_canvas.get_node_or_null("SubtitleLabel") as Label
	if not is_instance_valid(subtitle_label):
		subtitle_label = Label.new()
		subtitle_label.name = "SubtitleLabel"
		_fade_canvas.add_child(subtitle_label)

	subtitle_label.text = subtitle_text
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	subtitle_label.offset_left = 30.0
	subtitle_label.offset_right = -30.0
	subtitle_label.offset_top = -120.0
	subtitle_label.offset_bottom = -60.0
	subtitle_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	subtitle_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var applied_font: Font = subtitle_font if subtitle_font != null else SUBTITLE_FONT
	subtitle_label.add_theme_font_override("font", applied_font)
	subtitle_label.add_theme_font_size_override("font_size", subtitle_font_size)
	subtitle_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	subtitle_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	subtitle_label.add_theme_constant_override("outline_size", 4)
	subtitle_label.modulate.a = 0.0

	_fade_canvas.visible = true


func _collect_sound_effects() -> Array[Node]:
	var result: Array[Node] = []
	for np in initial_audio_players:
		var n := get_node_or_null(np)
		if is_instance_valid(n) and not result.has(n):
			result.append(n)

	# Include any autoplay audio streams in the scene except VisitorBGM and WelcomingHikeBGM
	for child in find_children("*", "AudioStreamPlayer", true, false):
		if child != visitor_bgm and child != welcoming_hike_bgm and not result.has(child):
			if child.autoplay or child.playing:
				result.append(child)

	for child in find_children("*", "AudioStreamPlayer3D", true, false):
		if not result.has(child):
			if child.autoplay or child.playing:
				result.append(child)

	return result


func _prepare_audio_players() -> void:
	var sfx_nodes := _collect_sound_effects()
	for sfx in sfx_nodes:
		var target_db: float = sfx.volume_db
		_target_volumes[sfx] = target_db
		# Start from 0 volume (inaudible floor -80 dB)
		sfx.volume_db = -80.0
		if not sfx.playing:
			sfx.play()


func start_intro_fade() -> void:
	if _has_faded or _is_fading:
		return

	_is_fading = true

	# Freeze player during black screen hold, subtitle, and fade (ensuring grounded on floor)
	if is_instance_valid(player):
		if player.has_method(&"snap_to_ground"):
			player.snap_to_ground()
		if player.has_method(&"freeze"):
			player.freeze()

	_setup_intro_camera()
	_hide_intro_player_ui()
	_fade_tween = create_tween()

	# Subtitle sequence (before fading in the actual game)
	if show_intro_subtitle and not subtitle_text.is_empty() and is_instance_valid(subtitle_label):
		if initial_black_hold > 0.0:
			_fade_tween.tween_interval(initial_black_hold)

		# Subtitle fades in
		_fade_tween.tween_property(
			subtitle_label,
			"modulate:a",
			1.0,
			subtitle_fade_in_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Hold for a few seconds
		if subtitle_hold_duration > 0.0:
			_fade_tween.tween_interval(subtitle_hold_duration)

		# Subtitle fades out
		_fade_tween.tween_property(
			subtitle_label,
			"modulate:a",
			0.0,
			subtitle_fade_out_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

		# Brief pause after subtitle before fading in the actual game
		if subtitle_pause_after > 0.0:
			_fade_tween.tween_interval(subtitle_pause_after)
	elif initial_black_hold > 0.0:
		_fade_tween.tween_interval(initial_black_hold)

	# Fading in the actual game (black screen fades out + audio fades in, 50% slower)
	_fade_tween.chain().set_parallel(true)

	# Black screen fade out
	if is_instance_valid(_black_screen):
		_fade_tween.tween_property(
			_black_screen,
			"color:a",
			0.0,
			fade_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Sound effects volume fade in together starting from 0 volume
	var sfx_nodes := _collect_sound_effects()
	for sfx in sfx_nodes:
		var target_db: float = _target_volumes.get(sfx, sfx.volume_db)
		var target_linear: float = db_to_linear(target_db)
		var update_vol := func(val: float) -> void:
			if is_instance_valid(sfx):
				sfx.volume_db = linear_to_db(maxf(val, 0.0001))
		_fade_tween.tween_method(
			update_vol,
			0.0,
			target_linear,
			fade_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if is_instance_valid(_intro_camera):
		if intro_camera_hold_duration > 0.0:
			_fade_tween.chain().tween_interval(intro_camera_hold_duration)
		_fade_tween.chain().tween_property(
			self, "_intro_camera_offset", 0.0, intro_camera_descent_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_fade_tween.parallel().tween_property(
			self, "_intro_ui_opacity", 1.0, intro_camera_descent_duration
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.chain().tween_callback(_on_fade_finished)


func _hide_intro_player_ui() -> void:
	if not is_instance_valid(player):
		return
	_intro_ui_colors.clear()
	# Fade UI roots so child HUD animations can keep their own opacity settings.
	for canvas in player.find_children("*", "CanvasLayer", true, false):
		for child in canvas.get_children():
			if child is CanvasItem:
				_intro_ui_colors[child] = child.modulate
	_intro_ui_opacity = 0.0


func _restore_intro_player_ui() -> void:
	_intro_ui_opacity = 1.0
	_intro_ui_colors.clear()


func _setup_intro_camera() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	# Copy the projection settings, keeping gameplay attachments on the player camera.
	_intro_camera = player.camera.duplicate(0) as Camera3D
	_intro_camera.name = "ForestIntroCamera"
	for child in _intro_camera.get_children():
		child.free()
	player.camera.add_child(_intro_camera)
	_intro_camera_offset = intro_camera_height
	_update_intro_camera()
	if is_instance_valid(player.distance_fog):
		_player_fog_was_visible = player.distance_fog.visible
		var intro_fog := player.distance_fog.duplicate() as MeshInstance3D
		_intro_camera.add_child(intro_fog)
		player.distance_fog.hide()
	_intro_camera.make_current()


func _update_intro_camera() -> void:
	if not is_instance_valid(_intro_camera) or not is_instance_valid(player) or not is_instance_valid(player.camera):
		return
	# Follow floor snapping so the final camera transform matches the live player view.
	_intro_camera.global_transform = player.camera.global_transform
	_intro_camera.global_position += Vector3.UP * _intro_camera_offset


func _restore_player_camera() -> void:
	if not is_instance_valid(_intro_camera):
		return
	if is_instance_valid(player):
		if is_instance_valid(player.camera):
			player.camera.make_current()
		if is_instance_valid(player.distance_fog):
			player.distance_fog.visible = _player_fog_was_visible
	_intro_camera.queue_free()
	_intro_camera = null
	_intro_camera_offset = 0.0


func skip_fade() -> void:
	if not _is_fading or _has_faded:
		return
	if is_instance_valid(_fade_tween) and _fade_tween.is_valid():
		_fade_tween.kill()
	_on_fade_finished()


func finish_fade_immediately() -> void:
	skip_fade()


func _unhandled_input(event: InputEvent) -> void:
	if _is_fading and not _has_faded:
		if event.is_action_pressed(&"ui_accept") or event.is_action_pressed(&"ui_cancel") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			skip_fade()
			get_viewport().set_input_as_handled()


func _on_fade_finished() -> void:
	_restore_player_camera()
	_restore_intro_player_ui()
	_is_fading = false
	_has_faded = true

	# Ensure all audio players reach exact target volume
	for sfx in _target_volumes.keys():
		if is_instance_valid(sfx):
			sfx.volume_db = _target_volumes[sfx]

	# Clean up black screen overlay and subtitle
	if is_instance_valid(_fade_canvas):
		_fade_canvas.visible = false
		_fade_canvas.queue_free()
		_fade_canvas = null
		_black_screen = null
		subtitle_label = null

	# Trigger opening dialogue if configured
	if delay_dialogue_until_fade and is_instance_valid(opening_balloon):
		if opening_balloon.dialogue_resource != null:
			opening_balloon.start(opening_balloon.dialogue_resource, opening_balloon.start_from_cue)
			return

	# If no opening dialogue, restore player movement
	if is_instance_valid(player) and player.has_method(&"unfreeze"):
		player.unfreeze()


func _setup_welcoming_hike_player() -> void:
	if not is_instance_valid(welcoming_hike_bgm):
		welcoming_hike_bgm = get_node_or_null("WelcomingHikeBGM") as AudioStreamPlayer
	if not is_instance_valid(welcoming_hike_bgm):
		welcoming_hike_bgm = AudioStreamPlayer.new()
		welcoming_hike_bgm.name = "WelcomingHikeBGM"
		welcoming_hike_bgm.process_mode = Node.PROCESS_MODE_ALWAYS
		welcoming_hike_bgm.stream = welcoming_hike_stream if welcoming_hike_stream != null else preload("res://music/welcomingHike.mp3")
		welcoming_hike_bgm.volume_db = -80.0
		welcoming_hike_bgm.bus = &"Music"
		add_child(welcoming_hike_bgm)

	if welcoming_hike_bgm.stream is AudioStreamMP3:
		(welcoming_hike_bgm.stream as AudioStreamMP3).loop = true
	if not welcoming_hike_bgm.finished.is_connected(welcoming_hike_bgm.play):
		welcoming_hike_bgm.finished.connect(welcoming_hike_bgm.play)


func _setup_barrier_music_trigger() -> void:
	var barrier: InteractableBlock3D = get_node_or_null(barrier_tree_node) as InteractableBlock3D
	if not is_instance_valid(barrier):
		barrier = find_child("BarrierTree", true, false) as InteractableBlock3D
	if is_instance_valid(barrier):
		if not barrier.climb_over_started.is_connected(_on_climb_over_started):
			barrier.climb_over_started.connect(_on_climb_over_started)
		if not barrier.climb_over_completed.is_connected(_on_climb_over_completed):
			barrier.climb_over_completed.connect(_on_climb_over_completed)


func _on_climb_over_started(_player: Node3D = null) -> void:
	transition_to_welcoming_hike()
	activate_fog()


func _on_climb_over_completed(_player: Node3D = null) -> void:
	activate_fog()
	var silo_ambience := get_node_or_null("SiloTreeExclusionZone/SiloAmbience")
	if is_instance_valid(silo_ambience):
		silo_ambience.start_ambience()


func transition_to_welcoming_hike(fade_out_time: float = music_fade_out_duration, fade_in_time: float = music_fade_in_duration) -> void:
	if _has_switched_music:
		return
	_has_switched_music = true

	# Ensure VisitorBGM will not trigger or loop again
	if is_instance_valid(visitor_bgm):
		if is_instance_valid(opening_balloon) and opening_balloon.dialogue_finished.is_connected(visitor_bgm.play):
			opening_balloon.dialogue_finished.disconnect(visitor_bgm.play)
		if visitor_bgm.finished.is_connected(visitor_bgm.play):
			visitor_bgm.finished.disconnect(visitor_bgm.play)

	_setup_welcoming_hike_player()

	if is_instance_valid(_music_transition_tween) and _music_transition_tween.is_valid():
		_music_transition_tween.kill()

	_music_transition_tween = create_tween().set_parallel(true)

	# 1. Fade out VisitorBGM
	if is_instance_valid(visitor_bgm) and visitor_bgm.playing:
		var v_start_linear: float = db_to_linear(visitor_bgm.volume_db)
		var update_visitor_vol := func(val: float) -> void:
			if is_instance_valid(visitor_bgm):
				visitor_bgm.volume_db = linear_to_db(maxf(val, 0.0001))

		_music_transition_tween.tween_method(
			update_visitor_vol,
			v_start_linear,
			0.0001,
			fade_out_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		_music_transition_tween.tween_callback(func() -> void:
			if is_instance_valid(visitor_bgm):
				visitor_bgm.stop()
				visitor_bgm.volume_db = -80.0
		).set_delay(fade_out_time)
	elif is_instance_valid(visitor_bgm):
		visitor_bgm.stop()
		visitor_bgm.volume_db = -80.0

	# 2. Fade in WelcomingHikeBGM
	if is_instance_valid(welcoming_hike_bgm):
		welcoming_hike_bgm.volume_db = -80.0
		if not welcoming_hike_bgm.playing:
			welcoming_hike_bgm.play()

		var h_target_linear: float = db_to_linear(welcoming_hike_volume_db)
		var update_hike_vol := func(val: float) -> void:
			if is_instance_valid(welcoming_hike_bgm):
				welcoming_hike_bgm.volume_db = linear_to_db(maxf(val, 0.0001))

		var hike_tweener := _music_transition_tween.tween_method(
			update_hike_vol,
			0.0001,
			h_target_linear,
			fade_in_time
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		if music_fade_in_delay > 0.0:
			hike_tweener.set_delay(music_fade_in_delay)


func finish_music_transition_immediately() -> void:
	if is_instance_valid(_music_transition_tween) and _music_transition_tween.is_valid():
		_music_transition_tween.kill()
	if is_instance_valid(visitor_bgm):
		visitor_bgm.volume_db = -80.0
		visitor_bgm.stop()
	if is_instance_valid(welcoming_hike_bgm):
		welcoming_hike_bgm.volume_db = welcoming_hike_volume_db
		if not welcoming_hike_bgm.playing:
			welcoming_hike_bgm.play()


func _setup_fog_volume() -> void:
	if not is_instance_valid(fog_volume):
		fog_volume = get_node_or_null(fog_volume_node) as FogVolume
	if not is_instance_valid(fog_volume):
		fog_volume = find_child("FogVolume", true, false) as FogVolume
	if not is_instance_valid(fog_volume):
		var volumes := find_children("*", "FogVolume", true, false)
		if not volumes.is_empty():
			fog_volume = volumes[0] as FogVolume

	# Fallback: automatically instantiate FogVolume if none was added in the scene tree
	if not is_instance_valid(fog_volume):
		fog_volume = FogVolume.new()
		fog_volume.name = "FogVolume"
		fog_volume.size = fog_size
		var default_mat := load("res://shaders/moving_gradient_noise_fog_material.tres") as ShaderMaterial
		if default_mat != null:
			fog_volume.material = default_mat
		add_child(fog_volume)

	# Ensure it is hidden initially until player gets over the log
	fog_volume.visible = false

	if fog_volume.material is ShaderMaterial:
		_fog_material_instance = fog_volume.material.duplicate()
		fog_volume.material = _fog_material_instance
		var base_den = _fog_material_instance.get_shader_parameter("base_density")
		# Fade to the density saved in the editor, including an intentional zero.
		_fog_target_density = maxf(float(base_den), 0.0) if base_den != null else 0.0
		_fog_material_instance.set_shader_parameter("base_density", 0.0)

	_update_fog_position()


func activate_fog(fade_duration: float = fog_fade_in_duration) -> void:
	if _is_fog_active or _fog_cleared_at_gas_station:
		return
	_is_fog_active = true

	if not is_instance_valid(fog_volume):
		_setup_fog_volume()
	if not is_instance_valid(fog_volume):
		return

	_update_fog_position()
	fog_volume.visible = true

	if is_instance_valid(_fog_material_instance):
		if is_instance_valid(_fog_fade_tween) and _fog_fade_tween.is_valid():
			_fog_fade_tween.kill()

		if fade_duration <= 0.0:
			_fog_material_instance.set_shader_parameter("base_density", _fog_target_density)
		else:
			_fog_fade_tween = create_tween()
			_fog_fade_tween.tween_method(
				func(val: float) -> void:
					if is_instance_valid(_fog_material_instance):
						_fog_material_instance.set_shader_parameter("base_density", val),
				0.0,
				_fog_target_density,
				fade_duration
			).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _update_fog_position() -> void:
	if not is_instance_valid(fog_volume) or not is_instance_valid(player):
		return
	if fog_volume.get_parent() == player:
		return
	var target_y := player.global_position.y + 1.5 if follow_player_y else fog_fixed_y
	fog_volume.global_position = Vector3(player.global_position.x, target_y, player.global_position.z)


func finish_fog_transition_immediately() -> void:
	if _fog_cleared_at_gas_station:
		return
	if not _is_fog_active:
		activate_fog(0.0)
	if is_instance_valid(_fog_fade_tween) and _fog_fade_tween.is_valid():
		_fog_fade_tween.kill()
	if is_instance_valid(_fog_material_instance):
		_fog_material_instance.set_shader_parameter("base_density", _fog_target_density)


func _on_gas_station_fog_clear_area_body_entered(body: Node3D) -> void:
	if body != player or _fog_cleared_at_gas_station:
		return
	_fog_cleared_at_gas_station = true
	if is_instance_valid(_fog_fade_tween) and _fog_fade_tween.is_valid():
		_fog_fade_tween.kill()
	var duration := maxf(gas_station_fog_clear_duration, 0.01)
	_fog_fade_tween = create_tween().set_parallel(true)
	if is_instance_valid(_fog_material_instance):
		_fog_fade_tween.tween_property(_fog_material_instance, "shader_parameter/base_density", 0.0, duration)
	var world := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if is_instance_valid(world) and world.environment != null:
		# Keep the fade local to this scene rather than changing a shared resource.
		world.environment = world.environment.duplicate() as Environment
		_fog_fade_tween.tween_property(world.environment, "fog_density", 0.0, duration)
		_fog_fade_tween.tween_property(world.environment, "volumetric_fog_density", 0.0, duration)
	var distance_material := player.get_distance_fog_material()
	if distance_material != null:
		distance_material = distance_material.duplicate() as ShaderMaterial
		player.distance_fog.material_override = distance_material
		if distance_material.get_shader_parameter("fog_strength") == null:
			distance_material.set_shader_parameter("fog_strength", 1.0)
		_fog_fade_tween.tween_property(distance_material, "shader_parameter/fog_strength", 0.0, duration)
	_fog_fade_tween.finished.connect(func() -> void:
		_is_fog_active = false
		if is_instance_valid(fog_volume):
			fog_volume.hide()
		if is_instance_valid(player):
			player.set_distance_fog_enabled(false)
		if is_instance_valid(world) and world.environment != null:
			world.environment.fog_enabled = false
			world.environment.volumetric_fog_enabled = false
	)
