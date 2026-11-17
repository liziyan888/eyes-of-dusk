shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform float pressure=0.0;
void fragment(){
	vec2 p=UV*2.0-1.0;
	float edge=smoothstep(.38,1.28,length(p*vec2(.76,1.0)));
	float warm=pressure*(.6+.4*sin(clock*2.1));
	COLOR=vec4(mix(vec3(.012,.018,.025),vec3(.20,.033,.018),warm),edge*(.38+pressure*.15));
}
