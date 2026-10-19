shader_type canvas_item;

// PSX look over the 3D view (drawn under the HUD): a low virtual resolution with crisp pixels,
// a limited palette with 4x4 ordered (Bayer) dithering, and a vignette.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float target_height = 240.0; // virtual vertical resolution, px
uniform float color_levels = 24.0; // per channel
uniform float dither_strength : hint_range(0.0, 1.0) = 0.8;
uniform float vignette : hint_range(0.0, 1.0) = 0.45;

const float BAYER[16] = float[](
	0.0, 8.0, 2.0, 10.0,
	12.0, 4.0, 14.0, 6.0,
	3.0, 11.0, 1.0, 9.0,
	15.0, 7.0, 13.0, 5.0);

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float pixel = max(1.0, screen_size.y / target_height); // screen px per virtual px
	vec2 cell = floor(FRAGCOORD.xy / pixel);
	vec3 color = texture(screen, (cell + 0.5) * pixel * SCREEN_PIXEL_SIZE).rgb;

	// the threshold of this virtual pixel in the 4x4 pattern, 0..1
	int index = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
	float threshold = mix(0.5, (BAYER[index] + 0.5) / 16.0, dither_strength);
	float steps = color_levels - 1.0;
	color = floor(color * steps + threshold) / steps;

	vec2 from_center = SCREEN_UV - 0.5;
	color *= 1.0 - dot(from_center, from_center) * vignette * 2.0;
	COLOR = vec4(color, 1.0);
}
