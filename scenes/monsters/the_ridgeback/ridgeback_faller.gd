class_name RidgebackFaller
extends CharacterBody3D
## One of the Ridgebacks on the roofs of the alt route's downtown (scenes/chapters/alt_route/rooftop_street.gd,
## which runs them all). It stands on a roof's edge over the street with the rest of its line, swaying and
## staring down, until the street makes the whole line shriek. When its turn comes it throws itself off at a
## point the street picks in front of the player, on the road or on a car's roof, falls flailing and
## screaming, and hits. Some die of it and lie where they hit. The rest lose their legs
## (ridgeback_faller_visual.gd), leave them lying there and drag themselves after the player on their arms,
## round the cars, to claw at the ankles: grab_damage, and the player held back a moment. One that lands on
## the player crushes for crush_damage.
## The shotgun's pellets find it through take_shot. On the roof a hit sends it off the edge early, at the
## player, or tips it off dead; any real hit in the air kills it before it lands; a crawler takes a couple.
## Its voice is the road Ridgebacks' pig, a little higher or lower in each one. Which of the ten walkers it is
## (its visual's walker) sets its look, its size (its shapes grow to match) and its voice's pitch.

signal landed(faller: RidgebackFaller)
signal died(faller: RidgebackFaller)

enum State { PERCHED, SHRIEKING, LEAPING, FALLING, SPLATTED, RISING, CRAWLING, GRABBING, HURT, DEAD }

@export var perch_health: float = 60.0
@export var crawler_health: float = 40.0
## A hit at least this hard while it falls kills it before it lands.
@export var air_kill_damage: float = 12.0
@export_range(0.2, 3.0, 0.05, "suffix:m/s") var crawl_speed: float = 1.0
## It claws when the player is this close to its head, and the claw lands if the player is still within
## grab_reach of it.
@export_range(0.5, 3.0, 0.05, "suffix:m") var grab_range: float = 1.25
@export_range(0.5, 3.0, 0.05, "suffix:m") var grab_reach: float = 1.8
@export var grab_damage: float = 12.0
@export_range(0.2, 5.0, 0.1, "suffix:s") var grab_cooldown: float = 1.5
@export_range(0.0, 3.0, 0.1, "suffix:s") var grab_hold_seconds: float = 0.8
@export_range(5.0, 30.0, 0.5, "suffix:m/s²") var fall_gravity: float = 13.0
@export var crush_damage: float = 25.0
## The death scare's kind when one kills the player (scenes/ui/death_scare.gd).
@export var scare_kind: String = "ridgeback_road"

const SHRIEK_SECONDS := 34.0 / 24.0
const LEAP_LAUNCH := 9.0 / 24.0
const SPLAT_SECONDS := 30.0 / 24.0
const RISE_SECONDS := 26.0 / 24.0
const GRAB_SECONDS := 24.0 / 24.0
const GRAB_HIT := 10.0 / 24.0
const HIT_SECONDS := 12.0 / 24.0
## How fast it hops up off the edge as it throws itself off, m/s.
const HOP := 2.2
## How far the fall pitches it forward by the time it lands, degrees.
const FALL_PITCH := 30.0
## How close to where it lands the player has to be for it to land on them, metres.
const CRUSH_RADIUS := 1.0
const PATH_REFRESH := 0.4
## The drag mark is laid in stretches this long.
const TRAIL_STEP := 0.55
const CHEST_STANDING := 1.55
const CHEST_LYING := 0.42
## How far in front of its hips a crawler's head is, lying down.
const HEAD_AHEAD := 0.8

@onready var visual: RidgebackFallerVisual = $Visual
@onready var stand_shape: CollisionShape3D = $StandShape
@onready var crawl_shape: CollisionShape3D = $CrawlShape
## A faint light on it from the street's side, so the line shows against the night sky; out once it is down.
@onready var rim: OmniLight3D = $Rim
@onready var shriek: AudioStreamPlayer3D = $Shriek
@onready var roar: AudioStreamPlayer3D = $Roar
@onready var fall_scream: AudioStreamPlayer3D = $FallScream
@onready var grunt: AudioStreamPlayer3D = $Grunt
@onready var pain: AudioStreamPlayer3D = $Pain
@onready var death_cry: AudioStreamPlayer3D = $DeathCry
@onready var impact: AudioStreamPlayer3D = $Impact
@onready var bones: AudioStreamPlayer3D = $Bones
@onready var squelch: AudioStreamPlayer3D = $Squelch
@onready var glass: AudioStreamPlayer3D = $Glass
## The claw landing (tools/prepare_ridgeback_audio.gd). It always processes, so a killing claw is heard
## through the death scare that stops everything else.
@onready var strike: AudioStreamPlayer3D = $Strike
## Its cries, which its one throat makes one at a time.
@onready var _cries: Array[AudioStreamPlayer3D] = [shriek, roar, fall_scream, grunt, pain, death_cry]

var street: Node
var state: State = State.PERCHED
var health: float
var dead := false
## Whether it lives through the fall; the street decides as it sends it off.
var survives := true
var suspended := false
var target: Node3D
var timer := 0.0
var home := Transform3D.IDENTITY
## The car it is falling onto, if any.
var landing_car: Node3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _launch_velocity := Vector3.ZERO
var _fall_time := 0.0
var _fall_duration := 0.0
var _waypoint := Vector3.ZERO
var _path_in := 0.0
var _grab_cool := 0.0
var _grab_landed := false
var _grunt_in := 2.0
var _trail_from := Vector3.ZERO
## Counts its returns to the roof, so a shriek it was waiting to give before one is never given after it.
var _wake := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"story_mob")
	add_to_group(&"corrupted_friend")
	_rng.randomize()
	var voice := _rng.randf_range(0.9, 1.1) * visual.voice_pitch
	for cry in _cries:
		cry.pitch_scale *= voice
	_fit_shapes(visual.walker_scale)
	health = perch_health
	home = global_transform
	visual.play("perch", true)
	visual.scatter_phase(_rng)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group(&"player") as Node3D
	if suspended:
		return
	timer -= delta
	match state:
		State.SHRIEKING:
			if timer <= 0.0:
				state = State.PERCHED
				visual.play("perch")
		State.LEAPING:
			if timer <= 0.0:
				_launch()
		State.FALLING:
			_fall(delta)
		State.SPLATTED:
			if timer <= 0.0:
				_after_splat()
		State.RISING:
			if timer <= 0.0:
				state = State.CRAWLING
				visual.play("crawl")
		State.CRAWLING:
			_crawl(delta)
		State.GRABBING:
			_grab(delta)
		State.HURT:
			if timer <= 0.0:
				state = State.CRAWLING
				visual.play("crawl")


## Stands it on a roof's edge, facing the street, swaying with the rest of the line.
func perch(at: Transform3D) -> void:
	home = at
	_restore()


## The line's shriek, `delay` seconds from now.
func line_shriek(delay: float) -> void:
	if state != State.PERCHED:
		return
	var wake := _wake
	await get_tree().create_timer(delay, false).timeout
	if wake != _wake or state != State.PERCHED or dead:
		return
	state = State.SHRIEKING
	timer = SHRIEK_SECONDS
	visual.play("shriek", true)
	_cry(shriek)


## Throws itself off the roof at `point`, on `car`'s roof if a car is given; `lives` is whether it survives.
func jump_at(point: Vector3, lives: bool, car: Node3D = null) -> void:
	if state not in [State.PERCHED, State.SHRIEKING]:
		return
	_to = point
	survives = lives and not dead
	landing_car = car
	state = State.LEAPING
	timer = LEAP_LAUNCH
	visual.play("leap", true)
	_cry(roar)
	var across := _flat(point - global_position)
	if across.length() > 0.01:
		rotation.y = atan2(-across.x, -across.z)


func is_perched() -> bool:
	return state in [State.PERCHED, State.SHRIEKING]


func is_crawling() -> bool:
	return state in [State.RISING, State.CRAWLING, State.GRABBING, State.HURT]


func is_falling() -> bool:
	return state in [State.LEAPING, State.FALLING]


## The point a pellet should bleed from.
func chest() -> Vector3:
	var lying := visual.is_crawler or state in [State.SPLATTED, State.DEAD]
	return global_position + Vector3.UP * (CHEST_LYING if lying else CHEST_STANDING) * visual.walker_scale


## A walker drawn bigger or smaller than the original gets shapes to match (copies: the scene's are shared).
func _fit_shapes(grow: float) -> void:
	if is_equal_approx(grow, 1.0):
		return
	for holder: CollisionShape3D in [stand_shape, crawl_shape]:
		var capsule := holder.shape.duplicate() as CapsuleShape3D
		capsule.radius *= grow
		capsule.height *= grow
		holder.shape = capsule
		holder.position *= grow


func _launch() -> void:
	_from = global_position
	var drop := _from.y - _to.y
	_fall_duration = (HOP + sqrt(HOP * HOP + 2.0 * fall_gravity * maxf(drop, 0.0))) / fall_gravity
	var across := Vector3(_to.x - _from.x, 0.0, _to.z - _from.z)
	_launch_velocity = across / _fall_duration + Vector3.UP * HOP
	_fall_time = 0.0
	state = State.FALLING
	visual.play("fall", true)
	if not dead:
		_cry(fall_scream)


func _fall(delta: float) -> void:
	_fall_time = minf(_fall_time + delta, _fall_duration)
	var t := _fall_time
	global_position = _from + _launch_velocity * t + Vector3.DOWN * 0.5 * fall_gravity * t * t
	visual.rotation.x = -deg_to_rad(FALL_PITCH) * t / _fall_duration
	if _fall_time >= _fall_duration:
		_touch_down()


func _touch_down() -> void:
	global_position = _to
	visual.rotation.x = 0.0
	rim.hide()
	state = State.SPLATTED
	timer = SPLAT_SECONDS
	visual.play("splat", true)
	impact.play()
	bones.play()
	if is_instance_valid(landing_car):
		glass.play()
	if not dead:
		_quiet()
	if is_instance_valid(street):
		street.call("on_landed", self, _to, landing_car)
	if is_instance_valid(target) and _flat(target.global_position - _to).length() < CRUSH_RADIUS * visual.walker_scale \
			and absf(target.global_position.y - _to.y) < 1.5:
		_hurt_player(crush_damage)
	landed.emit(self)
	if survives:
		health = crawler_health
	else:
		_die()


func _after_splat() -> void:
	if dead:
		return
	visual.lose_legs()
	stand_shape.disabled = true
	crawl_shape.disabled = false
	state = State.RISING
	timer = RISE_SECONDS
	_trail_from = global_position
	_grunt_in = _rng.randf_range(0.5, 1.5)
	_cry(pain)


func _crawl(delta: float) -> void:
	_grab_cool -= delta
	if not is_instance_valid(target):
		return
	var to_player := _flat(target.global_position - global_position)
	var reachable := absf(target.global_position.y - global_position.y) < 1.2
	if _from_head(target.global_position) < grab_range and _grab_cool <= 0.0 and reachable:
		_start_grab()
		return
	_path_in -= delta
	if _path_in <= 0.0:
		_path_in = PATH_REFRESH
		_waypoint = street.call("next_waypoint", global_position, target.global_position) if is_instance_valid(street) \
			else target.global_position
	var heading := _flat(_waypoint - global_position)
	var wish := heading.normalized() * crawl_speed if heading.length() > 0.15 else Vector3.ZERO
	velocity.x = wish.x
	velocity.z = wish.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	_face(heading if heading.length() > 0.15 else to_player, delta, 4.0)
	var moved := get_real_velocity()
	visual.set_crawl_speed(Vector2(moved.x, moved.z).length())
	_grunt_in -= delta
	if _grunt_in <= 0.0:
		_grunt_in = _rng.randf_range(2.0, 4.5)
		_cry(grunt)
	if _flat(global_position - _trail_from).length() >= TRAIL_STEP:
		if is_instance_valid(street):
			street.call("drag_mark", _trail_from, global_position)
		_trail_from = global_position


func _start_grab() -> void:
	state = State.GRABBING
	timer = GRAB_SECONDS
	_grab_landed = false
	visual.play("attack", true)
	_cry(roar)


func _grab(delta: float) -> void:
	_face_target(delta, 10.0)
	if not _grab_landed and GRAB_SECONDS - timer >= GRAB_HIT:
		_grab_landed = true
		if is_instance_valid(target) and _from_head(target.global_position) <= grab_reach:
			_quiet()
			strike.play()
			_hurt_player(grab_damage)
			if is_instance_valid(street):
				street.call("hold_player", grab_hold_seconds)
	if timer <= 0.0 and state == State.GRABBING:
		state = State.CRAWLING
		_grab_cool = grab_cooldown
		visual.play("crawl")


## How far a point is from its head, along the ground.
func _from_head(point: Vector3) -> float:
	var head := global_position - global_basis.z * HEAD_AHEAD * visual.scale.z
	return _flat(point - head).length()


func _hurt_player(amount: float) -> void:
	var health_node := target.get_node_or_null("CombatHealth")
	if health_node != null and health_node.has_method("take_damage"):
		health_node.take_damage(amount, self)
	elif target.has_method("take_damage"):
		target.take_damage(amount)


## The shotgun's pellets, summed over one shot.
func take_shot(damage: float, from: Vector3 = Vector3.ZERO) -> void:
	if dead or damage <= 0.0:
		return
	if is_instance_valid(street):
		street.call("bleed", chest(), (chest() - from).normalized() if from != Vector3.ZERO else Vector3.UP)
	match state:
		State.PERCHED, State.SHRIEKING:
			health -= damage
			if health <= 0.0:
				_topple()
			elif is_instance_valid(street):
				visual.play("hit", true)
				_cry(pain)
				street.call("send_off", self)
		State.LEAPING, State.FALLING:
			if damage >= air_kill_damage:
				dead = true
				survives = false
				_cry(death_cry)
		State.SPLATTED:
			health -= damage
			if health <= 0.0:
				_die()
		State.RISING, State.CRAWLING, State.GRABBING, State.HURT:
			health -= damage
			squelch.play()
			if health <= 0.0:
				_die()
			else:
				state = State.HURT
				timer = HIT_SECONDS
				visual.play("hit", true)
				_cry(pain)


func take_damage(amount: float) -> void:
	take_shot(amount)


## Shot dead on the roof: it goes over the edge and falls, limp, to the street below.
func _topple() -> void:
	dead = true
	survives = false
	_cry(death_cry)
	_to = street.call("below_edge", self) if is_instance_valid(street) else global_position + Vector3.DOWN * global_position.y
	landing_car = null
	_launch()


func _die() -> void:
	var was_dead := dead
	dead = true
	survives = false
	if not was_dead:
		_cry(death_cry)
	if visual.is_crawler:
		visual.play("dead", true)
	state = State.DEAD
	timer = 0.0
	velocity = Vector3.ZERO
	stand_shape.set_deferred("disabled", true)
	crawl_shape.set_deferred("disabled", true)
	if is_instance_valid(street):
		street.call("on_died", self)
	died.emit(self)


## Back on its roof's edge, whole, as it was before the street woke.
func _restore() -> void:
	_wake += 1
	_quiet()
	for sound: AudioStreamPlayer3D in [impact, bones, squelch, glass, strike]:
		sound.stop()
	dead = false
	survives = true
	health = perch_health
	state = State.PERCHED
	timer = 0.0
	velocity = Vector3.ZERO
	landing_car = null
	global_transform = home
	visual.rotation = Vector3.ZERO
	visual.set_whole()
	visual.play("perch", true)
	visual.scatter_phase(_rng)
	stand_shape.disabled = false
	crawl_shape.disabled = true
	rim.show()


## The player came back from a death: every one of them goes back up on its roof.
func reset_enemy() -> void:
	_restore()


## Lets out one of its cries, cutting off any it was making.
func _cry(cry: AudioStreamPlayer3D) -> void:
	_quiet()
	cry.play()


func _quiet() -> void:
	for cry in _cries:
		cry.stop()


func _face(direction: Vector3, delta: float, rate: float) -> void:
	var flat := _flat(direction)
	if flat.length() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(-flat.x, -flat.z), 1.0 - exp(-rate * delta))


func _face_target(delta: float, rate: float = 7.0) -> void:
	if is_instance_valid(target):
		_face(target.global_position - global_position, delta, rate)


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
