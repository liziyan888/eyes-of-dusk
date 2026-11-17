extends Control
## Quiet reading artwork with separate painted objects and causal, tactile input.
const ObjectArt=preload("res://scripts/grassland_object.gd")
const HandAlpha=preload("res://shaders/creek_sample_alpha.gdshader")
const BASE:=Vector2(1280,720)
var page:Dictionary={}
var kind:="panorama"
var background:TextureRect
var objects:Array=[]
var hands:Dictionary={}
var hand_meta:Dictionary={}
var target:=BASE*Vector2(.5,.5)
var pointer:=Vector2.ZERO
var holding:=false
var energy:=0.0
var clock:=0.0
var gaze:=Vector2.ZERO
var hand_reach:=0.0
var wind_strength:=0.0
var bird_progress:=-1.0
var active:=false
var _hand_config:Dictionary={}
var _hand_rest:=BASE*Vector2(1.03,.94)
var _hand_contact:=Vector2.ZERO
var _last_pointer:=Vector2.ZERO
var _drag_speed:=0.0
var _listen_amount:=0.0

func _ready()->void:
	size=BASE;mouse_filter=MOUSE_FILTER_IGNORE;clip_contents=true;set_process(false)

func configure(data:Dictionary)->void:
	page=data.duplicate(true);kind=str(page.get("kind","panorama"));target=_coord(page.get("target"),BASE*.5)
	background=TextureRect.new();background.name="Background";background.texture=_asset(str(page.get("background","")));background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;background.size=BASE;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	for entry in page.get("layers",[]):
		if not entry is Dictionary:continue
		var texture:=_asset(str(entry.get("file","")))
		var frames:Array[Texture2D]=[]
		for frame_entry in entry.get("frames",[]):
			var frame:=_frame_asset(frame_entry)
			if frame!=null:frames.append(frame)
		if not frames.is_empty():texture=frames[0]
		var item:=ObjectArt.new();item.configure(entry,texture,frames);item.z_index=int(entry.get("z",2));add_child(item);objects.append(item)
	_hand_config=page.get("hand",{})
	_hand_rest=_coord(_hand_config.get("rest"),BASE*Vector2(1.03,.94));_hand_contact=_coord(_hand_config.get("contact"),target)
	if kind in ["flower","grass","wind"]:_create_hands()
	reset_vignette()

func _asset(path:String)->Texture2D:
	if path.is_empty():return null
	var full:=path if path.begins_with("res://") else "res://assets/grassland-v2/"+path
	# Exported PNGs are remapped to imported resources; the raw file may be absent.
	if ResourceLoader.exists(full):return load(full) as Texture2D
	if FileAccess.file_exists(full) and full.get_extension().to_lower()=="png":
		var image:=Image.new()
		if image.load(full)==OK:return ImageTexture.create_from_image(image)
	return null

func _frame_asset(value:Variant)->Texture2D:
	if not value is Dictionary:return _asset(str(value))
	var source:=_asset(str(value.get("file","")))
	if source==null:return null
	var raw:Variant=value.get("region")
	if not raw is Array or raw.size()<4:return source
	var source_size:=source.get_size()
	var region:=Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
	if absf(region.position.x)<=1:region.position.x*=source_size.x
	if absf(region.position.y)<=1:region.position.y*=source_size.y
	if absf(region.size.x)<=1:region.size.x*=source_size.x
	if absf(region.size.y)<=1:region.size.y*=source_size.y
	if region.size.x<=0 or region.size.y<=0:return null
	var atlas:=AtlasTexture.new();atlas.atlas=source;atlas.region=region;atlas.filter_clip=true
	return atlas

func _vector(value:Variant,fallback:Vector2)->Vector2:
	return Vector2(float(value[0]),float(value[1])) if value is Array and value.size()>=2 else fallback

func _coord(value:Variant,fallback:Vector2)->Vector2:
	if not value is Array or value.size()<2:return fallback
	var result:=_vector(value,Vector2.ZERO)
	return result*BASE if absf(result.x)<=2 and absf(result.y)<=2 else result

func _create_hands()->void:
	var approved:Dictionary={}
	var source:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/creek-sample/manifest.json")) if FileAccess.file_exists("res://assets/creek-sample/manifest.json") else {}
	if source is Dictionary:approved=source.get("hands",{})
	for pose in (["wind"] if kind=="wind" else ["rest","reach","touch"]):
		var entry:Dictionary=approved.get(pose,{}).duplicate(true)
		var file:=str(_hand_config.get("file","res://assets/grassland-v2/hand-wind.png")) if pose=="wind" else "res://assets/creek-sample/"+str(entry.get("file","hand-"+pose+".png"))
		var texture:=_asset(file)
		var node:=Sprite2D.new();node.name="Hand"+str(pose).capitalize();node.texture=texture;node.centered=false;node.z_index=5;add_child(node);hands[pose]=node
		var pivot:=_vector(_hand_config.get("pivot"),Vector2(.65,.72)) if pose=="wind" else _vector(entry.get("pivot"),Vector2(.63,.67))
		var tip:=_vector(_hand_config.get("tip"),Vector2(.22,.31)) if pose=="wind" else _vector(entry.get("tip"),Vector2(.145,.178))
		hand_meta[pose]={"pivot":pivot,"tip":tip}
		var alpha:=ShaderMaterial.new();alpha.shader=HandAlpha;alpha.set_shader_parameter("alpha_cutoff",float(_hand_config.get("alpha_cutoff",.22)));alpha.set_shader_parameter("alpha_feather",.08);node.material=alpha

func reset_vignette()->void:
	holding=false;clock=0;energy=0;gaze=Vector2.ZERO;hand_reach=0;wind_strength=0;bird_progress=-1;_listen_amount=0;_drag_speed=0;pointer=target;_last_pointer=pointer
	for item in objects:
		item.reset_motion()
		if item.kind=="bird":item.hide()
	_update_hand()

func set_active(value:bool)->void:
	active=value;visible=value
	if not value:end_hold()

func is_interaction_point(point:Vector2)->bool:
	if point.y<60 or point.y>585:return false
	if kind in ["panorama","listen"]:return Rect2(20,60,1240,525).has_point(point)
	if kind=="flower":return point.distance_to(interaction_target())<180
	if kind=="grass":return Rect2(150,210,1000,375).has_point(point)
	return point.distance_to(target)<270

func interaction_target()->Vector2:
	if kind=="flower":
		for item in objects:
			if item.kind=="flower":return item.art_point(_vector(item.definition.get("head"),Vector2(.5,.2)))
	return target

func begin_hold(point:Vector2)->void:
	if holding:return
	holding=true;pointer=point;_last_pointer=point
	if kind=="listen" and bird_progress>=1.0:bird_progress=-1.0

func drag_hold(point:Vector2,relative:Vector2)->void:
	if not holding:return
	pointer=point;_last_pointer=point;_drag_speed=minf(2.5,_drag_speed+relative.length()*.012)
	if kind=="panorama":gaze=Vector2(clampf(gaze.x-relative.x/520.0,-1,1),clampf(gaze.y-relative.y/400.0,-1,1))

func end_hold()->void:holding=false

func step(delta:float)->void:
	if not active:return
	clock+=delta;_drag_speed=move_toward(_drag_speed,0,delta*1.5)
	energy=move_toward(energy,1.0 if holding else 0.0,delta*(1.3 if holding else .8))
	hand_reach=move_toward(hand_reach,1.0 if holding else 0.0,delta/(1.0 if holding else .85))
	var breeze:=.24
	if kind=="wind":breeze=.3+energy*.95
	elif kind=="listen":breeze=.28+energy*.34
	wind_strength=lerpf(wind_strength,breeze,1.0-exp(-delta*2.5))
	var grasp:=_smooth((hand_reach-.68)/.32)
	for item in objects:
		var force:=0.0
		if kind=="flower" and item.kind=="flower":force=grasp*24.0
		elif kind=="grass" and item.kind=="grass":
			var distance:float=item.base_position.x-pointer.x
			var proximity:=exp(-absf(distance)/300.0)
			var side:=-1.0 if distance<0 else 1.0
			force=grasp*side*(52.0+_drag_speed*18.0)*proximity
		elif kind=="wind" and item.kind=="grass":force=energy*(18+sin(clock*2.1-item.base_position.x*.006)*16)
		item.set_bend(force);item.set_environment(wind_strength,gaze);item.step(delta)
	if kind=="listen":_step_birds(delta)
	_update_hand()

func _step_birds(delta:float)->void:
	_listen_amount=move_toward(_listen_amount,1.0 if holding else 0.0,delta*2)
	if _listen_amount>.22 and bird_progress<0:bird_progress=0
	if bird_progress>=0:bird_progress=minf(1.1,bird_progress+delta/5.2)
	for item in objects:
		if item.kind!="bird":continue
		var phase:=float(item.motion.get("phase",0))
		if bird_progress<0:
			item.visible=false
			continue
		var t:=clampf(bird_progress-phase*.03,0,1)
		var start:Vector2=item.base_position
		var b:=start+Vector2(340,-100);var c:=Vector2(1080,150+phase*20);var d:=Vector2(1400,170+phase*20)
		item.position=_bezier(start,b,c,d,t)
		var next:=_bezier(start,b,c,d,minf(1,t+.01));var tangent:Vector2=next-item.position
		item.rotation=clampf(tangent.angle(),-.32,.32) if tangent.length()>.01 else 0.0
		item.visible=t<.999;item.set_bird_frame(int(clock*7.0+phase*2.0))

func _smooth(value:float)->float:
	var t:=clampf(value,0,1);return t*t*(3.0-2.0*t)

func _bezier(a:Vector2,b:Vector2,c:Vector2,d:Vector2,t:float)->Vector2:
	var u:=1.0-t;return a*u*u*u+b*3*u*u*t+c*3*u*t*t+d*t*t*t

func _update_hand()->void:
	if hands.is_empty():return
	for node in hands.values():node.hide()
	var pose:="wind" if kind=="wind" else "rest" if hand_reach<.07 else "touch" if hand_reach>.96 else "reach"
	var node:Sprite2D=hands[pose]
	if node.texture==null:return
	# Registered authored key poses are switched near the outer frame, never ghosted.
	var meta:Dictionary=hand_meta[pose]
	var contact:=interaction_target() if kind=="flower" else _hand_contact
	if kind=="grass":contact+=Vector2(clampf(pointer.x-target.x,-150,150)*.42,clampf(pointer.y-target.y,-70,40)*.2)
	var t:=_smooth(hand_reach)
	var tip:=_bezier(_hand_rest,_hand_rest+Vector2(-90,-55),contact+Vector2(30,-55),contact,t)
	var factor:=float(_hand_config.get("width",640))/node.texture.get_width()
	node.scale=Vector2.ONE*factor;node.offset=-node.texture.get_size()*meta.pivot
	node.position=tip-(meta.tip-meta.pivot)*node.texture.get_size()*factor;node.visible=true

func release_resources()->void:
	end_hold();active=false
