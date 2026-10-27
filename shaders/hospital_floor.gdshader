shader_type spatial;
// Hospital sheet vinyl laid in 0.6 m world-space tiles with fine seams, tinted per room
// (story_building.gd passes each floor material's colour as the tint).
uniform vec3 tint : source_color = vec3(0.5, 0.57, 0.49);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz / 0.6;
	vec2 edge = min(fract(p), 1.0 - fract(p));
	float seam = 1.0 - smoothstep(0.006, 0.018, min(edge.x, edge.y));
	float alternate = mod(floor(p.x) + floor(p.y), 2.0);
	ALBEDO = mix(tint * mix(1.0, 0.9, alternate), tint * 0.62, seam);
	ROUGHNESS = 0.85;
}
