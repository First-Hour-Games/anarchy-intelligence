class_name ShotgunCrosshair
extends Control
## The shotgun's crosshair (scenes/player/weapons/shotgun_weapon.gd): a dot where a shot is aimed, and a
## ring broken at the top, bottom and sides, as wide as the spread of the pellets at the camera's field of
## view, so whatever the ring covers a shot can hit. The ring kicks open with each shot and settles back,
## and dims while the gun cannot fire, empty or reloading. When pellets land on something that can be
## hurt, an X flashes round the dot, bigger and red when the shot killed.

## Each of the ring's four arcs spans this many degrees; the gaps between them face up, down and to the sides.
const ARC_DEGREES := 50.0
const DOT_RADIUS := 1.8
const LINE_WIDTH := 2.0
## The dark edge drawn under every mark, so it shows on bright ground as well as in the dark.
const OUTLINE_WIDTH := 1.5
const COLOR := Color(0.84, 0.93, 0.86, 0.78)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.5)
## How much wider a shot kicks the ring open, and how long it takes to settle back.
const KICK := 0.6
const KICK_SECONDS := 0.32
## The ring's opacity while the gun cannot fire.
const DIM := 0.28
## The X of a hit: how far from the dot each stroke starts and ends, its colour and how long it shows; and
## the same for a killing shot.
const HIT_FROM := 5.0
const HIT_TO := 11.0
const HIT_COLOR := Color(1.0, 0.94, 0.86, 0.95)
const HIT_SECONDS := 0.22
const KILL_FROM := 6.0
const KILL_TO := 16.0
const KILL_COLOR := Color(1.0, 0.3, 0.22, 1.0)
const KILL_SECONDS := 0.45
## The field of view assumed until a camera is given.
const DEFAULT_FOV := 74.0

## The pellets' spread, from the middle of the view to the edge of the pattern.
var spread_degrees := 5.0
var camera: Camera3D
## Whether a shot would go off now.
var ready_to_fire := true
var _kick := 0.0
var _hit := 0.0
var _hit_killed := false
var _opacity := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## A shot went off: the ring kicks open.
func kick() -> void:
	_kick = 1.0


## Pellets landed on something that can be hurt; `killed` if the shot finished it.
func mark_hit(killed: bool) -> void:
	# A kill keeps its mark if another target of the same shot only took a hit.
	_hit_killed = killed or (_hit_killed and _hit > 0.0)
	_hit = KILL_SECONDS if _hit_killed else HIT_SECONDS


func is_marking_hit() -> bool:
	return _hit > 0.0


func is_marking_kill() -> bool:
	return _hit > 0.0 and _hit_killed


## The ring's radius at rest, in this control's units: where the edge of the pellets' spread is on screen.
func spread_radius() -> float:
	var fov := camera.fov if is_instance_valid(camera) else DEFAULT_FOV
	return tan(deg_to_rad(spread_degrees)) / tan(deg_to_rad(fov) * 0.5) * get_viewport_rect().size.y * 0.5


func _process(delta: float) -> void:
	_kick = maxf(_kick - delta / KICK_SECONDS, 0.0)
	_hit = maxf(_hit - delta, 0.0)
	_opacity = move_toward(_opacity, 1.0 if ready_to_fire else DIM, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var centre := size * 0.5
	# Opens at once and eases back.
	var radius := spread_radius() * (1.0 + KICK * _kick * _kick)
	var colour := Color(COLOR, COLOR.a * _opacity)
	var outline := Color(OUTLINE_COLOR, OUTLINE_COLOR.a * _opacity)
	var half_arc := deg_to_rad(ARC_DEGREES) * 0.5
	for quarter in 4:
		var middle := TAU * (quarter + 0.5) / 4.0
		draw_arc(centre, radius, middle - half_arc, middle + half_arc, 16, outline, LINE_WIDTH + OUTLINE_WIDTH * 2.0, true)
	for quarter in 4:
		var middle := TAU * (quarter + 0.5) / 4.0
		draw_arc(centre, radius, middle - half_arc, middle + half_arc, 16, colour, LINE_WIDTH, true)
	draw_circle(centre, DOT_RADIUS + OUTLINE_WIDTH, outline)
	draw_circle(centre, DOT_RADIUS, colour)
	if _hit > 0.0:
		var length := KILL_SECONDS if _hit_killed else HIT_SECONDS
		var fade := clampf(_hit / length * 1.6, 0.0, 1.0)
		var from := KILL_FROM if _hit_killed else HIT_FROM
		var to := KILL_TO if _hit_killed else HIT_TO
		var mark := KILL_COLOR if _hit_killed else HIT_COLOR
		var width := LINE_WIDTH + (1.0 if _hit_killed else 0.0)
		for quarter in 4:
			var direction := Vector2.from_angle(TAU * (quarter + 0.5) / 4.0)
			draw_line(centre + direction * from, centre + direction * to, Color(0.0, 0.0, 0.0, 0.55 * fade),
				width + OUTLINE_WIDTH * 2.0, true)
			draw_line(centre + direction * from, centre + direction * to, Color(mark, mark.a * fade), width, true)
