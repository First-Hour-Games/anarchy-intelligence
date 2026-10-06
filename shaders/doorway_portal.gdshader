shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D portal_view : source_color, filter_linear;
uniform sampler2D mask : hint_default_white, filter_nearest;
uniform float mask_threshold : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	if (texture(mask, UV).a < mask_threshold) {
		discard;
	}
	// The portal camera matches the player's camera, so screen UVs preserve parallax.
	ALBEDO = texture(portal_view, SCREEN_UV).rgb;
}
