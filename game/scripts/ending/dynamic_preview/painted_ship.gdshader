shader_type spatial;
render_mode diffuse_burley,specular_schlick_ggx;
uniform sampler2D painted_reference:source_color,filter_linear_mipmap;
uniform sampler2D hull_atlas:source_color,filter_linear_mipmap;
uniform bool use_atlas=false;
uniform vec4 atlas_region=vec4(0.0,0.0,.5,.5);
uniform mat4 craft_inverse;
uniform vec4 base_color:source_color=vec4(.6,.65,.7,1.0);
uniform float heat_clock=0.0;
uniform float heat_pressure=0.0;
varying vec3 paint_position;
void vertex(){paint_position=(craft_inverse*MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	vec2 art_uv=vec2(mix(.080,.939,clamp((paint_position.x+4.5)/8.65,0.0,1.0)),clamp(.50-paint_position.y*.255,.20,.80));
	vec3 ink=texture(painted_reference,art_uv).rgb;
	if(use_atlas){
		vec2 region_uv=atlas_region.xy+clamp(UV,vec2(.012),vec2(.988))*atlas_region.zw;
		ink=texture(hull_atlas,region_uv).rgb;
	}
	vec3 paint=use_atlas ? ink*(.72+base_color.rgb*.28) : base_color.rgb*(.38+ink*.94);
	ALBEDO=paint;
	ROUGHNESS=.82;METALLIC=.18;SPECULAR=.23;
	float warm_band=.5+.5*sin(paint_position.x*1.3-heat_clock*.65);
	float belly=1.0-smoothstep(-.6,.2,paint_position.y);
	EMISSION=paint*vec3(.045,.006,.001)*belly*warm_band*(.4+heat_pressure*.6);
	ALPHA=1.0;
}
