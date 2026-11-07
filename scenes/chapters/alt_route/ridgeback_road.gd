class_name RidgebackRoad
extends Node3D
## The alt route's road past the yard gate: fenced off on both sides and blocked with wrecked cars in
## rows, each with one way through, so the player has to wind between them, while a pack of Ridgebacks
## (ridgeback_ambusher.gd) leaps from car to car around them. This runs the pack. It finds every
## vehicle-sized box on the road and makes the places the Ridgebacks use from them: one beside each side
## of a car, facing it, to hide behind, and one on the roof to perch on. A place counts as cover while
## the player cannot see the head of whatever crouches there. It wakes the pack when the player steps
## onto the road, hands out the attacks one at a time, and works out how high a leap has to go to clear
## everything under it, or which roof it has to bound off on the way.

signal cleared

## The stretch of road the pack keeps to, and takes its cover from.
@export var corridor := AABB(Vector3(122.4, -1.0, 56.0), Vector3(12.5, 9.0, 68.0))
## Seconds between one Ridgeback's attack and the next one's, between these two.
@export var attack_gap := Vector2(1.2, 2.4)
@export_range(4.0, 16.0, 0.5, "suffix:m") var max_leap: float = 10.5
## The distance from the player a Ridgeback likes to hide at while it closes in, and while it flees.
@export_range(2.0, 20.0, 0.5, "suffix:m") var close_in_distance: float = 6.5
@export_range(2.0, 30.0, 0.5, "suffix:m") var flee_distance: float = 12.0
## Seconds from stepping onto the road until the first one shows itself on a roof, as Thomas's second line
## comes up; it grunts from hiding on the way. The rest start moving after it.
@export_range(0.0, 8.0, 0.1, "suffix:s") var reveal_delay: float = 3.0

@export_group("Thomas's lines")
## Said as the pack wakes, the first time the player steps onto the road.
@export var entry_lines: PackedStringArray = ["Thomas: Somebody fenced the road off and just left the cars.",
	"Thomas: Something's moving between them."]
@export_multiline var cleared_line: String = "Thomas: That's all of them... I think. Keep moving."
@export_multiline var out_of_shells_line: String = "Thomas: I'm out of shells. I just have to get through."
@export_group("")

## How far from a car's side it crouches, facing the car.
const COVER_GAP := 0.7
## The tallest car it peeks over, standing up behind it: on taller ones its head would barely clear a
## roof that is level with the player's eyes.
const PEEK_TOP := 1.62
## A leap clears what is under it by this much, reached CLEARANCE_STRETCH along the ground from either
## end, and its top is never more than MAX_RISE above the higher of its two ends.
const CLEARANCE := 0.45
const CLEARANCE_STRETCH := 0.9
const MAX_RISE := 2.4
## It perches only on boxes at least this big across and this tall; smaller ones are not vehicles.
const VEHICLE_WIDTH := 1.4
const VEHICLE_LENGTH := 3.0
const VEHICLE_HEIGHT := 1.05

## Each place: {position, facing (toward its car), perch, car, peek}.
var spots: Array[Dictionary] = []
## Each car: {centre, axes (two horizontal unit vectors), half (half lengths along them), top, bottom}.
var cars: Array[Dictionary] = []
var ambushers: Array[RidgebackAmbusher] = []
var active := false
var attacker: RidgebackAmbusher
var attack_cooldown := 0.0
var player: Node3D
var _occupied := {}
var _cleared_sent := false
var _spoken := {}
var _shell_check := 0.0
var _rng := RandomNumberGenerator.new()

@onready var trigger: Area3D = $Trigger


func _ready() -> void:
	add_to_group(&"corrupted_friend")
	_rng.randomize()
	for node in find_children("*", "RidgebackAmbusher", true, false):
		var ambusher := node as RidgebackAmbusher
		ambusher.road = self
		ambushers.append(ambusher)
		ambusher.died.connect(_on_ambusher_died)
	trigger.body_entered.connect(_on_trigger_body_entered)
	# The cars' collision is in the physics world from the first physics frame.
	await get_tree().physics_frame
	await get_tree().physics_frame
	build_spots()
	for ambusher in ambushers:
		if ambusher.dead:
			continue
		var home := nearest_spot(ambusher.global_position, false)
		if home < 0:
			continue
		ambusher.home_spot = home
		ambusher.spot = home
		reserve_spot(ambusher, home)
		ambusher.global_position = spot_position(home)
		ambusher.rotation.y = spot_yaw(home)
	player = get_tree().get_first_node_in_group(&"player") as Node3D
	if is_instance_valid(player) and corridor.has_point(player.global_position) \
			and player.global_position.z > trigger.global_position.z:
		activate()


func _physics_process(delta: float) -> void:
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Node3D
	_shell_check -= delta
	if active and _shell_check <= 0.0 and is_instance_valid(player):
		_shell_check = 0.5
		var shotgun := player.get_node_or_null("Head/Camera3D/ShotgunWeapon")
		if shotgun != null and shotgun.has_method("shells_left") and int(shotgun.call("shells_left")) == 0 \
				and _living() > 0:
			_say_once("out_of_shells", out_of_shells_line)


func _on_trigger_body_entered(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		activate()


## Wakes the pack: the first one leaps up onto a roof in view and shrieks, the rest follow it out.
func activate() -> void:
	if active:
		return
	active = true
	var living := ambushers.filter(func(ambusher: RidgebackAmbusher) -> bool: return not ambusher.dead)
	for index in living.size():
		(living[index] as RidgebackAmbusher).activate(reveal_delay + 1.0 + index * 0.9)
	if not living.is_empty():
		(living[0] as RidgebackAmbusher).reveal(reveal_delay)
		for index in entry_lines.size():
			_say_once("entry_%d" % index, entry_lines[index])


## The player came back from a death: the pack goes back to sleep until they step onto the road again.
func reset_enemy() -> void:
	active = false
	attacker = null
	attack_cooldown = 0.0


func _on_ambusher_died() -> void:
	if _cleared_sent or _living() > 0:
		return
	_cleared_sent = true
	_say_once("cleared", cleared_line)
	cleared.emit()


func _living() -> int:
	var count := 0
	for ambusher in ambushers:
		if is_instance_valid(ambusher) and not ambusher.dead:
			count += 1
	return count


func _say_once(id: String, text: String) -> void:
	if _spoken.has(id) or text.is_empty():
		return
	_spoken[id] = true
	get_tree().call_group(&"route_subtitles", &"say", text)


# --- Attacks ---------------------------------------------------------------------------------------------

func claim_attack(who: RidgebackAmbusher) -> bool:
	if attacker != null and is_instance_valid(attacker) and not attacker.dead and attacker != who:
		return false
	if attack_cooldown > 0.0:
		return false
	attacker = who
	return true


func release_attack(who: RidgebackAmbusher) -> void:
	if attacker == who:
		attacker = null
		attack_cooldown = _rng.randf_range(attack_gap.x, attack_gap.y)


## Whether `who` could pounce on the player from where it is: close enough, and an arc it can fly.
func can_pounce_from(who: RidgebackAmbusher) -> bool:
	if not is_instance_valid(player) or not active:
		return false
	var health := player.get_node_or_null("CombatHealth")
	if health != null and bool(health.get("is_dead")):
		return false
	var along := _flat(player.global_position - who.global_position)
	if along.length() > who.pounce_range or absf(player.global_position.y - who.global_position.y) > 2.2:
		return false
	var landing := who.global_position + along.normalized() * maxf(along.length() - 0.9, 0.0)
	landing.y = ground_height(landing, who.global_position.y)
	return can_leap(who.global_position, landing)


# --- Places ----------------------------------------------------------------------------------------------

## Finds the vehicles on the road and makes the places round them.
func build_spots() -> void:
	spots.clear()
	cars.clear()
	_occupied.clear()
	var section := owner if owner != null else get_parent()
	if section == null:
		section = self
	for body: StaticBody3D in section.find_children("*", "StaticBody3D", true, false):
		for shape_node: CollisionShape3D in body.find_children("*", "CollisionShape3D", false, false):
			var car := _vehicle_box(shape_node)
			if not car.is_empty():
				cars.append(car)
	for index in cars.size():
		_add_spots(index)


func _vehicle_box(shape_node: CollisionShape3D) -> Dictionary:
	var box := shape_node.shape as BoxShape3D
	if box == null or shape_node.disabled:
		return {}
	var xform := shape_node.global_transform
	var centre := xform.origin
	if not corridor.has_point(centre):
		return {}
	# Whichever of the box's axes points most nearly up is its height; the other two lie on the ground.
	var axes: Array[Vector3] = [xform.basis.x * box.size.x, xform.basis.y * box.size.y, xform.basis.z * box.size.z]
	var up := 0
	for index in 3:
		if absf(axes[index].normalized().y) > absf(axes[up].normalized().y):
			up = index
	var height := absf(axes[0].y) + absf(axes[1].y) + absf(axes[2].y)
	var flat: Array[Vector3] = []
	for index in 3:
		if index != up:
			flat.append(_flat(axes[index]))
	if flat[0].length() > flat[1].length():
		flat.reverse()
	if flat[0].length() < VEHICLE_WIDTH or flat[1].length() < VEHICLE_LENGTH or height < VEHICLE_HEIGHT:
		return {}
	return {
		"centre": centre,
		"axes": [flat[0].normalized(), flat[1].normalized()],
		"half": [flat[0].length() * 0.5, flat[1].length() * 0.5],
		"top": centre.y + height * 0.5,
		"bottom": centre.y - height * 0.5,
	}


func _add_spots(car_index: int) -> void:
	var car: Dictionary = cars[car_index]
	var centre: Vector3 = car.centre
	var axes: Array = car.axes
	var half: Array = car.half
	for side in 2:
		var normal: Vector3 = axes[side]
		var along: Vector3 = axes[1 - side]
		var reach: float = half[1 - side]
		var offsets: Array[float] = [0.0]
		if reach >= 1.6:
			offsets = [-reach * 0.5, reach * 0.5]
		for sign: float in [-1.0, 1.0]:
			for offset in offsets:
				var point: Vector3 = centre + normal * sign * (float(half[side]) + COVER_GAP) + along * offset
				if not corridor.has_point(Vector3(point.x, corridor.position.y + 1.0, point.z)):
					continue
				point.y = ground_height(point, float(car.top) + 1.0)
				if point.y > float(car.bottom) + 0.6 or not _room_for_crouch(point):
					continue
				# Reared up behind it, its head clears a roof no higher than PEEK_TOP.
				var height: float = float(car.top) - point.y
				spots.append({"position": point, "facing": -normal * sign, "perch": false, "car": car_index,
					"peek": height >= 1.2 and height <= PEEK_TOP})
	var roof := Vector3(centre.x, float(car.top) + 0.01, centre.z)
	if _room_for_crouch(roof):
		spots.append({"position": roof, "facing": Vector3.ZERO, "perch": true, "car": car_index, "peek": false})


func _room_for_crouch(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = 0.38
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 0.5)
	query.exclude = _exclusions()
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func nearest_spot(point: Vector3, perch: bool) -> int:
	var best := -1
	var best_distance := INF
	for index in spots.size():
		if bool(spots[index].perch) != perch or _occupied.has(index):
			continue
		var distance := point.distance_squared_to(spots[index].position)
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func spot_position(index: int) -> Vector3:
	return spots[index].position if index >= 0 and index < spots.size() else Vector3.ZERO


func spot_facing(index: int) -> Vector3:
	if index < 0 or index >= spots.size():
		return Vector3.FORWARD
	var facing: Vector3 = spots[index].facing
	if facing == Vector3.ZERO and is_instance_valid(player):
		return _flat(player.global_position - spots[index].position)
	return facing


func spot_yaw(index: int) -> float:
	var facing := spot_facing(index)
	return atan2(-facing.x, -facing.z)


func spot_is_perch(index: int) -> bool:
	return index >= 0 and index < spots.size() and bool(spots[index].perch)


func spot_can_peek(index: int) -> bool:
	return index >= 0 and index < spots.size() and bool(spots[index].peek)


## Whether the player can see the head of whatever crouches there.
func spot_exposed(index: int) -> bool:
	if index < 0 or index >= spots.size():
		return false
	var height := RidgebackAmbusher.HIDDEN_HEAD if not bool(spots[index].perch) else 1.0
	return seen_by_player(spots[index].position + Vector3.UP * height)


func reserve_spot(who: RidgebackAmbusher, index: int) -> void:
	if index >= 0:
		_occupied[index] = who


func release_spot(who: RidgebackAmbusher, index: int) -> void:
	if _occupied.get(index) == who:
		_occupied.erase(index)


## Where `who` leaps next: a roof in the player's view when it wants to perch, otherwise cover the player
## cannot see, close in on them or, fleeing, well back. Only leaps it can fly count.
func pick_spot(who: RidgebackAmbusher, want_perch: bool, fleeing: bool) -> int:
	if spots.is_empty() or not is_instance_valid(player):
		return -1
	var here := who.global_position
	var target := _flat(player.global_position)
	var wanted := flee_distance if fleeing else close_in_distance
	var candidates: Array[Vector2] = []
	for index in spots.size():
		var place: Dictionary = spots[index]
		if bool(place.perch) != want_perch or index == who.spot or (_occupied.has(index) and _occupied[index] != who):
			continue
		var place_at: Vector3 = place.position
		var leap := _flat(place_at - here).length()
		if leap < 1.5 or leap > max_leap:
			continue
		var from_player := _flat(place_at).distance_to(target)
		if from_player < 3.0:
			continue
		var score := -absf(from_player - (9.0 if want_perch else wanted))
		for other in ambushers:
			if other != who and not other.dead and _flat(other.global_position - place_at).length() < 2.5:
				score -= 4.0
		candidates.append(Vector2(index, score + _rng.randf() * 2.5))
	candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.y > b.y)
	# The visibility and the arc are the dear part; try the best few until one passes.
	for candidate in candidates.slice(0, 14):
		var index := int(candidate.x)
		var place: Dictionary = spots[index]
		var in_view := seen_by_player(place.position + Vector3.UP * (1.0 if want_perch else RidgebackAmbusher.HIDDEN_HEAD))
		if in_view != want_perch:
			continue
		if not can_leap(here, place.position):
			continue
		return index
	return -1


# --- Geometry --------------------------------------------------------------------------------------------

## The height a leap from `from` to `to` has to rise above the straight line between them at its middle,
## to clear everything under it; -1 if no leap it can make would.
func arc_height(from: Vector3, to: Vector3) -> float:
	var length := _flat(to - from).length()
	var needed := clampf(0.35 + 0.09 * length, 0.45, 1.6)
	var samples := maxi(int(ceil(length / 0.45)), 2)
	var higher := maxf(from.y, to.y)
	var top := higher + MAX_RISE + 1.0
	for step in range(1, samples):
		var s := float(step) / samples
		if s < 0.07 or s > 0.93:
			continue
		var point := from.lerp(to, s)
		var under := _top_under(point, top)
		# Taking off from a roof or coming down on one, it is on that roof at the ends of the arc: the
		# clearance comes in over the first and last stretch, so it does not have to bound high off it.
		var margin := CLEARANCE * clampf(minf(s, 1.0 - s) * length / CLEARANCE_STRETCH, 0.0, 1.0)
		var required := (under + margin - lerpf(from.y, to.y, s)) / (4.0 * s * (1.0 - s))
		needed = maxf(needed, required)
	# The top of the arc is at its middle: the line's midpoint plus the height above it.
	return needed if (from.y + to.y) * 0.5 + needed - higher <= MAX_RISE else -1.0


## Whether a Ridgeback can leap from `from` to `to`, in one arc or by way of a roof.
func can_leap(from: Vector3, to: Vector3) -> bool:
	return arc_height(from, to) >= 0.0 or vault_point(from, to) != Vector3.INF


## Where a leap from `from` to `to` that cannot clear the car in its way in one arc touches down on that
## car's roof, to spring on from there; Vector3.INF if both halves cannot be flown. Crouched close behind
## a car, nothing clears it far: it has to bound up onto it first. The car it stands on does not count.
func vault_point(from: Vector3, to: Vector3) -> Vector3:
	var length := _flat(to - from).length()
	var samples := maxi(int(ceil(length / 0.25)), 2)
	var standing_on := car_at(from)
	var crossed := -1
	var enter := 0.0
	var leave := 0.0
	for step in range(1, samples):
		var s := float(step) / samples
		var car := car_at(from.lerp(to, s))
		if crossed < 0:
			if car >= 0 and car != standing_on:
				crossed = car
				enter = s
				leave = s
		elif car == crossed:
			leave = s
		else:
			break
	if crossed < 0:
		return Vector3.INF
	var point := from.lerp(to, (enter + leave) * 0.5)
	point.y = ground_height(point, float(cars[crossed].top) + 0.5)
	if point.y < float(cars[crossed].top) - 0.3 or arc_height(from, point) < 0.0 or arc_height(point, to) < 0.0:
		return Vector3.INF
	return point


## The ground, or whatever stands on it, under a point: the first thing a ray down from `from_height`
## meets, not counting the pack or the player.
func ground_height(point: Vector3, from_height: float) -> float:
	return _top_under(point, from_height + 0.5)


func _top_under(point: Vector3, from_height: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, from_height, point.z), Vector3(point.x, -3.0, point.z))
	query.exclude = _exclusions()
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else 0.0


## The car whose footprint a point is over, at any height; -1 for none.
func car_at(point: Vector3) -> int:
	for index in cars.size():
		var car: Dictionary = cars[index]
		var offset := _flat(point - car.centre)
		var axes: Array = car.axes
		var half: Array = car.half
		if absf(offset.dot(axes[0])) <= float(half[0]) and absf(offset.dot(axes[1])) <= float(half[1]):
			return index
	return -1


func is_roof(point: Vector3) -> bool:
	for car in cars:
		if point.y < float(car.top) - 0.3:
			continue
		var offset := _flat(point - car.centre)
		var axes: Array = car.axes
		var half: Array = car.half
		if absf(offset.dot(axes[0])) <= float(half[0]) + 0.1 and absf(offset.dot(axes[1])) <= float(half[1]) + 0.1:
			return true
	return false


## Whether the player can see a point: nothing solid between their eyes and it.
func seen_by_player(point: Vector3) -> bool:
	if not is_instance_valid(player):
		return false
	var camera := player.get_node_or_null("Head/Camera3D") as Node3D
	var eye := camera.global_position if camera != null else player.global_position + Vector3.UP * 1.6
	var query := PhysicsRayQueryParameters3D.create(eye, point)
	query.exclude = _exclusions()
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _exclusions() -> Array[RID]:
	var rids: Array[RID] = []
	for ambusher in ambushers:
		if is_instance_valid(ambusher):
			rids.append(ambusher.get_rid())
	if is_instance_valid(player) and player is CollisionObject3D:
		rids.append((player as CollisionObject3D).get_rid())
	return rids


static func _flat(vector: Vector3) -> Vector3:
	return Vector3(vector.x, 0.0, vector.z)
