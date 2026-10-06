extends CharacterBody3D

@export_enum("Wrapper", "Clawman") var encounter_kind: int = 0
@export var movement_speed: float = 1.25
@export var territory_radius: float = 22.0
@export var max_step_height: float = 0.4
const ROUTE := preload("res://scenes/shared/entity_route.gd")
var navigation_route := ROUTE.new()
var enabled: bool = false
var suspended: bool = false
var spawn: Transform3D
var player: FirstPersonPlayer
var last_heard := Vector3.ZERO
var memory: float = 0.0
var attack_cooldown: float = 0.0
var warning_cooldown: float = 0.0
var strike_time: float = 0.0
var strike_hit: bool = false
var alert_time: float = 0.0
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	add_to_group("story_mob")
	add_to_group("corrupted_friend")
	spawn = global_transform
	player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer

func reset_enemy() -> void:
	global_transform = spawn
	velocity = Vector3.ZERO
	memory = 0.0
	attack_cooldown = 2.0
	strike_time = 0.0
	alert_time = 0.0
	navigation_route.reset()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not enabled or suspended:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	warning_cooldown = maxf(0.0, warning_cooldown - delta)
	memory = maxf(0.0, memory - delta)
	var distance := global_position.distance_to(player.global_position)
	var in_territory := encounter_kind == 0 or player.global_position.distance_to(spawn.origin) < territory_radius
	var visible_player := _clear_sight(player.camera.global_position)
	var watched := visible_player and not player.camera.is_position_behind(global_position + Vector3.UP)
	if watched:
		var screen := player.camera.unproject_position(global_position + Vector3.UP)
		watched = player.get_viewport().get_visible_rect().has_point(screen)
	var should_move := false
	if encounter_kind == 0:
		should_move = in_territory and not watched
		last_heard = player.global_position
	else:
		var noisy := Vector2(player.velocity.x, player.velocity.z).length() > 1.0 and not player.is_crouching
		if in_territory and ((noisy and distance < 12.0) or (visible_player and distance < 7.0)):
			if memory <= 0.0:
				alert_time = 0.75
			last_heard = player.global_position
			memory = 4.5
			if warning_cooldown <= 0.0:
				get_tree().call_group("opening_story", "narrate_once", "claw_warning", "Something heard me. I should keep still and get behind cover.")
				warning_cooldown = 5.0
		should_move = in_territory and memory > 0.0
	var motion := Vector3.ZERO
	if should_move and distance > 1.4:
		# Keep progress through doorway links instead of rebuilding the route
		# every frame and pulling the enemy back onto the exterior polygon.
		if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			motion = navigation_route.direction(self, agent.get_navigation_map(), last_heard, delta) * movement_speed
	if in_territory and distance < 1.65 and visible_player and attack_cooldown <= 0.0 and strike_time <= 0.0 and (encounter_kind == 1 or not watched):
		strike_time = 0.9
		strike_hit = false
		attack_cooldown = 2.0
	if strike_time > 0.0:
		strike_time = maxf(0.0, strike_time - delta)
		motion = Vector3.ZERO
	if strike_time > 0.0 and strike_time < 0.4 and not strike_hit:
		strike_hit = true
		var health := player.get_node_or_null("CombatHealth")
		if health != null and distance < 1.9 and visible_player:
			health.take_damage(35.0, self)
		get_tree().call_group("opening_story", "narrate_once", "caught_warning", "Too close. I need to get away!")
	alert_time = maxf(0.0, alert_time - delta)
	if alert_time > 0.0:
		motion = Vector3.ZERO
	var visual := $Visual
	if visual.has_method("play"):
		visual.play("attack" if strike_time > 0.0 else "windup" if alert_time > 0.0 else "run" if motion.length() > 0.1 else "idle")
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = velocity.y - 9.8 * delta if not is_on_floor() else 0.0
	if motion.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-motion.x, -motion.z), delta * 4.0)
	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()

func _clear_sight(point: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, point)
	ray.exclude = [get_rid(), player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
