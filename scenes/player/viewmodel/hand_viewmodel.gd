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

@onready var hand_pivot: Node2D = $HandPivot
@onready var hands: AnimatedSprite2D = $HandPivot/Hands
@onready var player: CharacterBody3D = get_parent() as CharacterBody3D

var base_position: Vector2 = Vector2.ZERO
var movement_phase: float = 0.0
var idle_phase: float = 0.0
var look_lag: Vector2 = Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()
	hands.play(&"idle")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		look_lag -= event.relative * look_lag_strength
		look_lag.x = clampf(look_lag.x, -look_lag_limit, look_lag_limit)
		look_lag.y = clampf(look_lag.y, -look_lag_limit, look_lag_limit)


func _process(delta: float) -> void:
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
