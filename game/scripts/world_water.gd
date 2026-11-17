extends RefCounted
## A painted water-surface anchor, an authored reach, and actual fingertip feedback.
var active:=false
var phase:=""
var point:Dictionary={}
var ground_y:=700.0
var stance:=Vector2.ZERO
var route_start:=Vector2.ZERO
var route_time:=0.0
var route_duration:=.8
var route_x:=0.0
var route_ground:=700.0
var contact_elapsed:=0.0
var touched:=false
var foley:AudioStreamPlayer
var calibration:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/water_contact.json"))
var fish:Texture2D=preload("res://assets/creek-sample/fish-right.png")
var fish_region:Rect2

func setup(game:Node)->void:
	foley=AudioStreamPlayer.new();foley.bus="Effects";foley.volume_db=-8;foley.stream=load("res://assets/grassland-creek-clean-frames/action-sound.mp3");game.add_child(foley)
	var image:=fish.get_image();if image.is_compressed():image.decompress()
	fish_region=Rect2(image.get_used_rect())

func reset()->void:
	active=false;phase="";touched=false;contact_elapsed=0
	if foley!=null:foley.stop()

func begin(game:Node,value:Dictionary)->void:
	point=value;active=true;phase="invitation";touched=false;ground_y=game._ground();route_ground=ground_y;route_x=game.player_x
	game.moving=false;game.active_id=str(point.id);game.action_override="idle";game.dialogue_phase="water_invitation"
	game._open_dialogue([point.lines[1],{"who":"我","tone":"me","text":"好，我慢慢蹲下来，让指尖先碰到水。"}])

func start_approach(game:Node)->void:
	var target:Vector2=game.point_position(point)
	game.facing=1.0 # This authored reach is toward the stream to the right.
	var clip:Dictionary=game.action_player.clips.water;var ref:int=int(calibration.reference_frame)
	var tip:Array=calibration.tips[str(ref)];var origin:Array=clip.origins[ref]
	var offset:=Vector2(float(tip[0])-float(origin[0]),float(tip[1])-float(origin[1]))*float(clip.scale)*float(game.layout.data.player_scale)
	stance=target-offset;route_start=Vector2(game.player_x,ground_y);route_time=0
	route_duration=clampf(route_start.distance_to(stance)/110.0,.45,1.4);phase="approach";game.action_override="walk_v2"

func update(delta:float,game:Node)->void:
	if not active:return
	if phase in ["approach","return"]:
		route_time+=delta;var t:=clampf(route_time/route_duration,0,1)
		var target:=stance if phase=="approach" else Vector2(route_x,route_ground)
		var p:=route_start.lerp(target,t);var previous:=Vector2(game.player_x,ground_y)
		game.player_x=p.x;ground_y=p.y
		game.walk_phase=fposmod(game.walk_phase+p.distance_to(previous)/(game.SPEED*game.WALK_CYCLE),1.0)
		if t>=1:
			if phase=="approach":phase="reaching";game.action_override="water";game.pose="water";game.animation_time=0
			else:reset();game.action_override="";game.pose="idle";game.animation_time=0
	elif phase=="reaching":
		if game.animation_time>=float(calibration.touch_frame)/float(game.action_player.clips.water.fps):
			phase="contact";touched=true;contact_elapsed=0;foley.play(1.6);game._remember_experience("water")
			var lines:Array=[]
			for index in [2,4,5,7,8,9,10]:lines.append(point.lines[index])
			game.dialogue_phase="response";game._open_dialogue(lines)
	elif phase=="contact":
		contact_elapsed+=delta
		if game.action_override=="wind":phase="wind";foley.stop()
	elif phase=="withdraw" and not game.action_player.busy():_start_return(game)

func actor_pose(game:Node)->String:
	if phase in ["approach","return"]:return "walk_v2"
	if phase=="invitation":return "idle"
	if phase=="wind":return "wind"
	return "water"

func finish(game:Node)->void:
	foley.stop()
	if game.pose=="water":game.action_player.finish("water",game.animation_time);phase="withdraw"
	else:_start_return(game)

func _start_return(game:Node)->void:
	phase="return";route_start=Vector2(game.player_x,ground_y);route_time=0;route_duration=.7;game.action_override="walk_v2"

func tip_world(game:Node)->Vector2:
	var index:int=game.current_frame();var key:=str(index)
	if not calibration.tips.has(key):key=str(calibration.reference_frame)
	var tip:Array=calibration.tips[key];var origin:Vector2=game.pose_origins.water[index]
	var offset:Vector2=(Vector2(tip[0],tip[1])-origin)*game.pose_scales.water[index]*float(game.layout.data.player_scale)
	var breath:=1.0+sin(game.elapsed*2.1)*.004
	return Vector2(game.player_x+offset.x*game.facing,ground_y+offset.y*breath)

func draw_surface(canvas:CanvasItem,game:Node)->void:
	if not active or phase!="contact" or game.pose!="water":return
	var contact:Vector2=tip_world(game)-Vector2(game.camera_x,0)
	for ring in range(3):
		var t:=fposmod(contact_elapsed*.65+float(ring)/3,1)
		canvas.draw_set_transform(game._world_origin()+contact*game.zoom,0,Vector2(1,.24)*game.zoom)
		canvas.draw_arc(Vector2.ZERO,3+t*27,0,TAU,48,Color(.85,.97,1,(1-t)*.40),1,true)
	if contact_elapsed<2.0:
		var t:=contact_elapsed/2.0;var pos:=contact+Vector2(18+72*t,-4+sin(t*4)*3)
		canvas.draw_set_transform(game._world_origin()+pos*game.zoom,0,Vector2.ONE*game.zoom)
		canvas.draw_texture_rect_region(fish,Rect2(-7,-3,14,6),fish_region,Color(1,1,1,sin(t*PI)*.48))
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
