shader_type canvas_item;
render_mode unshaded;
uniform float cut_y = 648.0;
uniform float overlap = 12.0;
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float layer_offset_y = 0.0;
void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float x = UV.x * 1697.0;
	float y = UV.y * 720.0 + layer_offset_y;
	// Stable, texture-aligned plant contours. They do not swim with time or the camera.
	float contours = sin(x * 0.071) * 0.43 + sin(x * 0.197 + 1.8) * 0.32 + sin(x * 0.411) * 0.25;
	float petal = smoothstep(0.06, 0.35, max(paint.r - paint.g * 0.8, paint.b - paint.g * 0.8));
	float fringe = min(overlap * 0.50, 7.0);
	float boundary = cut_y + contours * fringe - petal * fringe * 0.5;
	float softness = min(overlap * 0.8, 9.0);
	float cover = smoothstep(boundary - 1.0, boundary + softness, y);
	COLOR = vec4(paint.rgb, paint.a * cover * opacity);
}
