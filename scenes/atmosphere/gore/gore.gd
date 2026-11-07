class_name Gore
extends RefCounted
## Blood for the alt route's downtown Ridgebacks (scenes/chapters/alt_route/rooftop_street.gd): decals that
## stain whatever lies under them (the road, a car's roof), sprays of drops, chunks that bounce off the road,
## pools that spread under a body and the smear a crawler drags behind it. Everything goes in the node
## passed in, which clears it with clear(). The decals leave out GORE_FREE_LAYER, which the Ridgebacks'
## own meshes are drawn on, so a body never wears the stain it lies in. The textures come from
## tools/make_gore_textures.gd.

const SPLATS: Array[Texture2D] = [
	preload("res://img/textures/gore/blood_splat_1.png"),
	preload("res://img/textures/gore/blood_splat_2.png"),
	preload("res://img/textures/gore/blood_splat_3.png"),
]
const POOL: Texture2D = preload("res://img/textures/gore/blood_pool.png")
const SPATTER: Texture2D = preload("res://img/textures/gore/blood_spatter.png")
const SMEAR: Texture2D = preload("res://img/textures/gore/blood_smear.png")
const BLOOD := Color(0.3, 0.012, 0.01)
const FRESH := Color(0.42, 0.02, 0.014)
## The render layer (11) the Ridgebacks are drawn on.
const GORE_FREE_LAYER := 1 << 10
## Stains past this many go, oldest first.
const MOST_DECALS := 220
const CHUNK_SECONDS := 2.5

static var _materials: Dictionary = {}


## A stain projected straight down onto whatever lies within `depth` of `at`.
static func stain(parent: Node3D, texture: Texture2D, at: Vector3, size: Vector2, yaw: float, colour := BLOOD,
		depth := 1.4) -> Decal:
	var mark := Decal.new()
	mark.texture_albedo = texture
	mark.modulate = colour
	mark.size = Vector3(size.x, depth, size.y)
	mark.normal_fade = 0.35
	mark.upper_fade = 0.15
	mark.lower_fade = 0.3
	mark.cull_mask = 0xFFFFF & ~GORE_FREE_LAYER
	mark.add_to_group(&"gore_decal")
	parent.add_child(mark)
	mark.global_position = at
	mark.rotation.y = yaw
	var marks := parent.get_tree().get_nodes_in_group(&"gore_decal")
	if marks.size() > MOST_DECALS:
		marks[0].queue_free()
	return mark


## A body hitting the ground: a splat as wide as `size`, a spray of drops and a few chunks.
static func splat(parent: Node3D, at: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	stain(parent, SPLATS[rng.randi() % SPLATS.size()], at, Vector2.ONE * size, rng.randf() * TAU, FRESH)
	spray(parent, at + Vector3.UP * 0.2, Vector3.UP, 40, 5.5, 70.0)
	chunks(parent, at + Vector3.UP * 0.3, 6, 4.0, rng)


## A pool spreading out under a body over `seconds`.
static func pool(parent: Node3D, at: Vector3, size: float, seconds: float, rng: RandomNumberGenerator) -> void:
	var mark := stain(parent, POOL, at, Vector2.ONE * size * 0.2, rng.randf() * TAU, BLOOD)
	var spread := mark.create_tween()
	spread.tween_property(mark, "size", Vector3(size, mark.size.y, size), seconds).set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


## A shot landing: drops sprayed back along `direction`, and a spatter on the ground below.
static func wound(parent: Node3D, at: Vector3, direction: Vector3, ground: float, rng: RandomNumberGenerator) -> void:
	spray(parent, at, direction, 18, 3.0, 40.0)
	stain(parent, SPATTER, Vector3(at.x, ground, at.z) + direction * 0.6, Vector2.ONE * 1.4, rng.randf() * TAU,
		FRESH)


## One stretch of a crawler's drag mark, from `from` to `to` on the ground.
static func smear(parent: Node3D, from: Vector3, to: Vector3) -> void:
	var along := to - from
	along.y = 0.0
	if along.length() < 0.05:
		return
	stain(parent, SMEAR, (from + to) * 0.5, Vector2(0.75, along.length() + 0.35), atan2(along.x, along.z), BLOOD, 0.8)


static func spray(parent: Node3D, at: Vector3, direction: Vector3, amount: int, speed: float, spread: float) -> void:
	var drops := CPUParticles3D.new()
	drops.one_shot = true
	drops.explosiveness = 0.92
	drops.amount = amount
	drops.lifetime = 0.9
	drops.direction = direction
	drops.spread = spread
	drops.initial_velocity_min = speed * 0.4
	drops.initial_velocity_max = speed
	drops.gravity = Vector3(0, -14.0, 0)
	drops.scale_amount_min = 0.5
	drops.scale_amount_max = 1.4
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	mesh.material = _meat(FRESH)
	drops.mesh = mesh
	parent.add_child(drops)
	drops.global_position = at
	drops.emitting = true
	drops.finished.connect(drops.queue_free)


## Bits of flesh flung out that bounce and settle on whatever is below, then stop moving.
static func chunks(parent: Node3D, at: Vector3, count: int, speed: float, rng: RandomNumberGenerator) -> void:
	for index in count:
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		chunk.mass = 0.3
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		var edge := rng.randf_range(0.05, 0.1)
		box.size = Vector3(edge, edge * 0.7, edge * 1.2)
		shape.shape = box
		chunk.add_child(shape)
		var look := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box.size
		mesh.material = _meat(BLOOD)
		look.mesh = mesh
		chunk.add_child(look)
		chunk.add_to_group(&"gore_chunk")
		parent.add_child(chunk)
		chunk.global_position = at + Vector3(rng.randf_range(-0.2, 0.2), 0.0, rng.randf_range(-0.2, 0.2))
		chunk.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		chunk.linear_velocity = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.6, 1.3), rng.randf_range(-1.0, 1.0)) \
			.normalized() * speed * rng.randf_range(0.5, 1.0)
		chunk.angular_velocity = Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		parent.get_tree().create_timer(CHUNK_SECONDS).timeout.connect(_settle.bind(chunk))


static func clear(parent: Node) -> void:
	for child in parent.get_children():
		if child.is_in_group(&"gore_decal") or child.is_in_group(&"gore_chunk") or child is CPUParticles3D:
			child.queue_free()


static func _settle(chunk: RigidBody3D) -> void:
	if is_instance_valid(chunk):
		chunk.freeze = true


static func _meat(colour: Color) -> StandardMaterial3D:
	if not _materials.has(colour):
		var material := StandardMaterial3D.new()
		material.albedo_color = colour
		material.roughness = 0.25
		_materials[colour] = material
	return _materials[colour]
