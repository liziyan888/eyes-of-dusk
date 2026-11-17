shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float pressure=0.0;
void fragment(){
	vec2 p=UV+vec2(sin(UV.y*19.0+clock*.55),cos(UV.x*15.0-clock*.42))*(.45+pressure)*.0035;
	vec4 medium=texture(TEXTURE,clamp(p,vec2(.003),vec2(.997)));
	float front=smoothstep(.48,.78,UV.y+sin(UV.x*9.0-clock*.35)*.025);
	medium.a=front*(.12+pressure*.15);
	COLOR=medium;
}
