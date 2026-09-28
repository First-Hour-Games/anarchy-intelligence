shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest, repeat_disable;
uniform vec4 frame_rect = vec4(0.0, 0.0, 0.125, 0.111111);
uniform float eye_energy = 0.0;
void fragment() {
	vec4 color = texture(atlas, frame_rect.xy + UV * frame_rect.zw);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = 0.08;
	ALBEDO = color.rgb;
	ROUGHNESS = 1.0;
	float red_dominance = color.r - max(color.g, color.b);
	float implant = smoothstep(0.45, 0.8, color.r) * smoothstep(0.18, 0.45, red_dominance);
	EMISSION = vec3(1.0, 0.03, 0.01) * implant * eye_energy;
}
