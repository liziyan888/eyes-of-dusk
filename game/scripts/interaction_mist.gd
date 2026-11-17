extends RefCounted
## Fixed radial motion, instanced on the GPU; no per-particle frame allocations.
const BURST_SHADER=preload("res://shaders/interaction_burst.gdshader")
var bursts: Array[Dictionary] = []
const BURST_LIFE:=4.8
const PARTICLE_COUNT:=680
const MAX_BURSTS:=4
var batches:Array[MultiMeshInstance2D]=[]
var geometry:MultiMesh
var prewarming:=false

func setup(canvas:CanvasItem)->void:
	if not batches.is_empty():return
	var quad:=QuadMesh.new();quad.size=Vector2(2,2)
	geometry=MultiMesh.new();geometry.transform_format=MultiMesh.TRANSFORM_2D;geometry.mesh=quad
	geometry.instance_count=PARTICLE_COUNT
	geometry.custom_aabb=AABB(Vector3(-600,-600,-1),Vector3(1200,1200,2))
	for index in range(PARTICLE_COUNT):geometry.set_instance_transform_2d(index,Transform2D.IDENTITY)
	for index in range(MAX_BURSTS):
		var node:=MultiMeshInstance2D.new();node.name="InteractionDust"+str(index);node.multimesh=geometry
		var material:=ShaderMaterial.new();material.shader=BURST_SHADER;material.set_shader_parameter("burst_life",BURST_LIFE);material.set_shader_parameter("burst_age",BURST_LIFE)
		node.material=material;canvas.add_child(node);node.hide();batches.append(node)
	# Render one fully transparent batch behind the initial cover. The first
	# interaction does not pay for the first shader/pipeline compilation.
	if DisplayServer.get_name()!="headless":
		prewarming=true;batches[0].position=Vector2(640,360);batches[0].show()
		RenderingServer.frame_post_draw.connect(_finish_prewarm,CONNECT_ONE_SHOT)

func _finish_prewarm()->void:
	prewarming=false
	if not is_instance_valid(batches[0]):return
	for burst in bursts:
		if int(burst.get("slot",-1))==0:return
	batches[0].hide()

func _release(burst:Dictionary)->void:
	var slot:=int(burst.get("slot",-1))
	if slot>=0 and slot<batches.size() and is_instance_valid(batches[slot]):batches[slot].hide()

func _free_slot()->int:
	for slot in range(batches.size()):
		var occupied:=false
		for burst in bursts:
			if int(burst.get("slot",-1))==slot:occupied=true;break
		if not occupied:return slot
	return -1

func hide_bursts()->void:
	for index in range(batches.size()):
		if not prewarming or index!=0:batches[index].hide()

func trigger(world_position: Vector2) -> void:
	var seed:=float(bursts.size())*1.93
	if bursts.size()>=MAX_BURSTS:_release(bursts.pop_front())
	bursts.append({"position":world_position,"age":0.0,"seed":seed,"slot":_free_slot()})

func update(delta: float) -> void:
	for index in range(bursts.size()-1,-1,-1):
		bursts[index].age+=delta
		if float(bursts[index].age)>=BURST_LIFE:
			_release(bursts[index]);bursts.remove_at(index)

func idle(canvas: CanvasItem,p: Vector2,time: float,amount:=1.0) -> void:
	# The fog fills the ring and smoothly disappears towards its edge.
	for i in range(16,0,-1):
		var radius:=float(i)*4.2
		canvas.draw_circle(p,radius,Color(.05,.10,.14,.004*amount))
		canvas.draw_circle(p,radius*.93,Color(.95,.98,1,.008*amount))
	for i in range(3):
		var phase:=fposmod(time*.29+float(i)/3.0,1.0)
		var radius:=9.0+phase*68.0
		var a:=sin(phase*PI)*pow(1.0-phase,1.15)*.82*amount
		canvas.draw_arc(p+Vector2(0,1),radius,0,TAU,72,Color(.04,.09,.08,a*.23),3.3,true)
		canvas.draw_arc(p,radius,0,TAU,72,Color(.97,1,.94,a),1.7,true)
		canvas.draw_arc(p,radius+1.5,0,TAU,72,Color(1,1,1,a*.12),4.4,true)
	canvas.draw_circle(p,9,Color(.95,.98,1,.065*amount))
	canvas.draw_circle(p,2.4+sin(time*2.0)*.25,Color(1,1,1,.98*amount))
	for i in range(5):
		var angle:=float(i)*2.4
		var d:=15.0+fposmod(float(i)*13.7,37.0)
		canvas.draw_circle(p+Vector2.from_angle(angle)*d, .75,Color(1,1,1,(.15+.23*sin(time+float(i)))*amount))

func draw(canvas: CanvasItem,game: Node) -> void:
	if batches.is_empty():setup(canvas)
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	for point in game.points():
		if not game.point_available(point):continue
		if game.completed.has(point.id) or game.active_id==str(point.id):continue
		var pos: Vector2=game.interaction_cue_world(point)-Vector2(game.camera_x,0)
		if pos.x < -90 or pos.x >1370:continue
		var distance:=absf(game.player_x-game.point_position(point).x)
		idle(canvas,pos,game.elapsed+float(point.x)*.002,.65 if distance>530 else 1.0)
		if distance<=game.interaction_radius(point):
			canvas.draw_string(game.font,pos+Vector2(-24,-31),"E 互动",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(.04,.08,.1,.98))
			canvas.draw_string(game.font,pos+Vector2(-25,-32),"E 互动",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
	for burst in bursts:
		var age:float=burst.age
		var p:Vector2=burst.position-Vector2(game.camera_x,0)
		var t:=clampf(age/BURST_LIFE,0,1)
		var r:=14.0+520.0*sin(t*PI*.5)
		var a:=pow(1.0-t,1.35)
		canvas.draw_arc(p,r,0,TAU,128,Color(.96,.99,1,a*.26),1.4+3*(1-t),true)
		canvas.draw_arc(p,r-7,0,TAU,128,Color(.96,.99,1,a*.06),18,true)
		if int(burst.get("slot",-1))<0:burst.slot=_free_slot()
		var node:MultiMeshInstance2D=batches[int(burst.slot)]
		node.position=game._world_origin()+p*float(game.zoom);node.scale=Vector2.ONE*float(game.zoom)
		node.material.set_shader_parameter("burst_age",age);node.material.set_shader_parameter("burst_seed",float(burst.seed));node.show()

func burst_particle(burst:Dictionary,index:int)->Dictionary:
	# Reference sampler for authoring/trajectory checks; never called by draw().
	# Direction is fixed at birth. No angular oscillation or vertical drift.
	var direction:=Vector2.from_angle(float(index)*2.399963+float(burst.seed))
	var delay:=fposmod(float(index)*.071,.42)
	var age:=maxf(0.0,float(burst.age)-delay)
	var t:=clampf(age/(BURST_LIFE-delay),0,1)
	var travel:=150.0+fposmod(float(index)*67.31,390.0)
	return {"position":Vector2(burst.position)+direction*travel*sin(t*PI*.5),"opacity":pow(1.0-t,1.5)*(.30+fposmod(float(index)*.31,.6))*smoothstep(0.0,.16,age),"size":.32+fposmod(float(index)*.77,.83)}
