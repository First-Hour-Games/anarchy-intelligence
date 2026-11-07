// Adapted from tentabrobpy's Minimal Retroreflective Microfacet (MIT):
// https://godotshaders.com/shader/minimal-retroreflective-microfacet/
// Godot PBR lighting attribution and license: retroreflective_sign.LICENSE.txt
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness : hint_range(0.08, 1.0) = 0.35;
uniform float metallic : hint_range(0.0, 1.0) = 0.65;
uniform float retroreflection : hint_range(0.0, 1.0) = 0.9;
// UV rectangle confines reflective sheeting to the sign face on an atlas.
uniform vec4 reflective_uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
varying float sheeting_mask;

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb * tint.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	vec2 inside_min = step(reflective_uv_rect.xy, UV);
	vec2 inside_max = step(UV, reflective_uv_rect.zw);
	sheeting_mask = inside_min.x * inside_min.y * inside_max.x * inside_max.y;
}

float schlick_fresnel(float u) {
	float m = 1.0 - u;
	return m * m * m * m * m;
}

vec3 microfacet_specular(vec3 n, vec3 l, vec3 v, vec3 f0, float alpha) {
	float nl = max(dot(n, l), 0.0);
	float nv = max(dot(n, v), 0.0001);
	vec3 half_sum = v + l;
	vec3 h = half_sum / max(length(half_sum), 0.0001);
	float nh = clamp(dot(n, h), 0.0, 1.0);
	float lh = clamp(dot(l, h), 0.0, 1.0);
	float denominator = max(1.0 - nh * nh + pow(nh * alpha, 2.0), 0.000001);
	float distribution = pow(alpha / denominator, 2.0) / PI;
	float visibility = 0.5 / max(mix(2.0 * nl * nv, nl + nv, alpha), 0.0001);
	float f90 = clamp(50.0 * f0.g, 0.0, 1.0);
	vec3 fresnel = f0 + (vec3(f90) - f0) * schlick_fresnel(lh);
	return nl * distribution * fresnel * visibility;
}

void light() {
	float nl = max(dot(NORMAL, LIGHT), 0.0);
	float nv = max(dot(NORMAL, VIEW), 0.0001);
	vec3 h_sum = VIEW + LIGHT;
	vec3 h = h_sum / max(length(h_sum), 0.0001);
	float lh = clamp(dot(LIGHT, h), 0.0, 1.0);
	float fd90_minus_one = 2.0 * lh * lh * ROUGHNESS - 0.5;
	float diffuse = (1.0 + fd90_minus_one * schlick_fresnel(nv))
		* (1.0 + fd90_minus_one * schlick_fresnel(nl)) * nl / PI;
	DIFFUSE_LIGHT += LIGHT_COLOR * diffuse * ATTENUATION;
	// MRM reflects the view around the normal before evaluating the GGX lobe.
	vec3 retro_view = -VIEW + 2.0 * dot(VIEW, NORMAL) * NORMAL;
	vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
	float alpha = max(ROUGHNESS * ROUGHNESS, 0.0064);
	vec3 regular = microfacet_specular(NORMAL, LIGHT, VIEW, f0, alpha);
	vec3 retro = microfacet_specular(NORMAL, LIGHT, retro_view, f0, alpha);
	SPECULAR_LIGHT += mix(regular, retro, sheeting_mask * retroreflection)
		* LIGHT_COLOR * ATTENUATION * SPECULAR_AMOUNT;
}
