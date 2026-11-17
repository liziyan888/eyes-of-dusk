shader_type canvas_item;
render_mode unshaded;
uniform float cutout=0.0;
uniform bool standing_cleanup=false;
void fragment(){
	vec4 paint=texture(TEXTURE,UV);
	paint.a=mix(paint.a,smoothstep(0.70,0.93,paint.a),cutout);
	if(standing_cleanup){
		vec2 px=TEXTURE_PIXEL_SIZE;
		float xp=texture(TEXTURE,UV+vec2(px.x*1.4,0.0)).a;
		float xm=texture(TEXTURE,UV-vec2(px.x*1.4,0.0)).a;
		float yp=texture(TEXTURE,UV+vec2(0.0,px.y*1.4)).a;
		float ym=texture(TEXTURE,UV-vec2(0.0,px.y*1.4)).a;
		float interior=min(min(xp,xm),min(yp,ym));
		vec2 gradient=vec2(xp-xm,yp-ym);
		vec2 inward=gradient/max(length(gradient),0.0001);
		vec4 body=texture(TEXTURE,UV+inward*px*3.0);
		// Only repair the exterior contour. Soft alpha inside white clothing,
		// insignia and shoelaces is authored paint, not background to erode.
		float exterior=1.0-smoothstep(.02,.60,interior);
		float edge=(1.0-smoothstep(.25,.95,interior))*smoothstep(.65,.98,body.a);
		paint.rgb=mix(paint.rgb,body.rgb,edge*.95);
		paint.a*=mix(1.0,smoothstep(.02,.50,interior),exterior);
	}
	COLOR=paint;
}
