shader_type canvas_item;
render_mode unshaded;
uniform sampler2D left_image:filter_linear,repeat_disable;
uniform sampler2D right_image:filter_linear,repeat_disable;
uniform vec4 left_rect;
uniform vec4 right_rect;
uniform vec2 left_source_position;
uniform vec2 right_source_position;
uniform bool left_visible=true;
uniform bool right_visible=true;
uniform bool left_extend_top=false;
uniform bool right_extend_top=false;
uniform float camera_x=0.0;
uniform float world_begin=0.0;
uniform float world_end=0.0;
uniform float seam=0.0;
uniform float feather=96.0;
uniform bool continuous_landscape=false;
uniform bool cover_only=false;
uniform float ground_left=700.0;
uniform float ground_right=700.0;
uniform float overlap=12.0;
varying vec2 logical_position;
void vertex(){logical_position=VERTEX;}
vec2 reflection(vec2 uv){return vec2(1.0-abs(mod(uv.x,2.0)-1.0),1.0-abs(mod(uv.y,2.0)-1.0));}
vec4 paint_at(sampler2D image,vec4 rect,bool shown,bool extend_top,bool bridge){
 if(!shown)return vec4(0.0);
 vec2 uv=(logical_position-rect.xy)/rect.zw;
 if(uv.y>1.0 || (uv.y<0.0&&!extend_top))return vec4(0.0);
 if((uv.x<0.0||uv.x>1.0)&&!bridge)return vec4(0.0);
 return texture(image,reflection(uv));
}
float grass_cover(vec4 paint,vec4 rect,vec2 source_position,float ground){
 vec2 uv=reflection((logical_position-rect.xy)/rect.zw);
 vec2 point=source_position+uv*rect.zw;
 float contour=sin(point.x*.071)*.43+sin(point.x*.197+1.8)*.32+sin(point.x*.411)*.25;
 float flower=smoothstep(.06,.35,max(paint.r-paint.g*.8,paint.b-paint.g*.8));
 float depth=clamp(overlap,4.0,30.0);
 float fringe=min(depth*.50,7.0);
 float boundary=ground-depth+contour*fringe-flower*fringe*.5;
 return smoothstep(boundary-1.0,boundary+min(depth*.8,9.0),point.y);
}
void fragment(){
 float world_x=logical_position.x+camera_x;
 bool bridge=abs(world_x-seam)<=feather;
 vec4 a=paint_at(left_image,left_rect,left_visible,left_extend_top,bridge);
 vec4 b=paint_at(right_image,right_rect,right_visible,right_extend_top,bridge);
 if(cover_only){
  a.a*=grass_cover(a,left_rect,left_source_position,ground_left);
  b.a*=grass_cover(b,right_rect,right_source_position,ground_right);
 }
 float t=smoothstep(seam-feather,seam+feather,world_x);
 float alpha=mix(a.a,b.a,t);
 vec3 rgb=mix(a.rgb*a.a,b.rgb*b.a,t)/max(alpha,.00001);
 if(world_x<world_begin||world_x>world_end)alpha=0.0;
 COLOR=vec4(rgb,alpha);
 if(continuous_landscape){
  // One mirrored landscape crosses the boundary. Never alpha-mix displaced plants.
  vec4 continuous=paint_at(left_image,left_rect,left_visible,left_extend_top,true);
  if(cover_only)continuous.a*=grass_cover(continuous,left_rect,left_source_position,ground_left);
  if(world_x<world_begin||world_x>world_end)continuous.a=0.0;
  COLOR=continuous;
 }
}
