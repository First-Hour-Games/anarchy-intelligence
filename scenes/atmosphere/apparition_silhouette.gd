extends Node3D

enum Shape { HAT_MAN, DOG }
@export var shape: Shape = Shape.HAT_MAN
const VIEW_LAYER: int = 1 << 19
const VOID_SHADER: Shader = preload("res://shaders/apparition_void.gdshader")
var _material: ShaderMaterial

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = VOID_SHADER
	if shape == Shape.HAT_MAN:
		_build_hat_man()
	else:
		_build_dog()

func _part(mesh: Mesh, at: Vector3, stretch: Vector3 = Vector3.ONE, tilt: Vector3 = Vector3.ZERO) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = _material
	visual.position = at
	visual.scale = stretch
	visual.rotation = tilt
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.layers = VIEW_LAYER
	add_child(visual)

func configure_peek(view_origin: Vector3, forward: Vector3, direction: Vector3, edges: PackedVector3Array) -> void:
	_material.set_shader_parameter("concealed_peek", true)
	update_peek_occlusion(view_origin, forward, direction, edges)
	set_reveal_amount(0.0)

func update_peek_occlusion(view_origin: Vector3, forward: Vector3, direction: Vector3, edges: PackedVector3Array) -> void:
	_material.set_shader_parameter("conceal_view_origin", view_origin)
	_material.set_shader_parameter("conceal_forward", forward)
	_material.set_shader_parameter("conceal_direction", direction)
	_material.set_shader_parameter("conceal_edges", edges)

func set_reveal_amount(amount: float) -> void:
	_material.set_shader_parameter("reveal_amount", amount)

func _oval(at: Vector3, dimensions: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	_part(mesh, at, dimensions)

func _taper(at: Vector3, height: float, bottom: float, top: float, tilt: Vector3 = Vector3.ZERO) -> void:
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.radial_segments = 12
	_part(mesh, at, Vector3.ONE, tilt)

func _build_hat_man() -> void:
	_taper(Vector3(0, 1.22, 0), 1.15, 0.34, 0.23)
	_oval(Vector3(0, 1.71, 0), Vector3(0.57, 0.29, 0.31))
	_oval(Vector3(0, 1.97, 0), Vector3(0.29, 0.38, 0.29))
	_taper(Vector3(0, 2.15, 0), 0.045, 0.35, 0.35)
	_taper(Vector3(0, 2.27, 0), 0.22, 0.19, 0.16)
	for side: float in [-1.0, 1.0]:
		_taper(Vector3(side * 0.30, 1.24, 0), 0.9, 0.07, 0.105, Vector3(0, 0, side * 0.08))
		_taper(Vector3(side * 0.14, 0.37, 0), 0.74, 0.07, 0.095)
		_oval(Vector3(side * 0.14, 0.055, 0.06), Vector3(0.17, 0.11, 0.30))

func _build_dog() -> void:
	_oval(Vector3(0, 0.68, 0), Vector3(1.13, 0.53, 0.38))
	_oval(Vector3(-0.47, 0.86, 0), Vector3(0.39, 0.62, 0.34))
	_oval(Vector3(-0.66, 1.10, 0), Vector3(0.38, 0.35, 0.29))
	_oval(Vector3(-0.90, 1.03, 0), Vector3(0.36, 0.17, 0.20))
	for side: float in [-1.0, 1.0]:
		_taper(Vector3(-0.59, 1.33, side * 0.105), 0.29, 0.09, 0.0, Vector3(0, 0, -0.15))
		for x: float in [-0.39, 0.38]:
			_taper(Vector3(x, 0.31, side * 0.13), 0.56, 0.045, 0.075, Vector3(0, 0, -0.06))
			_oval(Vector3(x - 0.045, 0.055, side * 0.13), Vector3(0.19, 0.11, 0.12))
	_taper(Vector3(0.69, 0.66, 0), 0.68, 0.025, 0.09, Vector3(0, 0, 0.80))
