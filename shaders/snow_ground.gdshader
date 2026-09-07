shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap;
uniform sampler2D height_texture : hint_default_white, filter_linear_mipmap;
uniform sampler2D detail_albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;

uniform float tiling = 4.0;
uniform float randomize_rotation : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(0.0, 5.0) = 1.0;
uniform float height_scale : hint_range(0.0, 2.0) = 0.15;
uniform float detail_world_scale : hint_range(0.5, 12.0) = 3.5;
uniform float detail_patch_scale : hint_range(4.0, 50.0) = 18.0;
uniform float detail_strength : hint_range(0.0, 1.0) = 0.32;
uniform vec4 ground_tint : source_color = vec4(1.0);
uniform float ground_saturation : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_vertex_position;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 rotate_uv(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	mat2 rot = mat2(vec2(c, -s), vec2(s, c));
	return rot * (uv - 0.5) + 0.5;
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 blend = fract(p);
	blend = blend * blend * (3.0 - 2.0 * blend);
	float bottom = mix(rand(cell), rand(cell + vec2(1.0, 0.0)), blend.x);
	float top = mix(rand(cell + vec2(0.0, 1.0)), rand(cell + vec2(1.0, 1.0)), blend.x);
	return mix(bottom, top, blend.y);
}

vec4 sample_tiled_texture(sampler2D tex, vec2 uv) {
	vec2 st = uv * tiling;
	// Continuous UVs preserve mip derivatives and avoid cell-edge seams.
	if (randomize_rotation == 0.0) { return texture(tex, st); }
	vec2 grid_id = floor(st);
	vec2 grid_uv = fract(st);
	
	float random_angle = rand(grid_id) * 6.2831853 * randomize_rotation;
	vec2 rotated_uv = rotate_uv(grid_uv, random_angle);
	
	return texture(tex, rotated_uv);
}

vec4 sample_tiled_texture_lod(sampler2D tex, vec2 uv, float lod) {
	vec2 st = uv * tiling;
	if (randomize_rotation == 0.0) { return textureLod(tex, st, lod); }
	vec2 grid_id = floor(st);
	vec2 grid_uv = fract(st);
	
	float random_angle = rand(grid_id) * 6.2831853 * randomize_rotation;
	vec2 rotated_uv = rotate_uv(grid_uv, random_angle);
	
	return textureLod(tex, rotated_uv, lod);
}

void vertex() {
	vec4 height_tex = sample_tiled_texture_lod(height_texture, UV, 0.0);
	VERTEX.y += (height_tex.r - 0.5) * height_scale;
	world_vertex_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 albedo_tex = sample_tiled_texture(albedo_texture, UV);
	vec4 normal_tex = sample_tiled_texture(normal_texture, UV);
	vec4 rough_tex = sample_tiled_texture(roughness_texture, UV);
	vec4 ao_tex = sample_tiled_texture(ao_texture, UV);
	vec3 detail_albedo = texture(
		detail_albedo_texture,
		world_vertex_position.xz / max(detail_world_scale, 0.01)
	).rgb;
	float detail_mask = smoothstep(
		0.42,
		0.78,
		value_noise(world_vertex_position.xz / max(detail_patch_scale, 0.01))
	) * detail_strength;
	
	ALBEDO = mix(albedo_tex.rgb, detail_albedo, detail_mask);
	float luminance = dot(ALBEDO, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = mix(vec3(luminance), ALBEDO, ground_saturation) * ground_tint.rgb;
	NORMAL_MAP = normal_tex.rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = rough_tex.r;
	AO = ao_tex.r;
}
