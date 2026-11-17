shader_type canvas_item;
render_mode unshaded;
uniform float elevation : hint_range(0.0,1.0) = 0.0;
void fragment() {
	// Adjust the device's actual field of view, without translating a hand sprite.
	vec2 extent=vec2(.87,.70);
	vec2 center=vec2(.55,mix(.65,.35,elevation));
	vec2 uv=center+(UV-.5)*extent;
	vec4 image=texture(TEXTURE,clamp(uv,vec2(0.0),vec2(1.0)));
	float peripheral=smoothstep(.13,.85,length((UV-.5)*vec2(1.0,.8)));
	image.rgb*=1.0-peripheral*.12;
	COLOR=image;
}
