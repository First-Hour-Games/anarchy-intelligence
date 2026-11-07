class_name RidgebackAmbusher
extends CharacterBody3D
## One of the Ridgebacks in the alt route's car ambush (scenes/chapters/alt_route/ridgeback_road.gd). It
## gets about by leaping, on all fours: from behind one car to behind another, up onto roofs, over the
## cars and at the player, flying an arc high enough to clear whatever is in the way, or bounding off the
## roof of a car too close in front to clear in one arc. Hidden, it crouches
## facing its car, grunts now and then and rears up to peek over it; on a roof it shrieks and lurks in plain
## view. The road hands out the attacks one at a time: it crouches with a roar, pounces, does 15 damage if
## the player is still there when it comes down, crouches there a moment, open to a shot, and leaps back
## into cover. A hit makes it squeal, flinch and flee. Its voice is a pig's, played low
## (tools/prepare_ridgeback_pig_audio.gd), a little higher or lower in each one of the pack.
## The shotgun's pellets find it through take_shot. Dead, it stays where it fell; a save keeps it dead.

signal died

enum State { DORMANT, HIDING, PEEKING, PERCHED, LEAPING, WINDUP, POUNCING, RECOVERING, HURT, DEAD }

@export var max_health: float = 100.0
@export var pounce_damage: float = 15.0
## It pounces at a player no further than this, along the ground.
@export_range(2.0, 14.0, 0.5, "suffix:m") var pounce_range: float = 8.0
## A pounce hurts if the player is this close to its chest at any point of the dive or the landing.
@export_range(0.5, 3.0, 0.05, "suffix:m") var pounce_reach: float = 1.6
@export_range(0.1, 1.5, 0.05, "suffix:s") var windup_seconds: float = 0.5
## After a pounce it stays crouched where it came down this long, open to a shot, before it leaps away.
@export_range(0.2, 2.0, 0.05, "suffix:s") var recover_seconds: float = 0.9
## How fast a leap covers the ground.
@export_range(2.0, 20.0, 0.5, "suffix:m/s") var leap_speed: float = 8.5
## Seconds it stays hidden before it moves again, between these two.
@export var hide_seconds := Vector2(1.0, 3.0)
@export var perch_seconds := Vector2(1.2, 2.4)
@export_range(0.0, 1.0, 0.05) var peek_chance: float = 0.35
@export_range(0.0, 1.0, 0.05) var perch_chance: float = 0.3
## The death scare names its kill sound by this (scenes/ui/death_scare.gd): the pig scream these ones kill with.
@export var scare_kind: String = "ridgeback_road"

## The body leaves the ground this far into fours_leap, and fours_land and the others last this long
## (tools/blender/ridgeback/clips.py: LEAP_LAUNCH, LAND_FRAMES, PEEK_FRAMES, SHRIEK_FRAMES at 24 fps).
const LEAP_LAUNCH := 5.0 / 24.0
const LAND_SECONDS := 8.0 / 24.0
const PEEK_SECONDS := 36.0 / 24.0
const SHRIEK_SECONDS := 26.0 / 24.0
const HIT_SECONDS := 0.5
## How long the roar from its crouch carries a pounce: one that springs at the player later than this, from
## the roof of a car on the way, roars again.
const ROAR_SECONDS := 1.2
## How high its head is crouched behind a car, and reared up over one.
const HIDDEN_HEAD := 0.75
const PEEKING_HEAD := 1.85

var road: Node
var state: State = State.DORMANT
var health: float
## Kept by the save and by streaming (the story_mob group).
var dead := false
## The story pauses story mobs while a document is open.
var suspended := false
var target: Node3D
var timer := 0.0
## The road's spot it stands on or is leaping to, and the one it started on.
var spot := -1
var home_spot := -1
var _leap_from := Vector3.ZERO
var _leap_to := Vector3.ZERO
var _leap_height := 0.0
var _leap_duration := 0.0
var _leap_time := 0.0
var _leap_then := State.HIDING
var _launched := false
var _landing := false
var _pounce_landed := false
## A leap that cannot clear the car in its way in one arc touches down on that car's roof first and springs
## on from there: LEAPING on to its place, or POUNCING at the player. DORMANT when there is no second leg.
var _onward := State.DORMANT
## A clip to play once the one playing now has run this long, if the state is still the same.
var _next_clip := ""
var _next_clip_in := 0.0
var _next_clip_state := State.HIDING
var _reveal_pending := false
var _since_roar := INF
## Seconds until it next looks whether its cover still hides it, and until it may grunt from hiding.
var _exposure_check := 0.0
var _grunt_in := 4.0
## Where it crouches at its place; a peek leans it this far toward its car.
var _crouch_at := Vector3.ZERO
var _lean: Tween
var _rng := RandomNumberGenerator.new()

@onready var visual: RidgebackVisual = $Visual
@onready var body_shape: CollisionShape3D = $BodyShape
@onready var peek_shape: CollisionShape3D = $PeekShape
@onready var grunt: AudioStreamPlayer3D = $Grunt
@onready var shriek: AudioStreamPlayer3D = $Shriek
@onready var roar: AudioStreamPlayer3D = $Roar
@onready var pain: AudioStreamPlayer3D = $Pain
@onready var death_cry: AudioStreamPlayer3D = $DeathCry
@onready var thud: AudioStreamPlayer3D = $Thud
@onready var clang: AudioStreamPlayer3D = $Clang
## The slam, claws and snarl of a pounce that lands (tools/prepare_ridgeback_audio.gd). It always processes,
## so a killing strike is heard through the death scare that stops everything else.
@onready var strike: AudioStreamPlayer3D = $Strike
## Its cries, which its one throat makes one at a time.
@onready var _cries: Array[AudioStreamPlayer3D] = [grunt, shriek, roar, pain, death_cry]


func _ready() -> void:
	add_to_group(&"story_mob")
	add_to_group(&"corrupted_friend")
	health = max_health
	_rng.randomize()
	# Each one of the pack has a voice of its own, a little higher or lower than the others'.
	var voice_pitch := _rng.randf_range(0.92, 1.08)
	for cry in _cries:
		cry.pitch_scale *= voice_pitch
	peek_shape.disabled = true
	visual.play("hide", true)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	if suspended or not is_instance_valid(road):
		return
	timer -= delta
	_since_roar += delta
	if _next_clip != "":
		_next_clip_in -= delta
		if _next_clip_in <= 0.0:
			if state == _next_clip_state:
				visual.play(_next_clip, true)
			_next_clip = ""
	match state:
		State.DORMANT:
			pass
		State.HIDING:
			_face(road.spot_facing(spot), delta, 6.0)
			_exposure_check -= delta
			var exposed := false
			if _exposure_check <= 0.0:
				_exposure_check = 0.25
				exposed = road.spot_exposed(spot)
			_grunt_in -= delta
			if _grunt_in <= 0.0:
				_grunt_in = _rng.randf_range(5.0, 11.0)
				if is_instance_valid(target) and (_reveal_pending or global_position.distance_to(target.global_position) < 14.0):
					_cry(grunt)
			if timer <= 0.0 or exposed:
				_decide()
		State.PEEKING:
			_face(road.spot_facing(spot), delta, 6.0)
			if timer <= 0.0:
				_end_peek()
		State.PERCHED:
			_face_target(delta)
			if timer <= 0.0:
				_decide()
		State.LEAPING, State.POUNCING:
			_fly(delta)
		State.WINDUP:
			_face_target(delta, 12.0)
			if timer <= 0.0:
				_pounce()
		State.RECOVERING:
			_face_target(delta)
			if timer <= 0.0:
				road.release_attack(self)
				_flee()
		State.HURT:
			if timer <= 0.0:
				_flee()


## Wakes it: it starts moving among the cars after `delay` seconds.
func activate(delay: float = 0.0) -> void:
	if state != State.DORMANT:
		return
	state = State.HIDING
	timer = delay


## The first one the player sees: it grunts from hiding, then after `delay` seconds its first move is up
## onto a roof in view, shrieking.
func reveal(delay: float = 0.35) -> void:
	_reveal_pending = true
	if state == State.DORMANT:
		state = State.HIDING
	timer = delay
	_grunt_in = delay * 0.4


func _decide() -> void:
	if not is_instance_valid(target):
		timer = 1.0
		return
	if _reveal_pending:
		_reveal_pending = false
		var perch: int = road.pick_spot(self, true, false)
		if perch >= 0:
			_leap(perch, State.PERCHED)
			return
	var distance := _flat(target.global_position - global_position).length()
	if distance <= pounce_range and road.can_pounce_from(self) and road.claim_attack(self):
		_start_windup()
		return
	if state == State.HIDING and not road.spot_exposed(spot) and distance < 22.0 and road.spot_can_peek(spot) \
			and _rng.randf() < peek_chance:
		_start_peek()
		return
	var next: int = road.pick_spot(self, _rng.randf() < perch_chance, false)
	if next < 0:
		next = road.pick_spot(self, false, false)
	if next >= 0:
		_leap(next, State.PERCHED if road.spot_is_perch(next) else State.HIDING)
	else:
		timer = _rng.randf_range(0.4, 0.9)


func _start_peek() -> void:
	state = State.PEEKING
	timer = PEEK_SECONDS
	peek_shape.disabled = false
	visual.play("peek", true)
	if _rng.randf() < 0.5:
		_cry(grunt)
	# Up against the car, so the claws hook over its edge, and back down to where it crouched.
	_crouch_at = global_position
	var toward := _flat(road.spot_facing(spot)).normalized() * 0.22
	_cancel_lean()
	_lean = create_tween()
	_lean.tween_property(self, "global_position", _crouch_at + toward, 0.3).set_trans(Tween.TRANS_SINE)
	_lean.tween_interval(PEEK_SECONDS - 0.75)
	_lean.tween_property(self, "global_position", _crouch_at, 0.35).set_trans(Tween.TRANS_SINE)


func _end_peek() -> void:
	peek_shape.disabled = true
	_cancel_lean()
	global_position = _crouch_at
	_hide(_rng.randf_range(0.4, 1.2))


func _cancel_lean() -> void:
	if _lean != null and _lean.is_valid():
		_lean.kill()
	_lean = null


func _hide(seconds: float) -> void:
	state = State.HIDING
	timer = seconds
	visual.play("hide")


func _start_windup() -> void:
	if state == State.PEEKING:
		_cancel_lean()
		global_position = _crouch_at
	state = State.WINDUP
	timer = windup_seconds
	peek_shape.disabled = true
	visual.play("windup", true)
	# The roar starts with the crouch, the player's warning, and carries on through the leap.
	_cry(roar)
	_since_roar = 0.0


## Leaps at where the player will be, landing a step short of them.
func _pounce() -> void:
	if not is_instance_valid(target):
		road.release_attack(self)
		_hide(1.0)
		return
	var aim := target.global_position
	var moving: Variant = target.get("velocity")
	if moving is Vector3:
		aim += Vector3(moving.x, 0.0, moving.z) * 0.3
	var along := _flat(aim - global_position)
	var reach := minf(along.length(), pounce_range + 1.0)
	var landing := global_position + along.normalized() * maxf(reach - 0.9, 0.0)
	landing.y = road.ground_height(landing, global_position.y)
	var height: float = road.arc_height(global_position, landing)
	var vault: Vector3 = Vector3.INF if height >= 0.0 else road.vault_point(global_position, landing)
	if height < 0.0 and vault == Vector3.INF:
		road.release_attack(self)
		_flee()
		return
	_release_spot()
	_pounce_landed = false
	if _since_roar > ROAR_SECONDS:
		# Springing at the player from a roof, its first roar spent.
		_cry(roar)
		_since_roar = 0.0
	if vault != Vector3.INF:
		# Up onto the car between them, and at the player from its roof, wherever they are by then.
		_onward = State.POUNCING
		_begin_flight(vault, road.arc_height(global_position, vault), State.RECOVERING)
		state = State.LEAPING
	else:
		_onward = State.DORMANT
		_begin_flight(landing, maxf(height, 0.6), State.RECOVERING)
		state = State.POUNCING
	visual.play("leap", true)


func _flee() -> void:
	var next: int = road.pick_spot(self, false, true)
	if next >= 0:
		_leap(next, State.HIDING)
	else:
		_hide(_rng.randf_range(0.6, 1.4))


func _leap(next: int, then: State) -> void:
	var landing: Vector3 = road.spot_position(next)
	var height: float = road.arc_height(global_position, landing)
	var vault: Vector3 = Vector3.INF if height >= 0.0 else road.vault_point(global_position, landing)
	if height < 0.0 and vault == Vector3.INF:
		_hide(_rng.randf_range(0.3, 0.8))
		return
	_release_spot()
	spot = next
	road.reserve_spot(self, next)
	peek_shape.disabled = true
	if vault != Vector3.INF:
		_onward = State.LEAPING
		_begin_flight(vault, road.arc_height(global_position, vault), then)
	else:
		_onward = State.DORMANT
		_begin_flight(landing, height, then)
	state = State.LEAPING
	visual.play("leap", true)


func _begin_flight(landing: Vector3, height: float, then: State) -> void:
	_leap_from = global_position
	_leap_to = landing
	_leap_height = height
	var length := _flat(landing - global_position).length()
	_leap_duration = clampf(0.2 + length / leap_speed + 0.12 * height, 0.4, 1.25)
	_leap_time = -LEAP_LAUNCH
	_leap_then = then
	_launched = false
	_landing = false
	var heading := _flat(landing - global_position)
	if heading.length() > 0.05:
		rotation.y = atan2(-heading.x, -heading.z)


## Follows the arc: a parabola over the chord between take-off and landing, `_leap_height` above it at
## the top, after the take-off's gather. The model tips with the slope of the arc.
func _fly(delta: float) -> void:
	_leap_time += delta
	if _leap_time < 0.0:
		return
	if not _launched:
		_launched = true
		visual.play("airborne", true)
	var s := clampf(_leap_time / _leap_duration, 0.0, 1.0)
	var here := _leap_from.lerp(_leap_to, s)
	here.y += 4.0 * _leap_height * s * (1.0 - s)
	global_position = here
	var climb := (_leap_to.y - _leap_from.y) + 4.0 * _leap_height * (1.0 - 2.0 * s)
	var run := maxf(_flat(_leap_to - _leap_from).length(), 0.01)
	visual.rotation.x = clampf(atan2(climb, run) * 0.5, -0.45, 0.45)
	if state == State.POUNCING and not _pounce_landed and s > 0.45:
		_try_pounce_hit()
		# A killing hit has stopped the world for the death scare, which plays its own clip on this one.
		if not can_process():
			return
	if not _landing and s >= 0.86:
		_landing = true
		visual.play("land", true)
	if s >= 1.0:
		_touch_down()


func _touch_down() -> void:
	visual.rotation.x = 0.0
	var on_roof: bool = road.is_roof(global_position)
	(clang if on_roof else thud).play()
	if _onward != State.DORMANT:
		var onward := _onward
		_onward = State.DORMANT
		if onward == State.POUNCING:
			_pounce()
		else:
			var landing: Vector3 = road.spot_position(spot)
			_begin_flight(landing, maxf(road.arc_height(global_position, landing), 0.6), _leap_then)
			state = State.LEAPING
			visual.play("leap", true)
		return
	if state == State.POUNCING:
		if not _pounce_landed:
			_try_pounce_hit()
		state = State.RECOVERING
		timer = recover_seconds
		_queue_clip("perch", LAND_SECONDS)
		return
	match _leap_then:
		State.PERCHED:
			state = State.PERCHED
			timer = SHRIEK_SECONDS + _rng.randf_range(perch_seconds.x, perch_seconds.y)
			visual.play("shriek", true)
			_cry(shriek)
			_queue_clip("perch", SHRIEK_SECONDS)
		_:
			_hide(LAND_SECONDS + _rng.randf_range(hide_seconds.x, hide_seconds.y))
			_queue_clip("hide", LAND_SECONDS)


func _try_pounce_hit() -> void:
	if not is_instance_valid(target):
		return
	var chest := global_position + Vector3.UP * 0.6
	var centre := target.global_position + Vector3.UP * 0.9
	if chest.distance_to(centre) > pounce_reach:
		return
	_pounce_landed = true
	# The roar ends in the bite.
	_quiet()
	strike.play()
	var health_node := target.get_node_or_null("CombatHealth")
	if health_node != null and health_node.has_method("take_damage"):
		health_node.take_damage(pounce_damage, self)
		# A killing hit stops the world for the death scare, this one too: it finishes its lunge onto the
		# player rather than hanging in the air, while the death scare plays its own clip on it.
		if bool(health_node.get("is_dead")):
			visual.rotation.x = 0.0
			var rest := (1.0 - clampf(_leap_time / _leap_duration, 0.0, 1.0)) * _leap_duration
			if rest > 0.02:
				var lunge := get_tree().create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				lunge.tween_property(self, "global_position", _leap_to, rest).set_trans(Tween.TRANS_QUAD) \
					.set_ease(Tween.EASE_IN)
	elif target.has_method("take_damage"):
		target.take_damage(pounce_damage)


## Plays `clip` once the clip playing now has had `after` seconds, unless the state moved on.
func _queue_clip(clip: String, after: float) -> void:
	_next_clip = clip
	_next_clip_in = after
	_next_clip_state = state


## Lets out one of its cries, cutting off any it was making.
func _cry(cry: AudioStreamPlayer3D) -> void:
	_quiet()
	cry.play()


func _quiet() -> void:
	for cry in _cries:
		cry.stop()


## The shotgun's pellets, summed over one shot.
func take_shot(damage: float, _from: Vector3 = Vector3.ZERO) -> void:
	take_damage(damage)


func take_damage(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	if state == State.DORMANT:
		state = State.HIDING
	health = maxf(health - amount, 0.0)
	if state == State.PEEKING:
		_cancel_lean()
		global_position = _crouch_at
	if health <= 0.0:
		_die()
		return
	if state in [State.LEAPING, State.POUNCING]:
		return
	if state in [State.WINDUP, State.RECOVERING]:
		road.release_attack(self)
	peek_shape.disabled = true
	state = State.HURT
	timer = HIT_SECONDS
	visual.play("hit", true)
	_cry(pain)


func _die() -> void:
	road.release_attack(self)
	_release_spot()
	dead = true
	state = State.DEAD
	visual.rotation.x = 0.0
	body_shape.set_deferred("disabled", true)
	peek_shape.set_deferred("disabled", true)
	_cry(death_cry)
	# Shot out of the air, it drops to whatever is under it first.
	var floor_height: float = road.ground_height(global_position, global_position.y)
	if global_position.y - floor_height > 0.05:
		var fall := create_tween()
		fall.tween_property(self, "global_position:y", floor_height, clampf((global_position.y - floor_height) * 0.25, 0.12, 0.5)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	visual.play("dead", true)
	died.emit()


## Puts it back dead where a save or streaming left it, lying still.
func restore_dead(at: Vector3, yaw: float) -> void:
	if not is_node_ready():
		await ready
	_release_spot()
	dead = true
	state = State.DEAD
	health = 0.0
	global_position = at
	rotation.y = yaw
	body_shape.set_deferred("disabled", true)
	peek_shape.set_deferred("disabled", true)
	visual.play("dead", true)
	var player := visual.animation_player
	if player != null and player.current_animation != &"":
		player.seek(player.current_animation_length, true)


## The player came back from a death: the living ones go back to where they started, still.
func reset_enemy() -> void:
	# The death scare froze every sound where it was; none may carry on once the world moves again.
	_quiet()
	for sound: AudioStreamPlayer3D in [strike, thud, clang]:
		sound.stop()
	if dead:
		return
	if is_instance_valid(road):
		road.release_attack(self)
	_release_spot()
	_cancel_lean()
	health = max_health
	visual.rotation.x = 0.0
	peek_shape.disabled = true
	body_shape.disabled = false
	_reveal_pending = false
	_next_clip = ""
	_onward = State.DORMANT
	state = State.DORMANT
	if is_instance_valid(road) and home_spot >= 0:
		spot = home_spot
		road.reserve_spot(self, home_spot)
		global_position = road.spot_position(home_spot)
		rotation.y = road.spot_yaw(home_spot)
	visual.play("hide", true)


func is_hidden_now() -> bool:
	return state in [State.DORMANT, State.HIDING]


func head_height() -> float:
	return PEEKING_HEAD if state == State.PEEKING else HIDDEN_HEAD


func _release_spot() -> void:
	if spot >= 0 and is_instance_valid(road):
		road.release_spot(self, spot)
	spot = -1


func _face(direction: Vector3, delta: float, rate: float) -> void:
	var flat := _flat(direction)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-rate * delta))


func _face_target(delta: float, rate: float = 7.0) -> void:
	if is_instance_valid(target):
		_face(target.global_position - global_position, delta, rate)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
