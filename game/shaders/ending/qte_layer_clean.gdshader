shader_type canvas_item;
// Runtime matte cleanup for supplied transparent reference layers. Originals stay intact.
varying vec4 item_modulate;
uniform bool remove_red_fringe = false;
void vertex() { item_modulate = COLOR; }
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 d = TEXTURE_PIXEL_SIZE;
	float a = c.a;
	a = min(a, texture(TEXTURE,UV+vec2(d.x,0.0)).a);
	a = min(a, texture(TEXTURE,UV-vec2(d.x,0.0)).a);
	a = min(a, texture(TEXTURE,UV+vec2(0.0,d.y)).a);
	a = min(a, texture(TEXTURE,UV-vec2(0.0,d.y)).a);
	float blue = smoothstep(0.22,0.48,c.b-max(c.r,c.g));
	float magenta = smoothstep(0.25,0.5,min(c.r,c.b)-c.g);
	c.a = smoothstep(0.09,0.85,a) * (1.0-max(blue,magenta));
	if (remove_red_fringe) { c.a *= 1.0-smoothstep(.42,.68,c.r-max(c.g,c.b)); }
	COLOR = item_modulate * c;
}
