class_name RooftopStreet
extends Node3D
## The alt route's way to the hospital (scenes/chapters/alt_route/map_alt.tscn): the downtown's main street,
## walled in by the alt downtown's tall rows (tools/blender/downtown/plan_alt.py), choked with the cars the
## evacuation left on its way to the hospital, and a line of Ridgebacks (ridgeback_faller.tscn) standing on
## the roofs' edges along both sides of it. They are up there once Carrie's notebook has sent Thomas to the
## hospital (the story's stage 2). The first rows of cars set the whole line shrieking; then they throw
## themselves off, one after another, at points ahead of the player and in view, onto the road or a car's
## roof, which sets its alarm off. Some die of the fall. The rest lose their legs and drag themselves after
## the player round the cars, along a grid of the street (AStarGrid2D) that knows where the cars are. Past
## finale_x every one still up there comes down at once. The police car crashed into the signal at the corner
## has a box of shells by it, and the shotgun on its hood for one who comes without one; there is another
## box on a car halfway along. Fences close the alleys and the
## lots, so the street is the way. A death puts the whole street back as it was before the shriek.

signal shrieked
signal finale_started

enum Phase { ASLEEP, WATCHING, SHRIEKING, RAINING, FINALE, DONE }

@export_file("*.json") var markers_path: String = "res://models/buildings/downtown_alt/downtown_alt_markers.json"
## The story stage (opening_story.gd) from which they stand on the roofs; with no story, from the start.
@export var stage_needed: int = 2
@export_range(0, 24, 1) var ridgeback_count: int = 14
## Walkers for the line (ridgeback_faller_visual.gd), in order along the north roofs then the south, repeating
## when there are more Ridgebacks than names. Empty: every one is the original Ridgeback.
@export var walker_order: Array[StringName] = []
## The player's x where the line shrieks, among the first cars, and where the rest all come down.
@export var shriek_x: float = 121.0
@export var finale_x: float = 211.0
## Past this x, at the hospital, the street lets the player go.
@export var end_x: float = 240.0
## Seconds between one leap and the next, while they come down one at a time.
@export var leap_gap := Vector2(0.8, 1.5)
@export var finale_gap := Vector2(0.15, 0.4)
## How far from the player a leap likes to land, metres, and the furthest one leaps from its roof.
@export var landing_ahead := Vector2(4.5, 14.0)
@export_range(6.0, 25.0, 0.5, "suffix:m") var leap_reach: float = 13.0
## Each one goes when the player has come within this far of it along the street (picked for each one),
## but those standing past finale_x - finale_lead wait for the finale.
@export var lead := Vector2(12.0, 24.0)
@export_range(0.0, 40.0, 0.5, "suffix:m") var finale_lead: float = 10.0
@export_range(0.0, 1.0, 0.05) var survive_chance: float = 0.7
@export_range(0.0, 1.0, 0.05) var car_landing_chance: float = 0.3
## Crawlers dragging themselves about at once; past this many, the next ones die of the fall.
@export_range(1, 20, 1) var most_crawlers: int = 7
@export_group("Thomas's lines")
@export_multiline var sighted_line: String = "Thomas: There's something on the roofs. All along the street."
@export_multiline var shriek_line: String = "Thomas: They're... they're going to jump."
@export_multiline var first_fall_line: String = "Thomas: Oh God. It's still moving."
@export_multiline var finale_line: String = "Thomas: All of them. Run!"
@export_multiline var end_line: String = "Thomas: The hospital. Get inside, get inside..."
@export_group("")

const FALLER: PackedScene = preload("res://scenes/monsters/the_ridgeback/ridgeback_faller.tscn")
const SHELLS: PackedScene = preload("res://scenes/items/shell_box_pickup.tscn")
const SHOTGUN: PackedScene = preload("res://scenes/items/shotgun_pickup.tscn")
const POLICE_CAR: PackedScene = preload("res://models/map/cop_car_sedan.tscn")
const CARS := {
	"hearse": preload("res://models/props/vehicles/cadillac_hearse.tscn"),
	"freelander": preload("res://models/props/vehicles/freelander.tscn"),
	"prelude": preload("res://models/props/vehicles/honda_prelude.tscn"),
	"lincoln": preload("res://models/props/vehicles/lincoln_town_car.tscn"),
	"mercedes": preload("res://models/props/vehicles/mercedes_benz_s_class.tscn"),
	"panda": preload("res://models/props/vehicles/panda.tscn"),
	"crown": preload("res://models/props/vehicles/toyota_crown_model.tscn"),
}
const FENCE_MESHES: Array[Mesh] = [
	preload("res://models/props/metalFences/fence1.tres"),
	preload("res://models/props/metalFences/fence2.tres"),
	preload("res://models/props/metalFences/fence3.tres"),
]
const FENCE_MATERIAL: Material = preload("res://models/props/metalFences/fence_cutout_material.tres")
const CAR_SCALE := 1.15
## The jam, in rows across the street at x, each sealed but for one gap at the north sidewalk, the
## middle of the road or the south sidewalk; the cars are packed in from the walls, nose to tail across
## the street, turned a little each way. Then cars on their own, stranded along it: model, x, z, heading
## (degrees; 0 runs east, 90 south).
const ROWS := [
	[124.0, "middle", ["lincoln", "panda", "prelude"]],
	[135.0, "south", ["crown", "prelude", "panda"]],
	[147.0, "north", ["freelander", "prelude", "panda"]],
	[158.5, "middle", ["crown", "panda", "prelude"]],
	[170.0, "south", ["hearse", "panda", "panda"]],
	[180.0, "north", ["mercedes", "panda", "panda"]],
	[192.5, "middle", ["prelude", "panda", "lincoln"]],
	[203.0, "south", ["lincoln", "panda", "prelude"]],
	[217.5, "north", ["crown", "prelude", "panda"]],
	[227.5, "middle", ["freelander", "panda", "prelude"]],
]
const STRANDED := [
	["crown", 130.0, 222.4, 8.0], ["panda", 141.5, 231.4, -14.0], ["freelander", 152.5, 222.6, 4.0],
	["prelude", 164.5, 231.8, 172.0], ["lincoln", 175.5, 228.6, 4.0], ["panda", 186.5, 219.0, -6.0],
	["hearse", 198.0, 227.6, 2.0], ["crown", 210.5, 223.0, -18.0], ["prelude", 222.5, 231.5, 6.0],
]
## Where the street's walkable band runs, and the gap between a car and the next in a row.
const NORTH_WALL := 216.55
const SOUTH_WALL := 233.95
## The narrowest a row's gap may be, and the space between a car and the next one packed against it.
const GAP_WIDTH := 2.2
const PACK_GAP := 0.3
## How far each car of a row is turned off square, degrees, at most.
const ROW_TURN := 5.0
const ROAD_TOP := 0.1
const WALK_TOP := 0.13
const CURBS := Vector2(221.0, 229.0)
## Fences across the alley mouths, the lots' open sides and the service lane's end on the Connector road: from
## (x, z) to (x, z).
const FENCES := [
	[Vector2(108.7, 216.45), Vector2(135.0, 216.45)], [Vector2(108.7, 203.0), Vector2(108.7, 216.45)],
	[Vector2(171.0, 216.45), Vector2(174.5, 216.45)], [Vector2(220.5, 216.45), Vector2(224.5, 216.45)],
	[Vector2(240.5, 216.45), Vector2(262.0, 216.45)],
	[Vector2(137.25, 234.05), Vector2(140.75, 234.05)], [Vector2(167.25, 234.05), Vector2(170.75, 234.05)],
	[Vector2(199.25, 234.05), Vector2(202.75, 234.05)],
	[Vector2(104.4, 254.2), Vector2(108.7, 254.2)], [Vector2(104.4, 254.2), Vector2(104.4, 275.0)],
]
const FENCE_PANEL := 4.31
## The grid the crawlers find their way on: cells, how far it reaches, and how wide a crawler is.
const GRID_CELL := 0.5
const GRID_AREA := Rect2(100.0, 214.0, 165.0, 24.0)
const CRAWLER_RADIUS := 0.45
## The street lamp and tree trunks the crawlers go round.
const POSTS := ["lamp", "tree"]
## Furniture a car stands on is knocked over: hidden.
const KNOCKED_RADIUS := 0.5
## The corner: where the police car crashed into the signal, and its shells.
const POLICE_AT := Vector3(110.2, 0.0, 229.6)
const POLICE_HEADING := -148.0
const SHELLS_AT := [Vector3(108.6, WALK_TOP, 227.2), Vector3(181.5, 0.0, 224.6)]
const SHOTGUN_AT := Vector3(107.9, 1.2, 228.9)
## The evacuation's floodlights at the corner, thrown down the street at the roofs: where they stand and the
## point each is aimed at.
const FLOODLIGHTS := [[Vector3(105.6, 0.0, 219.2), Vector3(205.0, 26.0, 227.5)],
	[Vector3(105.6, 0.0, 232.6), Vector3(205.0, 26.0, 222.5)]]
const FLOOD_HEIGHT := 6.5
## The cars' lamps fade out from this far from the camera, over the next LAMP_FADE_OVER metres, where the fog
## hides them anyway.
const LAMP_FADE_FROM := 120.0
const LAMP_FADE_OVER := 40.0
## A headlight's or tail light's shadow is drawn only this close to the camera.
const HEADLIGHT_SHADOW_REACH := 40.0
## A car's spot lamp at least this bright is a headlight; its dimmer ones are the fills.
const HEADLIGHT_ENERGY := 1.0
## A car's round lamp reaching further than this is a tail light; the short ones are the glows.
const TAIL_LIGHT_REACH := 20.0
## A tail light's reach is cut to this (at least TAIL_LIGHT_REACH). The car model's own 67 m drew much of the
## street, and the hospital's back, into each of its shadows. With the default falloff the red on the road behind
## a car is within 5% of before out to 10 m, then fades out by this far instead of carrying on faintly to 67 m.
const TAIL_LIGHT_RANGE := 25.0
## The moonlight that falls on the Ridgebacks alone (their layer, Gore.GORE_FREE_LAYER), from high in the west,
## so the line stands out against the night sky and a crawler shows in the dark between the cars.
const MOON_COLOUR := Color(0.7, 0.78, 1.0)
const MOON_ENERGY := 2.7
const MOON_FROM := Vector3(-0.6, 0.8, -0.1)
## A body landing this close to the player shakes the view.
const SHAKE_RADIUS := 9.0

var phase: Phase = Phase.ASLEEP
var fallers: Array[RidgebackFaller] = []
## The cars of the jam: {node, centre, axes, half, top}.
var cars: Array[Dictionary] = []
var grid := AStarGrid2D.new()
var player: FirstPersonPlayer
var _markers: Dictionary = {}
var _gore: Node3D
var _alarms: Dictionary = {}
var _leap_in := 0.0
var _recent: Array[Vector3] = []
var _crawling := 0
var _first_fall := true
var _hold_left := 0.0
var _held_speeds := Vector2.ZERO
var _shake := 0.0
var _shotgun: Node3D
## Each one's lead, and those kept for the finale.
var _leads: Dictionary = {}
var _kept: Array[RidgebackFaller] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"corrupted_friend")
	_rng.randomize()
	_markers = JSON.parse_string(FileAccess.get_file_as_string(markers_path))
	_gore = Node3D.new()
	_gore.name = "Gore"
	add_child(_gore)
	_build_jam()
	_build_corner()
	_build_fences()
	_build_grid()
	_build_line()
	_budget_lights()
	var moon := DirectionalLight3D.new()
	moon.name = "RidgebackMoon"
	moon.light_color = MOON_COLOUR
	moon.light_energy = MOON_ENERGY
	moon.light_cull_mask = Gore.GORE_FREE_LAYER
	moon.shadow_enabled = false
	add_child(moon)
	moon.global_basis = Basis.looking_at(-MOON_FROM)
	_knock_over_furniture.call_deferred()
	_sleep(true)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as FirstPersonPlayer
		if player == null:
			return
	_release_hold(delta)
	_settle_shake(delta)
	if is_instance_valid(_shotgun) and _shotgun.visible and player.has_item(&"shotgun"):
		_shotgun.queue_free()
	var at := player.global_position
	match phase:
		Phase.ASLEEP:
			if _story_stage() >= stage_needed:
				_sleep(false)
				phase = Phase.WATCHING
		Phase.WATCHING:
			if at.x > 100.0 and at.z > 205.0 and at.z < 245.0:
				_say(sighted_line)
			if at.x >= shriek_x and _in_street(at):
				_shriek()
		Phase.RAINING, Phase.FINALE:
			_leap_in -= delta
			if phase == Phase.RAINING and at.x >= finale_x:
				phase = Phase.FINALE
				_say(finale_line, true)
				finale_started.emit()
				_leap_in = 0.0
			if _leap_in <= 0.0:
				var gap := finale_gap if phase == Phase.FINALE else leap_gap
				_leap_in = _rng.randf_range(gap.x, gap.y)
				_send_next()
			if at.x >= end_x:
				_finish()
		Phase.SHRIEKING, Phase.DONE:
			pass


## Whether a point is on the street, between the rows from the corner to the hospital.
func _in_street(at: Vector3) -> bool:
	return at.x > 104.0 and at.x < 262.0 and at.z > NORTH_WALL - 0.5 and at.z < SOUTH_WALL + 0.5


func _story_stage() -> int:
	var story := get_tree().get_first_node_in_group(&"opening_story")
	return int(story.get("stage")) if story != null else stage_needed


# --- The line -------------------------------------------------------------------------------------------

func _shriek() -> void:
	phase = Phase.SHRIEKING
	_say(shriek_line, true)
	_hold_story(true)
	var longest := 0.0
	for faller in fallers:
		var delay := _rng.randf_range(0.0, 0.6)
		longest = maxf(longest, delay)
		faller.line_shriek(delay)
	shrieked.emit()
	await get_tree().create_timer(longest + RidgebackFaller.SHRIEK_SECONDS * 0.85, false).timeout
	if phase == Phase.SHRIEKING:
		phase = Phase.RAINING
		_leap_in = 0.0


## The one whose turn it is: of those the player has come within its own lead of, the nearest in view, then the
## nearest. Those kept for the finale wait for it; in the finale every one still up there goes, nearest first.
func _send_next() -> void:
	var at := player.global_position
	var view := _view()
	var best: RidgebackFaller = null
	var best_score := INF
	for faller in fallers:
		if not faller.is_perched():
			continue
		var offset := faller.global_position - at
		var flat := Vector2(offset.x, offset.z)
		if phase == Phase.RAINING and (_kept.has(faller) or offset.x > float(_leads.get(faller, 0.0))):
			continue
		var score := flat.length()
		if view.dot(offset.normalized()) < 0.55:
			score += 40.0
		if offset.x < -4.0:
			score += 20.0
		if score < best_score:
			best_score = score
			best = faller
	send_off(best)


## Sends `faller` off the roof now, at a landing the street picks.
func send_off(faller: RidgebackFaller) -> void:
	if faller == null or not faller.is_perched():
		return
	var lives := _rng.randf() < survive_chance and _crawling < most_crawlers
	if _first_fall:
		lives = true
	var landing := _landing_for(faller)
	if lives:
		_crawling += 1
	faller.jump_at(landing[0], lives, landing[1])


## [point, car or null]: in one leap from the faller's roof, in front of the player and in view, clear of the
## player and of where the last few landed; on a car's roof now and then.
func _landing_for(faller: RidgebackFaller) -> Array:
	var at := player.global_position
	var view := _view()
	var from := faller.global_position
	var on_car := _first_fall or _rng.randf() < car_landing_chance
	var best := [below_edge(faller), null]
	var best_score := INF
	if on_car:
		for car in cars:
			var centre: Vector3 = car.centre
			var point := Vector3(centre.x, float(car.top), centre.z)
			if Vector2(point.x - from.x, point.z - from.z).length() > leap_reach:
				continue
			var score := _landing_score(point, at, view) - 4.0
			if score < best_score:
				best_score = score
				best = [point, car.node]
	if best[1] == null:
		for attempt in 32:
			var point := Vector3(from.x + _rng.randf_range(-leap_reach, leap_reach), 0.0,
				_rng.randf_range(NORTH_WALL + 0.6, SOUTH_WALL - 0.6))
			if Vector2(point.x - from.x, point.z - from.z).length() > leap_reach or not _walkable(point):
				continue
			point.y = _ground(point.z)
			var score := _landing_score(point, at, view)
			if score < best_score:
				best_score = score
				best = [point, null]
	_recent.push_front(best[0])
	_recent.resize(mini(_recent.size(), 4))
	return best


## Lower is better: in front of the player at landing_ahead, in view, away from the last few landings.
func _landing_score(point: Vector3, at: Vector3, view: Vector3) -> float:
	var flat := Vector3(point.x - at.x, 0.0, point.z - at.z)
	if flat.length() < 2.6:
		return INF
	var score := (1.0 - view.dot((point - (at + Vector3.UP * 1.6)).normalized())) * 20.0
	score += maxf(landing_ahead.x - flat.length(), 0.0) * 4.0 + maxf(flat.length() - landing_ahead.y, 0.0) * 2.0
	for recent in _recent:
		if Vector2(point.x - recent.x, point.z - recent.z).length() < 2.5:
			score += 25.0
	return score + _rng.randf() * 3.0


## Where one shot dead on its roof lands: straight down off the edge, a little out into the street.
func below_edge(faller: RidgebackFaller) -> Vector3:
	var out := -faller.global_basis.z
	out.y = 0.0
	var point := faller.global_position + out.normalized() * 1.6
	point.z = clampf(point.z, NORTH_WALL + 0.4, SOUTH_WALL - 0.4)
	point.y = _ground(point.z)
	for car in cars:
		if _inside(car, point, 0.0):
			point.y = float(car.top)
			break
	return point


## A body has hit the street at `point` (on `car`'s roof, when there is one).
func on_landed(faller: RidgebackFaller, point: Vector3, car: Node3D) -> void:
	Gore.splat(_gore, point + Vector3.UP * 0.1, _rng.randf_range(2.4, 3.4), _rng)
	if not faller.survives:
		Gore.pool(_gore, point + Vector3.UP * 0.1, _rng.randf_range(1.6, 2.4), 6.0, _rng)
	if is_instance_valid(car):
		_sound_alarm(car)
	if is_instance_valid(player) and player.global_position.distance_to(point) < SHAKE_RADIUS:
		_shake = maxf(_shake, 1.0 - player.global_position.distance_to(point) / SHAKE_RADIUS)
	if _first_fall and faller.survives:
		_first_fall = false
		_say(first_fall_line)
	_first_fall = false


func on_died(faller: RidgebackFaller) -> void:
	if faller.visual.is_crawler:
		_crawling = maxi(_crawling - 1, 0)
		Gore.pool(_gore, faller.global_position + Vector3.UP * 0.1, _rng.randf_range(1.2, 1.8), 5.0, _rng)


## A pellet's wound: drops flying back along the shot, and a spatter below.
func bleed(point: Vector3, direction: Vector3) -> void:
	Gore.wound(_gore, point, direction, _ground(point.z) + 0.1, _rng)


## A stretch of a crawler's drag mark.
func drag_mark(from: Vector3, to: Vector3) -> void:
	Gore.smear(_gore, from + Vector3.UP * 0.1, to + Vector3.UP * 0.1)


## A crawler's claw has the player by the ankle: they move at a crawl for `seconds`.
func hold_player(seconds: float) -> void:
	if not is_instance_valid(player):
		return
	if _hold_left <= 0.0:
		_held_speeds = Vector2(player.walk_speed, player.sprint_speed)
		player.walk_speed *= 0.3
		player.sprint_speed *= 0.3
	_hold_left = maxf(_hold_left, seconds)


func _release_hold(delta: float) -> void:
	if _hold_left <= 0.0:
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		player.walk_speed = _held_speeds.x
		player.sprint_speed = _held_speeds.y


func _settle_shake(delta: float) -> void:
	if _shake <= 0.0 or not is_instance_valid(player) or not player.has_node("Head/Camera3D"):
		return
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var camera := player.get_node("Head/Camera3D") as Camera3D
	camera.h_offset = _rng.randf_range(-1.0, 1.0) * 0.06 * _shake
	camera.v_offset = _rng.randf_range(-1.0, 1.0) * 0.08 * _shake


## The next point a crawler at `from` should make for on its way to `to`, round the cars.
func next_waypoint(from: Vector3, to: Vector3) -> Vector3:
	if not _in_street(to) or to.x >= end_x:
		return from
	# On a car's roof it makes straight for the player, off the edge, and drops to the road.
	if from.y > _ground(from.z) + 0.7:
		var off := Vector3(to.x - from.x, 0.0, to.z - from.z)
		return from + off.normalized() * 2.0 if off.length() > 0.01 else to
	var start := _cell(from)
	if grid.is_point_solid(start):
		start = _nearest_open(start)
		if start == Vector2i(-1, -1):
			return to
		return _point(start, from.y)
	var goal := _nearest_open(_cell(to))
	if goal == Vector2i(-1, -1):
		return to
	var path := grid.get_id_path(start, goal, true)
	if path.size() < 2:
		return to
	return _point(path[mini(2, path.size() - 1)], from.y)


# --- Building it ------------------------------------------------------------------------------------------

func _build_jam() -> void:
	var holder := Node3D.new()
	holder.name = "Jam"
	add_child(holder)
	for row: Array in ROWS:
		_build_row(holder, float(row[0]), String(row[1]), row[2])
	for entry: Array in STRANDED:
		_place_car(holder, String(entry[0]), Vector3(float(entry[1]), 0.0, float(entry[2])), float(entry[3]))


## Packs a row's cars in from the walls, nose to tail across the street, leaving the gap where it says.
func _build_row(holder: Node3D, x: float, gap: String, models: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(x * 100.0)
	var lengths: Array[float] = []
	var filled := 0.0
	for model: String in models:
		lengths.append(_length_of(model))
		filled += lengths[-1] + PACK_GAP
	if SOUTH_WALL - NORTH_WALL - filled < GAP_WIDTH:
		push_warning("The row at x %.1f leaves only %.1f m for its gap." % [x, SOUTH_WALL - NORTH_WALL - filled])
	var north: Array[int] = []
	var south: Array[int] = []
	if gap == "middle":
		for index in models.size():
			(north if index < models.size() / 2 else south).append(index)
	elif gap == "north":
		for index in models.size():
			south.append(index)
	else:
		for index in models.size():
			north.append(index)
	var cursor := NORTH_WALL + PACK_GAP
	for index in north:
		var heading := 90.0 + rng.randf_range(-ROW_TURN, ROW_TURN)
		_place_car(holder, String(models[index]), Vector3(x + rng.randf_range(-0.5, 0.5), 0.0,
			cursor + lengths[index] * 0.5), heading)
		cursor += lengths[index] + PACK_GAP
	cursor = SOUTH_WALL - PACK_GAP
	for index in south:
		var heading := 90.0 + rng.randf_range(-ROW_TURN, ROW_TURN)
		_place_car(holder, String(models[index]), Vector3(x + rng.randf_range(-0.5, 0.5), 0.0,
			cursor - lengths[index] * 0.5), heading)
		cursor -= lengths[index] + PACK_GAP


func _length_of(model: String) -> float:
	var box := _box_of(CARS[model].instantiate())
	return box.size.z * CAR_SCALE if box != null else 4.5


func _place_car(holder: Node3D, model: String, at: Vector3, heading: float) -> void:
	var car := CARS[model].instantiate() as Node3D
	car.name = "%s_%d_%d" % [model.capitalize(), int(at.x), int(at.z)]
	holder.add_child(car)
	car.scale = Vector3.ONE * CAR_SCALE
	car.rotation.y = deg_to_rad(90.0 - heading)
	car.global_position = Vector3(at.x, 0.0, at.z)
	var shape := _shape_of(car)
	if shape == null:
		return
	# Down onto the road or the sidewalk it stands on.
	var box := shape.shape as BoxShape3D
	var bottom := shape.global_position.y - box.size.y * 0.5 * CAR_SCALE
	car.global_position.y += _ground(at.z) - bottom
	var xform := shape.global_transform
	cars.append({
		"node": car,
		"centre": xform.origin,
		"axes": [Vector3(xform.basis.x.x, 0.0, xform.basis.x.z).normalized(),
			Vector3(xform.basis.z.x, 0.0, xform.basis.z.z).normalized()],
		"half": [box.size.x * 0.5 * CAR_SCALE, box.size.z * 0.5 * CAR_SCALE],
		"top": xform.origin.y + box.size.y * 0.5 * CAR_SCALE,
	})


func _shape_of(car: Node) -> CollisionShape3D:
	for shape: CollisionShape3D in car.find_children("*", "CollisionShape3D", true, false):
		if shape.shape is BoxShape3D:
			return shape
	return null


func _box_of(car: Node) -> BoxShape3D:
	var shape := _shape_of(car)
	var box := shape.shape as BoxShape3D if shape != null else null
	car.free()
	return box


func _build_corner() -> void:
	var police := POLICE_CAR.instantiate() as Node3D
	police.name = "CrashedPoliceCar"
	add_child(police)
	police.global_position = POLICE_AT
	police.rotation.y = deg_to_rad(90.0 - POLICE_HEADING)
	police.rotation.z = deg_to_rad(-2.5)
	var body := StaticBody3D.new()
	body.name = "Body"
	police.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 1.5, 4.8)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)
	body.add_child(shape)
	for flood: Array in FLOODLIGHTS:
		_floodlight(flood[0], flood[1])
	_shotgun = SHOTGUN.instantiate() as Node3D
	_shotgun.name = "Shotgun"
	add_child(_shotgun)
	_shotgun.global_position = SHOTGUN_AT
	_shotgun.rotation = Vector3(0.0, deg_to_rad(30.0), deg_to_rad(90.0))
	for index in SHELLS_AT.size():
		var shells := SHELLS.instantiate() as Node3D
		shells.name = "Shells%d" % (index + 1)
		add_child(shells)
		var point: Vector3 = SHELLS_AT[index]
		for car in cars:
			if _inside(car, point, 0.0):
				point.y = float(car.top)
		shells.global_position = point


## A light tower: a mast with a lamp head, its beam thrown at `aim`.
func _floodlight(base: Vector3, aim: Vector3) -> void:
	var tower := Node3D.new()
	tower.name = "Floodlight"
	add_child(tower)
	tower.global_position = base + Vector3.UP * WALK_TOP
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.34, 0.36, 0.38)
	steel.metallic = 0.6
	steel.roughness = 0.5
	var mast := MeshInstance3D.new()
	var pole := CylinderMesh.new()
	pole.top_radius = 0.07
	pole.bottom_radius = 0.09
	pole.height = FLOOD_HEIGHT
	pole.material = steel
	mast.mesh = pole
	mast.position = Vector3.UP * FLOOD_HEIGHT * 0.5
	tower.add_child(mast)
	var foot := MeshInstance3D.new()
	var base_box := BoxMesh.new()
	base_box.size = Vector3(1.2, 0.5, 1.2)
	base_box.material = steel
	foot.mesh = base_box
	foot.position = Vector3.UP * 0.25
	tower.add_child(foot)
	var head := Node3D.new()
	tower.add_child(head)
	head.position = Vector3.UP * FLOOD_HEIGHT
	head.look_at(aim, Vector3.UP)
	var lamp := MeshInstance3D.new()
	var lamp_box := BoxMesh.new()
	lamp_box.size = Vector3(0.9, 0.6, 0.35)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.9, 0.93, 1.0)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.93, 1.0)
	glow.emission_energy_multiplier = 3.0
	lamp_box.material = glow
	lamp.mesh = lamp_box
	head.add_child(lamp)
	var beam := SpotLight3D.new()
	beam.light_color = Color(0.82, 0.88, 1.0)
	beam.light_energy = 9.0
	beam.light_volumetric_fog_energy = 0.6
	beam.spot_range = 120.0
	beam.spot_angle = 11.0
	beam.spot_attenuation = 0.6
	beam.shadow_enabled = true
	beam.position = Vector3(0, 0, -0.25)
	# It lights the street from 120 m away: never faded with distance (light_distance_fade.gd).
	beam.set_meta(&"keep_far", true)
	head.add_child(beam)


## The street's lamps on a budget. The car props light as they do everywhere, every lamp shadowed: here that
## is forty shadowed lights, each tail light's 67 m reach drawing the whole street into a cube of shadows. So
## the headlights and tail lights keep their shadows (their light stops at the cars around them), but only near
## the camera, and the tail lights' in two halves instead of a six-sided cube, over a reach cut to
## TAIL_LIGHT_RANGE; the dim fills and the short glows light without them. Every lamp fades out in the
## distance. The floodlights are left as they are: they light the street from far away, so their shadows are
## seen from the far end of it.
func _budget_lights() -> void:
	for node: Node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D or light.has_meta(&"keep_far"):
			continue
		var headlight := light is SpotLight3D and light.light_energy >= HEADLIGHT_ENERGY
		var tail_light := light is OmniLight3D and (light as OmniLight3D).omni_range >= TAIL_LIGHT_REACH
		light.shadow_enabled = light.shadow_enabled and (headlight or tail_light)
		if tail_light:
			var omni := light as OmniLight3D
			omni.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
			omni.omni_range = minf(omni.omni_range, TAIL_LIGHT_RANGE)
		light.distance_fade_enabled = true
		light.distance_fade_begin = LAMP_FADE_FROM
		light.distance_fade_length = LAMP_FADE_OVER
		light.distance_fade_shadow = HEADLIGHT_SHADOW_REACH


func _build_fences() -> void:
	var holder := Node3D.new()
	holder.name = "Fences"
	add_child(holder)
	var panel_shape := BoxShape3D.new()
	panel_shape.size = Vector3(1.9, 0.134, 3.19)
	var count := 0
	for line: Array in FENCES:
		var from: Vector2 = line[0]
		var to: Vector2 = line[1]
		var length := from.distance_to(to)
		var panels := maxi(1, ceili(length / FENCE_PANEL))
		var direction := (to - from).normalized()
		var turn := Basis(Vector3.UP, atan2(direction.x, direction.y))
		for index in panels:
			var middle := from + direction * (length * (index + 0.5) / panels)
			var panel := MeshInstance3D.new()
			panel.name = "Fence%d" % count
			panel.mesh = FENCE_MESHES[count % FENCE_MESHES.size()]
			panel.material_override = FENCE_MATERIAL
			holder.add_child(panel)
			var upright := Basis(Vector3(0, -1.35, 0), Vector3(1.485, 0, 0), Vector3(0, 0, 1.35 * length / panels / FENCE_PANEL))
			panel.global_transform = Transform3D(turn * upright, Vector3(middle.x, 1.4086, middle.y))
			var body := StaticBody3D.new()
			panel.add_child(body)
			var shape := CollisionShape3D.new()
			shape.shape = panel_shape
			shape.position = Vector3(0.15, 0, 0)
			body.add_child(shape)
			count += 1


## The crawlers' grid: the street's band from the corner to the hospital, less the cars and posts.
func _build_grid() -> void:
	grid.region = Rect2i(0, 0, int(GRID_AREA.size.x / GRID_CELL), int(GRID_AREA.size.y / GRID_CELL))
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for x in grid.region.size.x:
		for y in grid.region.size.y:
			if not _in_band(_point(Vector2i(x, y), 0.0)):
				grid.set_point_solid(Vector2i(x, y), true)
	for car in cars:
		var reach := Vector2(float(car.half[0]), float(car.half[1])).length() + CRAWLER_RADIUS
		_solid_round(car.centre, reach, func(point: Vector3) -> bool: return _inside(car, point, CRAWLER_RADIUS))
	for item: Dictionary in _markers.get("furniture", []):
		if String(item.kind) in POSTS:
			var post := Vector3(float(item.position[0]), 0.0, float(item.position[1]))
			_solid_round(post, CRAWLER_RADIUS + 0.25, func(point: Vector3) -> bool:
				return Vector2(point.x - post.x, point.z - post.z).length() < CRAWLER_RADIUS + 0.25)


## Marks solid the cells within `reach` of `centre` for which `blocked` holds.
func _solid_round(centre: Vector3, reach: float, blocked: Callable) -> void:
	var low := _cell(centre - Vector3(reach, 0.0, reach))
	var high := _cell(centre + Vector3(reach, 0.0, reach))
	for x in range(low.x, high.x + 1):
		for y in range(low.y, high.y + 1):
			if blocked.call(_point(Vector2i(x, y), 0.0)):
				grid.set_point_solid(Vector2i(x, y), true)


## The street's band between the rows, and the corner where it meets the Connector road.
func _in_band(point: Vector3) -> bool:
	var corner := point.x < 108.6 and point.z > 205.0 and point.z < 245.0
	return corner or (point.z > NORTH_WALL + CRAWLER_RADIUS - 0.4 and point.z < SOUTH_WALL - CRAWLER_RADIUS + 0.4)


func _walkable(point: Vector3) -> bool:
	if not _in_band(point):
		return false
	for car in cars:
		if _inside(car, point, CRAWLER_RADIUS):
			return false
	for item: Dictionary in _markers.get("furniture", []):
		if String(item.kind) in POSTS:
			var post := Vector2(float(item.position[0]), float(item.position[1]))
			if post.distance_to(Vector2(point.x, point.z)) < CRAWLER_RADIUS + 0.25:
				return false
	return true


func _inside(car: Dictionary, point: Vector3, margin: float) -> bool:
	var offset := Vector3(point.x, 0.0, point.z) - Vector3(car.centre.x, 0.0, car.centre.z)
	return absf(offset.dot(car.axes[0])) < float(car.half[0]) + margin \
		and absf(offset.dot(car.axes[1])) < float(car.half[1]) + margin


## The line: perches spread evenly along the front edges of both rows' roofs, facing the street.
func _build_line() -> void:
	var perches: Array[Transform3D] = []
	for row: String in ["north", "south"]:
		var spans: Array = []
		var total := 0.0
		for building: Dictionary in _markers.get("buildings", []):
			if String(building.row) != row:
				continue
			var x0 := float(building.footprint[0]) + 1.4
			var x1 := float(building.footprint[1]) - 1.4
			if x1 > x0 and x0 < end_x:
				spans.append([x0, x1, building])
				total += x1 - x0
		var count := ridgeback_count / 2 + (ridgeback_count % 2 if row == "north" else 0)
		for index in count:
			var along := (index + 0.5) / count * total
			for span: Array in spans:
				var width: float = span[1] - span[0]
				if along <= width:
					var building: Dictionary = span[2]
					var front := float(building.footprint[3]) - 0.22 if row == "north" else float(building.footprint[2]) + 0.22
					var at := Vector3(span[0] + along, float(building.height), front)
					var facing := Basis(Vector3.UP, PI if row == "north" else 0.0)
					perches.append(Transform3D(facing, at))
					break
				along -= width
	var holder := Node3D.new()
	holder.name = "Line"
	add_child(holder)
	for index in perches.size():
		var faller := FALLER.instantiate() as RidgebackFaller
		faller.name = "Ridgeback%d" % (index + 1)
		faller.street = self
		if not walker_order.is_empty():
			(faller.get_node("Visual") as RidgebackFallerVisual).walker = walker_order[index % walker_order.size()]
		holder.add_child(faller)
		faller.perch(perches[index])
		fallers.append(faller)
		_leads[faller] = _rng.randf_range(lead.x, lead.y)
		if perches[index].origin.x >= finale_x - finale_lead:
			_kept.append(faller)


## Lamps, meters and benches a car of the jam stands on were knocked over.
func _knock_over_furniture() -> void:
	var finishing := get_parent().get_node_or_null("Buildings/CivicFinishing")
	if finishing == null:
		return
	for child: Node in finishing.get_children():
		var prop := child as Node3D
		if prop == null:
			continue
		for car in cars:
			if _inside(car, prop.global_position, KNOCKED_RADIUS):
				prop.hide()
				for collider: CollisionShape3D in prop.find_children("*", "CollisionShape3D", true, false):
					collider.disabled = true
				break


func _sound_alarm(car: Node3D) -> void:
	var alarm := car.get_node_or_null("CarAlarm") as CarAlarm
	if alarm == null:
		for entry in cars:
			if entry.node == car:
				alarm = CarAlarm.fit(car, Vector2(float(entry.half[0]), float(entry.half[1])), float(entry.top))
				break
	if alarm != null:
		alarm.sound()


func _sleep(asleep: bool) -> void:
	for faller in fallers:
		faller.visible = not asleep
		faller.process_mode = Node.PROCESS_MODE_DISABLED if asleep else Node.PROCESS_MODE_INHERIT


## The player came back from a death: the street goes back to before the shriek.
func reset_enemy() -> void:
	if phase == Phase.DONE:
		return
	Gore.clear(_gore)
	for car in cars:
		var alarm := (car.node as Node).get_node_or_null("CarAlarm") as CarAlarm
		if alarm != null:
			alarm.silence()
	_recent.clear()
	_crawling = 0
	_first_fall = true
	_shake = 0.0
	if _hold_left > 0.0:
		_hold_left = 0.0
		player.walk_speed = _held_speeds.x
		player.sprint_speed = _held_speeds.y
	if phase != Phase.ASLEEP:
		phase = Phase.WATCHING
	_leap_in = 0.0
	for faller in fallers:
		faller.reset_enemy()


## Which way the player is looking.
func _view() -> Vector3:
	var camera := player.get_node_or_null("Head/Camera3D") as Camera3D
	return -camera.global_basis.z if camera != null else Vector3.RIGHT


## Thomas has made it to the hospital: the street is over, and what lies in it stays there, whatever happens
## to him after.
func _finish() -> void:
	phase = Phase.DONE
	_say(end_line)
	_hold_story(false)
	remove_from_group(&"corrupted_friend")
	for faller in fallers:
		faller.remove_from_group(&"corrupted_friend")


## The story's hold on the Wrapper and its checkpoint at the corner, in the alt route's story.
func _hold_story(holding: bool) -> void:
	var story := get_tree().get_first_node_in_group(&"opening_story")
	if story != null and story.has_method("set_street_hold"):
		story.call("set_street_hold", holding)


func _say(line: String, interrupt: bool = false) -> void:
	if line.is_empty():
		return
	var story := get_tree().get_first_node_in_group(&"opening_story")
	if story != null:
		var words := line.trim_prefix("Thomas: ")
		story.call("narrate_once", "street_" + str(line.hash()), words, "Thomas", interrupt)


func _ground(z: float) -> float:
	return ROAD_TOP if z > CURBS.x and z < CURBS.y else WALK_TOP


func _cell(point: Vector3) -> Vector2i:
	return Vector2i(clampi(int((point.x - GRID_AREA.position.x) / GRID_CELL), 0, grid.region.size.x - 1),
		clampi(int((point.z - GRID_AREA.position.y) / GRID_CELL), 0, grid.region.size.y - 1))


func _point(cell: Vector2i, height: float) -> Vector3:
	return Vector3(GRID_AREA.position.x + (cell.x + 0.5) * GRID_CELL, height, GRID_AREA.position.y + (cell.y + 0.5) * GRID_CELL)


func _nearest_open(cell: Vector2i) -> Vector2i:
	if not grid.is_point_solid(cell):
		return cell
	for radius in range(1, 12):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var next := cell + Vector2i(dx, dy)
				if grid.is_in_boundsv(next) and not grid.is_point_solid(next):
					return next
	return Vector2i(-1, -1)
