@tool
extends Node3D
## Render the same sky material and environment used by the tutorial into the gem.

const TUTORIAL_ENVIRONMENT: Environment = preload("res://shaders/tutorial_sky_environment.tres")
const PORTAL_MATERIAL: ShaderMaterial = preload("res://shaders/save_gem_portal_material.tres")

var _sky_view: SubViewport
var _sky_camera: Camera3D
var _material: ShaderMaterial

func _ready() -> void:
	_sky_view = SubViewport.new()
	_sky_view.name = "TutorialSkyView"
	_sky_view.own_world_3d = true
	_sky_view.handle_input_locally = false
	_sky_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_sky_view)
	_sky_camera = Camera3D.new()
	_sky_camera.current = true
	_sky_camera.cull_mask = 0
	_sky_camera.environment = TUTORIAL_ENVIRONMENT.duplicate() as Environment
	# Match the tutorial controller's runtime sky energy.
	_sky_camera.environment.background_energy_multiplier = 0.6
	_sky_view.add_child(_sky_camera)
	_material = PORTAL_MATERIAL.duplicate() as ShaderMaterial
	_material.set_shader_parameter("portal_view", _sky_view.get_texture())
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		(mesh_node as MeshInstance3D).material_override = _material
	_sync_view()

func _process(_delta: float) -> void:
	_sync_view()

func _sync_view() -> void:
	if not is_instance_valid(_sky_view):
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null or not is_visible_in_tree() or camera.global_position.distance_to(global_position) > 40.0 \
			or camera.is_position_behind(global_position):
		_sky_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	_sky_view.size = Vector2i(get_viewport().get_visible_rect().size).max(Vector2i.ONE)
	_sky_camera.global_basis = camera.global_basis.orthonormalized()
	_sky_camera.projection = camera.projection
	_sky_camera.fov = camera.fov
	_sky_camera.size = camera.size
	_sky_camera.frustum_offset = camera.frustum_offset
	_sky_camera.keep_aspect = camera.keep_aspect
	_sky_camera.h_offset = camera.h_offset
	_sky_camera.v_offset = camera.v_offset
	_sky_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
