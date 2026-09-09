class_name RobotKid extends CharacterBody3D

## A human-looking NPC that notices the player, closes the distance, and
## transforms into a ScrapAutomaton once it reaches them.

enum State { IDLE, ALERT, APPROACH, SPRINT, TRANSFORMING }

const AUTOMATON_SCENE_PATH := "res://scenes/monsters/scrap_automaton/scrap_automaton.tscn"

@export_category("Detection")
@export var notice_distance: float = 14.0
@export var alert_duration: float = 0.8

@export_category("Movement")
@export var walk_speed: float = 1.0
@export var run_speed: float = 2.8
@export var run_trigger_distance: float = 6.0
@export var reach_trigger_distance: float = 2.2
@export var movement_acceleration: float = 6.0

@onready var visual_pivot: Node3D = $VisualPivot
@onready var directional_sprite: AnimatedSprite3D = $VisualPivot/DirectionalSprite
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
var player: Node3D
var player_camera: Camera3D
var state: State = State.IDLE
var alert_timer: float = 0.0


func _ready() -> void:
	_find_player()
	directional_sprite.play("idle")
	directional_sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	if state == State.TRANSFORMING:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if not is_instance_valid(player):
		_find_player()

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	var desired_velocity := Vector3.ZERO

	if is_instance_valid(player):
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		var distance_to_player := to_player.length()

		if distance_to_player > 0.001:
			_update_facing(to_player / distance_to_player)

		match state:
			State.IDLE:
				if distance_to_player <= notice_distance:
					_enter_alert()
			State.ALERT:
				alert_timer -= delta
				if alert_timer <= 0.0:
					state = State.APPROACH
					directional_sprite.play("walk")
			State.APPROACH, State.SPRINT:
				if distance_to_player <= reach_trigger_distance:
					_enter_transform_sequence()
				elif distance_to_player > 0.001:
					if state != State.SPRINT and distance_to_player <= run_trigger_distance:
						state = State.SPRINT
						directional_sprite.play("run")
					var pursuit_direction := _pursuit_direction_toward(player.global_position, to_player, distance_to_player)
					var speed := run_speed if state == State.SPRINT else walk_speed
					desired_velocity = pursuit_direction * speed

	velocity.x = move_toward(velocity.x, desired_velocity.x, movement_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, movement_acceleration * delta)
	move_and_slide()


func _enter_alert() -> void:
	state = State.ALERT
	alert_timer = alert_duration
	directional_sprite.play("idle_alert")


func _enter_transform_sequence() -> void:
	state = State.TRANSFORMING
	directional_sprite.play("reach")


func _on_animation_finished() -> void:
	if state != State.TRANSFORMING:
		return
	if directional_sprite.animation == "reach":
		directional_sprite.play("transform")
	elif directional_sprite.animation == "transform":
		_transform_into_automaton()


func _transform_into_automaton() -> void:
	var automaton_scene := load(AUTOMATON_SCENE_PATH) as PackedScene
	var automaton := automaton_scene.instantiate()
	get_parent().add_child(automaton)
	(automaton as Node3D).global_transform = global_transform
	if "pursuit_enabled" in automaton:
		automaton.pursuit_enabled = true
	queue_free()


## Routes movement through the baked navmesh when one covers this position,
## falling back to a straight line otherwise (see ScrapAutomaton for the same
## pattern, used there for the same reason: test scenes have no navmesh).
func _pursuit_direction_toward(target_position: Vector3, direct_offset: Vector3, direct_distance: float) -> Vector3:
	var direct_direction := direct_offset / direct_distance
	nav_agent.target_position = target_position
	if not nav_agent.is_target_reachable():
		return direct_direction

	var next_point := nav_agent.get_next_path_position()
	var to_next := next_point - global_position
	to_next.y = 0.0
	if to_next.is_zero_approx():
		return direct_direction
	return to_next.normalized()


## The sprite sheet only has front and left-facing side views, so instead of
## rotating the body (invisible anyway once billboarded) we flip the sprite
## based on which side of the camera the player is on. Runs every frame in
## every state, not just while moving, so idle/alert also face correctly.
func _update_facing(direction: Vector3) -> void:
	if not is_instance_valid(player_camera):
		return
	var camera_right: Vector3 = player_camera.global_transform.basis.x
	var dot := direction.dot(camera_right)
	if absf(dot) > 0.05:
		directional_sprite.flip_h = dot < 0.0


func _find_player() -> void:
	player = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player):
		player_camera = player.get_node_or_null("Head/Camera3D") as Camera3D
