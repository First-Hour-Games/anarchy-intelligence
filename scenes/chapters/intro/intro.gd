extends Node3D

@onready var blur_rect: ColorRect = %BlurRect if has_node("%BlurRect") else null
@onready var music_player: AudioStreamPlayer = $MusicPlayer
@onready var ambience_player: AudioStreamPlayer = %AmbiencePlayer if has_node("%AmbiencePlayer") else null
@onready var turn_tv_player: AudioStreamPlayer = %TurnTvPlayer if has_node("%TurnTvPlayer") else null
@onready var static_tv_player: AudioStreamPlayer = %StaticTvPlayer if has_node("%StaticTvPlayer") else null
@onready var cutscene_picture: TextureRect = %CutscenePicture if has_node("%CutscenePicture") else null
@onready var static_rect: TextureRect = %Static if has_node("%Static") else null
@onready var intro_overlay: ColorRect = $IntroCanvasLayer/IntroBlackOverlay if has_node("IntroCanvasLayer/IntroBlackOverlay") else null
@onready var camera: Camera3D = $Path3D/PathFollow3D/Camera3D if has_node("Path3D/PathFollow3D/Camera3D") else ($Camera3D if has_node("Camera3D") else null)
@onready var path: Path3D = $Path3D if has_node("Path3D") else null
@onready var path_follow: PathFollow3D = $Path3D/PathFollow3D if has_node("Path3D/PathFollow3D") else null

const INTRO_DIALOGUE: Resource = preload("res://scenes/chapters/intro/intro.dialogue")
const CUSTOM_BALLOON: PackedScene = preload("res://scenes/ui/balloon/balloon.tscn")

var active_balloon: Node = null
var static_textures: Array[Texture2D] = []
var static_timer: float = 0.0
const STATIC_INTERVAL: float = 0.24

# Driving simulation controller
var is_driving: bool = false
var current_speed: float = 0.0
var current_yaw: float = 0.0

@export_group("Driving Controller")
@export var max_speed: float = 3.5 ## Maximum speed on straight roads (m/s)
@export var min_speed: float = 3 ## Speed when negotiating sharp corners (m/s)
@export var acceleration: float = 5.0 ## Rate of acceleration on straightaways (m/s²)
@export var braking: float = 1.0 ## Rate of deceleration when approaching corners (m/s²)
@export var steering_smoothness: float = 4.0 ## Steering interpolation speed (lower = smoother tweening into turns)

func _input(event: InputEvent) -> void:
	if OS.has_feature("editor") and event.is_action_pressed("ui_cancel"): # Escape key
		if is_instance_valid(active_balloon):
			active_balloon.queue_free()
			active_balloon = null
		_on_dialogue_ended(null)

func _ready() -> void:
	print("Intro scene loaded: Starting 5-second dropping ambience fade-in...")
	if camera:
		camera.fov = 50
	
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
	
	if is_driving:
		_update_driving(delta)

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
	if not path or not path.curve or path.curve.point_count == 0 or not path_follow:
		return
	
	path_follow.loop = false
	path_follow.cubic_interp = false
	path_follow.rotation_mode = PathFollow3D.ROTATION_NONE
	path_follow.progress = 0.0
	
	# Align initial heading directly forward down the road
	var curve: Curve3D = path.curve
	var initial_target: Vector3 = path.to_global(curve.sample_baked(min(8.0, curve.get_baked_length())))
	initial_target.y = path_follow.global_position.y
	if path_follow.global_position.distance_squared_to(initial_target) > 0.01:
		var init_transform: Transform3D = path_follow.global_transform.looking_at(initial_target, Vector3.UP)
		current_yaw = init_transform.basis.get_euler().y
		path_follow.rotation = Vector3(0.0, current_yaw, 0.0)
	
	current_speed = 2.0 # Smooth start roll
	is_driving = true

func _update_driving(delta: float) -> void:
	if not is_driving or not path or not path.curve or not path_follow:
		return
	
	var curve: Curve3D = path.curve
	var total_length: float = curve.get_baked_length()
	var current_prog: float = path_follow.progress
	
	# Gently bring vehicle to a stop at the end of the road
	if current_prog >= total_length - 0.5:
		current_speed = move_toward(current_speed, 0.0, braking * delta)
		if current_speed <= 0.05:
			is_driving = false
			return
	
	# 1. Sample upcoming road geometry to evaluate curvature
	var sample_cur: Vector3 = curve.sample_baked(current_prog)
	var sample_mid: Vector3 = curve.sample_baked(min(current_prog + 5.0, total_length))
	var sample_ahead: Vector3 = curve.sample_baked(min(current_prog + 16.0, total_length))
	
	var dir_now: Vector3 = sample_mid - sample_cur
	dir_now.y = 0.0
	dir_now = dir_now.normalized() if not dir_now.is_zero_approx() else Vector3.FORWARD
	
	var dir_ahead: Vector3 = sample_ahead - sample_mid
	dir_ahead.y = 0.0
	dir_ahead = dir_ahead.normalized() if not dir_ahead.is_zero_approx() else dir_now
	
	# Corner sharpness in radians (0.0 on straights, ~0.4+ on tight turns)
	var corner_angle: float = dir_now.angle_to(dir_ahead)
	var turn_intensity: float = clampf(corner_angle / 0.45, 0.0, 1.0)
	
	# 2. Dynamic realistic speed: slow down into corners, accelerate on straightaways
	var target_speed: float = lerpf(max_speed, min_speed, turn_intensity)
	var accel_rate: float = acceleration if target_speed > current_speed else braking
	current_speed = move_toward(current_speed, target_speed, accel_rate * delta)
	
	# Advance progress along the road
	path_follow.progress += current_speed * delta
	
	# 3. Smooth car steering: look ahead down the road and smoothly tween rotation (eliminates sudden flicks)
	var look_dist: float = clampf(current_speed * 1.5, 7.0, 14.0)
	var target_pos: Vector3 = path.to_global(curve.sample_baked(min(path_follow.progress + look_dist, total_length)))
	target_pos.y = path_follow.global_position.y
	
	if path_follow.global_position.distance_squared_to(target_pos) > 0.01:
		var target_transform: Transform3D = path_follow.global_transform.looking_at(target_pos, Vector3.UP)
		var target_yaw: float = target_transform.basis.get_euler().y
		current_yaw = lerp_angle(current_yaw, target_yaw, steering_smoothness * delta)
		path_follow.rotation.y = current_yaw
		
		# Subtle chassis roll/lean into turns for realistic driving feel
		var steer_diff: float = wrapf(target_yaw - current_yaw, -PI, PI)
		var target_roll: float = clampf(steer_diff * 0.08, -0.025, 0.025)
		path_follow.rotation.z = lerpf(path_follow.rotation.z, target_roll, 4.0 * delta)

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
