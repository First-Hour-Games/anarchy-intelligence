@tool
extends CompositorEffect
## Accumulation motion blur by xandwr, CC0:
## https://godotshaders.com/shader/accumulation-motion-blur-compositor-pipeline/
## Local changes: the shader path, a history reset when blur restarts from 0,
## and freeing the pipeline.

## How much of the previous blurred frame to blend in. 0 = off. Keep below 1.
@export_range(0.0, 1.0, 0.001) var alpha: float = 0.0

const SHADER_PATH := "res://shaders/accumulation_blur.glsl"

var rd: RenderingDevice
var shader: RID
var pipeline: RID
var _was_active: bool = false


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	enabled = true
	rd = RenderingServer.get_rendering_device()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and rd:
		if pipeline.is_valid():
			rd.free_rid(pipeline)
		if shader.is_valid():
			rd.free_rid(shader)


func _ensure_shader() -> bool:
	if pipeline.is_valid():
		return true
	if not rd:
		return false
	var shader_file := load(SHADER_PATH) as RDShaderFile
	if not shader_file:
		return false
	shader = rd.shader_create_from_spirv(shader_file.get_spirv())
	if not shader.is_valid():
		return false
	pipeline = rd.compute_pipeline_create(shader)
	return pipeline.is_valid()


func _render_callback(_effect_callback_type: int, render_data: RenderData) -> void:
	if alpha <= 0.0:
		_was_active = false
		return
	if not rd or not _ensure_shader():
		return

	var render_scene_buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if not render_scene_buffers:
		return
	var size := render_scene_buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return

	var usage_bits := (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	)
	render_scene_buffers.create_texture(
		&"accum_blur", &"prev_frame",
		RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
		usage_bits,
		RenderingDevice.TEXTURE_SAMPLES_1,
		size, 1, 1, false, false
	)

	var reset := 0.0 if _was_active else 1.0
	_was_active = true
	var push_constant := PackedFloat32Array([size.x, size.y, alpha, reset])
	var x_groups := ceili(float(size.x) / 8.0)
	var y_groups := ceili(float(size.y) / 8.0)

	for view in range(render_scene_buffers.get_view_count()):
		var color_uniform := RDUniform.new()
		color_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		color_uniform.binding = 0
		color_uniform.add_id(render_scene_buffers.get_color_layer(view))

		var prev_uniform := RDUniform.new()
		prev_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		prev_uniform.binding = 1
		prev_uniform.add_id(render_scene_buffers.get_texture_slice(&"accum_blur", &"prev_frame", view, 0, 1, 1))

		var uniform_set := UniformSetCacheRD.get_cache(shader, 0, [color_uniform, prev_uniform])
		var compute_list := rd.compute_list_begin()
		rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
		rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
		rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
		rd.compute_list_dispatch(compute_list, x_groups, y_groups, 1)
		rd.compute_list_end()
