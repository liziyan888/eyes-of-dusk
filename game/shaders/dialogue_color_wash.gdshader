shader_type canvas_item;
render_mode unshaded;

void fragment() {
	// A faint colored wash under the words, with no visible panel edge.
	float sides = smoothstep(0.0, 0.13, UV.x) * smoothstep(0.0, 0.13, 1.0 - UV.x);
	float ends = smoothstep(0.0, 0.34, UV.y) * smoothstep(0.0, 0.34, 1.0 - UV.y);
	COLOR.a *= sides * ends;
}
