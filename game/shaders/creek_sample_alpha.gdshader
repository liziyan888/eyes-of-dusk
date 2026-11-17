shader_type canvas_item;
uniform float alpha_cutoff : hint_range(0.0,0.9)=0.08;
uniform float alpha_feather : hint_range(0.001,0.2)=0.04;
uniform float layer_opacity : hint_range(0.0,1.0)=1.0;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 c.a*=smoothstep(alpha_cutoff,alpha_cutoff+alpha_feather,c.a)*layer_opacity;
 COLOR=c;
}
