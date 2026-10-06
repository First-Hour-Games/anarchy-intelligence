extends Node3D

enum Shape { HAT_MAN, DOG }
@export var shape: Shape = Shape.HAT_MAN
const VIEW_LAYER: int = 1 << 19
const HAT_MAN_HEIGHT: float = 2.40
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

func configure_partial_cover(minimum_y: float, maximum_y: float) -> void:
	_material.set_shader_parameter("partial_cover", true)
	_material.set_shader_parameter("conceal_height_range", Vector2(minimum_y, maximum_y))

func set_reveal_origin(origin: Vector3) -> void:
	_material.set_shader_parameter("reveal_origin", origin)

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
	# Reference silhouette: squared shoulders, a long coat, hanging sleeves,
	# a featureless face, and a low, flat brim beneath a straight hat crown.
	var rings: Array[Vector3] = [Vector3(0.39, 0.42, 0.17), Vector3(0.40, 0.62, 0.18), Vector3(0.31, 1.18, 0.19), Vector3(0.33, 1.56, 0.20), Vector3(0.34, 1.78, 0.18), Vector3(0.26, 1.86, 0.16), Vector3(0.14, 1.91, 0.12)]
	var outline: Array[Vector2] = [Vector2(-1, -0.6), Vector2(-0.65, -1), Vector2(0.65, -1), Vector2(1, -0.6), Vector2(1, 0.6), Vector2(0.65, 1), Vector2(-0.65, 1), Vector2(-1, 0.6)]
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring: Vector3 in rings:
		for point: Vector2 in outline:
			vertices.append(Vector3(point.x * ring.x, ring.y, point.y * ring.z))
	for ring_index in rings.size() - 1:
		for side in outline.size():
			var lower := ring_index * outline.size() + side
			var next := ring_index * outline.size() + (side + 1) % outline.size()
			var upper := lower + outline.size()
			var upper_next := next + outline.size()
			indices.append_array(PackedInt32Array([lower, upper_next, next, lower, upper, upper_next]))
	for side in range(1, outline.size() - 1):
		indices.append_array(PackedInt32Array([0, side, side + 1]))
		var top := (rings.size() - 1) * outline.size()
		indices.append_array(PackedInt32Array([top, top + side + 1, top + side]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var coat := ArrayMesh.new()
	coat.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_part(coat, Vector3.ZERO)
	_taper(Vector3(0, 1.875, 0), 0.15, 0.10, 0.10)
	_oval(Vector3(0, 1.99, 0), Vector3(0.26, 0.37, 0.255))
	_taper(Vector3(0, 2.175, 0), 0.025, 0.39, 0.39)
	_taper(Vector3(0, 2.29, 0), 0.22, 0.17, 0.155)
	for side: float in [-1.0, 1.0]:
		_taper(Vector3(side * 0.32, 1.30, 0.005), 1.06, 0.08, 0.12, Vector3(0, 0, side * 0.12))
		_oval(Vector3(side * 0.385, 0.72, 0.025), Vector3(0.13, 0.20, 0.14))
		_taper(Vector3(side * 0.14, 0.25, 0), 0.50, 0.075, 0.085)
		_oval(Vector3(side * 0.14, 0.045, -0.06), Vector3(0.18, 0.09, 0.28))

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
