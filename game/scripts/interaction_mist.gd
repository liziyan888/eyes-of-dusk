extends RefCounted
## Analytic, frame-rate independent mist ripples and long-travelling dust. No video loops.
var bursts: Array[Dictionary] = []
const BURST_LIFE:=4.8
const PARTICLE_COUNT:=680

func trigger(world_position: Vector2) -> void:
	bursts.append({"position":world_position,"age":0.0,"seed":float(bursts.size())*1.93})
	if bursts.size()>4:bursts.pop_front()

func update(delta: float) -> void:
	for b in bursts:b.age+=delta
	bursts=bursts.filter(func(b):return b.age<BURST_LIFE)

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
		for i in range(PARTICLE_COUNT):
			var particle:=burst_particle(burst,i)
			var q:Vector2=particle.position-Vector2(game.camera_x,0)
			var opacity:float=particle.opacity
			var size:float=particle.size
			if i%4==0:canvas.draw_circle(q,size*2.8,Color(.94,.98,1,opacity*.075))
			canvas.draw_circle(q,size,Color(.96,.99,1,opacity))

func burst_particle(burst:Dictionary,index:int)->Dictionary:
	# Direction is fixed at birth. No angular oscillation or vertical drift.
	var direction:=Vector2.from_angle(float(index)*2.399963+float(burst.seed))
	var delay:=fposmod(float(index)*.071,.42)
	var age:=maxf(0.0,float(burst.age)-delay)
	var t:=clampf(age/(BURST_LIFE-delay),0,1)
	var travel:=150.0+fposmod(float(index)*67.31,390.0)
	return {"position":Vector2(burst.position)+direction*travel*sin(t*PI*.5),"opacity":pow(1.0-t,1.5)*(.30+fposmod(float(index)*.31,.6))*smoothstep(0.0,.16,age),"size":.32+fposmod(float(index)*.77,.83)}
