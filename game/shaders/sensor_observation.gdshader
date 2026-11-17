shader_type canvas_item;
render_mode unshaded;
uniform int mode=0;
uniform bool flip_art=false;
uniform float attention=0.0;
uniform float effect_clock=0.0;
uniform int glass_focus=0;
uniform vec2 led_points[64];
uniform ivec3 led_sizes=ivec3(0);
bool in_led(vec2 p,int start,int count){
	bool inside=false;
	if(count<3){return false;}
	for(int i=0;i<28;i++){
		if(i>=count){break;}
		int j=(i+count-1)%count;
		vec2 a=led_points[start+i],b=led_points[start+j];
		if((a.y>p.y)!=(b.y>p.y) && p.x<(b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x){inside=!inside;}
	}
	return inside;
}
void fragment(){
	vec2 uv=UV;vec2 source=vec2(flip_art?1.0-uv.x:uv.x,uv.y);
	vec4 c=texture(TEXTURE,source);
	if(mode==1 && attention>0.001){
		bool led=in_led(uv,0,led_sizes.x)||in_led(uv,led_sizes.x,led_sizes.y)||in_led(uv,led_sizes.x+led_sizes.y,led_sizes.z);
		if(led){float lum=dot(c.rgb,vec3(.299,.587,.114));vec3 warm=min(vec3(1),vec3(1,.70,.25)*(lum/.70));c.rgb=mix(c.rgb,warm,attention);}
		float reflection=pow(max(0.,1.-abs(uv.x+uv.y*.2-(.3+mod(effect_clock*.12,1.)*.6))/.10),2.);
		float visor=1.-smoothstep(.25,.30,length((uv-vec2(.54,.49))*vec2(1.,.70)));
		c.rgb+=vec3(1.,.80,.60)*reflection*visor*attention*.045;
	}else if(mode==2 && attention>0.001){
		float band=pow(max(0.,1.-abs(uv.x+uv.y*.16-(-.20+mod(effect_clock*.42,1.)*1.65))/.13),2.);
		float garment=1.-smoothstep(.775,.80,uv.x);
		c.rgb=mix(c.rgb,vec3(1.),band*garment*attention*.24);
	}else if(mode==3 && attention>0.001){
		if(glass_focus==1){
			float lens=(1.-smoothstep(.18,.23,length((uv-vec2(.46,.50))*vec2(.9,1.8))));
			float glint=pow(max(0.,1.-abs(uv.x+uv.y*.22-(.35+mod(effect_clock*.08,1.)*.24))/.035),2.);
			c.rgb+=vec3(.70,.86,1.)*lens*glint*attention*.08;
		}else{
			float sensor=1.-smoothstep(.025,.06,length((uv-vec2(.655,.415))*vec2(1.,2.)));
			c.rgb+=vec3(.35,.75,1.)*sensor*attention*.045;
		}
	}
	COLOR=c;
}
