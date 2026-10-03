extends CanvasLayer

const SETTINGS_PATH := "user://audio_settings.cfg"
const PAUSE_MUSIC_BOOST: float = 1.30
const MUSIC_TWEEN_DURATION: float = 0.4
const DISTORTION_IN_DURATION: float = 0.32
const DISTORTION_OUT_DURATION: float = 0.24

const TITLE_FONT_SIZE: int = 44
const SELECTED_FONT_SIZE: int = 32
const UNSELECTED_FONT_SIZE: int = 24
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const UNSELECTED_COLOR: Color = Color(0.65, 0.65, 0.65, 0.65)
const PAUSE_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/ui/pause1.mp3"),
	preload("res://sounds/ui/pause2.mp3")
]

var opened: bool = false
var overlay: Control
var previous_mouse: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var sliders: Dictionary = {}
var has_started_chapter: bool = false
var changing_scene: bool = false

var is_in_options: bool = false
var selected_index: int = 0
var master_volume_percent: int = 80
var music_volume_percent: int = 80

var _is_transitioning: bool = false
var _music_base_volume: float = 1.0
var _pause_music_scale: float = 1.0
var _music_tween: Tween = null
var _distortion_tween: Tween = null

var _distortion_rect: ColorRect = null
var _distortion_material: ShaderMaterial = null
var _menu_container: VBoxContainer = null
var _title_label: Label = null
var _items_vbox: VBoxContainer = null
var _labels: Array[Label] = []

var _pause_sfx_player: AudioStreamPlayer = null
var _move_sfx_player: AudioStreamPlayer = null
var _click_sfx_player: AudioStreamPlayer = null

var _main_menu_items: Array[Dictionary] = []
var _options_menu_items: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 99

	for bus: String in ["Effects", "Footsteps"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Footsteps"), "Reverb")
	for bus: String in ["InGameFootage", "Reverb"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_send(index, "Effects")

	# Sliders dictionary initialized for compatibility with mainMenu/menu.gd
	for bus: String in ["Master", "Music", "Effects", "Footsteps"]:
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.01
		sliders[bus] = slider

	_build_menu()

	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for bus: String in sliders:
		(sliders[bus] as HSlider).value = float(config.get_value("volume", bus, 1.0))
		_set_volume((sliders[bus] as HSlider).value, bus)

	master_volume_percent = roundi((sliders["Master"] as HSlider).value * 100)
	music_volume_percent = roundi((sliders["Music"] as HSlider).value * 100)

	_main_menu_items = [
		{"action": func(): set_open(false)},
		{"action": func(): _open_options()},
		{"action": func(): return_to_main_menu()},
		{"action": func(): _save_settings(); get_tree().quit()}
	]

	_options_menu_items = [
		{"action": func(): _toggle_master_volume_step()},
		{"action": func(): _toggle_music_volume_step()},
		{"action": func(): _close_options()}
	]

	get_tree().node_added.connect(_route_audio)
	_ensure_audio_process_modes()


func _route_audio(node: Node) -> void:
	if str(node.name).begins_with("Pause"):
		return
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		if str(node.name).begins_with("FootstepPlayer"):
			node.set("bus", &"Footsteps")
		elif node.get("bus") == &"Master":
			node.set("bus", &"Effects")

		var bus_name: StringName = node.get("bus")
		var is_music: bool = (bus_name == &"Music" or str(node.name).to_lower().contains("music") or str(node.name).to_lower().contains("bgm"))
		if is_music:
			if bus_name != &"Music":
				node.set("bus", &"Music")
			node.process_mode = Node.PROCESS_MODE_ALWAYS
		else:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE


func _ensure_audio_process_modes(node: Node = null) -> void:
	if node == null:
		node = get_tree().root
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D or node is AudioStreamPlayer2D:
		_route_audio(node)
	for child: Node in node.get_children():
		_ensure_audio_process_modes(child)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return

	# When paused menu is closed, check for Escape to pause
	if not opened:
		if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
			if not get_tree().paused and not _is_transitioning:
				var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
				if player == null or player.is_frozen:
					return
				set_open(true)
				get_viewport().set_input_as_handled()
		return

	# When pause menu is open
	if _is_transitioning or changing_scene:
		get_viewport().set_input_as_handled()
		return

	var active_count: int = _options_menu_items.size() if is_in_options else _main_menu_items.size()

	# Escape key / Cancel
	if event.is_action_pressed(&"ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE):
		if is_in_options:
			_close_options()
		else:
			set_open(false)
		get_viewport().set_input_as_handled()
		return

	# Up Arrow / W key
	if event.is_action_pressed("ui_up") or (event is InputEventKey and (event.keycode == KEY_UP or event.keycode == KEY_W)):
		selected_index = (selected_index - 1 + active_count) % active_count
		_update_menu_display(true)
		get_viewport().set_input_as_handled()
		return

	# Down Arrow / S key
	if event.is_action_pressed("ui_down") or (event is InputEventKey and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
		selected_index = (selected_index + 1) % active_count
		_update_menu_display(true)
		get_viewport().set_input_as_handled()
		return

	# Left Arrow / A key (Adjust volume down in Options)
	if is_in_options and (event.is_action_pressed("ui_left") or (event is InputEventKey and (event.keycode == KEY_LEFT or event.keycode == KEY_A))):
		_adjust_volume(-10)
		get_viewport().set_input_as_handled()
		return

	# Right Arrow / D key (Adjust volume up in Options)
	if is_in_options and (event.is_action_pressed("ui_right") or (event is InputEventKey and (event.keycode == KEY_RIGHT or event.keycode == KEY_D))):
		_adjust_volume(10)
		get_viewport().set_input_as_handled()
		return

	# Enter / Space key (Select current option)
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		_trigger_current_option()
		get_viewport().set_input_as_handled()
		return


func _process(_delta: float) -> void:
	if not opened:
		return
	var active_count: int = _options_menu_items.size() if is_in_options else _main_menu_items.size()
	for i in range(active_count):
		if i >= _labels.size() or not _labels[i].visible:
			continue
		if i == selected_index:
			var flash: float = (sin(Time.get_ticks_msec() * 0.006) + 1.0) * 0.5
			_labels[i].modulate = Color(1.0, 1.0, 1.0, lerp(0.75, 1.0, flash))
		else:
			_labels[i].modulate = UNSELECTED_COLOR


func set_open(value: bool) -> void:
	if value == opened or _is_transitioning:
		return

	if value:
		opened = true
		_is_transitioning = true
		_play_random_pause_sound()
		_update_distortion_rect_bounds()
		overlay.visible = true
		is_in_options = false
		selected_index = 0
		_update_menu_display(false)

		previous_mouse = Input.mouse_mode
		_ensure_audio_process_modes()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_tween_music_scale(PAUSE_MUSIC_BOOST)

		if _distortion_tween and _distortion_tween.is_valid():
			_distortion_tween.kill()

		_distortion_material.set_shader_parameter("distortion_strength", 0.0)
		_menu_container.modulate.a = 0.0

		_distortion_tween = create_tween().set_parallel(true)
		_distortion_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_distortion_tween.tween_property(_distortion_material, "shader_parameter/distortion_strength", 1.0, DISTORTION_IN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_distortion_tween.tween_property(_menu_container, "modulate:a", 1.0, DISTORTION_IN_DURATION * 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_distortion_tween.chain().tween_callback(func():
			_is_transitioning = false
		)
	else:
		_is_transitioning = true
		_play_random_pause_sound()
		_save_settings()

		if _distortion_tween and _distortion_tween.is_valid():
			_distortion_tween.kill()

		_distortion_tween = create_tween().set_parallel(true)
		_distortion_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_distortion_tween.tween_property(_menu_container, "modulate:a", 0.0, DISTORTION_OUT_DURATION * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_distortion_tween.tween_property(_distortion_material, "shader_parameter/distortion_strength", 0.0, DISTORTION_OUT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_distortion_tween.chain().tween_callback(func():
			overlay.visible = false
			opened = false
			get_tree().paused = false
			Input.mouse_mode = previous_mouse
			_is_transitioning = false
			is_in_options = false
		)
		_tween_music_scale(1.0)


func _play_random_pause_sound() -> void:
	if not is_instance_valid(_pause_sfx_player) or PAUSE_SOUNDS.is_empty():
		return
	var sound: AudioStream = PAUSE_SOUNDS.pick_random()
	_pause_sfx_player.stream = sound
	_pause_sfx_player.pitch_scale = randf_range(0.94, 1.06)
	_pause_sfx_player.play()


func _update_distortion_rect_bounds() -> void:
	if not is_instance_valid(_distortion_rect) or not is_instance_valid(_distortion_material):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var vp_size: Vector2 = vp.get_visible_rect().size
	if vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return

	var rect_min := Vector2(0.125, 0.0)
	var rect_size := Vector2(0.75, 1.0)

	var gr: Rect2 = _distortion_rect.get_global_rect()
	if gr.size.x > 0.0 and gr.size.y > 0.0:
		rect_min = Vector2(gr.position.x / vp_size.x, gr.position.y / vp_size.y)
		rect_size = Vector2(gr.size.x / vp_size.x, gr.size.y / vp_size.y)
	else:
		var vp_ar: float = vp_size.x / vp_size.y
		var target_ar: float = 4.0 / 3.0
		if vp_ar >= target_ar:
			var w_fraction := target_ar / vp_ar
			rect_size = Vector2(w_fraction, 1.0)
			rect_min = Vector2((1.0 - w_fraction) * 0.5, 0.0)
		else:
			var h_fraction := vp_ar / target_ar
			rect_size = Vector2(1.0, h_fraction)
			rect_min = Vector2(0.0, (1.0 - h_fraction) * 0.5)

	_distortion_material.set_shader_parameter("content_rect_min", rect_min)
	_distortion_material.set_shader_parameter("content_rect_size", rect_size)


func _build_menu() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	# 4:3 AspectRatio container matching CRT overlay
	var arc := AspectRatioContainer.new()
	arc.ratio = 1.33333
	arc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(arc)

	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arc.add_child(content)

	# 4:3 analog distortion background within CRT content
	_distortion_rect = ColorRect.new()
	_distortion_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_distortion_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_mat: ShaderMaterial = preload("res://shaders/analog_distortion_material.tres")
	_distortion_material = base_mat.duplicate() as ShaderMaterial
	_distortion_material.set_shader_parameter("distortion_strength", 0.0)
	_distortion_rect.material = _distortion_material
	content.add_child(_distortion_rect)

	_distortion_rect.resized.connect(_update_distortion_rect_bounds)
	get_viewport().size_changed.connect(_update_distortion_rect_bounds)

	# UI Sound Players
	_pause_sfx_player = AudioStreamPlayer.new()
	_pause_sfx_player.name = "PauseSfxPlayer"
	_pause_sfx_player.volume_db = -6.0
	_pause_sfx_player.bus = &"Master"
	_pause_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_sfx_player)

	_move_sfx_player = AudioStreamPlayer.new()
	_move_sfx_player.name = "PauseMoveSfxPlayer"
	_move_sfx_player.stream = preload("res://sounds/ui/move.mp3")
	_move_sfx_player.volume_db = -10.0
	_move_sfx_player.bus = &"Master"
	_move_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_move_sfx_player)

	_click_sfx_player = AudioStreamPlayer.new()
	_click_sfx_player.name = "PauseClickSfxPlayer"
	_click_sfx_player.stream = preload("res://sounds/ui/click.mp3")
	_click_sfx_player.volume_db = -10.0
	_click_sfx_player.bus = &"Master"
	_click_sfx_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click_sfx_player)

	# Centered text container for Silent Hill style presentation
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(center)

	_menu_container = VBoxContainer.new()
	_menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu_container.add_theme_constant_override("separation", 28)
	_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_menu_container)

	var menu_font: Font = preload("res://fonts/EuropeanTeletextNuevo.ttf")

	# "PAUSED" title
	_title_label = Label.new()
	_title_label.text = "PAUSED"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_override("font", menu_font)
	_title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	_title_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_title_label.add_theme_constant_override("shadow_offset_x", 2)
	_title_label.add_theme_constant_override("shadow_offset_y", 2)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_container.add_child(_title_label)

	# Menu options container
	_items_vbox = VBoxContainer.new()
	_items_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_items_vbox.add_theme_constant_override("separation", 16)
	_items_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_container.add_child(_items_vbox)

	_labels.clear()
	for i in range(4):
		var lbl := Label.new()
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_override("font", menu_font)
		lbl.add_theme_font_size_override("font_size", UNSELECTED_FONT_SIZE)
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 2)
		lbl.add_theme_constant_override("shadow_offset_y", 2)
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		lbl.mouse_entered.connect(func(): _on_label_hover(idx))
		lbl.gui_input.connect(func(ev: InputEvent): _on_label_gui_input(ev, idx))
		_items_vbox.add_child(lbl)
		_labels.append(lbl)

	# Pillarbox gutters to guarantee pure black outside the 4:3 area on layer 99
	var right_gutter := ColorRect.new()
	right_gutter.name = "RightGutter"
	right_gutter.color = Color(0, 0, 0, 1)
	right_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	right_gutter.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_gutter.offset_left = 0.0
	right_gutter.offset_right = 4000.0
	right_gutter.offset_top = -2000.0
	right_gutter.offset_bottom = 2000.0
	content.add_child(right_gutter)

	var left_gutter := ColorRect.new()
	left_gutter.name = "LeftGutter"
	left_gutter.color = Color(0, 0, 0, 1)
	left_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	left_gutter.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_gutter.offset_left = -4000.0
	left_gutter.offset_right = 0.0
	left_gutter.offset_top = -2000.0
	left_gutter.offset_bottom = 2000.0
	content.add_child(left_gutter)

	var top_gutter := ColorRect.new()
	top_gutter.name = "TopGutter"
	top_gutter.color = Color(0, 0, 0, 1)
	top_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	top_gutter.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_gutter.offset_left = -4000.0
	top_gutter.offset_right = 4000.0
	top_gutter.offset_top = -4000.0
	top_gutter.offset_bottom = 0.0
	content.add_child(top_gutter)

	var bottom_gutter := ColorRect.new()
	bottom_gutter.name = "BottomGutter"
	bottom_gutter.color = Color(0, 0, 0, 1)
	bottom_gutter.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_gutter.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_gutter.offset_left = -4000.0
	bottom_gutter.offset_right = 4000.0
	bottom_gutter.offset_top = 0.0
	bottom_gutter.offset_bottom = 4000.0
	content.add_child(bottom_gutter)

	overlay.hide()


func _update_menu_display(play_sound: bool = true) -> void:
	if _labels.is_empty():
		return

	if is_in_options:
		_title_label.text = "OPTIONS"
		_labels[0].text = "Master Volume: < " + str(master_volume_percent) + "% >"
		_labels[1].text = "Music Volume: < " + str(music_volume_percent) + "% >"
		_labels[2].text = "Back"
		_labels[0].show()
		_labels[1].show()
		_labels[2].show()
		_labels[3].hide()

		for i in range(3):
			_apply_label_style(_labels[i], i == selected_index)
	else:
		_title_label.text = "PAUSED"
		_labels[0].text = "Resume"
		_labels[1].text = "Options"
		_labels[2].text = "Main Menu"
		_labels[3].text = "Quit"
		_labels[0].show()
		_labels[1].show()
		_labels[2].show()
		_labels[3].show()

		for i in range(4):
			_apply_label_style(_labels[i], i == selected_index)

	if play_sound and _move_sfx_player:
		_move_sfx_player.play()


func _apply_label_style(lbl: Label, is_selected: bool) -> void:
	if is_selected:
		lbl.add_theme_font_size_override("font_size", SELECTED_FONT_SIZE)
		lbl.modulate = SELECTED_COLOR
	else:
		lbl.add_theme_font_size_override("font_size", UNSELECTED_FONT_SIZE)
		lbl.modulate = UNSELECTED_COLOR


func _on_label_hover(idx: int) -> void:
	if _is_transitioning or not opened or selected_index == idx:
		return
	var active_count: int = _options_menu_items.size() if is_in_options else _main_menu_items.size()
	if idx < active_count:
		selected_index = idx
		_update_menu_display(true)


func _on_label_gui_input(event: InputEvent, idx: int) -> void:
	if _is_transitioning or not opened:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var active_count: int = _options_menu_items.size() if is_in_options else _main_menu_items.size()
		if idx < active_count:
			selected_index = idx
			_update_menu_display(false)
			_trigger_current_option()


func _trigger_current_option() -> void:
	if _click_sfx_player:
		_click_sfx_player.play()
	if is_in_options:
		if selected_index >= 0 and selected_index < _options_menu_items.size():
			_options_menu_items[selected_index]["action"].call()
	else:
		if selected_index >= 0 and selected_index < _main_menu_items.size():
			_main_menu_items[selected_index]["action"].call()


func _open_options() -> void:
	is_in_options = true
	selected_index = 0
	_update_menu_display(false)


func _close_options() -> void:
	is_in_options = false
	selected_index = 1
	_update_menu_display(false)


func _adjust_volume(delta: int) -> void:
	if selected_index == 0:
		master_volume_percent = clampi(master_volume_percent + delta, 0, 100)
		_apply_master_volume()
		_update_menu_display(true)
	elif selected_index == 1:
		music_volume_percent = clampi(music_volume_percent + delta, 0, 100)
		_apply_music_volume()
		_update_menu_display(true)


func _toggle_master_volume_step() -> void:
	master_volume_percent = (master_volume_percent + 10) if master_volume_percent < 100 else 0
	_apply_master_volume()
	_update_menu_display(false)


func _toggle_music_volume_step() -> void:
	music_volume_percent = (music_volume_percent + 10) if music_volume_percent < 100 else 0
	_apply_music_volume()
	_update_menu_display(false)


func _apply_master_volume() -> void:
	if sliders.has("Master"):
		(sliders["Master"] as HSlider).value = float(master_volume_percent) / 100.0
	_set_volume(float(master_volume_percent) / 100.0, "Master")
	_save_settings()


func _apply_music_volume() -> void:
	if sliders.has("Music"):
		(sliders["Music"] as HSlider).value = float(music_volume_percent) / 100.0
	_set_volume(float(music_volume_percent) / 100.0, "Music")
	_save_settings()


func return_to_main_menu() -> void:
	if changing_scene:
		return
	changing_scene = true
	get_viewport().set_input_as_handled()
	_finish_return_to_menu.call_deferred()


func _finish_return_to_menu() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if _distortion_tween and _distortion_tween.is_valid():
		_distortion_tween.kill()
	if _distortion_material:
		_distortion_material.set_shader_parameter("distortion_strength", 0.0)
	overlay.visible = false
	opened = false
	_is_transitioning = false
	is_in_options = false
	_pause_music_scale = 1.0
	_apply_music_bus_volume()
	get_tree().call_group("opening_story", "_save")
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var departing := get_tree().current_scene
	if departing != null:
		departing.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().change_scene_to_file("res://scenes/mainMenu/menu.tscn")
	changing_scene = false


func _set_volume(value: float, bus: String) -> void:
	if bus == "Music":
		_music_base_volume = value
		_apply_music_bus_volume()
		return
	var index := AudioServer.get_bus_index(bus)
	if index >= 0:
		AudioServer.set_bus_mute(index, value <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))


func _apply_music_bus_volume() -> void:
	var index := AudioServer.get_bus_index("Music")
	if index >= 0:
		AudioServer.set_bus_mute(index, _music_base_volume <= 0.0)
		var effective_linear: float = maxf(_music_base_volume * _pause_music_scale, 0.0001)
		AudioServer.set_bus_volume_db(index, linear_to_db(effective_linear))


func _tween_music_scale(target_scale: float) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.set_trans(Tween.TRANS_SINE)
	_music_tween.set_ease(Tween.EASE_OUT if target_scale > _pause_music_scale else Tween.EASE_IN_OUT)
	_music_tween.tween_method(
		func(val: float) -> void:
			_pause_music_scale = val
			_apply_music_bus_volume(),
		_pause_music_scale,
		target_scale,
		MUSIC_TWEEN_DURATION
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	for bus: String in sliders:
		config.set_value("volume", bus, (sliders[bus] as HSlider).value)
	config.save(SETTINGS_PATH)
