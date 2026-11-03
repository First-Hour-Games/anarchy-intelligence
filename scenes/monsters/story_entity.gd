extends CharacterBody3D

## Emitted when the entity is put back at its post: placed there, or reset when the player respawns.
signal returned_to_post
## Emitted once, when the pipe kills a killable entity.
signal died

@export_enum("Wrapper", "Clawman") var encounter_kind: int = 0
@export var movement_speed: float = 1.25
@export var territory_radius: float = 22.0
@export var max_step_height: float = 0.4
## The generator ambush disables this on its own instance so it can approach in view.
@export var freeze_when_watched: bool = true
## Seconds the Clawman spends investigating a breaking bottle.
@export var noise_memory: float = 7.0
## Pipe hits that kill it; 0 means it can only be staggered. The count resets when the player respawns.
@export var hits_to_kill: int = 0
## How fast the ragdoll is thrown away from the player by the killing blow.
@export var death_push_speed: float = 2.0

@export_group("Roaming")
## Free-roaming Wrapper (spawn points): wanders near its home, hunts a player it hears, and
## walks home after losing them. It keeps moving while watched. Story Wrappers leave this off.
@export var roaming: bool = false
## Wandering stays within this distance of home (where it was placed).
@export_range(1.0, 60.0, 0.5, "suffix:m") var wander_radius: float = 12.0
@export_range(0.1, 5.0, 0.05, "suffix:m/s") var wander_speed: float = 0.7
@export_range(0.0, 20.0, 0.1, "suffix:s") var wander_pause_min: float = 1.5
@export_range(0.0, 20.0, 0.1, "suffix:s") var wander_pause_max: float = 4.0
@export_range(0.1, 6.0, 0.05, "suffix:m/s") var hunt_speed: float = 1.4
## Footsteps carry this far at full noise (sprinting); quieter steps carry proportionally less.
@export_range(1.0, 60.0, 0.5, "suffix:m") var detection_distance: float = 18.0
## Noise from 0 to 1 by how the player moves. Hearing range is detection_distance x noise.
@export_range(0.0, 1.0, 0.05) var sprint_noise: float = 1.0
@export_range(0.0, 1.0, 0.05) var walk_noise: float = 0.55
@export_range(0.0, 1.0, 0.05) var crouch_noise: float = 0.2
## Quieter than this is never heard, however close.
@export_range(0.0, 1.0, 0.05) var noise_threshold: float = 0.15
## Slower than this counts as standing still: no noise at all.
@export_range(0.0, 3.0, 0.05, "suffix:m/s") var min_noise_speed: float = 0.5
## The hunt ends after the player stays farther than escape_distance (or hidden) this long.
@export_range(1.0, 80.0, 0.5, "suffix:m") var escape_distance: float = 22.0
@export_range(0.1, 30.0, 0.1, "suffix:s") var escape_time: float = 6.0
@export_group("")

enum RoamState { WANDERING, HUNTING, RETURNING }
var roam_state: RoamState = RoamState.WANDERING
## Where a roaming entity was placed; it always returns here, never to a wander destination.
var home := Vector3.ZERO
var wander_target := Vector3.INF
var wander_pause: float = 0.0
var _wander_time: float = 0.0
var _lost_time: float = 0.0
## Gives up on a wander destination it cannot reach after this long.
const WANDER_TIMEOUT := 15.0
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
var melee_stagger_time: float = 0.0
var _melee_push := Vector3.ZERO
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
const RAGDOLL := preload("res://scenes/monsters/ragdoll.gd")
var hits_taken: int = 0
## Dead for good: nothing moves, resets or revives it, and saves keep it dead.
var dead: bool = false
var _pending_corpse: Array = []
@onready var agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	add_to_group("story_mob")
	add_to_group("corrupted_friend")
	spawn = global_transform
	home = spawn.origin
	player = get_tree().get_first_node_in_group("player") as FirstPersonPlayer
	if not _pending_corpse.is_empty():
		var corpse := _pending_corpse
		_pending_corpse = []
		restore_dead(corpse[0], corpse[1])

func reset_enemy() -> void:
	if dead:
		return
	hits_taken = 0
	global_transform = spawn
	velocity = Vector3.ZERO
	memory = 0.0
	attack_cooldown = 2.0
	strike_time = 0.0
	alert_time = 0.0
	melee_stagger_time = 0.0
	_melee_push = Vector3.ZERO
	hunted_spot = null
	investigating_noise = false
	returning_to_post = false
	navigation_route.reset()
	_set_roam_state(RoamState.WANDERING)
	_set_seated(seat != Vector3.INF)
	returned_to_post.emit()

## Gives the entity a new post and puts it there, sitting back at seat if one is given.
func set_post(post: Transform3D, seat_point: Vector3 = Vector3.INF) -> void:
	if dead:
		return
	spawn = post
	seat = seat_point
	reset_enemy()

## Moves the entity, on its feet, without changing its post.
func place(where: Transform3D) -> void:
	if dead:
		return
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
	if dead or encounter_kind != 1 or not enabled or is_instance_valid(hunted_spot):
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
	if dead or encounter_kind != 1 or not enabled or suspended or not is_instance_valid(player):
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
	if dead or not is_instance_valid(player):
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

func take_melee_hit(from_position: Vector3, duration: float, push_speed: float) -> void:
	if dead or not enabled or suspended:
		return
	var away := global_position - from_position
	away.y = 0.0
	hits_taken += 1
	if hits_to_kill > 0 and hits_taken >= hits_to_kill:
		_die(away.normalized() * death_push_speed + Vector3.UP * 0.5)
		return
	# Being hit gives the player away.
	if roaming and roam_state != RoamState.HUNTING:
		_set_roam_state(RoamState.HUNTING)
	# A hit that does not stun counts toward killing it but does not stop it.
	if duration <= 0.0:
		return
	_melee_push = away.normalized() * push_speed
	melee_stagger_time = maxf(melee_stagger_time, duration)
	strike_time = 0.0
	strike_hit = true
	attack_cooldown = maxf(attack_cooldown, duration + 0.3)
	navigation_route.reset()

## Lays a saved corpse back down where it died, without the killing push. A streamed section
## restores before it enters the tree, so the corpse waits for _ready then.
func restore_dead(origin: Vector3, yaw: float) -> void:
	if dead:
		return
	if not is_inside_tree():
		_pending_corpse = [origin, yaw]
		return
	global_transform = Transform3D(Basis(Vector3.UP, yaw).scaled(global_basis.get_scale()), origin)
	_die(Vector3.ZERO)

func _die(push: Vector3) -> void:
	dead = true
	enabled = false
	velocity = Vector3.ZERO
	strike_time = 0.0
	melee_stagger_time = 0.0
	hunted_spot = null
	_set_seated(false)
	# Off now, not deferred: the ragdoll's first physics step must not start inside it.
	($CollisionShape3D as CollisionShape3D).disabled = true
	RAGDOLL.fall(self, $Visual, push)
	died.emit()

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(player) or not enabled or suspended:
		return
	if melee_stagger_time > 0.0:
		melee_stagger_time = maxf(0.0, melee_stagger_time - delta)
		velocity.x = _melee_push.x
		velocity.z = _melee_push.z
		velocity.y = velocity.y - 9.8 * delta if not is_on_floor() else 0.0
		_melee_push = _melee_push.move_toward(Vector3.ZERO, delta * 5.0)
		if $Visual.has_method("play"):
			$Visual.play("idle")
		move_and_slide()
		return
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	warning_cooldown = maxf(0.0, warning_cooldown - delta)
	memory = maxf(0.0, memory - delta)
	if roaming and encounter_kind == 0:
		_roam(delta)
		return
	var distance := global_position.distance_to(player.global_position)
	var in_territory := encounter_kind == 0 or player.global_position.distance_to(spawn.origin) < territory_radius
	var hidden := player.is_hidden()
	if is_instance_valid(hunted_spot) and player.hiding_spot != hunted_spot:
		hunted_spot = null
	var visible_player := not hidden and _clear_sight(player.camera.global_position)
	var watched := (visible_player or (hidden and encounter_kind == 0)) and is_watched_by_player()
	var should_move := false
	if encounter_kind == 0:
		should_move = in_territory and (not freeze_when_watched or not watched)
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
	if in_territory and distance < 1.65 and visible_player and attack_cooldown <= 0.0 and strike_time <= 0.0 and (encounter_kind == 1 or not freeze_when_watched or not watched):
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
	_move(motion, delta)

## Plays the matching clip and moves (motion is the wanted horizontal velocity).
func _move(motion: Vector3, delta: float) -> void:
	var visual := $Visual
	if visual.has_method("play") and not seated:
		visual.play("attack" if strike_time > 0.0 else "windup" if alert_time > 0.0 else "run" if motion.length() > 0.1 else "idle")
	velocity.x = motion.x
	velocity.z = motion.z
	velocity.y = velocity.y - 9.8 * delta if not is_on_floor() else 0.0
	if motion.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-motion.x, -motion.z), delta * 4.0)
	StairStepping.apply(self, delta, max_step_height)
	move_and_slide()

## True while this entity is after the player: always for story entities, only while
## HUNTING for a roaming one. The hunt music follows it.
func is_hunting() -> bool:
	return not dead and (not roaming or roam_state == RoamState.HUNTING)

## How much noise the player is making, 0 to 1: none standing still, hidden or frozen.
func player_noise() -> float:
	if not is_instance_valid(player) or player.is_hidden() or player.is_frozen:
		return 0.0
	if Vector2(player.velocity.x, player.velocity.z).length() < min_noise_speed:
		return 0.0
	if player.is_crouching:
		return crouch_noise
	return sprint_noise if player.is_sprinting else walk_noise

## Whether the player is loud enough and close enough to be heard.
func hears_player() -> bool:
	var noise := player_noise()
	if noise <= 0.0 or noise < noise_threshold:
		return false
	return global_position.distance_to(player.global_position) <= detection_distance * noise

func _set_roam_state(next: RoamState) -> void:
	if next == RoamState.HUNTING and roam_state != RoamState.HUNTING:
		alert_time = 0.75
	roam_state = next
	_lost_time = 0.0
	wander_target = Vector3.INF
	_wander_time = 0.0
	if next == RoamState.WANDERING:
		wander_pause = randf_range(wander_pause_min, maxf(wander_pause_min, wander_pause_max))
	navigation_route.reset()

## WANDERING near home, HUNTING the player it heard, RETURNING home once they escape.
func _roam(delta: float) -> void:
	var nav_map := agent.get_navigation_map()
	var nav_ready := NavigationServer3D.map_get_iteration_id(nav_map) > 0
	var distance := global_position.distance_to(player.global_position)
	var hidden := player.is_hidden()
	if roam_state != RoamState.HUNTING and hears_player():
		_set_roam_state(RoamState.HUNTING)
	var motion := Vector3.ZERO
	match roam_state:
		RoamState.HUNTING:
			if not hidden:
				last_heard = player.global_position
			_lost_time = _lost_time + delta if hidden or distance > escape_distance else 0.0
			if _lost_time >= escape_time:
				_set_roam_state(RoamState.RETURNING)
			elif nav_ready and (distance > 1.4 or hidden) and _flat_distance(last_heard) > 0.3:
				motion = navigation_route.direction(self, nav_map, last_heard, delta) * hunt_speed
		RoamState.RETURNING:
			if _flat_distance(home) <= 0.8:
				_set_roam_state(RoamState.WANDERING)
			elif nav_ready:
				motion = navigation_route.direction(self, nav_map, home, delta) * movement_speed
		RoamState.WANDERING:
			if wander_pause > 0.0:
				wander_pause = maxf(0.0, wander_pause - delta)
			elif not wander_target.is_finite():
				if nav_ready:
					wander_target = _pick_wander_target(nav_map)
			elif _flat_distance(wander_target) <= 0.6 or _wander_time > WANDER_TIMEOUT:
				_set_roam_state(RoamState.WANDERING)
			else:
				_wander_time += delta
				motion = navigation_route.direction(self, nav_map, wander_target, delta) * wander_speed
	var visible_player := not hidden and _clear_sight(player.camera.global_position)
	if roam_state == RoamState.HUNTING and distance < 1.65 and visible_player and attack_cooldown <= 0.0 and strike_time <= 0.0:
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
	_move(motion, delta)

## A random reachable point on the navigation map within wander_radius of home, or INF.
func _pick_wander_target(nav_map: RID) -> Vector3:
	var lift := Vector3.UP * 0.6
	for attempt in 8:
		var angle := randf() * TAU
		var reach := sqrt(randf()) * wander_radius
		var point := NavigationServer3D.map_get_closest_point(nav_map, home + Vector3(cos(angle), 0.0, sin(angle)) * reach)
		if Vector2(point.x - home.x, point.z - home.z).length() > wander_radius or _flat_distance(point) < 1.5:
			continue
		var path := NavigationServer3D.map_get_path(nav_map, global_position + lift, point + lift, true)
		if path.size() >= 2 and path[path.size() - 1].distance_to(point + lift) < 1.0:
			return point
	return Vector3.INF

func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()

func _clear_sight(point: Vector3, also_exclude: Array[RID] = []) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.3, point)
	var exclude: Array[RID] = [get_rid(), player.get_rid()]
	exclude.append_array(also_exclude)
	ray.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
