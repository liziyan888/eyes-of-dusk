shader_type canvas_item;
// Blend registered, rigid drawings in premultiplied alpha. No vertex or UV warping.
uniform sampler2D pose_a : filter_linear, repeat_disable;
uniform sampler2D pose_b : filter_linear, repeat_disable;
uniform vec2 offset_a = vec2(0.0);
uniform vec2 offset_b = vec2(0.0);
uniform float blend_amount : hint_range(0.0, 1.0) = 0.0;
varying vec4 item_modulate;

void vertex() { item_modulate = COLOR; }

vec4 clean_pose(sampler2D source, vec2 point) {
	// The sleeve enters from offscreen left. Extend only its cropped canvas edge;
	// never stretch the wrist, palm or fingers to pin the arm to the screen.
	if (point.y < 0.0 || point.y > 1.0 || point.x > 1.0) { return vec4(0.0); }
	vec2 d = 1.0 / vec2(textureSize(source, 0));
	point.x = max(point.x, d.x * 0.5);
	vec4 c = texture(source, point);
	float a = c.a;
	a = min(a, texture(source, point + vec2(d.x, 0.0)).a);
	a = min(a, texture(source, point - vec2(d.x, 0.0)).a);
	a = min(a, texture(source, point + vec2(0.0, d.y)).a);
	a = min(a, texture(source, point - vec2(0.0, d.y)).a);
	float blue = smoothstep(0.22, 0.48, c.b - max(c.r, c.g));
	float magenta = smoothstep(0.25, 0.5, min(c.r, c.b) - c.g);
	c.a = smoothstep(0.09, 0.85, a) * (1.0 - max(blue, magenta));
	return vec4(c.rgb * c.a, c.a);
}

void fragment() {
	vec4 a = clean_pose(pose_a, UV - offset_a);
	vec4 b = clean_pose(pose_b, UV - offset_b);
	vec4 mixed = mix(a, b, blend_amount);
	vec3 rgb = mixed.rgb / max(mixed.a, 0.00001);
	// Fragment COLOR already contains the TextureRect's default texture sample.
	// Multiplying it again would clip every moved pose by the initial silhouette.
	COLOR = item_modulate * vec4(rgb, mixed.a);
}
