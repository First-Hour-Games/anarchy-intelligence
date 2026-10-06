extends Node
## One-shot flashlight ambush, confined to the starting forest gas station.
@export var rush_speed: float = 6.5
@export var turn_angle_degrees: float = 100.0
@onready var player: FirstPersonPlayer = get_parent().get_node("Player")
@onready var ridge: CorruptedFriend = get_parent().get_node("THE_RIDGEBACK")
@onready var pickup: FlashlightPickup = get_parent().get_node("FlashlightItem/Pickup")
var armed := false
var rushing := false
var finished := false
var pickup_forward := Vector3.ZERO

func _ready() -> void:
	ridge.hide()
	ridge.activation_enabled = false
	ridge.set_physics_process(false)
	ridge.get_node("CollisionShape3D").set_deferred("disabled", true)
	pickup.interacted.connect(_on_flashlight_picked_up)

func _on_flashlight_picked_up(interactor: Node3D) -> void:
	if interactor != player or armed:
		return
	armed = true
	pickup_forward = -player.camera.global_basis.z
	pickup_forward.y = 0.0
	pickup_forward = pickup_forward.normalized()
	get_parent().get_node("FlashlightItem").hide()

func _physics_process(delta: float) -> void:
	if not armed or finished:
		return
	if not rushing:
		var forward := -player.camera.global_basis.z
		forward.y = 0.0
		if forward.normalized().dot(pickup_forward) > cos(deg_to_rad(turn_angle_degrees)):
			return
		# Appear behind the direction the player faced when collecting the light.
		var spawn := player.global_position - pickup_forward * 4.0
		ridge.global_position = spawn
		ridge.velocity = Vector3.ZERO
		ridge.show()
		ridge.get_node("CollisionShape3D").disabled = false
		ridge.visual.play("chase", true)
		rushing = true
	var direction := player.global_position - ridge.global_position
	direction.y = 0.0
	direction = direction.normalized()
	ridge.rotation.y = atan2(-direction.x, -direction.z)
	ridge.velocity = direction * rush_speed
	if not ridge.is_on_floor():
		ridge.velocity.y = -ridge.gravity * delta
	StairStepping.apply(ridge, delta, ridge.max_step_height)
	ridge.move_and_slide()
	ridge.visual.set_movement_speed(rush_speed)
	for index in ridge.get_slide_collision_count():
		if ridge.get_slide_collision(index).get_collider() == player:
			_blackout()
	# Capsule contact can be missed when the player is moving into the creature.
	var separation := player.global_position - ridge.global_position
	if Vector2(separation.x, separation.z).length() <= 0.85 and absf(separation.y) < 1.8:
		_blackout()

func _blackout() -> void:
	if finished:
		return
	finished = true
	ridge.velocity = Vector3.ZERO
	player.freeze()
	var layer := CanvasLayer.new()
	layer.name = "RidgebackBlackout"
	layer.layer = 128
	add_child(layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(black)
