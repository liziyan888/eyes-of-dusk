shader_type canvas_item;

// Diagonal paper peel.  The snapshot of the old page is the only layer above
// the new page, so the new page cannot flash before the turn completes.
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float direction = 1.0;

void fragment() {
	vec2 uv = UV;
	float threshold = 2.06 - progress * 2.24;
	float bend = sin(uv.y * 3.14159265) * sin(progress * 3.14159265) * 0.08;
	float d = ((direction > 0.0 ? uv.x : 1.0 - uv.x) + uv.y - threshold + bend) * 0.70710678;
	float band = 0.058 + sin(progress * 3.14159265) * 0.035;
	vec4 front = texture(TEXTURE, uv);
	if (d > 0.0) {
		COLOR = vec4(0.0);
	} else if (d > -band) {
		float phase = clamp(-d / band, 0.0, 1.0);
		float shade = 0.78 + 0.19 * sin(phase * 3.14159265);
		float rim = exp(-pow(d / 0.003, 2.0)) * 0.20;
		COLOR = vec4(vec3(shade) + vec3(0.01, 0.015, 0.025) + rim, front.a);
	} else {
		float shadow = exp(-pow((d + band) / 0.022, 2.0)) * 0.22;
		COLOR = vec4(front.rgb * (1.0 - shadow), front.a);
	}
}
