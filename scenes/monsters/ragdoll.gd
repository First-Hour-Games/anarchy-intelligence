extends RefCounted
## Turns a rigged model into a ragdoll when it dies. The physical bones are built at runtime
## from the skeleton, the way the editor's "Create Physical Skeleton" does it: one capsule per
## bone, from the bone to its first child, joined to its parent with a cone joint.

## Bones shorter than this (fingers, toes, face) get no body and just follow their parent.
const MIN_BONE_LENGTH := 0.08
## Capsule radius as a share of the bone's length.
const RADIUS_SHARE := 0.18
## Layer 9 is unused, so the body falls onto the world (layer 1) but never blocks the player
## or the pipe's swing ray.
const BONE_LAYER := 1 << 8
const BONE_MASK := 1
const SWING_DEGREES := 40.0
const TWIST_DEGREES := 25.0


## Builds the ragdoll under visual's skeleton, starts it and sends every bone off at push
## (world-space velocity). Returns the simulator, or null when the model has no skeleton.
static func fall(visual: Node3D, push: Vector3) -> PhysicalBoneSimulator3D:
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	var skeleton := skeletons[0] as Skeleton3D
	for node: Node in visual.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()
	var simulator := _build(skeleton)
	simulator.physical_bones_start_simulation()
	# Push once the bones have switched to simulation, at the end of this frame.
	(func() -> void: _push(simulator, push)).call_deferred()
	return simulator


static func _build(skeleton: Skeleton3D) -> PhysicalBoneSimulator3D:
	var simulator := PhysicalBoneSimulator3D.new()
	simulator.name = "Ragdoll"
	var scale := absf(skeleton.global_basis.get_scale().x)
	for bone in skeleton.get_bone_count():
		var children := skeleton.get_bone_children(bone)
		if children.is_empty():
			continue
		var reach := skeleton.get_bone_rest(children[0]).origin
		if reach.length() * scale < MIN_BONE_LENGTH:
			continue
		simulator.add_child(_physical_bone(skeleton.get_bone_name(bone), reach))
	skeleton.add_child(simulator)
	return simulator


## A capsule from the bone's joint to its child's, in the bone's own space.
static func _physical_bone(bone_name: String, reach: Vector3) -> PhysicalBone3D:
	var half := reach.length() * 0.5
	var capsule := CapsuleShape3D.new()
	capsule.radius = half * 2.0 * RADIUS_SHARE
	capsule.height = maxf(half * 2.0, capsule.radius * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	# Capsules run along Y; the body looks down -Z toward the child bone.
	shape.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO)
	var up := Vector3.UP if not Vector3.UP.cross(reach).is_zero_approx() else Vector3.BACK
	var body_basis := Basis.looking_at(reach, up)
	var body := PhysicalBone3D.new()
	body.name = ("Bone_" + bone_name).validate_node_name()
	body.bone_name = bone_name
	body.body_offset = Transform3D(body_basis, body_basis * Vector3(0.0, 0.0, -half))
	body.joint_offset = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, half))
	body.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
	body.set(&"joint_constraints/swing_span", SWING_DEGREES)
	body.set(&"joint_constraints/twist_span", TWIST_DEGREES)
	body.collision_layer = BONE_LAYER
	body.collision_mask = BONE_MASK
	body.angular_damp = 2.0
	body.add_child(shape)
	return body


static func _push(simulator: PhysicalBoneSimulator3D, push: Vector3) -> void:
	if not is_instance_valid(simulator) or push.is_zero_approx():
		return
	for node: Node in simulator.get_children():
		if node is PhysicalBone3D:
			(node as PhysicalBone3D).apply_central_impulse(push * (node as PhysicalBone3D).mass)
