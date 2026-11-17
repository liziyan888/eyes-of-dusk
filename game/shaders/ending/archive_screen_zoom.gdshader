shader_type canvas_item;
uniform float progress : hint_range(0.0,1.0) = 0.0;
// Inner display corners measured on the decoded 1280 x 720 collapse end frame.
uniform vec2 top_left = vec2(0.4555,0.0875);
uniform vec2 top_right = vec2(0.9453,0.0528);
uniform vec2 bottom_left = vec2(0.4555,0.5208);
uniform vec2 bottom_right = vec2(0.9453,0.5097);
void fragment() {
	vec2 screen_uv = mix(mix(top_left,top_right,UV.x),mix(bottom_left,bottom_right,UV.x),UV.y);
	COLOR = texture(TEXTURE,mix(UV,screen_uv,progress));
}
