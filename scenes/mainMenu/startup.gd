extends CanvasLayer

const MENU := preload("res://scenes/mainMenu/menu.tscn")
@export var logo_fade_duration: float = 0.8
@export var logo_hold_duration: float = 1.5
@export var menu_fade_duration: float = 1.0
@onready var black: ColorRect = $Black
@onready var logo: TextureRect = $Black/Logo
var _menu_reveal_tween: Tween

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var sequence := create_tween()
	sequence.tween_property(logo, "modulate:a", 1.0, logo_fade_duration)
	sequence.tween_interval(logo_hold_duration)
	sequence.tween_property(logo, "modulate:a", 0.0, logo_fade_duration)
	sequence.tween_callback(_show_menu)

func _show_menu() -> void:
	var menu := MENU.instantiate()
	menu.play_music_on_ready = false
	get_tree().root.add_child(menu)
	get_tree().current_scene = menu
	menu.input_ready_at = Time.get_ticks_msec() + int(menu_fade_duration * 1000) + 250
	_menu_reveal_tween = create_tween()
	_menu_reveal_tween.tween_property(black, "modulate:a", 0.0, menu_fade_duration)
	_menu_reveal_tween.finished.connect(menu.start_menu_music)
	_menu_reveal_tween.finished.connect(queue_free)
