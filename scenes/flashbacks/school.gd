extends Node3D

@export var auto_start_intro: bool = true
@export_range(0.1, 10.0, 0.05) var fade_duration: float = 3.75

@onready var _player: FirstPersonPlayer = $Player
@onready var _fade: ColorRect = $IntroFadeCanvas/BlackScreen
@onready var _dialogue: BottomDialogueBalloon = $OpeningDialogue
@onready var _phone: OldPhone = $TeacherDesk/oldPhone


func _ready() -> void:
	$CRTOverlay/AspectRatioContainer/Content.resized.connect(_update_crt_side_bars)
	get_viewport().size_changed.connect(_update_crt_side_bars)
	_update_crt_side_bars.call_deferred()
	_dialogue.dialogue_finished.connect(_phone.start_ringing, CONNECT_ONE_SHOT)
	_phone.dialogue_finished.connect(_show_ending_logo, CONNECT_ONE_SHOT)
	if auto_start_intro:
		_start_intro()


func _start_intro() -> void:
	_player.freeze()
	_fade.modulate.a = 1.0
	_fade.show()
	var tween := create_tween()
	tween.tween_property(_fade, "modulate:a", 0.0, fade_duration)
	await tween.finished
	_fade.hide()
	_dialogue.start()


func _show_ending_logo() -> void:
	_player.freeze()
	_phone.stop_ringing()
	$EndingLogo.show()


func _update_crt_side_bars() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var content: Control = $CRTOverlay/AspectRatioContainer/Content
	var bounds := content.get_global_rect()
	var left: ColorRect = $CRTSideBars/LeftBar
	var right: ColorRect = $CRTSideBars/RightBar
	left.position = Vector2.ZERO
	left.size = Vector2(maxf(0.0, bounds.position.x), viewport_size.y)
	right.position = Vector2(bounds.end.x, 0.0)
	right.size = Vector2(maxf(0.0, viewport_size.x - bounds.end.x), viewport_size.y)
