shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, fog_disabled;
uniform vec4 volume_tint : source_color = vec4(0.29, 0.43, 0.53, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.0;
uniform float film_time = 0.0;
uniform float radius = 1.0;
varying vec3 volume_position;
void vertex() {
	volume_position = VERTEX / radius;
}
void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.4);
	float fluid = 0.5 + 0.5 * sin(volume_position.y * 7.0
		+ sin(volume_position.x * 3.8 + film_time * 0.045) * 1.2
		+ film_time * 0.055);
	ALBEDO = mix(volume_tint.rgb, vec3(0.46, 0.35, 0.21), fluid * 0.16);
	ALPHA = opacity * (0.20 + rim * 0.67 + fluid * 0.13);
}
