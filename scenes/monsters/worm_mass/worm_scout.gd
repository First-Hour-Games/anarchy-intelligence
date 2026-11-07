extends Node3D
## One free tendril of the worm mass (worm_mass.gd): a single long strand that slithers along the
## ground ahead of the body, reaching toward whatever the mass is interested in. The writhing comes
## from the strand shader; this node only steers, pulses forward and wags its heading. With no
## target it noses about near home. The mass hands every scout the same target; their own phases
## keep them apart.

var target := Vector3.ZERO
var home := Vector3.ZERO
var ground_y := 0.0

var _phase := 0.0
var _speed := 1.0
var _wander_angle := 0.0
var _rng := RandomNumberGenerator.new()


func setup(strand_mesh: Mesh, ground: float, seed_value: float) -> void:
	_rng.randomize()
	ground_y = ground
	_phase = seed_value * TAU
	_speed = _rng.randf_range(0.8, 1.35)
	_wander_angle = _rng.randf() * TAU
	var body := MeshInstance3D.new()
	body.name = "Strand"
	body.mesh = strand_mesh
	# The strand runs up its +Y; lay it along the node's forward (-Z), tip a touch off the ground.
	body.rotation_degrees.x = -80.0
	body.scale = Vector3(0.7, _rng.randf_range(1.3, 1.9), 0.7)
	body.position.y = 0.03
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(body)


func _physics_process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0 + _phase
	var goal := target
	var keep_off := 1.6
	if goal == Vector3.ZERO:
		_wander_angle += _rng.randf_range(-0.9, 0.9) * delta
		goal = home + Vector3(sin(_wander_angle), 0.0, cos(_wander_angle)) * 3.5
		keep_off = 0.4
	var heading := goal - global_position
	heading.y = 0.0
	global_position.y = ground_y + 0.01
	if heading.length() < keep_off:
		# Close enough: nose from side to side where it is.
		rotation.y += sin(t * 1.7) * 0.5 * delta
		return
	var wanted := atan2(-heading.x, -heading.z) + sin(t * 2.3) * 0.38
	rotation.y = lerp_angle(rotation.y, wanted, 1.0 - exp(-3.0 * delta))
	# It gathers and surges rather than gliding.
	var surge := 0.55 + 0.45 * sin(t * 2.9)
	global_position += -global_basis.z * _speed * surge * delta
