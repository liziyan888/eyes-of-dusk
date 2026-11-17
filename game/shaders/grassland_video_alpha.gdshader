shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec3 rgb=texture(TEXTURE,vec2(UV.x*.5,UV.y)).rgb;
 float a=texture(TEXTURE,vec2(.5+UV.x*.5,UV.y)).r;
 COLOR=vec4(rgb,smoothstep(.025,.975,a));
}
