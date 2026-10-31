// Adapted from Profesor Shader's shader-tiler (MIT).
// Source and license: third_party/shader-tiler/README.md and LICENSE.
shader_type sky;

#include "tutorial_starfield.gdshaderinc"

uniform vec4 lighting_color : source_color = vec4(0.270588, 0.270588, 0.270588, 1.0);

void sky() {
	if (AT_CUBEMAP_PASS) {
		// Keep moving stars out of scene lighting.
		COLOR = lighting_color.rgb;
	} else {
		COLOR = tutorial_starfield(SKY_COORDS, TIME);
	}
}
