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
	print("Chapter 1 loaded! Starting 5-second snowstorm ambience fade-in...")
	
	if intro_overlay:
		intro_overlay.color = Color(0, 0, 0, 1)
		intro_overlay.visible = true
	
	var is_editor: bool = OS.has_feature("editor")
	# Fade in snowstorm ambience over 5.0 seconds (skips delay if running in editor)
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

func trigger_car_revving() -> void:
	print("Triggering 3D car revving sequence...")
	
	# 1. Reveal 3D view by hiding intro_overlay, black Background, AND dialogue text UI
	if intro_overlay:
		intro_overlay.hide()
	if active_balloon:
		if active_balloon.has_method("set_background_visible"):
			active_balloon.set_background_visible(false)
		if active_balloon.has_method("set_dialogue_ui_visible"):
			active_balloon.set_dialogue_ui_visible(false)
	
	# 2. Fade out snowstorm ambience over 5.0 seconds
	if ambience_player:
		var fade_ambience_out = create_tween()
		fade_ambience_out.tween_property(ambience_player, "volume_db", -80.0, 5.0)
	
	# 3. Play car revving audio at full volume
	var camFovTween = create_tween().set_parallel(true)
	if car_revving_player:
		camFovTween.tween_property($Camera3D, "fov", 30.0, 7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		
		if "bus" in car_revving_player:
			car_revving_player.bus = "Master"
			
		if "volume_db" in car_revving_player:
			car_revving_player.volume_db = 0.0
		if car_revving_player.has_method("play"):
			car_revving_player.play()
	
	# 4. Show 3D view for 5.0 seconds before revving transition begins
	await get_tree().create_timer(5.0).timeout
	
	# 5. Start parallel 2.0-second audio cross-fade
	var transition_tween = create_tween().set_parallel(true)
	if car_revving_player and "volume_db" in car_revving_player:
		transition_tween.tween_property(car_revving_player, "volume_db", -80.0, 2.0)
	if ambience_player:
		transition_tween.tween_property(ambience_player, "volume_db", 0.0, 2.0)
	
	# 6. MIDWAY through the transition (1.0s in), return screen to solid black and restore dialogue UI
	await get_tree().create_timer(1.0).timeout
	if intro_overlay:
		intro_overlay.show()
	if active_balloon:
		if active_balloon.has_method("set_background_visible"):
			active_balloon.set_background_visible(true)
		if active_balloon.has_method("set_dialogue_ui_visible"):
			active_balloon.set_dialogue_ui_visible(true)
	
	# 7. Wait for the remaining 1.0s of audio transition to complete
	await transition_tween.finished
	if car_revving_player and car_revving_player.has_method("stop"):
		car_revving_player.stop()
		
func trigger_car_slumbering() -> void:	
	var camFovTween = create_tween().set_parallel(true)
	camFovTween.tween_property($Camera3D, "fov", 45.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	if blur_rect and blur_rect.material:
		blur_rect.show()
		blur_rect.material.set_shader_parameter("lod", 0.0)
		camFovTween.tween_property(blur_rect.material, "shader_parameter/lod", 4.0, 14.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	if intro_overlay:
		intro_overlay.hide()
	if active_balloon:
		if active_balloon.has_method("set_background_visible"):
			active_balloon.set_background_visible(false)
		if active_balloon.has_method("set_dialogue_ui_visible"):
			active_balloon.set_dialogue_ui_visible(false)
	
	var fade_ambience_out = create_tween().set_parallel(true)
	fade_ambience_out.tween_property(ambience_player, "volume_db", -80.0, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	await get_tree().create_timer(1.5).timeout
	music_player.play()
	await get_tree().create_timer(7.0).timeout
	
	if intro_overlay:
		intro_overlay.show()
	if active_balloon:
		if active_balloon.has_method("set_background_visible"):
			active_balloon.set_background_visible(true)
		if active_balloon.has_method("set_dialogue_ui_visible"):
			active_balloon.set_dialogue_ui_visible(true)
	if blur_rect and blur_rect.material:
		blur_rect.material.set_shader_parameter("lod", 0.0)

func _on_dialogue_ended(_resource: Resource) -> void:
	if intro_overlay:
		intro_overlay.hide()
