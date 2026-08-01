extends Node3D

@onready var ambience_player: AudioStreamPlayer = %AmbiencePlayer
@onready var intro_overlay: ColorRect = $IntroCanvasLayer/IntroBlackOverlay

const CHAPTER_DIALOGUE: Resource = preload("res://scenes/chapters/chapter_01/chapter_01.dialogue")
const CUSTOM_BALLOON: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")

func _ready() -> void:
	print("Chapter 1 loaded! Starting 5-second snowstorm ambience fade-in...")
	
	if intro_overlay:
		intro_overlay.color = Color(0, 0, 0, 1)
		intro_overlay.visible = true
	
	# Fade in snowstorm ambience over 5.0 seconds before starting dialogue
	if ambience_player:
		ambience_player.volume_db = -80.0
		ambience_player.play()
		var tween = create_tween()
		tween.tween_property(ambience_player, "volume_db", 0.0, 5.0)
		await tween.finished
	
	print("Ambience fade-in complete. Launching dialogue...")
	
	# Launch Chapter 1 intro dialogue with full-screen retro UI
	if CHAPTER_DIALOGUE and CUSTOM_BALLOON:
		var balloon = CUSTOM_BALLOON.instantiate()
		add_child(balloon)
		balloon.start(CHAPTER_DIALOGUE, "start")
		if intro_overlay:
			intro_overlay.hide()
