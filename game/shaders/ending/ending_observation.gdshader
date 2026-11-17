shader_type canvas_item;

// Quiet local inspection: a soft lens, no telescope frame, no UI plate.
uniform vec2 scan_point = vec2(-1000.0);
uniform float scan_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 clue_point = vec2(-1000.0);
uniform float clue_glow : hint_range(0.0, 1.0) = 0.0;
uniform float lens_radius = 92.0;
uniform bool local_patch_enabled=false;
uniform sampler2D local_patch:filter_linear,repeat_disable;
uniform vec4 patch_rect=vec4(0.0);
uniform float patch_feather=.02;

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if(local_patch_enabled){
	 vec2 inside=min(UV-patch_rect.xy,patch_rect.xy+patch_rect.zw-UV);
	 float weight=smoothstep(0.0,patch_feather,min(inside.x,inside.y));
	 c=mix(c,texture(local_patch,UV),weight);
	}
	float lens = 1.0 - smoothstep(lens_radius * 0.60, lens_radius, distance(local_position, scan_point));
	float spot = 1.0 - smoothstep(18.0, 96.0, distance(local_position, clue_point));
	vec3 lit = c.rgb * (0.94 + 0.10 * lens * scan_strength);
	lit += vec3(0.055, 0.115, 0.105) * spot * clue_glow * (0.65 + 0.35 * sin(TIME * 2.6));
	COLOR = vec4(lit, c.a);
}
