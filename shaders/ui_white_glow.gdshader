shader_type canvas_item;

uniform float glow_strength : hint_range(0.0, 2.0) = 0.85;
uniform float glow_radius : hint_range(0.5, 4.0) = 2.0;

void fragment() {
	vec2 step_size = TEXTURE_PIXEL_SIZE * glow_radius;
	float center_alpha = texture(TEXTURE, UV).a;
	float surrounding_alpha = 0.0;
	surrounding_alpha += texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a;
	surrounding_alpha += texture(TEXTURE, UV + vec2(-step_size.x, 0.0)).a;
	surrounding_alpha += texture(TEXTURE, UV + vec2(0.0, step_size.y)).a;
	surrounding_alpha += texture(TEXTURE, UV + vec2(0.0, -step_size.y)).a;
	surrounding_alpha += texture(TEXTURE, UV + step_size).a;
	surrounding_alpha += texture(TEXTURE, UV - step_size).a;
	surrounding_alpha += texture(TEXTURE, UV + vec2(step_size.x, -step_size.y)).a;
	surrounding_alpha += texture(TEXTURE, UV + vec2(-step_size.x, step_size.y)).a;
	surrounding_alpha /= 8.0;

	float glow_alpha = max(center_alpha * 0.7, surrounding_alpha) * glow_strength;
	COLOR = vec4(1.0, 1.0, 1.0, glow_alpha);
}
