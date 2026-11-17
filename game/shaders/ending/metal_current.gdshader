shader_type canvas_item;
uniform float clock=0.0;
uniform float strength=0.004;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	vec2 p=UV;
	p.x+=sin(UV.y*11.0-clock*.38)*strength;
	p.y+=sin(UV.x*7.0-clock*.22)*strength*.45;
	COLOR=tint*texture(TEXTURE,clamp(p,vec2(.002),vec2(.998)));
}
