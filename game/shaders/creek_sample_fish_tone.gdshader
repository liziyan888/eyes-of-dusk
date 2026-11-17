shader_type canvas_item;
uniform vec4 water_tint : source_color = vec4(1.0);
uniform sampler2D water_surface : source_color, filter_linear;
uniform vec4 water_rect = vec4(0.0, 0.0, 1280.0, 720.0);
uniform float water_glaze : hint_range(0.0, 0.15) = 0.055;
varying vec2 water_position;
void vertex() {
	water_position = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}
void fragment() {
	vec4 fish = texture(TEXTURE, UV) * water_tint;
	vec2 water_uv = (water_position - water_rect.xy) / water_rect.zw;
	vec3 surface_color = texture(water_surface, water_uv).rgb;
	// This water glaze only touches fish pixels; the background stays immutable.
	fish.rgb = mix(fish.rgb, surface_color, water_glaze);
	COLOR = fish;
}
