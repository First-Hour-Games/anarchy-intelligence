shader_type spatial;
render_mode cull_back, specular_schlick_ggx;
// One worm strand of the worm mass (worm_mass.gd). Hundreds of copies sit in MultiMeshes; all the
// writhing is done here in the vertex shader, so a strand costs the CPU nothing. The strand mesh
// runs along +Y from root (UV.y = 0) to tip (UV.y = 1); the root stays put and the tip swings.
// Per-instance variation comes from the MultiMesh custom data (INSTANCE_CUSTOM):
//   r: phase (0..1)   g: speed multiplier   b: amplitude multiplier   a: hue shift (0..1)
// A plain MeshInstance3D (a ground scout) has INSTANCE_CUSTOM = 0; it derives its phase from its
// node's world position instead, so no two scouts move alike either.

uniform float sway_speed: hint_range(0.1, 8.0) = 2.1;
uniform float sway_amplitude: hint_range(0.0, 0.5) = 0.075;
uniform float pulse_strength: hint_range(0.0, 0.5) = 0.1;
uniform float curl_strength: hint_range(0.0, 1.0) = 0.42;
uniform vec3 colour_root: source_color = vec3(0.10, 0.012, 0.016);
uniform vec3 colour_mid: source_color = vec3(0.30, 0.045, 0.05);
uniform vec3 colour_tip: source_color = vec3(0.43, 0.095, 0.085);
uniform float wetness: hint_range(0.0, 1.0) = 0.72;

varying float along;
varying float hue_shift;

void vertex() {
	along = UV.y;
	vec4 custom = INSTANCE_CUSTOM;
	if (custom.g <= 0.001) {
		// A single mesh, not a MultiMesh instance: seed it from where its node stands.
		float seed = fract(sin(dot(NODE_POSITION_WORLD.xz, vec2(12.9898, 78.233))) * 43758.5453);
		custom = vec4(seed, 0.85 + seed * 0.4, 1.0, seed);
	}
	hue_shift = custom.a;
	float phase = custom.r * 6.2831853;
	float t = TIME * sway_speed * custom.g;
	// The root is anchored; the tip swings. Two unsynchronised waves make an S-curve, not a metronome.
	float weight = along * along * (3.0 - 2.0 * along) * (0.25 + 0.75 * along);
	float amp = sway_amplitude * custom.b;
	vec3 bend = vec3(0.0);
	// A standing curl first, different in every strand, so the mass is a tangle of loops even
	// while it rests; the sway then stirs the tangle.
	float curl = curl_strength * (0.5 + 0.5 * sin(phase * 3.7));
	bend.x += sin(along * (2.6 + 3.0 * fract(phase)) + phase * 2.0) * curl;
	bend.z += cos(along * (3.4 + 2.2 * fract(phase * 1.7)) + phase) * curl * 0.9;
	bend.x += sin(t + phase + along * 5.1) * amp;
	bend.z += cos(t * 1.31 + phase * 1.7 + along * 7.3) * amp * 0.8;
	bend.x += sin(t * 0.37 + phase) * amp * 0.9;
	bend.z += cos(t * 0.29 + phase * 2.3) * amp * 0.7;
	VERTEX += bend * weight;
	// Peristalsis: a swallowing bulge travelling rootward, as if something moved inside it.
	float pulse = 1.0 + pulse_strength * sin(along * 9.0 - t * 1.6 + phase) * (0.35 + 0.65 * along);
	VERTEX.xz *= pulse;
	// Keep lighting stable while the strand bends: tilt normals with the bend a little.
	NORMAL = normalize(NORMAL + vec3(bend.x, 0.0, bend.z) * weight * 2.0);
}

void fragment() {
	vec3 low = mix(colour_root, colour_mid, smoothstep(0.0, 0.55, along));
	vec3 colour = mix(low, colour_tip, smoothstep(0.55, 1.0, along));
	// A touch of per-strand variety so the mass reads as many bodies, not one dyed clump.
	colour *= 0.82 + 0.2 * hue_shift;
	colour.r *= 1.0 + 0.08 * sin(hue_shift * 17.0);
	ALBEDO = colour;
	ROUGHNESS = mix(0.55, 0.3, wetness * (0.6 + 0.4 * along));
	SPECULAR = 0.5;
}
