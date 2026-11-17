shader_type canvas_item;
render_mode unshaded;
uniform vec2 camera=vec2(0);
uniform float source_aspect=1.75;
uniform float opacity=1.0;
void fragment(){
 vec2 screen=vec2(UV.x*2.0-1.0,1.0-UV.y*2.0);
 vec3 ray=normalize(vec3(screen.x*(16.0/9.0)*tan(.435),screen.y*tan(.435),-1.0));
 float cy=cos(camera.x),sy=sin(camera.x),cp=cos(camera.y),sp=sin(camera.y);
 ray=vec3(ray.x,cp*ray.y-sp*ray.z,sp*ray.y+cp*ray.z);
 ray=vec3(cy*ray.x-sy*ray.z,ray.y,sy*ray.x+cy*ray.z);
 vec2 source=vec2(.5+ray.x/(-ray.z)/(2.0*tan(.548)*source_aspect),.5-ray.y/(-ray.z)/(2.0*tan(.548)));
 COLOR=vec4(texture(TEXTURE,clamp(source,vec2(.001),vec2(.999))).rgb,opacity);
}
