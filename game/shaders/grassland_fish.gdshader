shader_type canvas_item;
uniform float clock=0.0;
uniform float impulse=0.0;
void fragment(){
 vec2 p=UV;
 float tail=smoothstep(.48,1.0,p.x);
 p.y+=sin(clock*(7.0+impulse*5.0)+p.x*4.0)*(.014+.018*impulse)*tail;
 COLOR=texture(TEXTURE,p);
}
