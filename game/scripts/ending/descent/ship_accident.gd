extends Control
## Original 03B artwork split at the FRONT connector, never a mirrored tail clip.
const DIR="res://assets/ending/descent/"
const SHIP=preload("res://shaders/ending/descent_ship.gdshader")
const FLOW=preload("res://shaders/ending/metal_current.gdshader")
var backdrop:TextureRect
var current:TextureRect
var assembly:Node2D
var front:TextureRect
var hull:TextureRect
var sinking:=false
func _ready()->void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_IGNORE;clip_contents=true
	backdrop=picture("metal-background.png",self);backdrop.size=Vector2(1280,1008);backdrop.position.y=-140
	var mat:=ShaderMaterial.new();mat.shader=FLOW;backdrop.material=mat
	assembly=Node2D.new();add_child(assembly)
	hull=picture("ship.png",assembly);front=picture("ship.png",assembly)
	for piece in [front,hull]:
		var shader:=ShaderMaterial.new();shader.shader=SHIP;shader.set_shader_parameter("front_piece",piece==front);piece.material=shader
	current=picture("metal-foreground.png",self);current.size=Vector2(1408,1109);current.position=Vector2(-64,0)
	var flow:=ShaderMaterial.new();flow.shader=FLOW;flow.set_shader_parameter("strength",.006);current.material=flow
	set_accident(0)
func picture(name:String,parent:Node)->TextureRect:
	var node:=TextureRect.new();node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE;node.texture=load(DIR+name);node.size=Vector2(1280,720);node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func set_accident(t:float)->void:
	sinking=false;front.show();assembly.scale=Vector2.ONE*1.25;assembly.position=Vector2(-85,-90)
	var strain:=smoothstep(0.0,1.25,t)
	var part:=smoothstep(1.25,2.15,t)
	var engulf:=smoothstep(2.15,4.6,t)
	front.pivot_offset=Vector2(574,356)
	front.position=Vector2(-8,3)*strain+Vector2(-105,65)*part+Vector2(-70,85)*engulf
	front.rotation=-.025*strain-.09*part;front.modulate.a=1-smoothstep(.5,1,engulf)
	hull.position=Vector2.ZERO;hull.rotation=0
	for piece in [front,hull]:
		piece.material.set_shader_parameter("heat",.18)
		piece.material.set_shader_parameter("rim",(.12+.36*strain)*(1-part*.7))
		piece.material.set_shader_parameter("depth",.12)
	current.position=Vector2(-64,-80-310*engulf);current.modulate.a=.82
	backdrop.material.set_shader_parameter("clock",t);current.material.set_shader_parameter("clock",t)
func set_sink(t:float)->void:
	sinking=true;front.hide();hull.position=Vector2.ZERO;hull.rotation=0
	assembly.scale=Vector2.ONE*.82
	assembly.position=Vector2(-70,5+310*smoothstep(0,6.2,t))
	hull.material.set_shader_parameter("rim",0.0);hull.material.set_shader_parameter("heat",.12)
	hull.material.set_shader_parameter("depth",.25+.75*smoothstep(0,6.2,t))
	current.position=Vector2(-64,-120-60*smoothstep(0,6.2,t));current.modulate.a=.95
	backdrop.material.set_shader_parameter("clock",t+8);current.material.set_shader_parameter("clock",t+8)
