shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink : source_color = vec4(.48,.72,.94,.12);
uniform float line_alpha=.58;
uniform float height=92.0;
void fragment(){
 float sides=smoothstep(0.0,.045,UV.x)*smoothstep(0.0,.045,1.0-UV.x);
 float gradient=pow(clamp(UV.y,0.0,1.0),1.65)*ink.a;
 float line=smoothstep(1.0-1.6/height,1.0-.3/height,UV.y)*line_alpha;
 COLOR=vec4(ink.rgb,max(gradient,line)*sides);
}
