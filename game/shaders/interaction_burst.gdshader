shader_type canvas_item;
render_mode unshaded;

uniform float burst_age = 4.8;
uniform float burst_seed = 0.0;
uniform float burst_life = 4.8;
varying float opacity;
varying float glow;
varying vec4 tint;

void vertex() {
	float index = float(INSTANCE_ID);
	float delay = mod(index * 0.071, 0.42);
	float age = max(0.0, burst_age - delay);
	float phase = clamp(age / (burst_life - delay), 0.0, 1.0);
	float angle = index * 2.399963 + burst_seed;
	float travel = 150.0 + mod(index * 67.31, 390.0);
	float radius = 0.32 + mod(index * 0.77, 0.83);
	opacity = pow(1.0 - phase, 1.5) * (0.30 + mod(index * 0.31, 0.6)) * smoothstep(0.0, 0.16, age);
	glow = 1.0 - step(0.5, mod(index, 4.0));
	tint = COLOR;
	VERTEX = VERTEX * radius * 3.15 + vec2(cos(angle), sin(angle)) * travel * sin(phase * PI * 0.5);
}

void fragment() {
	float distance = length((UV * 2.0 - 1.0) * 3.15);
	float edge = max(fwidth(distance) * 0.55, 0.025);
	float body_alpha = (1.0 - smoothstep(1.0 - edge, 1.0 + edge, distance)) * opacity;
	float glow_alpha = (1.0 - smoothstep(2.8 - edge, 2.8 + edge, distance)) * opacity * glow * 0.075;
	float alpha = body_alpha + glow_alpha * (1.0 - body_alpha);
	vec3 premultiplied = vec3(0.96, 0.99, 1.0) * body_alpha + vec3(0.94, 0.98, 1.0) * glow_alpha * (1.0 - body_alpha);
	COLOR = vec4(premultiplied / max(alpha, 0.00001), alpha) * tint;
}
