shader_type spatial;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap;
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;
uniform sampler2D roughness_texture : hint_default_white, filter_linear_mipmap;
uniform sampler2D ao_texture : hint_default_white, filter_linear_mipmap;

uniform float tiling = 4.0;
uniform float randomize_rotation : hint_range(0.0, 1.0) = 1.0;
uniform float normal_scale : hint_range(0.0, 5.0) = 1.0;

float rand(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

vec2 rotate_uv(vec2 uv, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	mat2 rot = mat2(vec2(c, -s), vec2(s, c));
	return rot * (uv - 0.5) + 0.5;
}

vec4 sample_tiled_texture(sampler2D tex, vec2 uv) {
	vec2 st = uv * tiling;
	vec2 grid_id = floor(st);
	vec2 grid_uv = fract(st);
	
	float random_angle = rand(grid_id) * 6.2831853 * randomize_rotation;
	vec2 rotated_uv = rotate_uv(grid_uv, random_angle);
	
	return texture(tex, rotated_uv);
}

void fragment() {
	vec4 albedo_tex = sample_tiled_texture(albedo_texture, UV);
	vec4 normal_tex = sample_tiled_texture(normal_texture, UV);
	vec4 rough_tex = sample_tiled_texture(roughness_texture, UV);
	vec4 ao_tex = sample_tiled_texture(ao_texture, UV);
	
	ALBEDO = albedo_tex.rgb;
	NORMAL_MAP = normal_tex.rgb;
	NORMAL_MAP_DEPTH = normal_scale;
	ROUGHNESS = rough_tex.r;
	AO = ao_tex.r;
}
