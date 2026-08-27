extends Node3D

@onready var blur_rect: ColorRect = %BlurRect if has_node("%BlurRect") else null
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = %AmbiencePlayer if has_node("%AmbiencePlayer") else null
@onready var turn_tv_player: AudioStreamPlayer = %TurnTvPlayer if has_node("%TurnTvPlayer") else null
@onready var static_tv_player: AudioStreamPlayer = %StaticTvPlayer if has_node("%StaticTvPlayer") else null
@onready var cutscene_picture: TextureRect = %CutscenePicture if has_node("%CutscenePicture") else null
@onready var static_rect: TextureRect = %Static if has_node("%Static") else null
@onready var intro_overlay: ColorRect = $IntroCanvasLayer/IntroBlackOverlay if has_node("IntroCanvasLayer/IntroBlackOverlay") else null

const INTRO_DIALOGUE: Resource = preload("res://scenes/chapters/intro/intro.dialogue")
const CUSTOM_BALLOON: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")

var active_balloon: Node = null
var static_textures: Array[Texture2D] = []
var static_timer: float = 0.0
const STATIC_INTERVAL: float = 0.24

func _ready() -> void:
	print("Intro scene loaded: Starting 5-second dropping ambience fade-in...")
	$Camera3D.fov = 40
	
	# Load all 20 static frames
	for i in range(1, 21):
		var frame_path: String = "res://img/static/%02d.png" % i
		if ResourceLoader.exists(frame_path):
			var tex: Texture2D = load(frame_path)
			if tex:
				static_textures.append(tex)
	
	if cutscene_picture:
		cutscene_picture.visible = false
	
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
	
	# Launch Intro dialogue
	if INTRO_DIALOGUE and CUSTOM_BALLOON:
		active_balloon = CUSTOM_BALLOON.instantiate()
		add_child(active_balloon)
		Engine.get_singleton("DialogueManager").dialogue_ended.connect(_on_dialogue_ended)
		active_balloon.start(INTRO_DIALOGUE, "start", [self])

func _process(delta: float) -> void:
	if static_rect and static_rect.is_visible_in_tree() and static_textures.size() > 0:
		static_timer += delta
		if static_timer >= STATIC_INTERVAL:
			static_timer = 0.0
			_pick_random_static_frame()

func _pick_random_static_frame() -> void:
	if static_rect and static_textures.size() > 0:
		static_rect.texture = static_textures.pick_random()

func tap_water_scene() -> void:
	print("Triggering tap_water_scene...")
	# Hide the dialogue into pitch black
	if active_balloon:
		active_balloon.set_dialogue_ui_visible(false)
	
	# Stop the initial water dripping ambience
	if ambience_player.playing:
		ambience_player.stop()

	# Pitch black for 1.5 seconds
	await get_tree().create_timer(1.5).timeout

	# Show CutscenePicture right as turnTv mp3 starts
	cutscene_picture.visible = true
	static_timer = 0.0
	_pick_random_static_frame()

	# Play turnTv.mp3 first
	turn_tv_player.volume_db = -8
	turn_tv_player.play()
		
	active_balloon.hide()

	# Play tvStaticLoop right after
	static_tv_player.play()
	ambience_player.play()
		
	await get_tree().create_timer(6).timeout

	# Restore dialogue UI with transparent background so CutscenePicture is visible
	if active_balloon:
		active_balloon.set_background_visible(false)
		active_balloon.set_dialogue_ui_visible(true)
		active_balloon.show()

func _on_dialogue_ended(_resource: Resource) -> void:
	if intro_overlay:
		intro_overlay.hide()
	if cutscene_picture:
		cutscene_picture.hide()
	if static_tv_player and static_tv_player.playing:
		static_tv_player.stop()
	if active_balloon:
		if active_balloon.has_method("clear_dialogue_text"):
			active_balloon.clear_dialogue_text()
		active_balloon.hide()
