shader_type canvas_item;
render_mode unshaded;
float matte(vec3 c){return 1.0-smoothstep(.08,.235,min(c.r,c.b)-c.g);}
void fragment(){
 vec4 c=texture(TEXTURE,UV);vec3 key=vec3(.79,.24,.61);
 vec2 px=TEXTURE_PIXEL_SIZE*2.0;
 float near_alpha=min(min(matte(texture(TEXTURE,UV+vec2(px.x,0)).rgb),matte(texture(TEXTURE,UV-vec2(px.x,0)).rgb)),min(matte(texture(TEXTURE,UV+vec2(0,px.y)).rgb),matte(texture(TEXTURE,UV-vec2(0,px.y)).rgb)));
 float a=matte(c.rgb)*mix(1.0,smoothstep(.14,.38,distance(c.rgb,key)),1.0-near_alpha);
 c.rgb=clamp((c.rgb-key*(1.0-a))/max(a,.08),vec3(0),vec3(1));
 float spill=max(0.0,min(c.r,c.b)-c.g-.025);c.r=max(0.0,c.r-spill*.25);c.b=max(0.0,c.b-spill*.55);
 float root=1.0-smoothstep(.018,.05,abs(UV.x-.285));a*=1.0-root*smoothstep(.892,.932,UV.y);
 COLOR=vec4(c.rgb,a);
}
