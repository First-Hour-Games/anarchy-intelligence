extends RefCounted

## Sits a humanoid model back in a chair, or stands it up again. Seated, the thighs point forward
## and the shins down, and the model drops so its hips rest just above the seat; the arms keep
## their rest pose (the Wrapper's are wrapped round itself). Bone names follow the Wrapper's rig
## (thigh.L, shin.L, foot.L...). Directions are in the body's frame: x right, y up, -z forward,
## the way story entities face.

## Hip joints above the floor when sitting: the armchair's cushion is 0.53 m high.
const HIP_HEIGHT := 0.62
const THIGH := Vector3(0.0, -0.12, -1.0)
const SHIN := Vector3(0.0, -1.0, -0.3)


## Seats the model's hips over seat (in the body's frame), or stands it back up at the body's feet.
static func apply(visual: Node3D, seated: bool, seat: Vector3) -> void:
	visual.position = Vector3.ZERO
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	skeleton.reset_bone_poses()
	if not seated:
		return
	var body := visual.get_parent() as Node3D
	var to_skeleton := skeleton.global_basis.inverse() * body.global_basis
	for side: String in ["L", "R"]:
		_aim(skeleton, "thigh." + side, "shin." + side, to_skeleton * THIGH)
		_aim(skeleton, "shin." + side, "foot." + side, to_skeleton * SHIN)
	var hips := (_joint(body, skeleton, "thigh.L") + _joint(body, skeleton, "thigh.R")) * 0.5
	visual.position = Vector3(seat.x - hips.x, HIP_HEIGHT - hips.y, seat.z - hips.z)


## Turns a bone about its joint so the line to its child bone points along direction (skeleton space).
static func _aim(skeleton: Skeleton3D, bone: String, child: String, direction: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(index)
	var reach := skeleton.get_bone_global_pose(skeleton.find_bone(child)).origin - pose.origin
	var turned := Transform3D(Basis(Quaternion(reach.normalized(), direction.normalized())) * pose.basis, pose.origin)
	var parent := skeleton.get_bone_parent(index)
	var local := skeleton.get_bone_global_pose(parent).affine_inverse() * turned if parent >= 0 else turned
	skeleton.set_bone_pose_rotation(index, local.basis.get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()


## Where a bone's joint is, in the body's frame.
static func _joint(body: Node3D, skeleton: Skeleton3D, bone: String) -> Vector3:
	return body.to_local(skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin)
