shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
	vec4 panel = COLOR;
	vec3 landscape = textureLod(screen_tex, SCREEN_UV, 1.7).rgb;
	float tint = panel.a > 0.85 ? 0.88 : 0.24;
	COLOR = vec4(mix(landscape, panel.rgb, tint), panel.a);
}
