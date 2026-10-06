shader_type spatial;

#include "res://shaders/natural_tiling.gdshaderinc"

uniform sampler2D albedo_texture : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_texture : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D roughness_texture : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D ao_texture : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D height_texture : hint_default_white, repeat_enable, filter_linear_mipmap_anisotropic;
uniform float texture_scale : hint_range(0.01, 4.0) = 0.385;
uniform float normal_strength : hint_range(0.0, 2.0) = 1.0;
uniform float height_scale : hint_range(0.0, 0.1) = 0.02;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 geometric_normal = normalize(world_normal);
	vec3 weights = pow(abs(geometric_normal), vec3(4.0));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);
	vec3 facing = step(vec3(0.0), geometric_normal) * 2.0 - 1.0;
	vec3 position = world_position * texture_scale;
	vec3 view_direction = normalize(CAMERA_POSITION_WORLD - world_position);
	vec3 color = vec3(0.0);
	vec3 mapped_normal = vec3(0.0);
	float roughness = 0.0;
	float occlusion = 0.0;
	// Project onto each face, including the thin road edges. Flat tops use one axis.
	for (int axis = 0; axis < 3; axis++) {
		float weight = weights[axis];
		if (weight > 0.0001) {
			vec2 uv;
			vec2 projected_view;
			if (axis == 0) {
				uv = vec2(position.z * facing.x, position.y);
				projected_view = vec2(view_direction.z * facing.x, view_direction.y);
			} else if (axis == 1) {
				uv = vec2(position.x, -position.z * facing.y);
				projected_view = vec2(view_direction.x, -view_direction.z * facing.y);
			} else {
				uv = vec2(-position.x * facing.z, position.y);
				projected_view = vec2(-view_direction.x * facing.z, view_direction.y);
			}
			float height = natural_texture(height_texture, uv).r - 0.5;
			uv -= projected_view / max(abs(view_direction[axis]), 0.25) * height * height_scale;
			color += natural_texture(albedo_texture, uv).rgb * weight;
			roughness += natural_texture(roughness_texture, uv).r * weight;
			occlusion += natural_texture(ao_texture, uv).r * weight;
			vec3 n = natural_normal(normal_texture, uv).rgb * 2.0 - 1.0;
			n.xy *= normal_strength;
			n = normalize(n);
			if (axis == 0) {
				mapped_normal += vec3(n.z * facing.x, n.y, n.x * facing.x) * weight;
			} else if (axis == 1) {
				mapped_normal += vec3(n.x, n.z * facing.y, -n.y * facing.y) * weight;
			} else {
				mapped_normal += vec3(-n.x * facing.z, n.y, n.z * facing.z) * weight;
			}
		}
	}
	ALBEDO = color;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mapped_normal), 0.0)).xyz);
	ROUGHNESS = roughness;
	AO = occlusion;
}
