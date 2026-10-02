extends CanvasLayer

const SETTINGS_PATH := "user://audio_settings.cfg"
const PAUSE_MUSIC_BOOST: float = 1.30
const MUSIC_TWEEN_DURATION: float = 0.4

var opened: bool = false
var overlay: Control
var previous_mouse: Input.MouseMode
var sliders: Dictionary = {}
var has_started_chapter: bool = false
var changing_scene: bool = false

var _music_base_volume: float = 1.0
var _pause_music_scale: float = 1.0
var _music_tween: Tween = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	for bus: String in ["Effects", "Footsteps"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Footsteps"), "Reverb")
	for bus: String in ["InGameFootage", "Reverb"]:
		var index := AudioServer.get_bus_index(bus)
		if index >= 0:
			AudioServer.set_bus_send(index, "Effects")
	get_tree().node_added.connect(_route_audio)
	_ensure_audio_process_modes()
	_build_menu()
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	for bus: String in sliders:
		(sliders[bus] as HSlider).value = float(config.get_value("volume", bus, 1.0))
		_set_volume((sliders[bus] as HSlider).value, bus)

func _route_audio(node: Node) -> void:
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
	if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
		if opened:
			set_open(false)
		elif not get_tree().paused:
			var player := get_tree().get_first_node_in_group("player") as FirstPersonPlayer
			if player == null or player.is_frozen:
				return
			set_open(true)
		else:
			return
		get_viewport().set_input_as_handled()

func set_open(value: bool) -> void:
	if value == opened:
		return
	opened = value
	overlay.visible = value
	if value:
		previous_mouse = Input.mouse_mode
		_ensure_audio_process_modes()
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_tween_music_scale(PAUSE_MUSIC_BOOST)
	else:
		_save_settings()
		get_tree().paused = false
		Input.mouse_mode = previous_mouse
		_tween_music_scale(1.0)

func _build_menu() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.01, 0.012, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 430
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.037, 0.038)
	style.border_color = Color(0.65, 0.52, 0.3)
	style.set_border_width_all(1)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var title := Label.new()
	title.text = "CICELY TOWN / PAUSED"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.82, 0.66, 0.35))
	column.add_child(title)
	for bus: String in ["Master", "Music", "Effects", "Footsteps"]:
		var row := HBoxContainer.new()
		column.add_child(row)
		var label := Label.new()
		label.text = bus.to_upper()
		label.custom_minimum_size.x = 115
		row.add_child(label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.01
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(slider)
		var percent := Label.new()
		percent.custom_minimum_size.x = 46
		row.add_child(percent)
		slider.value_changed.connect(func(value: float) -> void: percent.text = "%d%%" % roundi(value * 100); _set_volume(value, bus))
		sliders[bus] = slider
	var resume := Button.new()
	resume.text = "RESUME"
	resume.pressed.connect(set_open.bind(false))
	column.add_child(resume)
	var menu := Button.new()
	menu.text = "MAIN MENU"
	menu.pressed.connect(return_to_main_menu)
	column.add_child(menu)
	var quit_button := Button.new()
	quit_button.text = "QUIT GAME"
	quit_button.pressed.connect(func() -> void: _save_settings(); get_tree().quit())
	column.add_child(quit_button)
	var credits := Label.new()
	credits.text = "CREATURE AUDIO / FREESOUND / CC0\nGhost Monster Scream - NachtmahrTV\nmonster sound 2.wav - ZyryTSounds\ngrowl 2 - balloonhead"
	credits.add_theme_font_size_override("font_size", 13)
	credits.add_theme_color_override("font_color", Color(0.65, 0.67, 0.64))
	column.add_child(credits)
	overlay.hide()

func return_to_main_menu() -> void:
	if changing_scene:
		return
	changing_scene = true
	get_viewport().set_input_as_handled()
	_finish_return_to_menu.call_deferred()

func _finish_return_to_menu() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_pause_music_scale = 1.0
	_apply_music_bus_volume()
	get_tree().call_group("opening_story", "_save")
	set_open(false)
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Stop the departing scene before its physics bodies leave their world.
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
