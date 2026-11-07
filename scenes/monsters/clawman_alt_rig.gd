extends SkeletonModifier3D
## Poses the bones the creator's clips never move on the alt route's Clawman (TheClawman_alt.glb, built by
## tools/blender/build_the_clawman_alt.py). It runs after the AnimationPlayer every frame:
## - the five extra arms (MantisArmL/R, RibArmL/R, DragArm; bones 1-4 each) grope and twitch on their own;
## - the head's halves (JawL, JawR) swing apart about their hinge at the back of the skull;
## - the tongue (Tongue1-6) slides out along itself and whips.
## clawman_alt_visual.gd sets opening, lash and agitation from the clip that is playing; this only poses.

## 0 shut, 1 wide open.
var opening: float = 0.0
## 0 lying in the throat, 1 at full reach.
var lash: float = 0.0
## 0 slow groping, 1 frantic (chasing, striking).
var agitation: float = 0.0
## Where the tongue lashes at (global; INF for nowhere), and how far it turns there from where the head points.
var aim_target := Vector3.INF
var aim: float = 0.0

## Degrees each half of the head turns at full opening.
@export_range(0.0, 80.0, 1.0) var open_angle: float = 46.0
## How much longer the tongue grows at full lash, in the model's own metres.
@export_range(0.0, 1.5, 0.01) var tongue_reach: float = 0.8

## Each arm: its fold at rest for bones 2-4 (degrees about the bend axis, local X), how far it sways, how
## far it reaches out (unfolds) when agitated, and a phase so no two move together.
const ARMS := {
	"MantisArmL": [[72.0, 42.0, 26.0], 12.0, 0.55, 0.0],
	"MantisArmR": [[68.0, 46.0, 22.0], 12.0, 0.55, 2.1],
	"RibArmL": [[42.0, 32.0, 20.0], 16.0, 0.3, 4.0],
	"RibArmR": [[38.0, 30.0, 24.0], 16.0, 0.3, 5.3],
	"DragArm": [[14.0, 10.0, 6.0], 6.0, 0.1, 1.2],
}
const TONGUE_BONES := 6

var _time: float = 0.0
var _jaws := PackedInt32Array()
var _tongue := PackedInt32Array()
var _arms: Dictionary = {}


func _ready() -> void:
	_find_bones()


func _skeleton_changed(_old: Skeleton3D, _new: Skeleton3D) -> void:
	_find_bones()


func _find_bones() -> void:
	var skeleton := get_skeleton()
	_jaws.clear()
	_tongue.clear()
	_arms.clear()
	if skeleton == null:
		return
	for name: String in ["JawL", "JawR"]:
		_jaws.append(skeleton.find_bone(name))
	for index in TONGUE_BONES:
		_tongue.append(skeleton.find_bone("Tongue%d" % (index + 1)))
	for arm: String in ARMS:
		var chain := PackedInt32Array()
		for index in 4:
			chain.append(skeleton.find_bone("%s%d" % [arm, index + 1]))
		_arms[arm] = chain


## Whether every bone this poses is on the skeleton.
func has_bones() -> bool:
	if _jaws.has(-1) or _tongue.has(-1) or _arms.size() != ARMS.size():
		return false
	for chain: PackedInt32Array in _arms.values():
		if chain.has(-1):
			return false
	return not _jaws.is_empty()


func _process_modification_with_delta(delta: float) -> void:
	var skeleton := get_skeleton()
	if skeleton == null or not has_bones():
		return
	_time += delta * lerpf(1.0, 3.0, agitation)
	_pose_jaws(skeleton)
	_pose_tongue(skeleton)
	for arm: String in ARMS:
		_pose_arm(skeleton, arm)


func _turned(skeleton: Skeleton3D, bone: int, rotation: Quaternion) -> void:
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_rest(bone).basis.get_rotation_quaternion() * rotation)


func _pose_jaws(skeleton: Skeleton3D) -> void:
	for index in 2:
		var side := 1.0 if index == 0 else -1.0
		# Open, the halves never hold still: a quiver, and each a little out of step with the other.
		var quiver := (sin(_time * 21.0 + index * 1.7) * 1.4 + sin(_time * 5.3 + index) * 2.5) * opening
		var angle := side * (open_angle * opening + quiver)
		_turned(skeleton, _jaws[index], Quaternion(Vector3.UP, deg_to_rad(angle)))


func _pose_tongue(skeleton: Skeleton3D) -> void:
	var stir := maxf(opening, lash)
	for index in _tongue.size():
		var bone := _tongue[index]
		var rest := skeleton.get_bone_rest(bone)
		skeleton.set_bone_pose_position(bone, rest.origin + rest.basis.y.normalized() * tongue_reach * lash / _tongue.size())
		# A wave runs down it, wider the further out it is; at full reach it droops a little.
		var wave := sin(_time * 8.0 - index * 0.9) * lerpf(5.0, 13.0, lash) * stir
		var sway := sin(_time * 6.1 - index * 0.7 + 1.3) * lerpf(3.0, 9.0, lash) * stir
		var turn := rest.basis.get_rotation_quaternion() * Quaternion.from_euler(Vector3(deg_to_rad(wave + 4.0 * lash), 0.0, deg_to_rad(sway)))
		if index == 0 and aim > 0.0 and aim_target.is_finite():
			turn = _aimed(skeleton, bone, rest, turn)
		skeleton.set_bone_pose_rotation(bone, turn)


## The tongue's root turned, part way by aim, from where the head points it to straight at aim_target.
func _aimed(skeleton: Skeleton3D, bone: int, rest: Transform3D, turn: Quaternion) -> Quaternion:
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone))
	var parent_basis := parent.basis.orthonormalized()
	var pointing := parent_basis * Basis(turn)
	var root := parent * rest.origin
	var wanted := (skeleton.global_transform.affine_inverse() * aim_target - root).normalized()
	var arc := Quaternion(pointing.y.normalized(), wanted)
	var aimed := Basis(Quaternion.IDENTITY.slerp(arc, clampf(aim, 0.0, 1.0))) * pointing
	return (parent_basis.inverse() * aimed).get_rotation_quaternion()


func _pose_arm(skeleton: Skeleton3D, arm: String) -> void:
	var setup: Array = ARMS[arm]
	var folds: Array = setup[0]
	var sway: float = setup[1]
	var reach: float = setup[2]
	var phase: float = setup[3]
	var chain: PackedInt32Array = _arms[arm]
	var t := _time + phase
	# Now and then a sharp twitch through the whole arm.
	var twitch := pow(maxf(0.0, sin(t * 0.83 + phase * 3.0)), 18.0) * lerpf(18.0, 30.0, agitation)
	_turned(skeleton, chain[0], Quaternion.from_euler(Vector3(
		deg_to_rad(sin(t * 0.7) * sway + twitch * 0.5), 0.0, deg_to_rad(sin(t * 0.53 + 1.1) * sway * 0.6))))
	for index in 3:
		var fold: float = folds[index] * (1.0 - reach * agitation)
		var grope := sin(t * (1.3 + index * 0.45) + index * 1.9) * sway * (0.7 + 0.3 * index)
		_turned(skeleton, chain[index + 1], Quaternion(Vector3.RIGHT, deg_to_rad(fold + grope + twitch)))
