shader_type spatial;
// World-scale masonry: consistent brick size across separately built wall bays.
uniform vec4 brick_color : source_color = vec4(0.30, 0.15, 0.105, 1.0);
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = abs(world_normal.x) > abs(world_normal.z) ? world_position.zy : world_position.xy;
	float row = floor(p.y / 0.085);
	p.x += mod(row, 2.0) * 0.12;
	vec2 cell = p / vec2(0.24, 0.085);
	vec2 edge = fract(cell);
	vec2 distance_to_edge = min(edge, vec2(1.0) - edge) * vec2(0.24, 0.085);
	float pixel_width = max(fwidth(p.x), fwidth(p.y));
	float mortar = 1.0 - smoothstep(0.002, 0.002 + pixel_width, min(distance_to_edge.x, distance_to_edge.y));
	mortar *= 1.0 - smoothstep(0.008, 0.04, pixel_width);
	float variation = fract(sin(dot(floor(cell), vec2(12.9898, 78.233))) * 43758.5453);
	float grain = fract(sin(dot(world_position, vec3(317.1, 127.7, 91.3))) * 43758.5453);
	vec3 brick = brick_color.rgb * (0.78 + variation * 0.4 + grain * 0.06);
	ALBEDO = mix(brick, vec3(0.19, 0.175, 0.15), mortar);
	ROUGHNESS = 0.95;
}
