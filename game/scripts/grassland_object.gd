extends Node2D
## One separately painted object. Only flexible plant vertices bend; its root stays put.
const BASE:=Vector2(1280,720)
var definition:Dictionary={}
var motion:Dictionary={}
var kind:="static"
var base_position:=Vector2.ZERO
var design_size:=Vector2.ONE
var pivot:=Vector2(.5,.5)
var clock:=0.0
var bend:=0.0
var bend_velocity:=0.0
var bend_target:=0.0
var parallax:=Vector2.ZERO
var sprite:Sprite2D
var mesh_node:MeshInstance2D
var rest_vertices:=PackedVector3Array()
var arrays:Array=[]
var mesh:ArrayMesh
var frames:Array[Texture2D]=[]
var _wind:=0.0
var _gaze:=Vector2.ZERO

func configure(data:Dictionary,texture:Texture2D,frame_textures:Array[Texture2D]=[])->void:
	definition=data.duplicate(true)
	var raw:Variant=data.get("motion","static")
	motion=raw.duplicate(true) if raw is Dictionary else {"type":str(raw)}
	for key in ["phase","depth","drift","amplitude","hz","stiffness","damping"]:
		if data.has(key) and not motion.has(key):motion[key]=data[key]
	kind=str(motion.get("type",motion.get("kind","static")))
	name=str(data.get("id","Object"))
	pivot=_vector(data.get("pivot"),Vector2(.5,.94) if kind in ["grass","flower","sway"] else Vector2(.5,.5))
	base_position=_vector(data.get("at"),Vector2(.5,.5))*BASE;position=base_position
	z_index=int(data.get("z",0))
	if texture==null:return
	design_size=texture.get_size()*(float(data.get("width",250))/texture.get_width())
	frames=frame_textures
	if frames.is_empty():frames.append(texture)
	if kind in ["grass","flower","sway"]:
		_build_plant(texture)
	else:
		sprite=Sprite2D.new();sprite.name="Artwork";sprite.texture=texture;sprite.centered=false;sprite.offset=-texture.get_size()*pivot;sprite.scale=Vector2.ONE*(design_size.x/texture.get_width());add_child(sprite)
	if data.has("opacity"):modulate.a=float(data.opacity)
	rotation=deg_to_rad(float(data.get("rotation",0)))
	set_process(false)

func _vector(value:Variant,fallback:Vector2)->Vector2:
	return Vector2(float(value[0]),float(value[1])) if value is Array and value.size()>=2 else fallback

func _build_plant(texture:Texture2D)->void:
	var columns:=12 if kind=="flower" else 20
	var rows:=28
	var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	for row in range(rows+1):
		for column in range(columns+1):
			var uv:=Vector2(float(column)/columns,float(row)/rows)
			var point:Vector2=(uv-pivot)*design_size
			rest_vertices.append(Vector3(point.x,point.y,0));uvs.append(uv)
	for row in range(rows):
		for column in range(columns):
			var a:=row*(columns+1)+column;var b:=a+1;var c:=a+columns+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=rest_vertices.duplicate();arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	mesh=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_node=MeshInstance2D.new();mesh_node.name="RootLockedPlant";mesh_node.texture=texture;mesh_node.mesh=mesh;add_child(mesh_node)

func set_environment(wind:float,gaze:Vector2)->void:
	_wind=wind;_gaze=gaze

func set_bend(value:float)->void:
	bend_target=value

func step(delta:float)->void:
	clock+=delta
	var phase:=float(motion.get("phase",0))
	var amplitude:=float(motion.get("amplitude",6 if kind=="flower" else 13))
	var hz:=float(motion.get("hz",.22 if kind=="flower" else .32))
	var natural:=sin(clock*TAU*hz+phase)*amplitude*(.28+_wind*.65)
	var target:=bend_target+natural+_wind*amplitude*.6
	var remaining:=delta
	while remaining>0:
		var dt:=minf(remaining,.016);remaining-=dt
		bend_velocity+=(target-bend)*float(motion.get("stiffness",34))*dt
		bend_velocity*=exp(-float(motion.get("damping",7.2))*dt)
		bend+=bend_velocity*dt
	var depth:=float(motion.get("depth",.2 if kind=="cloud" else 1.0))*32.0
	parallax=Vector2(-_gaze.x*depth,-_gaze.y*depth*.3)
	position=base_position+parallax
	if kind=="cloud":position.x+=(sin(clock*.025+phase)-sin(phase))*float(motion.get("drift",2.0))/.025
	if mesh_node!=null:_update_plant()

func _update_plant()->void:
	var vertices:PackedVector3Array=rest_vertices.duplicate()
	var uvs:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
	for i in range(vertices.size()):
		var height:=clampf((pivot.y-uvs[i].y)/maxf(.01,pivot.y),0,1)
		var weight:=height*height
		var local_wave:=sin(clock*1.9+uvs[i].x*2.0+float(motion.get("phase",0)))*absf(_wind)*3.0*height
		vertices[i].x+=(bend+local_wave)*weight
		vertices[i].y+=absf(bend)*.065*weight
	arrays[Mesh.ARRAY_VERTEX]=vertices
	mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)

func reset_motion()->void:
	clock=0;bend=0;bend_velocity=0;bend_target=0;_wind=0;_gaze=Vector2.ZERO;position=base_position
	if mesh_node!=null:_update_plant()

func set_bird_frame(index:int)->void:
	if sprite!=null and not frames.is_empty():sprite.texture=frames[posmod(index,frames.size())]

func tip_position()->Vector2:
	return position+Vector2(bend,-design_size.y*pivot.y)

func art_point(uv:Vector2)->Vector2:
	var point:Vector2=(uv-pivot)*design_size
	if mesh_node!=null:
		var height:=clampf((pivot.y-uv.y)/maxf(.01,pivot.y),0,1)
		point.x+=(bend+sin(clock*1.9+uv.x*2.0+float(motion.get("phase",0)))*absf(_wind)*3.0*height)*height*height
		point.y+=absf(bend)*.065*height*height
	return position+point.rotated(rotation)
