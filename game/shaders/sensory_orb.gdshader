shader_type canvas_item;
render_mode unshaded;
uniform float clock=0.0;
uniform vec4 senses=vec4(0.0);
uniform float sample_age=99.0;
uniform float sample_radius=1.0;
uniform float release_amount=0.0;
uniform vec2 contact=vec2(1.0,0.0);
uniform float bird=0.0;
uniform float ring_clock=0.0;
uniform float voice_amount=0.0;
uniform float voice_from_her=0.0;
float softline(float d,float width){return exp(-pow(d/width,2.0));}
vec2 rotate_point(vec2 p,float a){return vec2(cos(a)*p.x-sin(a)*p.y,sin(a)*p.x+cos(a)*p.y);}
float segment(vec2 p,vec2 a,vec2 b){vec2 v=b-a;return length(p-a-v*clamp(dot(p-a,v)/max(dot(v,v),.00001),0.0,1.0));}
void fragment(){
 vec2 p=(UV-.5)*2.0;
 p/=sample_radius;
 float touch=clamp(senses.y,0.0,1.0);
 float hearing=clamp(max(senses.x,voice_amount),0.0,1.0);
 float scent=clamp(senses.w,0.0,1.0);
 // Touch: one slow organic outer ellipse, pulled toward the contact direction.
 vec2 t=rotate_point(p-contact*touch*.09,-.23);
 vec2 touch_axes=vec2(.70+touch*.07*sin(clock*.95),.79-touch*.045*sin(clock*.95));
 float tr=length(t/touch_axes);
 float wave=sin(atan(t.y,t.x)*3.0-clock*.85)*touch*.055;
 float ta=softline(tr-1.0-wave,.045)*(.22+touch*.72);
 ta+=exp(-tr*tr*3.0)*touch*.035;
 // Hearing: a smaller cyan oval, with brief pulses and two moving highlights.
 vec2 h=rotate_point(p,.20);
 float pulse=.5+.5*sin(clock*(2.5+bird*1.4));
 vec2 sound_axes=vec2(.57,.35)*(1.0+hearing*(pulse-.5)*.15);
 float hr=length(h/sound_axes);
 float angle=atan(h.y/sound_axes.y,h.x/sound_axes.x);
 float highlight=pow(.5+.5*cos(angle-ring_clock*2.0),10.0);
 highlight+=pow(.5+.5*cos(angle-ring_clock*2.0+3.14159),10.0)*.65;
 float ha=softline(hr-1.0,.06)*(.20+hearing*(.48+.35*pulse+highlight*.24));
 // Smell: two intertwined gold filaments, with restrained ladder connections.
 float drift=clock*.65;
 float amplitude=.13+scent*.075;
 float phase=p.y*13.0+drift;
 float x=sin(phase)*amplitude;
 float envelope=1.0-smoothstep(.37,.49,abs(p.y));
 float helix=(softline(p.x-x,.022)+softline(p.x+x,.022))*envelope;
 float rungs=0.0;
 for(int i=0;i<9;i++){
  float y=-.37+float(i)*.0925;
  float end_x=sin(y*13.0+drift)*amplitude;
  rungs+=softline(segment(p,vec2(-end_x,y),vec2(end_x,y)),.012)*(.5+.5*abs(cos(y*13.0+drift)));
 }
 float sa=(helix*.85+rungs*.52)*(.10+scent*.9);
 vec3 violet=vec3(.788,.655,1.0);
 vec3 cyan=vec3(.475,.875,1.0);
 vec3 gold=vec3(.941,.816,.541);
 float core=exp(-dot(p,p)*13.0)*senses.z*.10;
 float alpha=ta+ha+sa+core;
 vec3 color=(violet*ta+cyan*ha+gold*sa+vec3(1.0,.94,.84)*core)/max(alpha,.0001);
 alpha*=1.0-smoothstep(.91,1.04,length((UV-.5)*2.0));
 COLOR=vec4(color,clamp(alpha,0.0,.96));
}
