shader_type spatial;

render_mode cull_disabled, unshaded, depth_test_disabled, depth_draw_never;

uniform sampler2D depth_texture : source_color, hint_depth_texture;
uniform sampler2D screen_texture : source_color, hint_screen_texture, repeat_disable, filter_nearest;

uniform bool enable_fog = true; 
uniform vec3 fog_color : source_color = vec3(0.35, 0.38, 0.40);
uniform vec3 noise_color : source_color = vec3(0.24, 0.26, 0.28);
uniform float fog_distance : hint_range(1.0, 6000.0) = 60.0;
uniform float fog_fade_range : hint_range(1.0, 6000.0) = 40.0;

uniform bool affect_sky = false;
uniform float sky_horizon_blend : hint_range(0.0, 1.0) = 0.05;
uniform bool apply_effects_to_sky = false;

uniform bool enable_noise = true;
uniform float noise_time_fac : hint_range(0.1, 10.0) = 4.0;
uniform bool enable_color_limitation = true;
uniform int color_levels : hint_range(2, 256) = 32;
uniform bool enable_dithering = true;
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3; 

float hashOld12(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453 + (sin((TIME)) / noise_time_fac));
}

vec3 color_mix(vec3 a, vec3 b, float f) {
	f = clamp(abs(f), 0.0, 1.0);
	float invf = 1.0 - f;
	return (a * f) + (b * invf);
}

vec3 linear_to_srgb(vec3 color) {
	return mix(
		color * 12.92,
		pow(max(color, vec3(0.0)), vec3(1.0 / 2.4)) * 1.055 - vec3(0.055),
		step(vec3(0.0031308), color)
	);
}

vec3 srgb_to_linear(vec3 color) {
	return mix(
		color / 12.92,
		pow(max(color + vec3(0.055), vec3(0.0)) / 1.055, vec3(2.4)),
		step(vec3(0.04045), color)
	);
}

vec3 quantize_color(vec3 color, int levels) {
	if (levels <= 1) return color;
	vec3 srgb = linear_to_srgb(color);
	float quantizer = float(levels - 1);
	srgb = floor(srgb * quantizer + 0.5) / quantizer;
	return srgb_to_linear(srgb);
}

float dither(vec2 position, float brightness) {
	int x = int(mod(position.x, 4.0));
	int y = int(mod(position.y, 4.0));
	int index = x + y * 4;
	float dithering[16] = float[](
		0.0, 0.5, 0.125, 0.625,
		0.75, 0.25, 0.875, 0.375,
		0.1875, 0.6875, 0.0625, 0.5625,
		0.9375, 0.4375, 1.0, 0.8125
	);
	float threshold = dithering[index];
	return brightness < threshold ? 0.0 : 1.0;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec3 screen_color = texture(screen_texture, SCREEN_UV).rgb;
	vec2 screen_coords = SCREEN_UV * 2.0 - 1.0;
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec3 ndc = vec3(screen_coords, depth);
	
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	
	float linear_depth = -view.z;
	
	bool is_sky = depth <= 0.00001 || depth >= 0.99999 || linear_depth >= 1500.0;
	float depth_mask_inv = 0.0;
	
	if (is_sky) {
		if (affect_sky) {
			depth_mask_inv = 1.0;
		} else if (sky_horizon_blend > 0.0) {
			vec3 world_dir = normalize((INV_VIEW_MATRIX * vec4(view.xyz, 0.0)).xyz);
			depth_mask_inv = clamp(1.0 - (max(world_dir.y, 0.0) / sky_horizon_blend), 0.0, 1.0);
		} else {
			depth_mask_inv = 0.0;
		}
	} else {
		depth_mask_inv = clamp((linear_depth - (fog_distance - fog_fade_range)) / fog_fade_range, 0.0, 1.0);
	}
	
	vec3 final_color = screen_color;
	
	vec3 fog_base = fog_color;
	if (enable_noise) {
		fog_base = color_mix(fog_color, noise_color, hashOld12(screen_coords));
	}
	
	if (enable_fog || enable_noise) {
		final_color = color_mix(fog_base, final_color, depth_mask_inv);
	}
	
	bool apply_post = !is_sky || apply_effects_to_sky || depth_mask_inv > 0.01;
	
	if (apply_post) {
		if (enable_color_limitation) {
			vec3 srgb = linear_to_srgb(final_color);
			if (enable_dithering) {
				float d = (dither(FRAGCOORD.xy, dot(srgb, vec3(0.299, 0.587, 0.114))) - 0.5) * (dither_strength / max(float(color_levels - 1), 1.0));
				srgb = clamp(srgb + vec3(d), 0.0, 1.0);
			}
			float quantizer = float(max(color_levels - 1, 1));
			srgb = floor(srgb * quantizer + 0.5) / quantizer;
			final_color = srgb_to_linear(srgb);
		} else if (enable_dithering) {
			vec3 srgb = linear_to_srgb(final_color);
			float d = (dither(FRAGCOORD.xy, dot(srgb, vec3(0.299, 0.587, 0.114))) - 0.5) * (dither_strength * 0.08);
			srgb = clamp(srgb + vec3(d), 0.0, 1.0);
			final_color = srgb_to_linear(srgb);
		}
	}
	
	ALBEDO = final_color;
}
