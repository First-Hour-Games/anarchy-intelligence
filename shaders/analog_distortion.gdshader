/* License CC BY-NC-SA 4.0 Deed */
/* https://creativecommons.org/licenses/by-nc-sa/4.0/ */
/* Fork of Ryk's VCR distortion shader */
/* https://www.shadertoy.com/view/ldjGzV */

shader_type canvas_item;

uniform sampler2D screen_texture: hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms Bounds;
uniform vec2 content_rect_min = vec2(0.125, 0.0);
uniform vec2 content_rect_size = vec2(0.75, 1.0);

group_uniforms Transition;
uniform float distortion_strength: hint_range(0.0, 1.0, 0.01) = 1.0;

group_uniforms Image;
uniform float curvature: hint_range(0., 10., .01) = 2.;
uniform float skip: hint_range(0., 1., .01) = 1.;
uniform float image_flicker: hint_range(0., 1., .01) = 1.;

group_uniforms Vignette;
uniform float vignette_flicker_speed: hint_range(0., 2., .01) = 1.;
uniform float vignette_strength: hint_range(0., 2., 0.01) = 1.;

group_uniforms Scanlines;
uniform float small_scanlines_speed: hint_range(0., 10., .01) = 1.;
uniform float small_scanlines_proximity: hint_range(.01, 2., .01) = 1.;
uniform float small_scanlines_opacity: hint_range(0.01, 5., .01) = 1.;
uniform float scanlines_opacity: hint_range(0., 2., .01) = 1.;
uniform float scanlines_speed: hint_range(0., 5., .01) = 1.;
uniform float scanline_thickness: hint_range(0., .6, .01) = 0.5;
uniform float scanlines_spacing: hint_range(0.3, 3., .01) = 1.;

group_uniforms Noise;
uniform sampler2D noise_texture: filter_linear_mipmap, repeat_enable;

float noise(vec2 p, vec2 uv)
{
	float s = texture(noise_texture, vec2(1. * TIME, 2. * TIME) * 8. + p * 1.).x;
	s *= s;
	return s;
}

float onOff(float a, float b, float c)
{
	return step(c, sin(TIME + a * cos(TIME * b)));
}

float ramp(float y, float start, float end)
{
	float inside = step(start, y) - step(end, y);
	float fact = (y - start) / (end - start) * inside;
	return (1. - fact) * inside;
}

float stripes(vec2 uv)
{
	float noi = noise(uv * vec2(0.5, 1.) + vec2(1., 3.), uv) * scanlines_opacity;
	return ramp(mod(uv.y * 4. * scanlines_spacing + TIME * scanlines_speed / (2. * scanlines_spacing) + sin(TIME * scanlines_speed + sin(TIME * scanlines_speed * 0.63 * scanlines_spacing)), 1.), scanline_thickness, .6) * noi;
}

vec3 getVideo(vec2 uv)
{
	vec2 look = uv;
	float window = 1. / (1. + 20. * (look.y - mod(TIME / 4., 1.)) * (look.y - mod(TIME / 4., 1.))) * image_flicker;
	look.x = look.x + sin(look.y * 10. + TIME) / 50. * onOff(4., 4., .3) * (1. + cos(TIME * 80.)) * window * distortion_strength;
	float vShift = 0.4 * onOff(2., 3., .9) * (sin(TIME) * sin(TIME * 20.) + (0.5 + 0.1 * sin(TIME * 200.) * cos(TIME))) * skip * distortion_strength;
	look.y = mod(look.y + vShift, 1.);

	// Sample screen within the 4:3 content rect
	vec2 sample_screen_uv = content_rect_min + look * content_rect_size;
	vec3 video = texture(screen_texture, sample_screen_uv).xyz;
	if (look.x < 0.0 || look.x > 1.0) {
		video = vec3(0.0);
	}
	return video;
}

vec2 screenDistort(vec2 uv)
{
	uv -= vec2(.5, .5);
	uv = uv * 1.2 * (1. / 1.2 + (curvature * distortion_strength) * uv.x * uv.x * uv.y * uv.y);
	uv += vec2(.5, .5);
	return uv;
}

void fragment()
{
	vec2 screen_uv = SCREEN_UV;
	vec3 clean_video = texture(screen_texture, screen_uv).xyz;

	// Use UV (the 4:3 content rect) so curvature, vignette, and scanlines match the CRT frame
	vec2 uv = UV;
	vec2 distorted_uv = screenDistort(uv);

	vec3 video = getVideo(distorted_uv);

	// Vignette across 4:3 content
	float vigAmt = 3. + .3 * sin(TIME * vignette_flicker_speed + 1. + 5. * cos(TIME * 5. * vignette_flicker_speed + 1.));
	vigAmt *= (vignette_strength * distortion_strength);
	float vignette = (1. - vigAmt * (distorted_uv.y - .5) * (distorted_uv.y - .5)) * (1. - vigAmt * (distorted_uv.x - .5) * (distorted_uv.x - .5));

	// Stripes and noise
	video += stripes(distorted_uv) * distortion_strength;
	video += (noise(distorted_uv * 2., distorted_uv) / 2.) * distortion_strength;
	video *= vignette;

	// Small scanlines
	float scanline_factor = (12. / small_scanlines_opacity + mod(distorted_uv.y * 30. * small_scanlines_proximity + TIME * small_scanlines_speed, 1.)) / 13. * small_scanlines_opacity;
	video *= mix(1.0, scanline_factor, distortion_strength);

	// In-bounds clipping for curvature edge
	float in_bounds = float(distorted_uv.x >= 0.0 && distorted_uv.x <= 1.0 && distorted_uv.y >= 0.0 && distorted_uv.y <= 1.0);
	video *= in_bounds;

	vec3 final_color = mix(clean_video, video, distortion_strength);
	COLOR = vec4(final_color, 1.0);
}
