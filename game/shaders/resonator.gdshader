shader_type canvas_item;
render_mode unshaded;
uniform vec4 senses = vec4(0.0);
uniform float clock = 0.0;
uniform float bird = 0.0;
void fragment() {
	float activity = max(max(senses.x, senses.y), max(senses.z, senses.w));
	vec2 uv = UV;
	vec2 p = uv - vec2(0.5);
	float radius = length(p);
	float sound = sin(clock * mix(13.0, 23.0, bird) + p.y * 41.0) * senses.x;
	float touch = sin(clock * 8.0 - radius * 22.0) * exp(-fract(clock * 1.4) * 3.0) * senses.y;
	float scent = sin(clock * 1.8 + p.x * 8.0) * senses.w;
	float sight = sin(clock * 3.0 - p.y * 17.0) * senses.z;
	uv += normalize(p + vec2(0.0001)) * (sound * 0.009 + touch * 0.012 + scent * 0.009);
	uv.x += sin(p.y * 14.0 + clock * 2.0) * senses.w * 0.007;
	uv.y += sight * 0.004;
	vec4 art = texture(TEXTURE, uv);
	vec3 hue = mix(vec3(0.76,1.0,0.93),vec3(1.0,0.91,0.66),senses.y * 0.45 + senses.w * 0.4);
	art.rgb *= hue * (0.86 + activity * 0.28 + sound * 0.06 + touch * 0.07);
	COLOR = vec4(art.rgb, art.a * (0.72 + activity * 0.28));
}
