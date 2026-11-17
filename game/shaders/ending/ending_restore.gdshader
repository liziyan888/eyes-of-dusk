shader_type canvas_item;

// A separate, same-transform colour layer.  It is used for the restrained
// "a little green returns" moment and never invents a new object.
uniform vec2 center_uv = vec2(0.5, 0.5);
uniform float radius : hint_range(0.0, 1.5) = 0.10;
uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform float saturation : hint_range(0.0, 2.5) = 1.35;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, center_uv);
	float mask = 1.0 - smoothstep(radius, radius + 0.075, d);
	float luma = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 richer = mix(vec3(luma), c.rgb, saturation);
	richer *= 1.035;
	float a = clamp(mask * active, 0.0, 1.0);
	COLOR = vec4(mix(c.rgb, richer, mask), c.a * a);
}
