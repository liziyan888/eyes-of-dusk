shader_type canvas_item;

// Locked frames are desaturated and dim.  A click seeds a soft radial return
// of the original colour; every child layer/hotspot is gated in GDScript.
uniform float reveal : hint_range(0.0, 1.0) = 0.0;
uniform float eligible : hint_range(0.0, 1.0) = 0.0;
uniform float hovered : hint_range(0.0, 1.0) = 0.0;
uniform float rest : hint_range(0.0, 1.5) = 1.0;
uniform float grade_sat : hint_range(0.0, 1.8) = 1.0;
uniform vec2 rect_size = vec2(1280.0, 720.0);
uniform vec2 reveal_origin = vec2(0.5, 0.5);
uniform bool local_patch_enabled=false;
uniform sampler2D local_patch:filter_linear,repeat_disable;
uniform vec4 patch_rect=vec4(0.0);
uniform float patch_feather=.02;
uniform bool object_edge_cleanup=false;

varying vec2 panel_uv;

void vertex() {
	panel_uv = UV;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if(object_edge_cleanup){
		vec2 px=TEXTURE_PIXEL_SIZE;
		float xp=texture(TEXTURE,UV+vec2(px.x*.85,0.0)).a;
		float xm=texture(TEXTURE,UV-vec2(px.x*.85,0.0)).a;
		float yp=texture(TEXTURE,UV+vec2(0.0,px.y*.85)).a;
		float ym=texture(TEXTURE,UV-vec2(0.0,px.y*.85)).a;
		float interior=min(min(xp,xm),min(yp,ym));
		vec2 g=vec2(xp-xm,yp-ym);vec2 inward=g/max(length(g),.0001);
		vec4 core=texture(TEXTURE,UV+inward*px*1.6);
		float exterior=1.0-smoothstep(.005,.03,interior);
		c.rgb=mix(c.rgb,core.rgb,exterior*smoothstep(.5,.98,core.a)*.8);
		c.a*=mix(1.0,smoothstep(.005,.22,interior),exterior);
	}
	if(local_patch_enabled){
	 vec2 inside=min(UV-patch_rect.xy,patch_rect.xy+patch_rect.zw-UV);
	 float weight=smoothstep(0.0,patch_feather,min(inside.x,inside.y));
	 c=mix(c,texture(local_patch,UV),weight);
	}
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 cool_gray = vec3(luma) * vec3(0.88, 0.93, 0.98);
	vec3 locked = cool_gray * (0.50 + hovered * 0.10) + vec3(0.022, 0.036, 0.047);
	vec3 lit = mix(vec3(luma), c.rgb, grade_sat) * rest;

	float radius = distance(panel_uv, reveal_origin);
	float spread = 1.0 - smoothstep(reveal * 1.72 - 0.035, reveal * 1.72 + 0.045, radius);
	if (reveal <= 0.001) { spread = 0.0; }
	if (reveal >= 0.999) { spread = 1.0; }

	float edge = min(min(panel_uv.x * rect_size.x, (1.0 - panel_uv.x) * rect_size.x),
		min(panel_uv.y * rect_size.y, (1.0 - panel_uv.y) * rect_size.y));
	float breathe = 0.30 + 0.70 * pow(max(0.0, sin(TIME * 1.45)), 3.0);
	vec3 result = mix(locked, lit, spread);
	result += vec3(0.20, 0.235, 0.225)
		* (1.0 - smoothstep(0.0, 3.2, edge))
		* eligible * breathe * (1.0 - spread);

	COLOR = vec4(result, c.a);
}
