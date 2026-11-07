class_name WormMass
extends Node3D
## A creature made of nothing but worms: hundreds of writhing strands hung on a dozen invisible
## anchor points shaped like a hunched body. The strands are MultiMesh instances animated entirely
## in the vertex shader (worm_strand.gdshader), so the whole mass costs the CPU a dozen node
## transforms a frame; the body's lumber, climb and lunge are procedural poses on the anchors.
## The strands cast no shadows; one hidden capsule casts the body's shadow instead. A few free
## "scout" tendrils (worm_scout.gd) slither along the ground around it.
## Built for the worm-mass demo (scenes/chapters/playground/worm_mass_demo.tscn); not yet in the game.

enum State { IDLE, WALK, CLIMB, LUNGE }

## The total strands on show; set_density redistributes without rebuilding buffers.
@export_range(100, 1200, 10) var density: int = 600
@export_range(0.2, 4.0, 0.05, "suffix:m/s") var move_speed: float = 1.2
@export_range(1, 12, 1) var scout_count: int = 5
## Where the ground lies for the scouts (the demo floor is flat).
@export var scout_ground_y: float = 0.0

## The hardest density the buffers are sized for.
const MAX_DENSITY := 1200
const SQUIRM_SOUND: AudioStream = preload("res://sounds/entities/ridgeback/ridgeback_squelch.wav")
const SCOUT_SCRIPT := preload("res://scenes/monsters/worm_mass/worm_scout.gd")
const STRAND_SHADER: Shader = preload("res://scenes/monsters/worm_mass/worm_strand.gdshader")

## The body's anchor points: local rest position, the clump's spread, its share of the strands,
## and how long its strands run. "drape" strands hang longer (the mane on the head and chest).
const ANCHORS := [
	{"name": "head", "rest": Vector3(0.0, 1.95, 0.30), "radius": 0.26, "weight": 9.0, "length": Vector2(0.35, 0.62), "drape": 0.45},
	{"name": "neck", "rest": Vector3(0.0, 1.72, 0.16), "radius": 0.20, "weight": 6.0, "length": Vector2(0.30, 0.55), "drape": 0.3},
	{"name": "chest", "rest": Vector3(0.0, 1.42, 0.08), "radius": 0.34, "weight": 16.0, "length": Vector2(0.38, 0.72), "drape": 0.4},
	{"name": "belly", "rest": Vector3(0.0, 1.02, 0.04), "radius": 0.30, "weight": 13.0, "length": Vector2(0.36, 0.66), "drape": 0.25},
	{"name": "hips", "rest": Vector3(0.0, 0.74, -0.04), "radius": 0.28, "weight": 12.0, "length": Vector2(0.34, 0.62), "drape": 0.2},
	{"name": "shoulder_l", "rest": Vector3(-0.44, 1.60, 0.08), "radius": 0.21, "weight": 7.0, "length": Vector2(0.30, 0.58), "drape": 0.2},
	{"name": "shoulder_r", "rest": Vector3(0.44, 1.60, 0.08), "radius": 0.21, "weight": 7.0, "length": Vector2(0.30, 0.58), "drape": 0.2},
	{"name": "arm_l", "rest": Vector3(-0.56, 1.10, 0.16), "radius": 0.17, "weight": 5.5, "length": Vector2(0.28, 0.52), "drape": 0.15},
	{"name": "arm_r", "rest": Vector3(0.56, 1.10, 0.16), "radius": 0.17, "weight": 5.5, "length": Vector2(0.28, 0.52), "drape": 0.15},
	{"name": "hand_l", "rest": Vector3(-0.62, 0.56, 0.28), "radius": 0.15, "weight": 4.5, "length": Vector2(0.26, 0.5), "drape": 0.1},
	{"name": "hand_r", "rest": Vector3(0.62, 0.56, 0.28), "radius": 0.15, "weight": 4.5, "length": Vector2(0.26, 0.5), "drape": 0.1},
	{"name": "thigh_l", "rest": Vector3(-0.21, 0.46, 0.0), "radius": 0.19, "weight": 5.0, "length": Vector2(0.3, 0.55), "drape": 0.1},
	{"name": "thigh_r", "rest": Vector3(0.21, 0.46, 0.0), "radius": 0.19, "weight": 5.0, "length": Vector2(0.3, 0.55), "drape": 0.1},
	{"name": "foot_l", "rest": Vector3(-0.25, 0.14, 0.06), "radius": 0.15, "weight": 3.5, "length": Vector2(0.24, 0.45), "drape": 0.0},
	{"name": "foot_r", "rest": Vector3(0.25, 0.14, 0.06), "radius": 0.15, "weight": 3.5, "length": Vector2(0.24, 0.45), "drape": 0.0},
]
## The walk cycle's beat and bounds.
const STEP_FREQUENCY := 2.6
const CLIMB_REAR := 0.9
const CLIMB_HAUL := 2.3
const CLIMB_CREST := 0.8
const CLIMB_DROP := 0.7
const CLIMB_SETTLE := 0.4
const LUNGE_CROUCH := 0.3
const LUNGE_FLY := 0.5
const LUNGE_LAND := 0.3

var state: State = State.IDLE
## Scouts steer toward this; the demo points it at the camera.
var scout_focus := Vector3.ZERO

var _body: Node3D
var _anchors: Dictionary = {}
var _clumps: Dictionary = {}
var _capacity: Dictionary = {}
var _strand_mesh: ArrayMesh
var _material: ShaderMaterial
var _core_material: StandardMaterial3D
var _scouts: Array[Node3D] = []
var _squirm: AudioStreamPlayer3D
var _squirm_in := 0.5
var _rng := RandomNumberGenerator.new()
## Per-anchor wobble seeds, and the twitch that jolts one anchor now and then.
var _seeds: Dictionary = {}
var _twitch_anchor := ""
var _twitch_left := 0.0
var _twitch_in := 2.0
var _twitch_offset := Vector3.ZERO
## Walking.
var _move_target := Vector3.ZERO
var _gait_phase := 0.0
## Climbing and lunging.
var _action_t := 0.0
var _climb_base := Vector3.ZERO
var _climb_top := Vector3.ZERO
var _climb_land := Vector3.ZERO
var _climb_face := Vector3.ZERO
var _lunge_from := Vector3.ZERO
var _lunge_to := Vector3.ZERO


func _ready() -> void:
	_rng.randomize()
	_material = ShaderMaterial.new()
	_material.shader = STRAND_SHADER
	_core_material = StandardMaterial3D.new()
	_core_material.albedo_color = Color(0.11, 0.02, 0.022)
	_core_material.roughness = 0.88
	_core_material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_strand_mesh = _make_strand_mesh(_material)
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	for entry: Dictionary in ANCHORS:
		_build_anchor(entry)
	_build_shadow_proxy()
	_build_squirm()
	_spawn_scouts()
	set_density(density)


# --- The strands -------------------------------------------------------------------------------

## One worm: a hex tube running up +Y from a rooted base to a pointed tip, radius swelling a
## little below the middle. UV.y runs root to tip; the shader bends it by that.
static func _make_strand_mesh(material: Material) -> ArrayMesh:
	const RINGS := 12
	const SIDES := 6
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in RINGS + 1:
		var along := float(ring) / RINGS
		# A worm keeps its girth almost to the end, then rounds off; it never runs to a thorn.
		var round_off := smoothstep(0.82, 1.0, along)
		var radius := (0.023 + 0.005 * sin(along * PI)) * sqrt(maxf(1.0 - round_off * round_off, 0.06))
		for side in SIDES:
			var angle := TAU * side / SIDES
			var out := Vector3(cos(angle), 0.0, sin(angle))
			positions.append(out * maxf(radius, 0.003) + Vector3.UP * along)
			normals.append(out)
			uvs.append(Vector2(float(side) / SIDES, along))
	# Godot's front faces wind clockwise seen from outside.
	for ring in RINGS:
		for side in SIDES:
			var a := ring * SIDES + side
			var b := ring * SIDES + (side + 1) % SIDES
			var c := a + SIDES
			var d := b + SIDES
			indices.append_array([a, b, c, b, d, c])
	var tip := positions.size()
	positions.append(Vector3(0.0, 1.015, 0.0))
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 1.0))
	for side in SIDES:
		indices.append_array([RINGS * SIDES + side, RINGS * SIDES + (side + 1) % SIDES, tip])
	var base := positions.size()
	positions.append(Vector3.ZERO)
	normals.append(Vector3.DOWN)
	uvs.append(Vector2(0.5, 0.0))
	for side in SIDES:
		indices.append_array([base, (side + 1) % SIDES, side])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


## An anchor and its clump: a MultiMesh of strands rooted inside a ball round the anchor, each
## pointing its own way, filled once to the top density and shown up to the current one.
func _build_anchor(entry: Dictionary) -> void:
	var anchor := Node3D.new()
	anchor.name = String(entry.name).capitalize().replace(" ", "")
	_body.add_child(anchor)
	anchor.position = entry.rest
	_anchors[entry.name] = anchor
	_seeds[entry.name] = _rng.randf() * TAU
	# A dark knot of flesh under the strands, so the gaps between them show meat, not sky.
	var core := MeshInstance3D.new()
	core.name = "Core"
	var core_mesh := SphereMesh.new()
	core_mesh.radius = float(entry.radius) * 0.6
	core_mesh.height = float(entry.radius) * 1.1
	core_mesh.radial_segments = 12
	core_mesh.rings = 6
	core_mesh.material = _core_material
	core.mesh = core_mesh
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anchor.add_child(core)
	var clump := MultiMeshInstance3D.new()
	clump.name = "Clump"
	anchor.add_child(clump)
	var total_weight := 0.0
	for other: Dictionary in ANCHORS:
		total_weight += float(other.weight)
	var capacity := maxi(int(ceil(float(entry.weight) / total_weight * MAX_DENSITY)), 4)
	_capacity[entry.name] = capacity
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = _strand_mesh
	multimesh.instance_count = capacity
	var radius := float(entry.radius)
	var lengths: Vector2 = entry.length
	for index in capacity:
		var out := Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.8, 0.8), _rng.randf_range(-1.0, 1.0)).normalized()
		var length := _rng.randf_range(lengths.x, lengths.y) * 0.95
		var droops := out.y < 0.15 and _rng.randf() < float(entry.drape)
		if droops:
			length *= _rng.randf_range(1.5, 2.2)
			out = (out + Vector3.DOWN * 0.8).normalized()
		# Worms lie along the body, woven round it, far more than they stand out of it: the axis
		# leans tangent, and only the drapes and a few others point away.
		var tangent := out.cross(Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)).normalized())
		if tangent.length() < 0.05:
			tangent = out.cross(Vector3.RIGHT)
		var stand_out := _rng.randf_range(0.55, 1.0) if droops or _rng.randf() < 0.18 else _rng.randf_range(0.05, 0.35)
		var axis := (tangent.normalized() * (1.0 - stand_out) + out * stand_out).normalized()
		var basis := _basis_with_y(axis, _rng.randf() * TAU)
		var thickness := _rng.randf_range(0.45, 0.8)
		basis = basis * Basis.from_scale(Vector3(thickness, length, thickness))
		var origin := out * radius * _rng.randf_range(0.45, 0.85)
		multimesh.set_instance_transform(index, Transform3D(basis, origin))
		multimesh.set_instance_custom_data(index, Color(_rng.randf(), _rng.randf_range(0.75, 1.35), _rng.randf_range(0.7, 1.3), _rng.randf()))
	clump.multimesh = multimesh
	clump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var reach := radius + lengths.y * 2.4 + 0.5
	clump.custom_aabb = AABB(Vector3.ONE * -reach, Vector3.ONE * reach * 2.0)


## A basis whose Y runs along `axis`, rolled round it by `roll`.
static func _basis_with_y(axis: Vector3, roll: float) -> Basis:
	var swing := Quaternion(Vector3.UP, axis) if axis.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
	return Basis(swing * Quaternion(Vector3.UP, roll))


## The strands cast no shadows; this hidden capsule stands in for the body in the shadow pass.
func _build_shadow_proxy() -> void:
	var proxy := MeshInstance3D.new()
	proxy.name = "ShadowProxy"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.52
	capsule.height = 2.1
	proxy.mesh = capsule
	proxy.position = Vector3(0.0, 1.15, 0.05)
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	_body.add_child(proxy)


func _build_squirm() -> void:
	_squirm = AudioStreamPlayer3D.new()
	_squirm.name = "Squirm"
	_squirm.stream = SQUIRM_SOUND
	_squirm.volume_db = -14.0
	_squirm.unit_size = 6.0
	_squirm.max_distance = 40.0
	_squirm.position = Vector3.UP * 1.2
	_body.add_child(_squirm)


func _spawn_scouts() -> void:
	for index in scout_count:
		var scout := Node3D.new()
		scout.name = "Scout%d" % (index + 1)
		scout.set_script(SCOUT_SCRIPT)
		add_child(scout)
		scout.call("setup", _strand_mesh, scout_ground_y, _rng.randf())
		scout.global_position = global_position + Vector3(_rng.randf_range(-2.5, 2.5), 0.0, _rng.randf_range(-2.5, 2.5))
		_scouts.append(scout)


## Shares `total` strands out over the clumps, no rebuild: the buffers hold MAX_DENSITY.
func set_density(total: int) -> void:
	density = clampi(total, 20, MAX_DENSITY)
	var total_weight := 0.0
	for entry: Dictionary in ANCHORS:
		total_weight += float(entry.weight)
	for entry: Dictionary in ANCHORS:
		var clump: MultiMeshInstance3D = _anchors[entry.name].get_node("Clump")
		var share := int(round(float(entry.weight) / total_weight * density))
		clump.multimesh.visible_instance_count = clampi(share, 2, int(_capacity[entry.name]))


func strands_shown() -> int:
	var count := 0
	for entry: Dictionary in ANCHORS:
		var clump: MultiMeshInstance3D = _anchors[entry.name].get_node("Clump")
		count += clump.multimesh.visible_instance_count
	return count


# --- Moving it ---------------------------------------------------------------------------------

func walk_to(point: Vector3) -> void:
	_move_target = point
	state = State.WALK


## Hauls itself up and over: `top` is a point on the wall's top edge, `landing` the ground beyond,
## and `face` a point low on the wall's near face, so the haul hugs the wall instead of flying.
func climb_over(top: Vector3, landing: Vector3, face := Vector3.INF) -> void:
	_climb_base = global_position
	_climb_top = top
	_climb_land = landing
	_climb_face = face if face != Vector3.INF else Vector3(top.x, global_position.y + 0.8, top.z).lerp(global_position, 0.25)
	_action_t = 0.0
	state = State.CLIMB
	_face_toward(top, 1.0)
	_squelch(0.75, -8.0)


func lunge_at(point: Vector3) -> void:
	_lunge_from = global_position
	_lunge_to = point
	_action_t = 0.0
	state = State.LUNGE
	_face_toward(point, 1.0)
	_squelch(0.6, -4.0)


func idle() -> void:
	state = State.IDLE


func _physics_process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	_run_twitch(delta)
	_run_squirm(delta)
	match state:
		State.IDLE:
			_pose_idle(t)
		State.WALK:
			_run_walk(delta, t)
		State.CLIMB:
			_run_climb(delta)
		State.LUNGE:
			_run_lunge(delta)
	for scout in _scouts:
		scout.set("target", scout_focus)
		scout.set("home", global_position)


## The resting mass is never still: every anchor drifts on its own slow wave, and now and then
## one of them jolts, as if something under the surface shifted its grip.
func _pose_idle(t: float, flail := 0.0, pull_in := 0.0) -> void:
	for entry: Dictionary in ANCHORS:
		var name := String(entry.name)
		var anchor: Node3D = _anchors[name]
		var seed_value: float = _seeds[name]
		var rest: Vector3 = entry.rest
		var drift := Vector3(
			sin(t * 0.9 + seed_value) * 0.025,
			sin(t * 1.3 + seed_value * 2.0) * 0.03,
			cos(t * 1.1 + seed_value) * 0.025)
		if flail > 0.0:
			drift += Vector3(
				sin(t * 15.0 + seed_value * 3.0),
				absf(sin(t * 13.0 + seed_value * 5.0)) * 1.4,
				cos(t * 14.0 + seed_value * 4.0)) * 0.22 * flail
		var pose := rest.lerp(Vector3(rest.x * 0.6, rest.y * 0.82 + 0.1, rest.z * 0.6), pull_in) + drift
		if name == _twitch_anchor and _twitch_left > 0.0:
			pose += _twitch_offset * (_twitch_left / 0.15)
		anchor.position = pose


func _run_twitch(delta: float) -> void:
	_twitch_left = maxf(_twitch_left - delta, 0.0)
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch_in = _rng.randf_range(1.6, 4.5)
		_twitch_anchor = String(ANCHORS[_rng.randi_range(0, ANCHORS.size() - 1)].name)
		_twitch_left = 0.15
		_twitch_offset = Vector3(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.4, 1.0), _rng.randf_range(-1.0, 1.0)) * 0.14


## The wet bed under it: the squelch, quiet and pitched down, over and over, never in time.
func _run_squirm(delta: float) -> void:
	_squirm_in -= delta
	if _squirm_in <= 0.0:
		_squirm_in = _rng.randf_range(0.35, 0.95)
		_squirm.pitch_scale = _rng.randf_range(0.55, 0.9)
		_squirm.volume_db = -14.0
		_squirm.play()


## One louder squelch for a landing or a spring; the quiet bed resets the volume on its next tick.
func _squelch(pitch: float, volume_db: float) -> void:
	_squirm.pitch_scale = pitch
	_squirm.volume_db = volume_db
	_squirm.play()


func _run_walk(delta: float, t: float) -> void:
	var to_target := _move_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		state = State.IDLE
		return
	_face_toward(_move_target, delta * 3.0)
	global_position += to_target.normalized() * move_speed * delta
	_gait_phase += delta * STEP_FREQUENCY * TAU * 0.5
	var p := _gait_phase
	_pose_idle(t)
	# The lumber: hips and chest counter-sway, the head lags, the long arms drag and swing.
	_offset("hips", Vector3(sin(p) * 0.06, absf(cos(p)) * 0.05, 0.0))
	_offset("belly", Vector3(sin(p) * 0.045, absf(cos(p)) * 0.045, 0.0))
	_offset("chest", Vector3(sin(p + PI) * 0.05, absf(cos(p)) * 0.04, 0.02))
	_offset("head", Vector3(sin(p + PI) * 0.07, sin(p * 2.0) * 0.02, 0.03))
	for side in 2:
		var tag := "_l" if side == 0 else "_r"
		var leg_phase := p + (0.0 if side == 0 else PI)
		var lift := maxf(sin(leg_phase), 0.0)
		_offset("foot" + tag, Vector3(0.0, lift * 0.17, cos(leg_phase) * 0.26))
		_offset("thigh" + tag, Vector3(0.0, lift * 0.08, cos(leg_phase) * 0.13))
		var swing := p + (PI if side == 0 else 0.0)
		_offset("hand" + tag, Vector3(sin(p) * 0.02, maxf(sin(swing), 0.0) * 0.06, cos(swing) * 0.22))
		_offset("arm" + tag, Vector3(0.0, 0.0, cos(swing) * 0.1))
	_body.rotation.x = 0.07 + sin(p * 2.0) * 0.015


func _offset(anchor_name: String, by: Vector3) -> void:
	(_anchors[anchor_name] as Node3D).position += by


func _face_toward(point: Vector3, amount: float) -> void:
	var flat := point - global_position
	flat.y = 0.0
	if flat.length() < 0.05:
		return
	var wanted := atan2(-flat.x, -flat.z) + PI
	rotation.y = lerp_angle(rotation.y, wanted, clampf(amount, 0.0, 1.0))


## Up the wall: rear at its foot, haul to the top with everything flailing, tip over the edge,
## drop down the far side and land in a squash.
func _run_climb(delta: float) -> void:
	_action_t += delta
	var t := float(Time.get_ticks_msec()) / 1000.0
	var at := _action_t
	if at < CLIMB_REAR:
		var s := at / CLIMB_REAR
		_pose_idle(t, s * 0.5)
		global_position = _climb_base + Vector3.UP * 0.22 * s
		_body.rotation.x = -0.28 * s
		_offset("hand_l", Vector3(0.0, 0.85 * s, 0.1))
		_offset("hand_r", Vector3(0.0, 0.9 * s, 0.1))
		_offset("arm_l", Vector3(0.0, 0.5 * s, 0.05))
		_offset("arm_r", Vector3(0.0, 0.5 * s, 0.05))
		return
	at -= CLIMB_REAR
	if at < CLIMB_HAUL:
		var s := ease(at / CLIMB_HAUL, -1.8)
		_pose_idle(t, 1.0)
		# A bezier by way of the wall's face: in to the wall first, then up it to the top.
		var start := _climb_base + Vector3.UP * 0.22
		global_position = start.lerp(_climb_face, s).lerp(_climb_face.lerp(_climb_top, s), s)
		_body.rotation.x = -0.28 + 0.1 * sin(s * TAU * 2.0)
		return
	at -= CLIMB_HAUL
	if at < CLIMB_CREST:
		var s := at / CLIMB_CREST
		_pose_idle(t, 0.6)
		var over := _climb_top.lerp(Vector3(_climb_land.x, _climb_top.y, _climb_land.z), s * 0.45)
		global_position = over
		_body.rotation.x = 0.5 * s
		return
	at -= CLIMB_CREST
	if at < CLIMB_DROP:
		var s := ease(at / CLIMB_DROP, 2.2)
		_pose_idle(t, 0.35)
		var from := Vector3(_climb_land.x, _climb_top.y, _climb_land.z).lerp(_climb_top, 0.55)
		global_position = from.lerp(_climb_land, s)
		_body.rotation.x = 0.5 * (1.0 - s)
		return
	at -= CLIMB_DROP
	if at < CLIMB_SETTLE:
		var s := at / CLIMB_SETTLE
		_pose_idle(t)
		global_position = _climb_land
		_body.rotation.x = 0.0
		_body.position.y = -0.16 * sin(s * PI)
		if is_zero_approx(_body.position.y):
			_squelch(0.7, -6.0)
		return
	_body.position.y = 0.0
	state = State.IDLE


func _run_lunge(delta: float) -> void:
	_action_t += delta
	var t := float(Time.get_ticks_msec()) / 1000.0
	var at := _action_t
	if at < LUNGE_CROUCH:
		var s := at / LUNGE_CROUCH
		_pose_idle(t, 0.0, s * 0.8)
		_body.position.y = -0.22 * s
		_body.rotation.x = 0.12 * s
		return
	at -= LUNGE_CROUCH
	if at < LUNGE_FLY:
		var s := at / LUNGE_FLY
		_pose_idle(t, 1.0)
		var flat := _lunge_from.lerp(_lunge_to, s)
		flat.y += 4.0 * 0.6 * s * (1.0 - s)
		global_position = flat
		_body.position.y = -0.22 * (1.0 - s)
		_body.rotation.x = -0.2 + 0.5 * s
		return
	at -= LUNGE_FLY
	if at < LUNGE_LAND:
		var s := at / LUNGE_LAND
		_pose_idle(t, 0.3 * (1.0 - s))
		global_position = _lunge_to
		_body.rotation.x = 0.3 * (1.0 - s)
		_body.position.y = -0.2 * sin(s * PI)
		return
	_body.position.y = 0.0
	_body.rotation.x = 0.0
	state = State.IDLE
