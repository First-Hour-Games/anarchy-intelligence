// The tutorial sky is rendered by a camera with the player's projection.
// Screen coordinates make the gem a window without texture zoom or UV warping.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform sampler2D portal_view : source_color, filter_linear;

void fragment() {
	ALBEDO = texture(portal_view, SCREEN_UV).rgb;
}
