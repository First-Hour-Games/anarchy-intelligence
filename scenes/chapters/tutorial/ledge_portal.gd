extends Node

## Outside, a matching camera renders the hallway only onto the doorway surface.
## Crossing the opening changes spaces. Crossing the surrounding plane does not.
const INTERIOR_LAYER := 1 << 19

@export var door_path: NodePath = NodePath("../TutorialRooms/BakedMovingWall/WhiteDoor")
@export var camera_path: NodePath = NodePath("../Player/Head/Camera3D")
@export var player_path: NodePath = NodePath("../Player")
@export var ledge_path: NodePath = NodePath("../Ledge")
@export var portal_mask: Texture2D
@export_range(0.0, 1.0, 0.05) var mask_threshold: float = 0.5
@export_range(0.0, 2.0, 0.05) var crossing_height: float = 0.9
@export var interior_paths: Array[NodePath] = [
	NodePath("../TutorialRooms"), NodePath("../Door3"), NodePath("../Lights"),
	NodePath("../CeilingBulb"), NodePath("../CeilingBulb2"),
	NodePath("../HallwayBulbs")
]

var _door: InteractiveDoor
var _camera: Camera3D
var _player: Node3D
var _portal_viewport: SubViewport
var _portal_camera: Camera3D
var _portal_surface: MeshInstance3D
var _door_bounds: AABB
var _last_body_position: Vector3
var _bodies: Dictionary = {}
var _muted_audio: Dictionary = {}
var _interactables: Array[Interactable3D] = []
var _hidden_interactables: Array[Node] = []
var _outside_view := false
var _outside_body := false
var _wall_finished := false
var _initialized := false


func _ready() -> void:
	_door = get_node(door_path) as InteractiveDoor
	_camera = get_node(camera_path) as Camera3D
	_player = get_node(player_path) as Node3D
	_door_bounds = AABB(_door._door_center_local - _door._door_collision.shape.size * 0.5, _door._door_collision.shape.size)
	_last_body_position = _body_position()
	for path in interior_paths:
		_collect_interior(get_node(path))
	_add_ledge_collision()
	_create_portal_view()
	var zone := _door.get_node(_door.get("moving_wall_zone_path")) as MovingWallZone
	zone.wall_move_completed.connect(func(_wall: Node3D, _z: float): _wall_finished = true)
	zone.wall_move_started.connect(func(_wall: Node3D, _z: float, _duration: float): _wall_finished = false)
	_initialized = true


func _collect_interior(node: Node) -> void:
	if node == _door:
		return
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		geometry.layers = INTERIOR_LAYER
	if node is CollisionObject3D:
		_bodies[node] = [node.collision_layer, node.collision_mask]
	if node is Interactable3D:
		_interactables.append(node as Interactable3D)
	for child in node.get_children():
		_collect_interior(child)


func _add_ledge_collision() -> void:
	var ledge := get_node(ledge_path)
	if not ledge.find_children("*", "CollisionShape3D", true, false).is_empty():
		return
	for node in ledge.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh:
			mesh.create_trimesh_collision()


func _create_portal_view() -> void:
	_portal_viewport = SubViewport.new()
	_portal_viewport.name = "HallwayPortalView"
	_portal_viewport.world_3d = _door.get_world_3d()
	_portal_viewport.handle_input_locally = false
	_portal_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_portal_viewport)
	_portal_camera = Camera3D.new()
	_portal_camera.name = "PortalCamera"
	_portal_camera.cull_mask = INTERIOR_LAYER
	_portal_camera.current = true
	var environment := _door.get_world_3d().environment
	if environment:
		_portal_camera.environment = environment.duplicate() as Environment
		# The main viewport applies the tutorial color grade to the portal surface.
		_portal_camera.environment.adjustment_enabled = false
	_portal_viewport.add_child(_portal_camera)
	_portal_surface = MeshInstance3D.new()
	_portal_surface.name = "HallwayPortalSurface"
	var quad := QuadMesh.new()
	quad.size = Vector2(_door_bounds.size.x, _door_bounds.size.y)
	_portal_surface.mesh = quad
	_portal_surface.position = _door_bounds.get_center()
	_portal_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/doorway_portal.gdshader")
	material.set_shader_parameter("portal_view", _portal_viewport.get_texture())
	if portal_mask:
		material.set_shader_parameter("mask", portal_mask)
	material.set_shader_parameter("mask_threshold", mask_threshold)
	_portal_surface.material_override = material
	_portal_surface.visible = false
	_door.add_child(_portal_surface)
	_resize_portal_view()
	get_viewport().size_changed.connect(_resize_portal_view)


func _resize_portal_view() -> void:
	_portal_viewport.size = Vector2i(get_viewport().get_visible_rect().size).max(Vector2i.ONE)


func _sync_portal_camera() -> void:
	if _portal_camera.environment and _door.get_world_3d().environment:
		_portal_camera.environment.background_energy_multiplier = _door.get_world_3d().environment.background_energy_multiplier
	_portal_camera.global_transform = _camera.global_transform
	_portal_camera.projection = _camera.projection
	_portal_camera.fov = _camera.fov
	_portal_camera.size = _camera.size
	_portal_camera.frustum_offset = _camera.frustum_offset
	_portal_camera.near = _camera.near
	_portal_camera.far = _camera.far
	_portal_camera.keep_aspect = _camera.keep_aspect
	_portal_camera.h_offset = _camera.h_offset
	_portal_camera.v_offset = _camera.v_offset


func _process(_delta: float) -> void:
	if not _initialized:
		return
	var active := _wall_finished and (_door.is_open or _door._is_animating)
	var body_position := _body_position()
	if not active:
		if _outside_body:
			_set_outside_body(false)
			_set_outside_view(false)
	elif _crossed_opening(_last_body_position, body_position):
		_set_outside_body(not _outside_body)
		_set_outside_view(_outside_body)
	_last_body_position = body_position
	# Walking around the frame keeps the player outside, even behind the plane.
	var camera_on_front := _door.to_local(_camera.global_position).z > _door._door_center_local.z + 0.01
	_portal_surface.visible = _outside_view and camera_on_front
	_portal_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _portal_surface.visible else SubViewport.UPDATE_DISABLED
	if _portal_surface.visible:
		_sync_portal_camera()


func _body_position() -> Vector3:
	return _player.global_position + Vector3.UP * crossing_height


func _crossed_opening(previous: Vector3, current: Vector3) -> bool:
	var start := _door.to_local(previous)
	var end := _door.to_local(current)
	var plane_z := _door._door_center_local.z
	var from_side := start.z - plane_z
	var to_side := end.z - plane_z
	if _outside_body:
		if not (from_side > 0.0 and to_side <= 0.0):
			return false
	elif not (from_side <= 0.0 and to_side > 0.0):
		return false
	var crossing := start.lerp(end, -from_side / (to_side - from_side))
	return crossing.x > _door_bounds.position.x and crossing.x < _door_bounds.end.x \
		and crossing.y > _door_bounds.position.y and crossing.y < _door_bounds.end.y


func _set_outside_view(outside: bool) -> void:
	_outside_view = outside
	_camera.set_cull_mask_value(20, not outside)
	# Keep the scene's lighting and shadow casting unchanged on both sides.


func _set_outside_body(outside: bool) -> void:
	_outside_body = outside
	# The hallway extends over part of the ledge. Its invisible walls must not block it.
	# Keep the white door's own hinge/collision, and the separate ledge, active.
	for body in _bodies:
		var original: Array = _bodies[body]
		body.collision_layer = 0 if outside else original[0]
		body.collision_mask = 0 if outside else original[1]
	if outside:
		for path in interior_paths:
			var interior := get_node(path)
			for audio in interior.find_children("*", "AudioStreamPlayer3D", true, false):
				if _door.is_ancestor_of(audio):
					continue
				_muted_audio[audio] = audio.volume_db
				audio.volume_db = -80.0
		for interactable in _interactables:
			if interactable.is_in_group(&"interactable"):
				_hidden_interactables.append(interactable)
				interactable.remove_from_group(&"interactable")
	else:
		for audio in _muted_audio:
			if is_instance_valid(audio):
				audio.volume_db = _muted_audio[audio]
		_muted_audio.clear()
		for interactable in _hidden_interactables:
			if is_instance_valid(interactable):
				interactable.add_to_group(&"interactable")
		_hidden_interactables.clear()
