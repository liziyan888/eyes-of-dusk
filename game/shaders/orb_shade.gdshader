shader_type canvas_item;
render_mode unshaded;
void fragment(){
	float r=length((UV-0.5)*2.0);
	float shade=exp(-r*r*4.5)*(1.0-smoothstep(0.6,1.0,r))*0.13;
	COLOR=vec4(0.12,0.22,0.28,shade);
}
