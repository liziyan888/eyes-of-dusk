shader_type canvas_item;
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float rest : hint_range(0.0, 1.0) = 1.0;
uniform float glint = 0.0;
uniform vec2 rect_size=vec2(1280.0,720.0);
uniform vec2 reveal_origin=vec2(.5,.5);
uniform float eligible=0.0;
uniform float hovered=0.0;
varying vec2 panel_uv;
void vertex(){panel_uv=VERTEX/max(rect_size,vec2(1.0));}
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    float gray = dot(c.rgb, vec3(0.299, 0.587, 0.114));
    vec3 locked = vec3(gray) * (0.52+hovered*.13) + vec3(0.035);
    vec3 lit = c.rgb * rest;
    float sweep = 1.0-smoothstep(0.0,0.045,abs(UV.x + UV.y * 0.19 - mod(TIME * 0.2, 1.8)));
    float mask = smoothstep(0.15, 0.32, UV.y) * (1.0 - smoothstep(0.6, 0.76, UV.y));
    lit += vec3(0.13, 0.18, 0.2) * sweep * mask * glint;
    float radius=distance(panel_uv,reveal_origin);
    float spread=1.0-smoothstep(reveal*1.65-.02,reveal*1.65+.06,radius);
    if(reveal<=.001)spread=0.0;
    if(reveal>=.999)spread=1.0;
    float edge=min(min(panel_uv.x*rect_size.x,(1.0-panel_uv.x)*rect_size.x),min(panel_uv.y*rect_size.y,(1.0-panel_uv.y)*rect_size.y));
    float breathe=.28+.72*pow(max(0.0,sin(TIME*1.5)),3.0);
    vec3 result=mix(locked,lit,spread);
    result+=vec3(.22,.25,.25)*(1.0-smoothstep(1.0,4.0,edge))*eligible*breathe*(1.0-spread);
    COLOR = vec4(result,c.a);
}
