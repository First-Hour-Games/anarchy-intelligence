extends Node
## Turns a rigged model into a ragdoll when it dies: one capsule RigidBody3D per body bone,
## joined to its parent's with a cone-twist joint, and the skeleton posed from the bodies
## every frame.
##
## The bodies sit under this plain Node, so they inherit no scale. The Wrapper is scaled in
## its scenes and its FBX skeleton carries a unit scale. PhysicalBone3D bodies inside that
## scaled tree disagreed with their joints and flung the body apart on the first step.

## Rig control bones that move nothing on the mesh: they get no body and are never posed.
const CONTROL_BONE_MARKERS: Array[String] = ["root", "_ik", "pole", "WGT"]
## Bones shorter than this in the world (shoulders, toes) get no body and follow their parent.
const MIN_BONE_LENGTH := 0.08
## Capsule radius as a share of the bone's length, within these limits (metres).
const RADIUS_SHARE := 0.22
const MIN_RADIUS := 0.035
const MAX_RADIUS := 0.16
## Layer 9 is unused, so the body falls onto the world (layer 1). Bones never hit each other,
## and the player's movement and the pipe's swing ray pass through them.
const BONE_LAYER := 1 << 8
const BONE_MASK := 1
const SWING_DEGREES := 45.0
const TWIST_DEGREES := 20.0

var skeleton: Skeleton3D
var bones := PackedInt32Array()
var bodies: Array[RigidBody3D] = []
## Each bone's world transform relative to its body, scale included.
var offsets: Array[Transform3D] = []


## Builds the ragdoll for visual's skeleton under owner_body, sending every bone off at push
## (world-space velocity). Returns the ragdoll, or null when the model has no skeleton.
static func fall(owner_body: Node3D, visual: Node3D, push: Vector3) -> Node:
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return null
	for node: Node in visual.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()
	var ragdoll: Node = (load("res://scenes/monsters/ragdoll.gd") as GDScript).new()
	ragdoll.name = "Ragdoll"
	owner_body.add_child(ragdoll)
	var ignore: Array[PhysicsBody3D] = []
	if owner_body is PhysicsBody3D:
		ignore.append(owner_body)
	var player := owner_body.get_tree().get_first_node_in_group("player")
	if player is PhysicsBody3D:
		ignore.append(player)
	ragdoll.call("_build", skeletons[0], push, ignore)
	return ragdoll


func _build(target: Skeleton3D, push: Vector3, ignore: Array[PhysicsBody3D]) -> void:
	skeleton = target
	var by_bone := {}
	for bone in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone)
		if _is_control(bone_name) or bone_name.ends_with("_end"):
			continue
		var start := _world_origin(bone)
		var reach := _reach(bone, start)
		var parent := _body_ancestor(bone, by_bone)
		if reach.length() < MIN_BONE_LENGTH:
			if parent != null:
				continue
			# The first body (the hips) always gets one, or the legs would come loose.
			reach = (reach.normalized() if not reach.is_zero_approx() else Vector3.UP) * MIN_BONE_LENGTH * 1.5
		var length := reach.length()
		var body := _capsule_body(bone_name, start, reach, push)
		add_child(body)
		for other in ignore:
			body.add_collision_exception_with(other)
		if parent != null:
			_join(parent, body, start, reach / length)
		by_bone[bone] = body
		bones.append(bone)
		bodies.append(body)
		offsets.append(body.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone))


func _process(_delta: float) -> void:
	if not is_instance_valid(skeleton):
		return
	var to_skeleton := skeleton.global_transform.affine_inverse()
	# Bone indices run parent-first, so each parent is posed before its children.
	for i in bodies.size():
		skeleton.set_bone_global_pose(bones[i], to_skeleton * bodies[i].global_transform * offsets[i])


static func _is_control(bone_name: String) -> bool:
	for marker in CONTROL_BONE_MARKERS:
		if bone_name.contains(marker):
			return true
	return false


func _world_origin(bone: int) -> Vector3:
	return skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin


## The bone's span in the world: to its only child, or the middle of several (hips, chest).
func _reach(bone: int, start: Vector3) -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for child in skeleton.get_bone_children(bone):
		if _is_control(skeleton.get_bone_name(child)):
			continue
		total += _world_origin(child)
		count += 1
	return total / count - start if count > 0 else Vector3.ZERO


func _body_ancestor(bone: int, by_bone: Dictionary) -> RigidBody3D:
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		if by_bone.has(parent):
			return by_bone[parent]
		parent = skeleton.get_bone_parent(parent)
	return null


## An unscaled capsule spanning the bone, its long axis along the bone.
func _capsule_body(bone_name: String, start: Vector3, reach: Vector3, push: Vector3) -> RigidBody3D:
	var length := reach.length()
	var capsule := CapsuleShape3D.new()
	capsule.radius = clampf(length * RADIUS_SHARE, MIN_RADIUS, MAX_RADIUS)
	capsule.height = maxf(length, capsule.radius * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	var body := RigidBody3D.new()
	body.name = ("Bone_" + bone_name).validate_node_name()
	body.add_child(shape)
	# Capsules run along their Y axis; turn Y onto the bone.
	body.transform = Transform3D(_turn(Vector3.UP, reach / length), start + reach * 0.5)
	body.mass = maxf(length * 4.0, 0.3)
	body.collision_layer = BONE_LAYER
	body.collision_mask = BONE_MASK
	body.linear_damp = 0.2
	body.angular_damp = 3.0
	body.linear_velocity = push
	return body


## The rotation taking axis onto direction (both unit length), including straight opposite.
static func _turn(axis: Vector3, direction: Vector3) -> Basis:
	if axis.dot(direction) < -0.9999:
		var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
		return Basis(side, PI)
	return Basis(Quaternion(axis, direction))


## A cone-twist joint at the bone's root, twisting about the bone (the joint's X axis).
func _join(parent: RigidBody3D, child: RigidBody3D, at: Vector3, along: Vector3) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.transform = Transform3D(_turn(Vector3.RIGHT, along), at)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(SWING_DEGREES))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(TWIST_DEGREES))
	add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
