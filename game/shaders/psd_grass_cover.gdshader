shader_type canvas_item;
render_mode unshaded;
// Coordinates of the PSD texture in design units, before world/camera scaling.
uniform vec2 layer_position=vec2(0.0,611.53846);
uniform vec2 layer_extent=vec2(1920.0,220.96154);
uniform float ground_y=700.0;
uniform float overlap=12.0;
uniform vec2 contact_center=vec2(0.0,660.0);
uniform float contact_radius=0.0;
uniform vec4 source_uv_rect=vec4(0.0,0.0,1.0,1.0);
void fragment(){
 vec4 paint=texture(TEXTURE,UV);
 vec2 local_uv=(UV-source_uv_rect.xy)/source_uv_rect.zw;
 vec2 point=layer_position+local_uv*layer_extent;
 // Texture-locked grass contour: no time or camera term, so feet do not flicker.
 float contour=sin(point.x*.071)*.43+sin(point.x*.197+1.8)*.32+sin(point.x*.411)*.25;
 float flower=smoothstep(.06,.35,max(paint.r-paint.g*.8,paint.b-paint.g*.8));
 float depth=clamp(overlap,4.0,30.0);
 float fringe=min(depth*.50,7.0);
 float boundary=ground_y-depth+contour*fringe-flower*fringe*.5;
 float softness=min(depth*.8,9.0);
 float cover=smoothstep(boundary-1.0,boundary+softness,point.y);
 if(contact_radius>0.0){
  float local_weight=1.0-smoothstep(contact_radius*.65,contact_radius,abs(point.x-contact_center.x));
  float local_boundary=contact_center.y-depth+contour*fringe-flower*fringe*.5;
  cover=max(cover,local_weight*smoothstep(local_boundary-1.0,local_boundary+softness,point.y));
 }
 COLOR=vec4(paint.rgb,paint.a*cover);
}
