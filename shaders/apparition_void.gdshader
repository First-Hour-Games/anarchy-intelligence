shader_type spatial;
render_mode unshaded, fog_disabled;

uniform bool concealed_peek = false;
uniform vec3 conceal_view_origin = vec3(0.0);
uniform vec3 conceal_forward = vec3(0.0, 0.0, 1.0);
uniform vec3 conceal_direction = vec3(1.0, 0.0, 0.0);
uniform vec3 conceal_edges[4];
uniform float reveal_amount = 1.0;
uniform vec2 conceal_height_range = vec2(-100000.0, 100000.0);
uniform bool partial_cover = false;
uniform vec3 reveal_origin = vec3(0.0);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (concealed_peek) {
		if (reveal_amount <= 0.001) {
			discard;
		}
		// A peek can never reveal the inward half, including during camera motion.
		if (dot(world_position - reveal_origin, conceal_direction) < 0.0) {
			discard;
		}
		// Broad, flat cover also uses a gradual lateral reveal.
		if (partial_cover && dot(world_position - reveal_origin, conceal_direction) < mix(0.5, -0.5, reveal_amount)) {
			discard;
		}
		vec3 trunk_edge = conceal_edges[0];
		for (int i = 0; i < 3; i++) {
			float height = clamp((world_position.y - conceal_edges[i].y) / max(conceal_edges[i + 1].y - conceal_edges[i].y, 0.001), 0.0, 1.0);
			if (world_position.y >= conceal_edges[i].y) {
				trunk_edge = mix(conceal_edges[i], conceal_edges[i + 1], height);
			}
		}
		vec3 offset = world_position - conceal_view_origin;
		vec3 boundary = trunk_edge - conceal_view_origin;
		float edge = dot(offset, conceal_direction) / max(dot(offset, conceal_forward), 0.001);
		float bark_edge = dot(boundary, conceal_direction) / max(dot(boundary, conceal_forward), 0.001);
		if (world_position.y >= conceal_height_range.x && world_position.y <= conceal_height_range.y && edge <= bark_edge) {
			discard;
		}
	}
	ALBEDO = vec3(0.0);
}
