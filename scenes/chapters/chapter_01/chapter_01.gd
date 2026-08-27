extends Node3D

@onready var blur_rect: ColorRect = %BlurRect if has_node("%BlurRect") else null
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = %AmbiencePlayer if has_node("%AmbiencePlayer") else null
@onready var car_revving_player: Node = %CarRevving if has_node("%CarRevving") else find_child("CarRevving", true, false)
@onready var intro_overlay: ColorRect = $IntroCanvasLayer/IntroBlackOverlay if has_node("IntroCanvasLayer/IntroBlackOverlay") else null

const CHAPTER_DIALOGUE: Resource = preload("res://scenes/chapters/chapter_01/chapter_01.dialogue")
const CUSTOM_BALLOON: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")

var active_balloon: Node = null

func _ready() -> void:
	print("chapter 1 loaded: Starting 5-second dropping ambience fade-in...")
	$Camera3D.fov = 40
	
	if intro_overlay:
		intro_overlay.color = Color(0, 0, 0, 1)
		intro_overlay.visible = true
	
	var is_editor: bool = OS.has_feature("editor")
	
	if ambience_player:
		ambience_player.volume_db = -80.0
		ambience_player.play()
		var fade_time: float = 0.1 if is_editor else 5.0
		var tween = create_tween()
		tween.tween_property(ambience_player, "volume_db", 0.0, fade_time)
		if not is_editor:
			await tween.finished
	
	print("Ambience fade-in complete. Launching dialogue...")
	
	# Launch Chapter 1 intro dialogue with full-screen retro UI
	if CHAPTER_DIALOGUE and CUSTOM_BALLOON:
		active_balloon = CUSTOM_BALLOON.instantiate()
		add_child(active_balloon)
		Engine.get_singleton("DialogueManager").dialogue_ended.connect(_on_dialogue_ended)
		active_balloon.start(CHAPTER_DIALOGUE, "start", [self])

func _on_dialogue_ended(_resource: Resource) -> void:
	if intro_overlay:
		intro_overlay.hide()
	if active_balloon:
		if active_balloon.has_method("clear_dialogue_text"):
			active_balloon.clear_dialogue_text()
		active_balloon.hide()
