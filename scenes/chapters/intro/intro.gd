extends Node3D

@onready var blur_rect: ColorRect = %BlurRect if has_node("%BlurRect") else null
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = %AmbiencePlayer if has_node("%AmbiencePlayer") else null
@onready var turn_tv_player: AudioStreamPlayer = %TurnTvPlayer if has_node("%TurnTvPlayer") else null
@onready var static_tv_player: AudioStreamPlayer = %StaticTvPlayer if has_node("%StaticTvPlayer") else null
@onready var cutscene_picture: TextureRect = %CutscenePicture if has_node("%CutscenePicture") else null
@onready var static_rect: TextureRect = %Static if has_node("%Static") else null
@onready var intro_overlay: ColorRect = $IntroCanvasLayer/IntroBlackOverlay if has_node("IntroCanvasLayer/IntroBlackOverlay") else null
@onready var camera: Camera3D = $Camera3D if has_node("Camera3D") else null
@onready var path: Path3D = $Path3D if has_node("Path3D") else null

const INTRO_DIALOGUE: Resource = preload("res://scenes/chapters/intro/intro.dialogue")
const CUSTOM_BALLOON: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")

var active_balloon: Node = null
var static_textures: Array[Texture2D] = []
var static_timer: float = 0.0
const STATIC_INTERVAL: float = 0.24

func _ready() -> void:
	print("Intro scene loaded: Starting 5-second dropping ambience fade-in...")
	if camera:
		camera.fov = 40
	_setup_driving_camera()
	
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

func _setup_driving_camera() -> void:
	if not camera or not path or not path.curve or path.curve.point_count == 0:
		return
	
	var curve: Curve3D = path.curve
	var start_pos: Vector3 = path.to_global(curve.get_point_position(0))
	
	# Determine forward and lateral road vectors at the start of the path
	var sample_step: float = min(5.0, curve.get_baked_length())
	var next_sample: Vector3 = path.to_global(curve.sample_baked(sample_step))
	var forward_dir: Vector3 = (next_sample - start_pos).normalized()
	if forward_dir.is_zero_approx():
		forward_dir = Vector3(-1.0, 0.0, 0.0)
	
	var lateral_dir: Vector3 = forward_dir.cross(Vector3.UP).normalized()
	
	# The road mesh (CSGPolygon3D) has a width of 3.2m extruded laterally;
	# offset by 1.6m to align right in the middle of the road/path.
	var road_center_offset: Vector3 = lateral_dir * 1.6
	
	# Eye-level height for car driving POV (slightly up from ground/path level)
	var eye_height: float = 1.15
	var cam_pos: Vector3 = start_pos + road_center_offset + Vector3(0.0, eye_height, 0.0)
	
	# Target to look at down the middle of the path
	var look_target: Vector3
	if curve.point_count > 1:
		var target_sample_dist: float = min(15.0, curve.get_baked_length())
		if target_sample_dist > 0.0:
			var target_curve_pos: Vector3 = path.to_global(curve.sample_baked(target_sample_dist))
			var sample_ahead: Vector3 = path.to_global(curve.sample_baked(min(target_sample_dist + 1.0, curve.get_baked_length())))
			var target_forward: Vector3 = (sample_ahead - target_curve_pos).normalized()
			var target_lateral: Vector3 = target_forward.cross(Vector3.UP).normalized() if not target_forward.is_zero_approx() else lateral_dir
			look_target = target_curve_pos + target_lateral * 1.6 + Vector3(0.0, eye_height, 0.0)
		else:
			look_target = path.to_global(curve.get_point_position(1)) + road_center_offset + Vector3(0.0, eye_height, 0.0)
	else:
		look_target = cam_pos + forward_dir * 10.0
	
	if camera.has_method("set_driving_view"):
		camera.set_driving_view(cam_pos, look_target)
	else:
		camera.global_position = cam_pos
		camera.look_at(look_target, Vector3.UP)
		if "initial_rotation" in camera:
			camera.initial_rotation = camera.rotation

func _on_dialogue_ended(_resource: Resource) -> void:
	_setup_driving_camera()
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
