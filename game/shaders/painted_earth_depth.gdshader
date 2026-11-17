shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D layer_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform bool interior_only = false;
void fragment() {
	vec4 paint = texture(layer_texture, UV);
	// The rear painting owns the outer map contour. Only the INNER veils
	// parallax in front, avoiding a second drifting map/planet silhouette.
	float registration_mask = 1.0;
	if (interior_only) {
		float radial = length((UV - vec2(0.493, 0.48)) * vec2(1.7777778, 1.0));
		registration_mask = 1.0 - smoothstep(0.245, 0.345, radial);
	}
	ALBEDO = paint.rgb;
	ALPHA = paint.a * opacity * registration_mask;
}
