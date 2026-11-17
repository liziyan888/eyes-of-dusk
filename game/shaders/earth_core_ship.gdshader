shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D painted_reference : source_color, filter_linear_mipmap;
uniform sampler2D hull_atlas : source_color, filter_linear_mipmap;
uniform bool use_atlas = false;
uniform vec4 atlas_region = vec4(0.0, 0.0, 0.5, 0.5);
uniform mat4 craft_inverse;
uniform vec4 base_color : source_color = vec4(0.6, 0.65, 0.7, 1.0);
uniform float visibility : hint_range(0.0, 1.0) = 0.0;
uniform float absorption : hint_range(0.0, 1.0) = 0.28;
varying vec3 paint_position;
void vertex() {
	paint_position = (craft_inverse * MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 art_uv = vec2(mix(0.080, 0.939, clamp((paint_position.x + 4.5) / 8.65, 0.0, 1.0)),
		clamp(0.50 - paint_position.y * 0.255, 0.20, 0.80));
	vec3 ink = use_atlas ? texture(hull_atlas, atlas_region.xy + clamp(UV, vec2(0.012), vec2(0.988)) * atlas_region.zw).rgb
		: texture(painted_reference, art_uv).rgb;
	vec3 paint = use_atlas ? ink * (0.72 + base_color.rgb * 0.28)
		: base_color.rgb * (0.38 + ink * 0.94);
	// Absorption matches the pressure-fluid veils in front of the hull.
	ALBEDO = mix(paint, vec3(0.18, 0.25, 0.29), absorption * 0.32);
	ROUGHNESS = 0.83;
	METALLIC = 0.18;
	SPECULAR = 0.23;
	EMISSION = vec3(0.0);
	ALPHA = visibility;
}
