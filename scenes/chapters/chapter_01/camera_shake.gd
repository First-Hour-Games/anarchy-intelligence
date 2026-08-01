extends Camera3D

@onready var noise: FastNoiseLite = FastNoiseLite.new()

@export var decay: float = 0.2
@export var amplitude: float = 1.2
@export var max_offset: Vector2 = Vector2(0.1, 0.1)
@export var max_roll: float = 0.04

var trauma: float = 0.0
var trauma_power: float = 2.0
var noise_speed: float = 15.0
var _noise_y: float = 0.0
var seed_offset: float = 0.0

@onready var initial_rotation: Vector3 = rotation

func _ready() -> void:
	randomize()
	seed_offset = float(randi() % 10000)
	noise.seed = int(seed_offset)
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.5
	initial_rotation = rotation

func _physics_process(delta: float) -> void:
	_noise_y += noise_speed * delta
	if trauma > 0.0:
		trauma = max(trauma - decay * delta, 0.0)
		_shake()
	else:
		_idle_sway()

func add_trauma(amount: float) -> void:
	trauma = min(trauma + amount, 1.0)

func _shake() -> void:
	var amount: float = pow(trauma, trauma_power)
	var nx1: float = noise.get_noise_2d(seed_offset + 10.0, _noise_y)
	var nx2: float = noise.get_noise_2d(seed_offset + 20.0, _noise_y)
	var nx3: float = noise.get_noise_2d(seed_offset + 30.0, _noise_y)
	var nx4: float = noise.get_noise_2d(seed_offset + 40.0, _noise_y)
	var nx5: float = noise.get_noise_2d(seed_offset + 50.0, _noise_y)

	var rot_x: float = initial_rotation.x + max_roll * amount * nx1
	var rot_y: float = initial_rotation.y + max_roll * amount * nx2
	var rot_z: float = initial_rotation.z + max_roll * amount * nx3

	if is_finite(rot_x) and is_finite(rot_y) and is_finite(rot_z):
		quaternion = Quaternion.from_euler(Vector3(rot_x, rot_y, rot_z))
	if is_finite(nx4):
		h_offset = max_offset.x * amount * nx4
	if is_finite(nx5):
		v_offset = max_offset.y * amount * nx5

func _idle_sway() -> void:
	var sway_amount: float = 0.15 * amplitude
	var ny: float = _noise_y * 0.3
	var nx1: float = noise.get_noise_2d(seed_offset + 10.0, ny)
	var nx2: float = noise.get_noise_2d(seed_offset + 20.0, ny)
	var nx3: float = noise.get_noise_2d(seed_offset + 30.0, ny)
	var nx4: float = noise.get_noise_2d(seed_offset + 40.0, ny)
	var nx5: float = noise.get_noise_2d(seed_offset + 50.0, ny)

	var rot_x: float = initial_rotation.x + max_roll * sway_amount * nx1
	var rot_y: float = initial_rotation.y + max_roll * sway_amount * nx2
	var rot_z: float = initial_rotation.z + max_roll * sway_amount * nx3

	if is_finite(rot_x) and is_finite(rot_y) and is_finite(rot_z):
		quaternion = Quaternion.from_euler(Vector3(rot_x, rot_y, rot_z))
	if is_finite(nx4):
		h_offset = max_offset.x * sway_amount * nx4
	if is_finite(nx5):
		v_offset = max_offset.y * sway_amount * nx5

func _input(event: InputEvent) -> void:
	if InputMap.has_action("shake") and event.is_action_pressed("shake"):
		add_trauma(0.6)
