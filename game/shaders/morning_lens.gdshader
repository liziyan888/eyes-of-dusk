shader_type canvas_item;
uniform float clear_amount = 0.0;
uniform sampler2D lens_mask:filter_linear,repeat_disable;
uniform sampler2D clean_mask:filter_linear,repeat_disable;
varying vec4 tint;
void vertex() { tint=COLOR; }
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec2 d=TEXTURE_PIXEL_SIZE*3.0;
    float edge=min(base.a,min(min(texture(TEXTURE,UV+vec2(d.x,0)).a,texture(TEXTURE,UV-vec2(d.x,0)).a),min(texture(TEXTURE,UV+vec2(0,d.y)).a,texture(TEXTURE,UV-vec2(0,d.y)).a)));
    base.a*=smoothstep(.08,.65,edge);
    vec4 mask=texture(lens_mask,UV);
    float lenses=smoothstep(.3,.85,mask.a*mask.r);
    float clean = max(clear_amount,texture(clean_mask,UV).r);
    float haze = lenses * (1.0-clean) * .82;
    base.rgb = mix(base.rgb,vec3(.83,.88,.89),haze);
    COLOR = base * tint;
}
