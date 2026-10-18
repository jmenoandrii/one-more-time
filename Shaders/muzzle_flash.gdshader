shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

// Muzzle flash on a camera-facing quad: hot core, orange glow and a star of spikes.
// MuzzleFlash randomizes angle / rays for every shot and fades intensity out.

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.45, 0.1, 1.0);
uniform float intensity = 1.0;
uniform float angle = 0.0;
uniform float rays = 6.0;

void vertex() {
	// billboard that keeps the node's scale
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0] * length(MODEL_MATRIX[0].xyz),
		INV_VIEW_MATRIX[1] * length(MODEL_MATRIX[1].xyz),
		INV_VIEW_MATRIX[2] * length(MODEL_MATRIX[2].xyz),
		MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float c = cos(angle);
	float s = sin(angle);
	p = mat2(vec2(c, s), vec2(-s, c)) * p;

	float r = length(p);
	float spikes = pow(abs(cos(atan(p.y, p.x) * rays * 0.5)), 8.0) * smoothstep(1.0, 0.0, r);
	float glow = smoothstep(0.6, 0.0, r);
	float core = smoothstep(0.25, 0.0, r);

	float v = clamp(glow + spikes * 0.8, 0.0, 1.0) * intensity;
	ALBEDO = mix(edge_color.rgb, core_color.rgb, core) * v;
	ALPHA = v;
}
