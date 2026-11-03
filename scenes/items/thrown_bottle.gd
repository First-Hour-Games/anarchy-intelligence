class_name ThrownBottle extends RigidBody3D

## A thrown glass bottle. It shatters on its first impact and alerts every
## "story_mob" that can hear the noise radius, drawing hunters to the impact.

const MODEL := preload("res://assets/local_licensed/clinic_medical/Med_12.glb")
const SHATTER_SOUNDS: Array[AudioStream] = [
	preload("res://sounds/props/impacts/impactGlass_heavy_000.ogg"),
	preload("res://sounds/props/impacts/impactGlass_heavy_001.ogg"),
	preload("res://sounds/props/impacts/impactGlass_heavy_002.ogg"),
	preload("res://sounds/props/impacts/impactGlass_heavy_003.ogg"),
	preload("res://sounds/props/impacts/impactGlass_heavy_004.ogg"),
]
const MODEL_HEIGHT := 0.22
const SHARD_LIFETIME := 1.1

signal shattered(point: Vector3)

@export var noise_radius: float = 16.0
@export var max_flight_time: float = 4.0

var has_shattered: bool = false
var _flight_time: float = 0.0
var _visual: Node3D


func _init() -> void:
	name = "ThrownBottle"
	mass = 0.3
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 2
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.04
	capsule.height = MODEL_HEIGHT
	shape.shape = capsule
	add_child(shape)


func _ready() -> void:
	_visual = MODEL.instantiate() as Node3D
	add_child(_visual)
	PropSizing.fit_height(_visual, MODEL_HEIGHT, true)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_flight_time += delta
	if not has_shattered and _flight_time >= max_flight_time:
		shatter()


func _on_body_entered(_body: Node) -> void:
	shatter()


func shatter() -> void:
	if has_shattered:
		return
	has_shattered = true
	var point := global_position
	set_deferred("freeze", true)
	_visual.hide()
	_spawn_shards()
	var audio := AudioStreamPlayer3D.new()
	audio.stream = SHATTER_SOUNDS.pick_random()
	audio.bus = &"Reverb"
	audio.unit_size = 6.0
	audio.pitch_scale = randf_range(0.92, 1.08)
	add_child(audio)
	audio.play()
	# Stay until both the glass sound and the falling shards have finished.
	get_tree().create_timer(maxf(audio.stream.get_length(), SHARD_LIFETIME) + 0.2).timeout.connect(queue_free)
	for mob in get_tree().get_nodes_in_group("story_mob"):
		if mob.has_method(&"hear_noise"):
			mob.hear_noise(point, noise_radius)
	shattered.emit(point)


func _spawn_shards() -> void:
	var shards := CPUParticles3D.new()
	shards.one_shot = true
	shards.amount = 14
	shards.lifetime = SHARD_LIFETIME
	shards.explosiveness = 1.0
	shards.direction = Vector3.UP
	shards.spread = 70.0
	shards.initial_velocity_min = 1.0
	shards.initial_velocity_max = 2.6
	shards.gravity = Vector3(0, -9.8, 0)
	shards.scale_amount_min = 0.5
	shards.scale_amount_max = 1.2
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.025, 0.004, 0.018)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.42, 0.25, 0.85)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	glass.metallic_specular = 1.0
	glass.roughness = 0.1
	mesh.material = glass
	shards.mesh = mesh
	add_child(shards)
	shards.emitting = true
