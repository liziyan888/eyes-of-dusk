shader_type canvas_item;
uniform float clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
	vec2 p=(UV-0.5)*vec2(1.7778,1.0);
	float aura=exp(-dot(p,p)*4.5);
	vec2 grid=UV*vec2(180.0,100.0);vec2 cell=floor(grid);vec2 f=fract(grid)-0.5;
	float star=pow(max(0.0,1.0-length(f)*2.0),10.0)*step(0.992,hash(cell));
	star*=0.35+0.10*sin(clock*0.4+hash(cell)*6.28);
	vec3 base=mix(vec3(0.008,0.018,0.04),vec3(0.028,0.065,0.12),aura);
	base+=star*vec3(0.65,0.82,1.0);
	COLOR=vec4(base,1.0);
}
