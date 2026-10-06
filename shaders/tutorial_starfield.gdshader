// Adapted from Profesor Shader's shader-tiler (MIT).
// Source and license: third_party/shader-tiler/README.md and LICENSE.
shader_type sky;

uniform sampler2D space_background : source_color, filter_linear, repeat_disable;
uniform sampler2D star_texture : source_color, filter_linear, repeat_disable;
uniform float background_brightness : hint_range(0.0, 4.0, 0.05) = 1.5;
uniform float star_brightness : hint_range(0.0, 4.0, 0.05) = 1.8;
uniform float drift_speed : hint_range(0.0, 2.0, 0.05) = 0.3;
uniform float rotation_speed : hint_range(0.0, 2.0, 0.05) = 0.25;
uniform float twinkle_amount : hint_range(0.0, 1.0, 0.05) = 0.2;
uniform float star_size_min : hint_range(0.01, 0.5, 0.01) = 0.1;
uniform float star_size_max : hint_range(0.01, 0.7, 0.01) = 0.4;
uniform vec2 far_grid = vec2(80.0, 40.0);
uniform vec2 middle_grid = vec2(40.0, 20.0);
uniform vec2 near_grid = vec2(20.0, 10.0);
uniform vec4 lighting_color : source_color = vec4(0.270588, 0.270588, 0.270588, 1.0);

float random_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}

vec4 star_layer(vec2 uv, vec2 grid, float speed, float seed, float time) {
	vec2 grid_uv = uv * grid - vec2(speed * drift_speed * time, 0.0);
	vec2 cell = floor(grid_uv);
	// Wrap the random seed as well as the image, keeping the longitude seam continuous.
	cell.x = mod(cell.x, grid.x);
	cell += vec2(seed);
	float draw_size = mix(star_size_min, min(star_size_max, 0.7071), random_cell(cell));
	float margin = draw_size * 0.7071;
	vec2 center = mix(vec2(margin), vec2(1.0 - margin), vec2(random_cell(cell + 3.0), random_cell(cell + 4.0)));
	vec2 point = (fract(grid_uv) - center) / draw_size;
	float spin = (step(0.5, random_cell(cell + 1.0)) * 2.0 - 1.0) * mix(0.1, 1.0, random_cell(cell + 2.0));
	float angle = time * rotation_speed * spin;
	point = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * point;
	vec2 star_uv = point + vec2(0.5);
	if (star_uv.x < 0.0 || star_uv.x > 1.0 || star_uv.y < 0.0 || star_uv.y > 1.0) {
		return vec4(0.0);
	}
	vec4 star = texture(star_texture, star_uv);
	float twinkle = 1.0 - twinkle_amount * (0.5 + 0.5 * sin(time * mix(0.4, 1.2, random_cell(cell + 6.0)) + random_cell(cell + 7.0) * TAU));
	star.rgb *= star_brightness * twinkle;
	return star;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// A stable neutral radiance keeps moving stars out of the scene's lighting.
		COLOR = lighting_color.rgb;
	} else {
		vec2 uv = SKY_COORDS;
		// Mirror the panorama around the far side rather than exposing mismatched edges.
		vec2 background_uv = vec2(1.0 - abs(uv.x * 2.0 - 1.0), uv.y);
		float polar_fade = smoothstep(0.0, 0.16, sin(uv.y * PI));
		vec3 color = mix(vec3(0.003, 0.005, 0.012), texture(space_background, background_uv).rgb * background_brightness, polar_fade);
		vec4 far_stars = star_layer(uv, far_grid, 0.1, 0.0, TIME);
		vec4 middle_stars = star_layer(uv, middle_grid, 0.2, 19.0, TIME);
		vec4 near_stars = star_layer(uv, near_grid, 0.3, 43.0, TIME);
		color = mix(color, far_stars.rgb, far_stars.a * polar_fade);
		color = mix(color, middle_stars.rgb, middle_stars.a * polar_fade);
		color = mix(color, near_stars.rgb, near_stars.a * polar_fade);
		COLOR = color;
	}
}
