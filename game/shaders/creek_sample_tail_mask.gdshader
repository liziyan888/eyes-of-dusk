shader_type canvas_item;
uniform vec4 tail_rect_uv=vec4(0.0);
uniform vec4 water_tint : source_color=vec4(1.0);
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 if(UV.x>=tail_rect_uv.x && UV.y>=tail_rect_uv.y && UV.x<=tail_rect_uv.z && UV.y<=tail_rect_uv.w){c.a=0.0;}
 COLOR=c*water_tint;
}
