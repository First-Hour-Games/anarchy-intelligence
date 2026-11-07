#[compute]
#version 450

// Accumulation motion blur by xandwr, CC0:
// https://godotshaders.com/shader/accumulation-motion-blur-compositor-pipeline/
// Local change: `reset` seeds the history from the current frame, so a stale
// frame from the last hit does not flash back in.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform image2D color_image;
layout(rgba16f, set = 0, binding = 1) uniform image2D prev_frame;

layout(push_constant, std430) uniform Params {
	vec2 raster_size;
	float alpha; // blend factor: 0 = no trail, 1 = infinite trail
	float reset; // 1 = ignore the stored history this frame
} params;

void main() {
	ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(params.raster_size);

	if (texel.x >= size.x || texel.y >= size.y) {
		return;
	}

	vec4 current = imageLoad(color_image, texel);
	vec4 previous = params.reset > 0.5 ? current : imageLoad(prev_frame, texel);

	vec4 blended = mix(current, previous, params.alpha);

	imageStore(color_image, texel, blended);
	imageStore(prev_frame, texel, blended);
}
