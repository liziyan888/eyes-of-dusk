shader_type canvas_item;
render_mode unshaded,blend_add;
uniform vec2 nose_uv=vec2(.3,.5);
uniform float clock=0.0;
uniform float pressure=0.0;
void fragment(){
	vec2 d=(UV-nose_uv)*vec2(1.77778,1.0);
	float bloom=exp(-dot(d,d)/.0012)*(.15+.025*sin(clock*4.0));
	float halo=exp(-dot(d,d)/.007)*(.025+pressure*.018);
	COLOR=vec4(vec3(1.0,.26,.035)*(bloom+halo),1.0);
}
