shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float alarm=0.0;
uniform float flow=0.0;
void fragment(){
	vec2 p=UV;
	p+=vec2(sin(UV.y*19.0+clock*.55),cos(UV.x*15.0-clock*.42))*flow*.0035;
	vec4 c=texture(TEXTURE,clamp(p,vec2(.003),vec2(.997)));
	float pulse=.60+.40*sin(clock*4.4);
	float light=(.20+.8*smoothstep(.10,.95,UV.x))*alarm*pulse;
	c.rgb=mix(c.rgb,c.rgb*vec3(1.30,.67,.53)+vec3(.08,.005,0.0),light*.38);
	COLOR=c;
}
