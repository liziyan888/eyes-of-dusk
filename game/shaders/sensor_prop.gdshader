shader_type canvas_item;
render_mode unshaded;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
 vec4 paint=texture(TEXTURE,UV);
 vec2 d=TEXTURE_PIXEL_SIZE*3.0;
 float edge=paint.a;
 edge=min(edge,texture(TEXTURE,UV+vec2(d.x,0)).a);
 edge=min(edge,texture(TEXTURE,UV-vec2(d.x,0)).a);
 edge=min(edge,texture(TEXTURE,UV+vec2(0,d.y)).a);
 edge=min(edge,texture(TEXTURE,UV-vec2(0,d.y)).a);
 paint.a*=smoothstep(.08,.65,edge);
 COLOR=paint*tint;
}
