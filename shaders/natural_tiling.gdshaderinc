// Smoothly blend transformed patches with identical sampling for every PBR map.
uniform float anti_repeat_strength : hint_range(0.0, 1.0) = 0.0;
uniform float anti_repeat_patch_size : hint_range(1.0, 8.0) = 2.0;
uniform float patch_rotation_strength : hint_range(0.0, 1.0) = 0.0;
uniform float patch_scale_min : hint_range(0.1, 2.0) = 1.0;
uniform float patch_scale_max : hint_range(0.1, 2.0) = 1.0;
uniform float regular_tiling_blend : hint_range(0.0, 1.0) = 0.0;

vec2 patch_hash(vec2 cell) {
	return fract(sin(vec2(dot(cell, vec2(127.1, 311.7)),
		dot(cell, vec2(269.5, 183.3)))) * 43758.5453);
}

mat2 patch_rotation(vec2 cell) {
	float angle = patch_hash(cell + vec2(19.3, 71.7)).x * 6.2831853
		* patch_rotation_strength * anti_repeat_strength;
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, s), vec2(-s, c));
}

float patch_scale(vec2 cell) {
	float low = min(patch_scale_min, patch_scale_max);
	float high = max(patch_scale_min, patch_scale_max);
	return mix(1.0, mix(low, high, patch_hash(cell + vec2(53.1, 9.2)).y), anti_repeat_strength);
}

vec2 patch_uv(vec2 uv, vec2 cell, mat2 rotation, float scale) {
	// Rotate around each patch's own center to avoid distant-coordinate distortion.
	vec2 pivot = (cell + vec2(0.5)) * anti_repeat_patch_size;
	return rotation * (uv - pivot) * scale + pivot + patch_hash(cell) * 8.0 * anti_repeat_strength;
}

vec4 correct_patch_normal(vec4 color, mat2 rotation, float scale) {
	vec3 n = color.rgb * 2.0 - 1.0;
	// Inverse rotation brings the sampled tangent normal back into the original basis.
	n.xy = transpose(rotation) * n.xy * scale;
	return vec4(normalize(n) * 0.5 + 0.5, color.a);
}

vec4 sample_patch(sampler2D tex, vec2 uv, vec2 cell, vec2 dx, vec2 dy, bool normal_map) {
	mat2 rotation = patch_rotation(cell);
	float scale = patch_scale(cell);
	vec4 color = textureGrad(tex, patch_uv(uv, cell, rotation, scale),
		rotation * dx * scale, rotation * dy * scale);
	if (normal_map) { color = correct_patch_normal(color, rotation, scale); }
	return color;
}

float regular_patch_mask(vec2 uv) {
	vec2 p = uv / (anti_repeat_patch_size * 3.0);
	vec2 cell = floor(p);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	float a = mix(patch_hash(cell).x, patch_hash(cell + vec2(1.0, 0.0)).x, blend.x);
	float b = mix(patch_hash(cell + vec2(0.0, 1.0)).x,
		patch_hash(cell + vec2(1.0, 1.0)).x, blend.x);
	return mix(a, b, blend.y) * regular_tiling_blend;
}

vec4 natural_sample(sampler2D tex, vec2 uv, bool normal_map) {
	vec2 patch = uv / anti_repeat_patch_size;
	vec2 cell = floor(patch);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(patch));
	vec2 dx = dFdx(uv);
	vec2 dy = dFdy(uv);
	if (anti_repeat_strength <= 0.0) { return textureGrad(tex, uv, dx, dy); }
	vec4 a = sample_patch(tex, uv, cell, dx, dy, normal_map);
	vec4 b = sample_patch(tex, uv, cell + vec2(1.0, 0.0), dx, dy, normal_map);
	vec4 c = sample_patch(tex, uv, cell + vec2(0.0, 1.0), dx, dy, normal_map);
	vec4 d = sample_patch(tex, uv, cell + vec2(1.0, 1.0), dx, dy, normal_map);
	vec4 color = mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
	if (regular_tiling_blend > 0.0) {
		color = mix(color, textureGrad(tex, uv, dx, dy), regular_patch_mask(uv));
	}
	return color;
}

vec4 natural_texture(sampler2D tex, vec2 uv) { return natural_sample(tex, uv, false); }
vec4 natural_normal(sampler2D tex, vec2 uv) { return natural_sample(tex, uv, true); }

vec4 sample_patch_lod(sampler2D tex, vec2 uv, vec2 cell, float lod) {
	mat2 rotation = patch_rotation(cell);
	float scale = patch_scale(cell);
	return textureLod(tex, patch_uv(uv, cell, rotation, scale), max(lod + log2(scale), 0.0));
}

vec4 natural_texture_lod(sampler2D tex, vec2 uv, float lod) {
	if (anti_repeat_strength <= 0.0) { return textureLod(tex, uv, lod); }
	vec2 patch = uv / anti_repeat_patch_size;
	vec2 cell = floor(patch);
	vec2 blend = smoothstep(vec2(0.0), vec2(1.0), fract(patch));
	vec4 a = sample_patch_lod(tex, uv, cell, lod);
	vec4 b = sample_patch_lod(tex, uv, cell + vec2(1.0, 0.0), lod);
	vec4 c = sample_patch_lod(tex, uv, cell + vec2(0.0, 1.0), lod);
	vec4 d = sample_patch_lod(tex, uv, cell + vec2(1.0, 1.0), lod);
	vec4 color = mix(mix(a, b, blend.x), mix(c, d, blend.x), blend.y);
	if (regular_tiling_blend > 0.0) {
		color = mix(color, textureLod(tex, uv, lod), regular_patch_mask(uv));
	}
	return color;
}
