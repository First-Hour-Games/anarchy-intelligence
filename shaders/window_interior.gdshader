shader_type spatial;
render_mode cull_back, specular_schlick_ggx;

// Downtown window panes with a room behind the glass (interior mapping): the room is a box
// room_depth deep behind the pane, drawn from one picture per room. Its back wall is the picture;
// its side walls, floor and ceiling repeat the picture's edge columns and rows, so they carry on
// its wallpaper, floor and ceiling. Curtains, blinds and boards hang on the glass, and the sash
// bars are drawn here.
//
// UV runs 0-1 across each pane from its top left. UV2 carries the pane's codes, set by
// tools/blender/build_downtown.py (glass_codes): x is the room (+16 when lit), y is the overlay
// plus 16 times the frame style (0 two sashes, 1 one pane, 2 four panes, 3 none).

uniform sampler2D rooms : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D overlays : source_color, filter_linear_mipmap, repeat_disable;
uniform float grid = 4.0;
uniform float room_depth = 3.2;
// How much of an unlit room the street's light lets through, and how bright a lit one is.
uniform float dark_room = 0.16;
uniform float lit_room = 1.5;
uniform vec3 glass_colour : source_color = vec3(0.04, 0.05, 0.055);
uniform vec3 frame_colour : source_color = vec3(0.08, 0.085, 0.09);
uniform float frame_width = 0.055;

vec2 cell(float index, vec2 uv) {
	vec2 corner = vec2(mod(index, grid), floor(index / grid));
	return (corner + clamp(uv, vec2(0.004), vec2(0.996))) / grid;
}

void fragment() {
	float room_code = floor(UV2.x + 0.5);
	float room = mod(room_code, 16.0);
	float lit = step(15.5, room_code);
	float overlay_code = floor(UV2.y + 0.5);
	float overlay = mod(overlay_code, 16.0);
	float style = floor(overlay_code / 16.0);

	// The pane's axes and size in view space, from how UV and position change across the screen.
	vec3 dp_dx = dFdx(VERTEX);
	vec3 dp_dy = dFdy(VERTEX);
	vec2 duv_dx = dFdx(UV);
	vec2 duv_dy = dFdy(UV);
	float det = duv_dx.x * duv_dy.y - duv_dx.y * duv_dy.x;
	det = abs(det) < 1e-12 ? 1e-12 : det;
	vec3 along_u = (dp_dx * duv_dy.y - dp_dy * duv_dx.y) / det;
	vec3 along_v = (dp_dy * duv_dx.x - dp_dx * duv_dy.x) / det;
	float width = max(length(along_u), 0.05);
	float height = max(length(along_v), 0.05);

	// Follow the view ray into the room: x across, y down, z deeper, each 0-1.
	vec3 ray = normalize(VERTEX);
	vec3 step_dir = vec3(dot(ray, along_u) / (width * width), dot(ray, along_v) / (height * height),
			max(-dot(ray, normalize(NORMAL)), 0.02) / room_depth);
	vec3 start = vec3(UV, 0.0);
	vec3 walls = vec3(step_dir.x > 0.0 ? 1.0 : 0.0, step_dir.y > 0.0 ? 1.0 : 0.0, 1.0);
	vec3 reach = (walls - start) / step_dir;
	float t = min(reach.z, min(reach.x, reach.y));
	vec3 hit = start + step_dir * t;
	vec3 inside;
	if (t >= reach.z) {
		inside = texture(rooms, cell(room, hit.xy)).rgb;
	} else if (t >= reach.x) {
		inside = texture(rooms, cell(room, vec2(walls.x > 0.5 ? 0.99 : 0.01, hit.y))).rgb * 0.78;
	} else {
		inside = texture(rooms, cell(room, vec2(hit.x, walls.y > 0.5 ? 0.99 : 0.01))).rgb * (walls.y > 0.5 ? 0.82 : 0.92);
	}
	inside *= mix(1.0, 0.5, clamp(hit.z, 0.0, 1.0));

	// Whatever hangs on the glass, lit by the room when the room is lit.
	vec4 hung = texture(overlays, cell(overlay, UV));
	vec3 light = mix(inside, hung.rgb * mix(0.55, 1.0, lit), hung.a);

	// Sash bars and the frame, in metres so every pane gets the same widths.
	vec2 edge = min(UV, 1.0 - UV) * vec2(width, height);
	float bar = step(min(edge.x, edge.y), frame_width);
	if (style < 0.5) {
		bar = max(bar, step(abs(UV.y - 0.5) * height, frame_width * 0.8));
	} else if (style > 1.5 && style < 2.5) {
		bar = max(bar, step(abs(UV.y - 0.5) * height, frame_width * 0.6));
		bar = max(bar, step(abs(UV.x - 0.5) * width, frame_width * 0.6));
	} else if (style > 2.5) {
		bar = 0.0;
	}

	ALBEDO = mix(glass_colour + hung.rgb * hung.a * 0.35, frame_colour, bar);
	ROUGHNESS = mix(0.08, 0.6, max(bar, hung.a));
	SPECULAR = 0.5;
	EMISSION = light * mix(dark_room, lit_room, lit) * (1.0 - bar);
}
