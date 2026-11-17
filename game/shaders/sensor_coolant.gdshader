shader_type canvas_item;
render_mode unshaded;
uniform float effect_clock=0.0;
uniform float attention=0.0;
uniform float direction=1.0;
void fragment(){
	float edge=smoothstep(0.,.22,UV.y)*(1.-smoothstep(.78,1.,UV.y));
	float pulse=pow(.5+.5*sin(UV.x*TAU*7.-effect_clock*TAU*.18*direction),10.);
	float glint=pow(.5+.5*sin(UV.x*TAU*13.-effect_clock*TAU*.26*direction),25.)*(1.-smoothstep(.0,.16,abs(UV.y-.5)));
	COLOR=vec4(.72,.97,1.,edge*(pulse*.20+glint*.36)*(.15+.85*attention));
}
