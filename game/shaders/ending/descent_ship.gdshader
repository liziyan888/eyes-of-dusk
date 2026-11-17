shader_type canvas_item;
uniform bool front_piece = false;
uniform float heat : hint_range(0.0,1.0) = 0.0;
uniform float rim : hint_range(0.0,1.0) = 0.0;
uniform float depth : hint_range(0.0,1.0) = 0.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	vec4 c=texture(TEXTURE,UV);
	vec2 d=TEXTURE_PIXEL_SIZE;
	float a=min(c.a,min(texture(TEXTURE,UV+vec2(d.x,0)).a,texture(TEXTURE,UV-vec2(d.x,0)).a));
	float blue=smoothstep(.27,.55,c.b-max(c.r,c.g));
	float magenta=smoothstep(.25,.55,min(c.r,c.b)-c.g);
	float split=.436+.024*max(0.0,1.0-pow((UV.y-.493)/.115,2.0));
	float side=step(UV.x,split);
	a*=front_piece ? side : 1.0-side;
	// Preserve authored blue lamps and warm burner while stripping neon matte dots.
	a*=1.0-max(blue,magenta)*(1.0-smoothstep(.2,.97,c.a));
	float seam=exp(-abs(UV.x-split)*450.0)*rim;
	c.rgb=mix(c.rgb,vec3(.24,.075,.052),depth*.58);
	c.rgb+=vec3(.19,.035,.008)*heat+vec3(.85,.27,.04)*seam;
	COLOR=tint*vec4(c.rgb,smoothstep(.06,.82,a));
}
