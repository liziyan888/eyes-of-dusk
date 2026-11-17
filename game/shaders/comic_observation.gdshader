shader_type canvas_item;
uniform vec2 image_size=vec2(1280.0,720.0);
uniform vec2 scan_point=vec2(-1000.0);
uniform float scan_strength=0.0;
uniform vec2 clue_point=vec2(-1000.0);
uniform float clue_glow=0.0;
varying vec2 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 float lens=1.0-smoothstep(65.0,112.0,distance(local_position,scan_point));
 float spot=1.0-smoothstep(30.0,110.0,distance(local_position,clue_point));
 vec3 lit=c.rgb*(.91+.12*lens*scan_strength);
 lit+=vec3(.055,.12,.14)*spot*clue_glow*(.65+.35*sin(TIME*2.8));
 COLOR=vec4(lit,c.a);
}
