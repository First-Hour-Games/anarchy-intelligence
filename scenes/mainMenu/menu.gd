extends CanvasLayer

@onready var start_label: Label = $AspectRatioContainer/Control/MenuContainer/StartLabel
@onready var options_label: Label = $AspectRatioContainer/Control/MenuContainer/OptionsLabel
@onready var quit_label: Label = $AspectRatioContainer/Control/MenuContainer/QuitLabel

@onready var fade_rect: ColorRect = $AspectRatioContainer/Control/Fade
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var move_sfx_player: AudioStreamPlayer = $MoveSfxPlayer
@onready var click_sfx_player: AudioStreamPlayer = $ClickSfxPlayer

var main_options: Array[Dictionary] = []
var sub_options: Array[Dictionary] = []

var selected_index: int = 0
var is_in_options_menu: bool = false
var master_volume_percent: int = 80

const SELECTED_FONT_SIZE: int = 32
const UNSELECTED_FONT_SIZE: int = 20

func _ready() -> void:
	# Set initial Master Audio Bus volume to 80%
	_apply_master_volume()

	main_options = [
		{"label": start_label, "action": _start_game},
		{"label": options_label, "action": _open_options},
		{"label": quit_label, "action": _quit_game}
	]
	
	sub_options = [
		{"label": options_label, "action": _toggle_volume_step},
		{"label": quit_label, "action": _close_options}
	]
	
	_setup_mouse_listeners()
	_update_menu_display(false)
	
	# Start background music
	if music_player:
		music_player.finished.connect(music_player.play)
		if not music_player.playing:
			music_player.play()

func _setup_mouse_listeners() -> void:
	var active_list = sub_options if is_in_options_menu else main_options
	for i in range(active_list.size()):
		var idx = i
		var lbl: Label = active_list[i]["label"]
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Disconnect previous connections safely before reconnecting
		if lbl.gui_input.is_connected(_on_label_gui_input.bind(idx)):
			lbl.gui_input.disconnect(_on_label_gui_input.bind(idx))
		lbl.gui_input.connect(_on_label_gui_input.bind(idx))

func _on_label_gui_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected_index = idx
		_update_menu_display(false)
		_trigger_option_action()

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
		
	var active_list = sub_options if is_in_options_menu else main_options
	
	# Up Arrow / W key
	if event.is_action_pressed("ui_up") or (event is InputEventKey and (event.keycode == KEY_UP or event.keycode == KEY_W)):
		selected_index = (selected_index - 1 + active_list.size()) % active_list.size()
		_update_menu_display(true)
		get_viewport().set_input_as_handled()
		
	# Down Arrow / S key
	elif event.is_action_pressed("ui_down") or (event is InputEventKey and (event.keycode == KEY_DOWN or event.keycode == KEY_S)):
		selected_index = (selected_index + 1) % active_list.size()
		_update_menu_display(true)
		get_viewport().set_input_as_handled()
		
	# Left Arrow / A key (Adjust volume down in Options)
	elif is_in_options_menu and (event.is_action_pressed("ui_left") or (event is InputEventKey and (event.keycode == KEY_LEFT or event.keycode == KEY_A))):
		if selected_index == 0:
			master_volume_percent = clamp(master_volume_percent - 10, 0, 100)
			_apply_master_volume()
			_update_menu_display(true)
			get_viewport().set_input_as_handled()

	# Right Arrow / D key (Adjust volume up in Options)
	elif is_in_options_menu and (event.is_action_pressed("ui_right") or (event is InputEventKey and (event.keycode == KEY_RIGHT or event.keycode == KEY_D))):
		if selected_index == 0:
			master_volume_percent = clamp(master_volume_percent + 10, 0, 100)
			_apply_master_volume()
			_update_menu_display(true)
			get_viewport().set_input_as_handled()

	# Escape key (Return from Options menu)
	elif is_in_options_menu and (event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE)):
		_close_options()
		get_viewport().set_input_as_handled()

	# Enter / Space key
	elif event.is_action_pressed("ui_accept") or (event is InputEventKey and (event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE)):
		_trigger_option_action()
		get_viewport().set_input_as_handled()

func _update_menu_display(play_sound: bool = true) -> void:
	if is_in_options_menu:
		start_label.hide()
		options_label.show()
		quit_label.show()
		
		options_label.text = "Master Volume: < " + str(master_volume_percent) + "% >"
		quit_label.text = "Back"
		
		_apply_label_style(options_label, selected_index == 0)
		_apply_label_style(quit_label, selected_index == 1)
	else:
		start_label.show()
		options_label.show()
		quit_label.show()
		
		start_label.text = "Start Game"
		options_label.text = "Options"
		quit_label.text = "Quit"
		
		_apply_label_style(start_label, selected_index == 0)
		_apply_label_style(options_label, selected_index == 1)
		_apply_label_style(quit_label, selected_index == 2)

	if play_sound and move_sfx_player:
		move_sfx_player.play()

func _apply_label_style(lbl: Label, is_selected: bool) -> void:
	if is_selected:
		lbl.add_theme_font_size_override("font_size", SELECTED_FONT_SIZE)
		lbl.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		lbl.add_theme_font_size_override("font_size", UNSELECTED_FONT_SIZE)
		lbl.modulate = Color(0.55, 0.55, 0.55, 0.6)

func _apply_master_volume() -> void:
	var linear_val: float = float(master_volume_percent) / 100.0
	AudioServer.set_bus_volume_db(0, linear_to_db(linear_val))

func _trigger_option_action() -> void:
	if click_sfx_player:
		click_sfx_player.play()
	var active_list = sub_options if is_in_options_menu else main_options
	active_list[selected_index]["action"].call()

func _start_game() -> void:
	print("Start Game selected! Fading screen and music over 3 seconds...")
	
	var tween = create_tween().set_parallel(true)
	if fade_rect:
		fade_rect.color.a = 0.0
		fade_rect.visible = true
		tween.tween_property(fade_rect, "color:a", 1.0, 3.0)
	
	if music_player:
		tween.tween_property(music_player, "volume_db", -80.0, 3.0)
	
	await tween.finished
	
	if music_player:
		music_player.stop()
	
	print("Fade complete. Pausing 3 seconds in pitch black silence...")
	await get_tree().create_timer(3.0).timeout
	
	get_tree().change_scene_to_file("res://scenes/chapters/chapter_01/chapter_01.tscn")

func _open_options() -> void:
	is_in_options_menu = true
	selected_index = 0
	_update_menu_display(false)

func _toggle_volume_step() -> void:
	master_volume_percent = (master_volume_percent + 10) if master_volume_percent < 100 else 0
	_apply_master_volume()
	_update_menu_display(false)

func _close_options() -> void:
	is_in_options_menu = false
	selected_index = 1
	_update_menu_display(false)

func _quit_game() -> void:
	print("Quit selected!")
	if click_sfx_player and click_sfx_player.playing:
		await click_sfx_player.finished
	get_tree().quit()
