shader_type canvas_item;

// Darkens the clock face clockwise from 12 o'clock as the time runs out.
// Works per texture pixel, so the dark sector stays pixel art at any scale.

uniform float progress : hint_range(0.0, 1.0) = 0.0; // part of the time already gone
uniform vec2 face_center = vec2(15.0, 19.0); // in texture pixels
uniform float face_radius = 11.4; // texture pixels; the rim outside it is not darkened
uniform float darkness : hint_range(0.0, 1.0) = 0.45; // brightness left in the dark sector

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	vec2 d = floor(UV / TEXTURE_PIXEL_SIZE) - face_center;
	float angle = atan(d.x, -d.y); // 0 at 12 o'clock, clockwise
	if (angle < 0.0) {
		angle += TAU;
	}
	if (length(d) <= face_radius && angle / TAU < progress) {
		color.rgb *= darkness;
	}
	COLOR = color;
}
