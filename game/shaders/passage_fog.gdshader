shader_type canvas_item;
render_mode unshaded;

uniform vec2 texture_origin = vec2(0.0);
uniform vec2 texture_extent = vec2(1.0);
uniform float layer_opacity = 1.0;
varying vec2 world_position;
varying float mist_density;

void vertex() {
	world_position = VERTEX;
	mist_density = COLOR.a;
}

void fragment() {
	vec2 uv = clamp((world_position - texture_origin) / max(texture_extent, vec2(0.001)), vec2(0.0), vec2(1.0));
	vec4 paint = texture(TEXTURE, uv);
	COLOR = vec4(paint.rgb, paint.a * mist_density * layer_opacity);
}
