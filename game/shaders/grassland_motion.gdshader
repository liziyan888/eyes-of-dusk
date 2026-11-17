shader_type canvas_item;
uniform int scene=0;
uniform float clock=0.0;
uniform float energy=0.0;
uniform float reach=0.0;
uniform float reveal=1.0;
uniform vec2 contact=vec2(.5,.5);
uniform sampler2D restoration: source_color,filter_linear;

float blob(vec2 uv,vec2 c,vec2 extent){return 1.0-smoothstep(.58,1.0,length((uv-c)/extent));}
vec2 rotate_about(vec2 p,vec2 pivot,float a){vec2 d=p-pivot;return pivot+mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*d;}
void fragment(){
 vec2 p=UV;
 float strength=.25+energy;
 // Warp the original plant pixels around rooted stems, rather than overlaying a light.
 if(scene==0){p.x+=sin(clock*1.1+p.y*35.0)*.0014*strength*smoothstep(.57,.98,p.y);}
 if(scene==1){
  float petal=blob(p,vec2(.74,.46),vec2(.28,.40));
  p=mix(p,rotate_about(p,vec2(.73,.93),sin(clock*3.8)*.075*strength),petal);
  float hand=blob(p,vec2(.38,.52),vec2(.43,.6));p-=vec2(.018,-.018)*reach*hand;
 }
 if(scene==2||scene==3||scene==5){
  float root=smoothstep(scene==2?.02:.48,.82,p.y)*(1.0-smoothstep(.94,1.0,p.y));
  p.x+=sin(clock*1.8+p.y*12.0+p.x*7.0)*(.002+.009*energy)*root;
  p.y+=sin(clock*1.2+p.x*16.0)*.002*root*strength;
 }
 if(scene==3){
  p.x+=sin(clock*.65)*.009*blob(p,vec2(.62,.25),vec2(.3,.25));
 }
 if(scene==4){
  float water=blob(p,vec2(.52,.45),vec2(.40,.58));
  p+=vec2(sin(p.y*75.0-clock*2.0),cos(p.x*65.0+clock*1.6))*.0016*water*strength;
  float hand=blob(p,vec2(.82,.62),vec2(.30,.60));p-=vec2(-.018,.027)*reach*hand;
  // Original fish is drawn separately as a sprite. Sample only the adjacent water here.
 }
 if(scene==5){
  float hand=blob(p,vec2(.76,.62),vec2(.30,.55));
  p=mix(p,rotate_about(p,vec2(.89,.95),sin(clock*1.9)*.024*strength-reach*.018),hand);
 }
 vec4 c=texture(TEXTURE,clamp(p,vec2(.001),vec2(.999)));
 if(scene==4){
  float old_fish=1.0-smoothstep(.86,1.0,length((UV-vec2(.502,.535))/vec2(.12,.18)));
  vec4 clear_water=texture(restoration,clamp(p,vec2(.001),vec2(.999)));
  c=mix(c,clear_water,old_fish);
 }
 if(scene==2){c.rgb*=1.0+.018*sin(clock*1.5+p.y*21.0)*strength;}
 float gray=dot(c.rgb,vec3(.299,.587,.114));
 c.rgb=mix(vec3(gray)*.85,c.rgb,reveal);
 COLOR=c;
}
