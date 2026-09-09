class_name HandViewmodel extends CanvasLayer

## Screen-space presentation for the player's illustrated hands.
## The artwork stays independent from the 3D camera and cannot clip into walls.

const SOURCE_SIZE := Vector2(1774.0, 887.0)

@export_category("Layout")
@export_range(0.5, 1.2, 0.01) var viewmodel_scale: float = 0.84
@export var bottom_offset: float = 56.0
## Extra positive Y offsets lower moving hands without changing the source artwork.
@export var walk_vertical_offset: float = 34.0
@export var sprint_vertical_offset: float = 18.0

@export_category("Movement Sway")
@export var walk_reference_speed: float = 3.2
@export var sprint_reference_speed: float = 4.8
@export var walk_sway: Vector2 = Vector2(3.5, 4.5)
@export var sprint_sway: Vector2 = Vector2(7.0, 9.0)
@export var walk_sway_frequency: float = 1.8
@export var movement_smoothing: float = 10.0
@export var maximum_roll_degrees: float = 0.22

@export_category("Look Lag")
@export var look_lag_strength: float = 0.035
@export var look_lag_limit: float = 10.0
@export var look_lag_return_speed: float = 12.0

@export_category("HP Face")
@export var hp_face_frame_time: float = 0.7
@export_range(0, 5, 1) var hp_face_row: int = 0:
	set(value):
		hp_face_row = clampi(value, 0, 5)
		hp_face_column = 0
		hp_face_timer = 0.0
		_update_hp_face()
		_update_heartbeat()

@onready var hand_pivot: Node2D = $HandPivot
@onready var hands: AnimatedSprite2D = $HandPivot/Hands
@onready var hp_frame: Panel = $HPFrame
@onready var hp_face: Sprite2D = $HPFace
@onready var ecg_frame: Panel = $ECGFrame
@onready var ecg_grid: ECGGrid = $ECGFrame/ECGGrid
@onready var heartbeat: Heartbeat = $ECGFrame/Heartbeat
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D

var base_position: Vector2 = Vector2.ZERO
var movement_phase: float = 0.0
var idle_phase: float = 0.0
var look_lag: Vector2 = Vector2.ZERO
var hp_face_column: int = 0
var hp_face_timer: float = 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	hands.play(&"idle")
	_update_hp_face()
	_update_heartbeat()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_lag -= event.relative * look_lag_strength
		look_lag.x = clampf(look_lag.x, -look_lag_limit, look_lag_limit)
		look_lag.y = clampf(look_lag.y, -look_lag_limit, look_lag_limit)

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_DOWN or event.keycode == KEY_RIGHT:
			hp_face_row = (hp_face_row + 1) % 6
		elif event.keycode == KEY_UP or event.keycode == KEY_LEFT:
			hp_face_row = (hp_face_row - 1 + 6) % 6


func _process(delta: float) -> void:
	_update_hp_face_animation(delta)

	if not is_instance_valid(player):
		return

	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var is_moving: bool = player.is_on_floor() and horizontal_speed > 0.1
	var sprint_blend: float = clampf(
		inverse_lerp(walk_reference_speed, sprint_reference_speed, horizontal_speed),
		0.0,
		1.0
	)
	var target_motion: Vector2 = Vector2.ZERO
	var target_roll: float = 0.0
	var target_vertical_offset: float = 0.0

	if is_moving:
		var speed_ratio: float = horizontal_speed / walk_reference_speed
		movement_phase += delta * walk_sway_frequency * TAU * speed_ratio
		var sway: Vector2 = walk_sway.lerp(sprint_sway, sprint_blend)
		target_motion.x = sin(movement_phase) * sway.x
		target_motion.y = -abs(cos(movement_phase)) * sway.y
		target_roll = sin(movement_phase) * deg_to_rad(maximum_roll_degrees) * (1.0 + sprint_blend * 0.5)
		if sprint_blend > 0.5:
			target_vertical_offset = sprint_vertical_offset
			_set_animation(&"sprint")
		else:
			target_vertical_offset = walk_vertical_offset
			_set_animation(&"walk")
	else:
		idle_phase += delta * TAU / 2.4
		target_motion.y = sin(idle_phase) * 1.0
		_set_animation(&"idle")

	var look_return_weight: float = 1.0 - exp(-look_lag_return_speed * delta)
	look_lag = look_lag.lerp(Vector2.ZERO, look_return_weight)

	var movement_weight: float = 1.0 - exp(-movement_smoothing * delta)
	var state_offset := Vector2(0.0, target_vertical_offset)
	hand_pivot.position = hand_pivot.position.lerp(base_position + state_offset + target_motion + look_lag, movement_weight)
	hand_pivot.rotation = lerp_angle(hand_pivot.rotation, target_roll, movement_weight)


func _set_animation(next_animation: StringName) -> void:
	if hands.animation == next_animation and hands.is_playing():
		return
	hands.play(next_animation)


func _update_layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var fit_scale: float = minf(viewport_size.x / SOURCE_SIZE.x, viewport_size.y / SOURCE_SIZE.y)
	var final_scale: float = fit_scale * viewmodel_scale
	hand_pivot.scale = Vector2.ONE * final_scale
	base_position = Vector2(viewport_size.x * 0.5, viewport_size.y + bottom_offset)
	hand_pivot.position = base_position


func set_hp_stage(stage: int) -> void:
	hp_face_row = stage


func _update_hp_face_animation(delta: float) -> void:
	if not is_instance_valid(hp_face) or hp_face_frame_time <= 0.0:
		return
	hp_face_timer += delta
	if hp_face_timer >= hp_face_frame_time:
		hp_face_timer = fmod(hp_face_timer, hp_face_frame_time)
		hp_face_column = 1 - hp_face_column
		_update_hp_face()


func _update_hp_face() -> void:
	if is_instance_valid(hp_face):
		hp_face.frame_coords = Vector2i(hp_face_column, hp_face_row)


func _update_heartbeat() -> void:
	if not is_instance_valid(heartbeat):
		return
	var c := Color(0.2, 1.0, 0.45, 1.0)
	match hp_face_row:
		0:
			heartbeat.set_params(3.5, 1.4, 28.0, 1, 0.40)
			c = Color(0.2, 1.0, 0.45, 1.0)
		1:
			heartbeat.set_params(3.5, 1.7, 32.0, 1, 0.30)
			c = Color(0.4, 0.95, 0.35, 1.0)
		2:
			heartbeat.set_params(3.5, 2.0, 36.0, 1, 0.20)
			c = Color(0.9, 0.85, 0.2, 1.0)
		3:
			heartbeat.set_params(3.5, 2.4, 40.0, 2, 0.12)
			c = Color(1.0, 0.6, 0.15, 1.0)
		4:
			heartbeat.set_params(3.5, 3.0, 45.0, 2, 0.04)
			c = Color(1.0, 0.25, 0.2, 1.0)
		5:
			heartbeat.set_params(3.5, 0.6, 5.0, 1, 0.90)
			c = Color(0.7, 0.15, 0.15, 0.85)

	heartbeat.set_color(c)
	if is_instance_valid(ecg_grid):
		ecg_grid.set_color(c)


