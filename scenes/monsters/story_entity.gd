extends CharacterBody3D

## Emitted when the entity is put back at its post: placed there, or reset when the player respawns.
signal returned_to_post

@export_enum("Wrapper", "Clawman") var encounter_kind: int = 0
@export var movement_speed: float = 1.25
@export var territory_radius: float = 22.0
@export var max_step_height: float = 0.4
## Seconds the Clawman spends investigating a breaking bottle.
@export var noise_memory: float = 7.0
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
## A HidingSpot the Clawman watched the player enter; it goes there to pull them out.
var hunted_spot: Node3D = null
## True while the Clawman walks to a breaking bottle, even if the player is outside its territory.
var investigating_noise: bool = false
## True while the Clawman walks back to its post after losing a player who hid unseen.
var returning_to_post: bool = false
## Where the entity sits back at its post (world space), or INF where it just stands there. It
## stays seated until it first moves, and sits again whenever it is put back at its post.
var seat := Vector3.INF
var seated: bool = false
const GRAB_DAMAGE := 35.0
const SEATED_POSE := preload("res://scenes/monsters/seated_pose.gd")
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
	hunted_spot = null
	investigating_noise = false
	returning_to_post = false
	navigation_route.reset()
	_set_seated(seat != Vector3.INF)
	returned_to_post.emit()

## Gives the entity a new post and puts it there, sitting back at seat if one is given.
func set_post(post: Transform3D, seat_point: Vector3 = Vector3.INF) -> void:
	spawn = post
	seat = seat_point
	reset_enemy()

## Moves the entity, on its feet, without changing its post.
func place(where: Transform3D) -> void:
	global_transform = where
	velocity = Vector3.ZERO
	navigation_route.reset()
	_set_seated(false)

func _set_seated(value: bool) -> void:
	if seated == value:
		return
	seated = value
	SEATED_POSE.apply($Visual, value, to_local(seat) if value else Vector3.ZERO)

## Breaking glass draws the Clawman to the impact unless it is already tracking a hidden player.
## Noise that arrives while it is suspended (the player reading) is kept and acted on afterwards.
func hear_noise(point: Vector3, radius: float) -> void:
	if encounter_kind != 1 or not enabled or is_instance_valid(hunted_spot):
		return
	if global_position.distance_to(point) > radius or point.distance_to(spawn.origin) > territory_radius + 6.0:
		return
	if memory <= 0.0:
		alert_time = 0.6
	last_heard = point
	memory = noise_memory
	investigating_noise = true
	returning_to_post = false
	navigation_route.reset()
	get_tree().call_group("opening_story", "narrate_once", "bottle_lure", "It went after the sound. Now's my chance to slip past.")

## Called as the player climbs into a HidingSpot, before they disappear from view.
func notice_player_hiding(spot: Node3D) -> void:
	if encounter_kind != 1 or not enabled or suspended or not is_instance_valid(player):
		return
	var distance := global_position.distance_to(player.global_position)
	if not _clear_sight(player.camera.global_position):
		return
	if distance < 7.0 or (memory > 0.0 and distance < 10.0):
		hunted_spot = spot
		spot.set("seen_entering", true)
		investigating_noise = false
		returning_to_post = false
		# Head for the spot now instead of finishing the route to where the player stood.
		navigation_route.reset()

## Whether the player can currently see this entity on screen. A hidden player
## watches through vents or door gaps, so their own hiding spot does not block the view.
func is_watched_by_player() -> bool:
	if not is_instance_valid(player):
		return false
	var spot_rids: Array[RID] = []
	if player.is_hidden():
		spot_rids = player.hiding_spot.call("collision_rids")
	if not _clear_sight(player.camera.global_position, spot_rids):
		return false
	var focus := global_position + Vector3.UP
	if player.camera.is_position_behind(focus):
		return false
	return player.get_viewport().get_visible_rect().has_point(player.camera.unproject_position(focus))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not enabled or suspended:
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	warning_cooldown = maxf(0.0, warning_cooldown - delta)
	memory = maxf(0.0, memory - delta)
	var distance := global_position.distance_to(player.global_position)
	var in_territory := encounter_kind == 0 or player.global_position.distance_to(spawn.origin) < territory_radius
	var hidden := player.is_hidden()
	if is_instance_valid(hunted_spot) and player.hiding_spot != hunted_spot:
		hunted_spot = null
	var visible_player := not hidden and _clear_sight(player.camera.global_position)
	var watched := (visible_player or (hidden and encounter_kind == 0)) and is_watched_by_player()
	var should_move := false
	if encounter_kind == 0:
		should_move = in_territory and not watched
		# A hidden player is lost to it: it drifts back to its post, which leaves a way past.
		last_heard = spawn.origin if hidden else player.global_position
	else:
		var noisy := not hidden and Vector2(player.velocity.x, player.velocity.z).length() > 1.0 and not player.is_crouching
		if is_instance_valid(hunted_spot):
			last_heard = hunted_spot.hunter_position()
			memory = maxf(memory, 1.0)
		elif in_territory and ((noisy and distance < 12.0) or (visible_player and distance < 7.0)):
			if memory <= 0.0:
				alert_time = 0.75
			last_heard = player.global_position
			memory = 4.5
			investigating_noise = false
			returning_to_post = false
			if warning_cooldown <= 0.0:
				get_tree().call_group("opening_story", "narrate_once", "claw_warning", "Something heard me. I should keep still and get behind cover.")
				warning_cooldown = 5.0
		elif hidden and memory <= 0.0 and not returning_to_post and global_position.distance_to(spawn.origin) > 1.0:
			# The trail went cold at a hiding spot it never saw used: give up and walk back to its post.
			returning_to_post = true
			last_heard = spawn.origin
			navigation_route.reset()
		if memory <= 0.0:
			investigating_noise = false
		should_move = ((in_territory or investigating_noise) and memory > 0.0) or is_instance_valid(hunted_spot) or returning_to_post
	var motion := Vector3.ZERO
	var goal_distance := Vector2(last_heard.x - global_position.x, last_heard.z - global_position.z).length()
	if returning_to_post and goal_distance <= 0.6:
		returning_to_post = false
		should_move = false
	# Chasing a visible player stops at striking range; every other goal is a place to reach.
	var far_enough := distance > 1.4
	if hidden or (encounter_kind == 1 and (investigating_noise or returning_to_post or is_instance_valid(hunted_spot))):
		far_enough = goal_distance > 0.3
	if is_instance_valid(hunted_spot) and goal_distance <= 0.45 and strike_time <= 0.0 and attack_cooldown <= 0.0:
		var spot := hunted_spot
		hunted_spot = null
		spot.force_out()
		# The grab itself hurts, so climbing straight back in cannot dodge it.
		var grabbed := player.get_node_or_null("CombatHealth")
		if grabbed != null:
			grabbed.take_damage(GRAB_DAMAGE, self)
		get_tree().call_group("opening_story", "narrate_once", "hide_found", "It watched me hide. I can't let it see me get in next time.")
		strike_time = 0.9
		strike_hit = true
		attack_cooldown = 2.0
	if should_move and far_enough:
		# Keep progress through doorway links instead of rebuilding the route
		# every frame and pulling the enemy back onto the exterior polygon.
		if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) > 0:
			motion = navigation_route.direction(self, agent.get_navigation_map(), last_heard, delta) * movement_speed
	# It only moves unwatched, so nobody sees it get up.
	if seated and motion.length() > 0.1:
		_set_seated(false)
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
			health.take_damage(GRAB_DAMAGE, self)
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

func _clear_sight(point: Vector3, also_exclude: Array[RID] = []) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, point)
	var exclude: Array[RID] = [get_rid(), player.get_rid()]
	exclude.append_array(also_exclude)
	ray.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
