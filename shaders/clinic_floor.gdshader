shader_type spatial;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_position.xz / 0.6;
	vec2 edge = min(fract(p), 1.0 - fract(p));
	float line = 1.0 - smoothstep(0.006, 0.018, min(edge.x, edge.y));
	float alternate = mod(floor(p.x) + floor(p.y), 2.0);
	ALBEDO = mix(mix(vec3(0.43, 0.46, 0.40), vec3(0.36, 0.40, 0.35), alternate), vec3(0.25, 0.27, 0.23), line);
	ROUGHNESS = 0.88;
}
