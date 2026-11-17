shader_type spatial;
render_mode unshaded,cull_back,depth_draw_never;
uniform sampler2D land_mask : filter_linear_mipmap;
uniform float reveal=0.0;
void fragment(){
	float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.5);
	float land=texture(land_mask,vec2(fract(UV.x+0.25),UV.y)).r;
	float sunlight=max(0.0,dot(normalize(NORMAL),normalize(vec3(-0.6,0.6,0.8))));
	vec3 ocean=vec3(0.12,0.30,0.48);
	vec3 continent=vec3(0.32,0.62,0.72);
	vec3 crystal=mix(mix(ocean,continent,land),vec3(0.68,0.86,1.0),rim);
	crystal+=vec3(0.20,0.11,0.025)*sunlight*sunlight;
	ALBEDO=crystal;EMISSION=crystal*0.34;
	ALPHA=(0.025+land*0.15+rim*0.55)*reveal;
}
