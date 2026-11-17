shader_type canvas_item;
render_mode unshaded;
uniform vec4 ink : source_color = vec4(.48,.72,.94,.12);
uniform vec4 rule_color : source_color = vec4(.48,.72,.94,1.0);
uniform float gradient_power=1.65;
uniform float gradient_height=1.0;
uniform float line_alpha=.58;
uniform float line_width=1.3;
uniform float height=92.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 float sides=smoothstep(0.0,.045,UV.x)*smoothstep(0.0,.045,1.0-UV.x);
 float g=pow(clamp((UV.y-1.0+gradient_height)/max(.1,gradient_height),0.0,1.0),gradient_power)*ink.a;
 float line=0.0;
 if(line_width>0.0)line=smoothstep(1.0-(line_width+.3)/height,1.0-.3/height,UV.y)*line_alpha;
 float a=line+g*(1.0-line);
 vec3 rgb=(rule_color.rgb*line+ink.rgb*g*(1.0-line))/max(a,.00001);
 COLOR=vec4(rgb,a*sides)*tint;
}
