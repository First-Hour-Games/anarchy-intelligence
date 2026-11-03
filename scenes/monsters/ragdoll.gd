extends Node
## Turns a rigged model into a ragdoll when it dies: one capsule RigidBody3D per body bone,
## joined to its parent's with a cone-twist joint, and the skeleton posed from the bodies
## every frame.
##
## The bodies sit under this plain Node, so they inherit no scale. The Wrapper is scaled in
## its scenes and its FBX skeleton carries a unit scale. PhysicalBone3D bodies inside that
## scaled tree disagreed with their joints and flung the body apart on the first step.
##
## Each capsule is as thick as the mesh around its bone (measured from the skinned vertices),
## so the body keeps its volume on the ground instead of sinking flat into it. Bones collide
## with each other, except pairs that are joined or already overlap when it dies (its arms are
## wrapped round its body).

## Rig control bones that move nothing on the mesh: they get no body and are never posed.
const CONTROL_BONE_MARKERS: Array[String] = ["root", "_ik", "pole", "WGT"]
## Bones shorter than this in the world (shoulders, toes) get no body and follow their parent.
const MIN_BONE_LENGTH := 0.08
## The share of a bone's vertices that its capsule encloses.
const VERTEX_COVERAGE := 0.65
## Capsule radius limits (metres), and the radius used where the mesh gives no measurement,
## as a share of the bone's length.
const MIN_RADIUS := 0.03
const MAX_RADIUS := 0.3
const FALLBACK_RADIUS_SHARE := 0.3
## Layer 9 is unused. Bones fall onto the world (layer 1) and onto each other; the player's
## movement and the pipe's swing ray (both layer 1 only) pass through them.
const BONE_LAYER := 1 << 8
const BONE_MASK := 1 | BONE_LAYER
const DENSITY := 1000.0
## [swing, twist] limits in degrees, by the first marker in the bone's name.
const JOINT_LIMITS := {
	"spine": [12.0, 8.0], "torso": [12.0, 8.0], "chest": [12.0, 8.0],
	"neck": [25.0, 15.0], "head": [30.0, 20.0],
	"shoulder": [20.0, 10.0], "upper_arm": [70.0, 30.0], "forearm": [55.0, 5.0],
	"thigh": [55.0, 15.0], "shin": [55.0, 5.0],
	"hand": [30.0, 10.0], "foot": [25.0, 8.0], "toe": [20.0, 5.0],
}
const DEFAULT_LIMITS := [30.0, 10.0]

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
	ragdoll.call("_build", skeletons[0], visual, push, ignore)
	return ragdoll


func _build(target: Skeleton3D, visual: Node3D, push: Vector3, ignore: Array[PhysicsBody3D]) -> void:
	skeleton = target
	var radii := _mesh_radii(visual)
	var by_bone := {}
	var parents: Array[RigidBody3D] = []
	var segments: Array[PackedVector3Array] = []
	var radius_of: Array[float] = []
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
		var radius := clampf(float(radii.get(bone, length * FALLBACK_RADIUS_SHARE)), MIN_RADIUS, MAX_RADIUS)
		var body := _capsule_body(bone_name, start, reach, radius, push)
		add_child(body)
		for other in ignore:
			body.add_collision_exception_with(other)
		if parent != null:
			_join(parent, body, start, reach / length, _limits(bone_name))
		by_bone[bone] = body
		bones.append(bone)
		bodies.append(body)
		parents.append(parent)
		segments.append(PackedVector3Array([start, start + reach]))
		radius_of.append(radius)
		offsets.append(body.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone))
	# Bodies that start inside each other would burst apart, so those pairs never collide.
	for i in bodies.size():
		for j in range(i + 1, bodies.size()):
			if parents[j] == bodies[i] or parents[i] == bodies[j]:
				continue
			var closest := Geometry3D.get_closest_points_between_segments(segments[i][0], segments[i][1], segments[j][0], segments[j][1])
			if closest[0].distance_to(closest[1]) < radius_of[i] + radius_of[j]:
				bodies[i].add_collision_exception_with(bodies[j])
				bodies[j].add_collision_exception_with(bodies[i])


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


static func _limits(bone_name: String) -> Array:
	for marker: String in JOINT_LIMITS:
		if bone_name.contains(marker):
			return JOINT_LIMITS[marker]
	return DEFAULT_LIMITS


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


## The rest-pose segment of a bone in skeleton space, like _reach.
func _rest_segment(bone: int) -> PackedVector3Array:
	var start := skeleton.get_bone_global_rest(bone).origin
	var total := Vector3.ZERO
	var count := 0
	for child in skeleton.get_bone_children(bone):
		if _is_control(skeleton.get_bone_name(child)):
			continue
		total += skeleton.get_bone_global_rest(child).origin
		count += 1
	return PackedVector3Array([start, total / count if count > 0 else start])


## How thick the mesh is around each bone (world metres): the distance from the bone that
## VERTEX_COVERAGE of the vertices it mainly moves fall within, measured in the rest pose.
func _mesh_radii(visual: Node3D) -> Dictionary:
	var distances := {}
	var rest_segments := {}
	for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var skin := mesh_instance.skin
		if mesh_instance.mesh == null or skin == null or mesh_instance.get_node_or_null(mesh_instance.skeleton) != skeleton:
			continue
		var bind_bones := PackedInt32Array()
		for bind in skin.get_bind_count():
			var bone := skin.get_bind_bone(bind)
			bind_bones.append(bone if bone >= 0 else skeleton.find_bone(skin.get_bind_name(bind)))
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: Variant = arrays[Mesh.ARRAY_WEIGHTS]
			var bone_ids: Variant = arrays[Mesh.ARRAY_BONES]
			if weights == null or bone_ids == null or vertices.is_empty():
				continue
			var per_vertex := int(weights.size() / vertices.size())
			for v in vertices.size():
				var best := 0
				for k in per_vertex:
					if weights[v * per_vertex + k] > weights[v * per_vertex + best]:
						best = k
				var bind := int(bone_ids[v * per_vertex + best])
				if bind < 0 or bind >= bind_bones.size() or bind_bones[bind] < 0:
					continue
				var bone := bind_bones[bind]
				if not rest_segments.has(bone):
					rest_segments[bone] = _rest_segment(bone)
					distances[bone] = PackedFloat32Array()
				var rest_vertex := skeleton.get_bone_global_rest(bone) * skin.get_bind_pose(bind) * vertices[v]
				var segment: PackedVector3Array = rest_segments[bone]
				var on_bone := Geometry3D.get_closest_point_to_segment(rest_vertex, segment[0], segment[1])
				var bone_distances: PackedFloat32Array = distances[bone]
				bone_distances.append(rest_vertex.distance_to(on_bone))
				distances[bone] = bone_distances
	var basis_scale := skeleton.global_basis.get_scale().abs()
	var to_world := (basis_scale.x + basis_scale.y + basis_scale.z) / 3.0
	var radii := {}
	for bone: int in distances:
		var sorted: PackedFloat32Array = distances[bone]
		sorted.sort()
		radii[bone] = sorted[int((sorted.size() - 1) * VERTEX_COVERAGE)] * to_world
	return radii


func _body_ancestor(bone: int, by_bone: Dictionary) -> RigidBody3D:
	var parent := skeleton.get_bone_parent(bone)
	while parent >= 0:
		if by_bone.has(parent):
			return by_bone[parent]
		parent = skeleton.get_bone_parent(parent)
	return null


## An unscaled capsule around the bone, its long axis along the bone.
func _capsule_body(bone_name: String, start: Vector3, reach: Vector3, radius: float, push: Vector3) -> RigidBody3D:
	var length := reach.length()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = length + radius * 2.0
	var shape := CollisionShape3D.new()
	shape.shape = capsule
	var body := RigidBody3D.new()
	body.name = ("Bone_" + bone_name).validate_node_name()
	body.add_child(shape)
	# Capsules run along their Y axis; turn Y onto the bone.
	body.transform = Transform3D(_turn(Vector3.UP, reach / length), start + reach * 0.5)
	# Mass from volume, kept within a ratio the joints stay stable at.
	body.mass = clampf(PI * radius * radius * (length + radius * 4.0 / 3.0) * DENSITY, 0.8, 10.0)
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
## Joined bodies never collide with each other.
func _join(parent: RigidBody3D, child: RigidBody3D, at: Vector3, along: Vector3, limits: Array) -> void:
	var joint := ConeTwistJoint3D.new()
	joint.transform = Transform3D(_turn(Vector3.RIGHT, along), at)
	joint.set_param(ConeTwistJoint3D.PARAM_SWING_SPAN, deg_to_rad(float(limits[0])))
	joint.set_param(ConeTwistJoint3D.PARAM_TWIST_SPAN, deg_to_rad(float(limits[1])))
	joint.exclude_nodes_from_collision = true
	add_child(joint)
	joint.node_a = joint.get_path_to(parent)
	joint.node_b = joint.get_path_to(child)
