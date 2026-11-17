extends Control
const Mix=preload("res://scripts/audio_mix.gd")
## Standalone approval sample. Background pixels never move or deform.
## Input drives independent hand poses and a continuous, locally swimming fish.
const BASE:=Vector2(1280,720)
const ART:="res://assets/creek-sample/"
const TEXT:="一条突然出现的小溪，小溪中的一条小鱼，都会令她激动不已。"
const HandAlpha=preload("res://shaders/creek_sample_alpha.gdshader")
const FishTone=preload("res://shaders/creek_sample_fish_tone.gdshader")
const FISH_COLUMNS:=48
const FISH_ROWS:=8
@export var embedded:=false
var manifest:Dictionary={}
var sample_ready:=false
var phase:="rest"
var approach_progress:=0.0
var contact_active:=false
var touch_count:=0
var interaction_held:=false
var active_hand_pose:="rest"
var ripples:Array[Dictionary]=[]
var fish_state:="idle"
var fish_progress:=0.0
var fish_position:=Vector2.ZERO
var water_hit_rect:=Rect2(250,180,860,385)
var contact_point:=BASE*Vector2(.67,.57)
var background:TextureRect
var hand_layer:Node2D
var fish_layer:Node2D
var fish_left:Sprite2D
var fish_right:Sprite2D
var water_effects:Control
var contact_shadow:Control
var reading:Label
var hint:Label
var readiness:Label
var stream:AudioStreamPlayer
var wind:AudioStreamPlayer
var hand_nodes:Dictionary={}
var hand_data:Dictionary={}
var fish_left_frames:Array[Texture2D]=[]
var fish_right_frames:Array[Texture2D]=[]
var fish_meshes:Dictionary={}
var fish_speed:=0.0
var fish_motion_amplitude:=1.4
var fish_motion_frequency:=1.2
var _fish_mesh_data:Dictionary={}
var _fish_swim:Dictionary={}
var _fish_swim_phase:=0.0
var occluders:Array[Polygon2D]=[]
var _clock:=0.0
var _phase_elapsed:=0.0
var _approach_seconds:=1.15
var _withdraw_seconds:=.85
var _hand_tip:=Vector2.ZERO
var _rest_tip:=BASE*Vector2(1.13,.84)
var _approach_start:=Vector2.ZERO
var _withdraw_start:=Vector2.ZERO
var _withdraw_pose:="touch"
var _fish_home:=BASE*Vector2(.49,.46)
var _fish_left_hide:=BASE*Vector2(.265,.645)
var _fish_right_hide:=BASE*Vector2(.91,.265)
var _fish_path:PackedVector2Array=PackedVector2Array()
var _fish_elapsed:=0.0
var _fish_width:=153.0
var _fish_fps:=8.0
var _fish_heading:="left"
var _fish_shelter:="left"
var _fish_flee_seconds:=1.45
var _fish_return_seconds:=2.35
var _fish_idle_clock:=0.0
var _fish_rotation:=0.0
var _mouse_held:=false
var _key_held:=false
var _last_ripple_tip:=Vector2.ZERO
var _bg_draw_rect:=Rect2(Vector2.ZERO,BASE)
var _water_polygon:=PackedVector2Array()
var _audio_enabled:=false

func _ready()->void:
	size=BASE;mouse_filter=MOUSE_FILTER_IGNORE if embedded else MOUSE_FILTER_STOP
	if not embedded:
		get_window().content_scale_size=Vector2i(1280,720)
		get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_window().content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	background=TextureRect.new();background.name="Background";background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;background.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;background.size=BASE;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	fish_layer=Node2D.new();fish_layer.name="FishLayer";fish_layer.z_index=2;add_child(fish_layer)
	fish_left=Sprite2D.new();fish_left.name="FishLeft";fish_layer.add_child(fish_left)
	fish_right=Sprite2D.new();fish_right.name="FishRight";fish_layer.add_child(fish_right)
	hand_layer=Node2D.new();hand_layer.name="HandLayer";hand_layer.z_index=5;add_child(hand_layer)
	contact_shadow=Control.new();contact_shadow.name="FingertipShadow";contact_shadow.z_index=4;contact_shadow.size=BASE;contact_shadow.mouse_filter=MOUSE_FILTER_IGNORE;add_child(contact_shadow);contact_shadow.draw.connect(_draw_contact_shadow)
	for key in ["rest","reach","touch","withdraw"]:
		var node:=Sprite2D.new();node.name="Hand"+str(key).capitalize();node.centered=false;hand_layer.add_child(node);hand_nodes[key]=node
	water_effects=Control.new();water_effects.name="WaterEffects";water_effects.z_index=4;water_effects.size=BASE;water_effects.mouse_filter=MOUSE_FILTER_IGNORE;add_child(water_effects);water_effects.draw.connect(_draw_water)
	if not embedded:_make_reading()
	else:
		readiness=Label.new();readiness.name="AssetStatus";readiness.hide();add_child(readiness)
	stream=AudioStreamPlayer.new();stream.name="StreamAmbience";stream.bus="Ambience";stream.volume_db=-11;add_child(stream)
	wind=AudioStreamPlayer.new();wind.name="WindAmbience";wind.bus="Ambience";wind.volume_db=-13;add_child(wind)
	if not embedded:
		stream.stream=Mix.stream("res://assets/grassland/nature-minimax.wav");wind.stream=Mix.stream("res://assets/prologue/audio/wind-minimax.wav")
	_audio_enabled=not embedded and DisplayServer.get_name()!="headless"
	reload_assets();reset_sample()
	if _audio_enabled:stream.play();wind.play()
	if embedded:set_process(false)

func _make_reading()->void:
	var g:=Gradient.new();g.set_color(0,Color(.03,.08,.095,0));g.set_color(1,Color(.03,.08,.095,.23))
	var texture:=GradientTexture2D.new();texture.gradient=g;texture.fill_from=Vector2(.5,0);texture.fill_to=Vector2(.5,1)
	var plate:=TextureRect.new();plate.name="ReadingVeil";plate.texture=texture;plate.position=Vector2(0,575);plate.size=Vector2(1280,145);plate.mouse_filter=MOUSE_FILTER_IGNORE;plate.z_index=8;add_child(plate)
	reading=_label(TEXT,Rect2(110,615,1060,58),24,true);reading.name="Reading";reading.z_index=9
	hint=_label("按住右侧水面（或 E），松开收手",Rect2(220,681,840,24),13,false);hint.name="GestureHint";hint.modulate.a=.68;hint.z_index=9
	readiness=_label("",Rect2(200,270,880,70),19,false);readiness.name="AssetStatus";readiness.z_index=20
	var reset_button:=_quiet_button("重看  R",Rect2(1050,25,92,30));reset_button.pressed.connect(reset_sample)
	var full_button:=_quiet_button("全屏  F11",Rect2(1145,25,105,30));full_button.pressed.connect(_toggle_fullscreen)

func _label(text:String,rect:Rect2,font_size:int,serif:bool)->Label:
	var node:=Label.new();node.text=text;node.position=rect.position;node.size=rect.size;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["Noto Serif CJK SC","SimSun","Microsoft YaHei"] if serif else ["Microsoft YaHei","Noto Sans CJK SC"])
	node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color(.97,.97,.91,.98));node.add_theme_color_override("font_shadow_color",Color(.025,.045,.055,.40));node.add_theme_constant_override("shadow_offset_x",0);node.add_theme_constant_override("shadow_offset_y",1);add_child(node);return node

func _quiet_button(text:String,rect:Rect2)->Button:
	var button:=Button.new();button.text=text;button.position=rect.position;button.size=rect.size;button.z_index=9
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size",13);button.add_theme_color_override("font_color",Color(.15,.22,.22,.72));button.add_theme_color_override("font_hover_color",Color(.10,.16,.16,1));button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;add_child(button);return button

func _coord(value:Variant,fallback:Vector2)->Vector2:
	if not value is Array or value.size()<2:return fallback
	var p:=Vector2(float(value[0]),float(value[1]));return p*BASE if absf(p.x)<=2 and absf(p.y)<=2 else p

func _uv(value:Variant,fallback:Vector2)->Vector2:
	return Vector2(float(value[0]),float(value[1])) if value is Array and value.size()>=2 else fallback

func _asset(path:String)->Texture2D:
	if path.is_empty():return null
	var full:=path if path.begins_with("res://") else ART+path
	# ResourceLoader resolves the imported texture inside a portable PCK.
	if ResourceLoader.exists(full):return load(full) as Texture2D
	if FileAccess.file_exists(full) and full.get_extension().to_lower()=="png":
		var image:=Image.new()
		if image.load(full)==OK:return ImageTexture.create_from_image(image)
	return null

func _frame_list(value:Variant,fallback:String)->Array[Texture2D]:
	var result:Array[Texture2D]=[]
	var files:Array=value if value is Array else [fallback]
	for item in files:
		var texture:=_asset(str(item))
		if texture!=null:result.append(texture)
	return result

func reload_assets()->void:
	manifest={}
	if FileAccess.file_exists(ART+"manifest.json"):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(ART+"manifest.json"))
		if parsed is Dictionary:manifest=parsed
	background.texture=_asset(str(manifest.get("background","background.png")))
	if background.texture!=null:
		var texture_size:=background.texture.get_size();var factor:=maxf(BASE.x/texture_size.x,BASE.y/texture_size.y);_bg_draw_rect=Rect2((BASE-texture_size*factor)*.5,texture_size*factor)
	contact_point=_coord(manifest.get("contact_point"),BASE*Vector2(.67,.57))
	var water:Array=manifest.get("water_rect",[.54,.38,.31,.30])
	water_hit_rect=Rect2(_coord(water.slice(0,2),Vector2(280,172)),_coord(water.slice(2,4),Vector2(850,380)))
	_water_polygon=PackedVector2Array()
	for point in manifest.get("water_polygon",[]):_water_polygon.append(_coord(point,Vector2.ZERO))
	var hand:Dictionary=manifest.get("hand",{})
	_approach_seconds=maxf(.2,float(hand.get("approach_seconds",1.15)));_withdraw_seconds=maxf(.2,float(hand.get("withdraw_seconds",.85)))
	_rest_tip=_coord(hand.get("rest_tip"),BASE*Vector2(1.13,.84))
	var poses:Dictionary=manifest.get("hands",hand.get("poses",{}))
	hand_data.clear()
	var all_hands:=true
	for key in hand_nodes:
		var entry:Dictionary=poses.get(key,hand.get(key,{})).duplicate(true)
		var texture:=_asset(str(entry.get("file","hand-"+str(key)+".png")))
		if texture==null and key=="withdraw":texture=_asset("hand-reach.png")
		if texture==null:all_hands=false
		entry["texture"]=texture;entry["pivot_uv"]=_uv(entry.get("pivot"),Vector2(.63,.67));entry["tip_uv"]=_uv(entry.get("tip"),Vector2(.15,.145));entry["width_px"]=float(entry.get("width",hand.get("width",640)));entry["rotation"]=deg_to_rad(float(entry.get("rotation_deg",0)))
		hand_data[key]=entry
		var node:Sprite2D=hand_nodes[key];node.texture=texture
		var alpha:=ShaderMaterial.new();alpha.shader=HandAlpha;alpha.set_shader_parameter("alpha_cutoff",float(entry.get("alpha_cutoff",hand.get("alpha_cutoff",.23))));alpha.set_shader_parameter("alpha_feather",float(entry.get("alpha_feather",hand.get("alpha_feather",.08))));node.material=alpha
	var fish:Dictionary=manifest.get("fish",{})
	_fish_home=_coord(fish.get("home"),BASE*Vector2(.49,.46));_fish_left_hide=_coord(fish.get("left_hide"),BASE*Vector2(.265,.645));_fish_right_hide=_coord(fish.get("right_hide"),BASE*Vector2(.91,.265))
	_fish_width=float(fish.get("width",153));_fish_fps=maxf(1,float(fish.get("fps",8)));_fish_flee_seconds=maxf(.4,float(fish.get("flee_seconds",1.45)));_fish_return_seconds=maxf(.7,float(fish.get("return_seconds",2.35)))
	fish_left_frames=_frame_list(fish.get("left_frames"),str(fish.get("left","fish-left.png")));fish_right_frames=_frame_list(fish.get("right_frames"),str(fish.get("right","fish-right.png")))
	_fish_swim=fish.get("swim",{})
	_setup_fish_mesh("left",fish_left,fish_left_frames,fish)
	_setup_fish_mesh("right",fish_right,fish_right_frames,fish)
	_make_occluders()
	sample_ready=background.texture!=null and all_hands and not fish_left_frames.is_empty() and not fish_right_frames.is_empty()
	readiness.text="" if sample_ready else "样板素材尚未齐备"
	readiness.visible=not sample_ready and not embedded
	_update_visuals()

func _setup_fish_mesh(facing:String,node:Sprite2D,frames:Array[Texture2D],fish:Dictionary)->void:
	if fish_meshes.has(facing):
		var previous:MeshInstance2D=fish_meshes[facing]
		if is_instance_valid(previous):previous.queue_free()
		fish_meshes.erase(facing);_fish_mesh_data.erase(facing)
	# Keep the authored Sprite2D as a transform/inspection container only.
	# self_modulate does not affect its independently drawn mesh child.
	node.self_modulate=Color(1,1,1,0);node.material=null
	if frames.is_empty():return
	var color:Array=fish.get("water_tint",[1,1,1,1])
	var tint:=Color(float(color[0]),float(color[1]),float(color[2]),float(color[3]))
	var tone:=ShaderMaterial.new();tone.shader=FishTone;tone.set_shader_parameter("water_tint",tint)
	tone.set_shader_parameter("water_glaze",float(fish.get("water_glaze",.055)))
	tone.set_shader_parameter("water_surface",background.texture)
	tone.set_shader_parameter("water_rect",Vector4(_bg_draw_rect.position.x,_bg_draw_rect.position.y,_bg_draw_rect.size.x,_bg_draw_rect.size.y))
	var renderer:=MeshInstance2D.new();renderer.name="FishMesh";renderer.texture=frames[0];renderer.material=tone;node.add_child(renderer)
	var rest:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
	var texture_size:=frames[0].get_size()
	for row in range(FISH_ROWS+1):
		for column in range(FISH_COLUMNS+1):
			var point:=Vector2(float(column)/FISH_COLUMNS,float(row)/FISH_ROWS)
			var local:=texture_size*(point-Vector2(.5,.5))
			rest.append(Vector3(local.x,local.y,0));uv.append(point)
	for row in range(FISH_ROWS):
		for column in range(FISH_COLUMNS):
			var a:=row*(FISH_COLUMNS+1)+column;var b:=a+1;var c:=a+FISH_COLUMNS+1;var d:=c+1
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=rest.duplicate();arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays);renderer.mesh=mesh
	fish_meshes[facing]=renderer
	_fish_mesh_data[facing]={"rest":rest,"arrays":arrays,"mesh":mesh,"texture_size":texture_size}

func get_fish_mesh(facing:String="left")->MeshInstance2D:
	return fish_meshes.get(facing) as MeshInstance2D

func get_fish_vertices(facing:String="left")->PackedVector3Array:
	var renderer:=get_fish_mesh(facing)
	if renderer==null or renderer.mesh.get_surface_count()==0:return PackedVector3Array()
	return renderer.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]

func get_fish_rest_vertices(facing:String="left")->PackedVector3Array:
	return _fish_mesh_data.get(facing,{}).get("rest",PackedVector3Array()).duplicate()

func _update_fish_mesh(facing:String,texture:Texture2D)->void:
	if not _fish_mesh_data.has(facing):return
	var data:Dictionary=_fish_mesh_data[facing]
	var vertices:PackedVector3Array=data.rest.duplicate()
	var uv:PackedVector2Array=data.arrays[Mesh.ARRAY_TEX_UV]
	var head_lock:=clampf(float(_fish_swim.get("head_lock",.30)),.30,.55)
	var native_amplitude:=fish_motion_amplitude*float(data.texture_size.x)/_fish_width
	for i in range(vertices.size()):
		var rearward:float=uv[i].x if facing=="left" else 1.0-uv[i].x
		var weight:=pow(_smooth((rearward-head_lock)/(1.0-head_lock)),1.6)
		# A continuous travelling bend, increasingly driven by the caudal region.
		# Each cross-section translates as one unit: no length/width squashing.
		vertices[i].y+=sin(_fish_swim_phase-rearward*3.8)*weight*native_amplitude
	var arrays:Array=data.arrays
	arrays[Mesh.ARRAY_VERTEX]=vertices
	var mesh:ArrayMesh=data.mesh;mesh.clear_surfaces();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var renderer:MeshInstance2D=fish_meshes[facing];renderer.texture=texture

func _make_occluders()->void:
	for old in occluders:old.queue_free()
	occluders.clear()
	if background.texture==null:return
	var defaults=[[[.015,.51],[.11,.405],[.235,.438],[.33,.52],[.397,.62],[.385,.68],[.30,.755],[.20,.795],[.03,.79]],[[.824,.29],[.84,.247],[.866,.219],[.89,.201],[.947,.203],[.969,.236],[.982,.293],[.945,.336],[.87,.326]]]
	for raw in manifest.get("occluders",defaults):
		var shape:=Polygon2D.new();shape.name="ForegroundRock"+str(occluders.size()+1);shape.texture=background.texture;shape.z_index=3
		var points:=PackedVector2Array();var uv:=PackedVector2Array()
		for point in raw:
			var normalized:=_uv(point,Vector2.ZERO);points.append(_bg_draw_rect.position+_bg_draw_rect.size*normalized);uv.append(background.texture.get_size()*normalized)
		shape.polygon=points;shape.uv=uv;add_child(shape);occluders.append(shape)

func is_interaction_point(screen_point:Vector2)->bool:
	if not visible or not sample_ready:return false
	if screen_point.y>=590 or not water_hit_rect.has_point(screen_point):return false
	return _water_polygon.is_empty() or Geometry2D.is_point_in_polygon(screen_point,_water_polygon)

func begin_interaction()->void:
	if interaction_held:return
	interaction_held=true;_approach_start=_hand_tip;_phase_elapsed=0;approach_progress=0;phase="approach";contact_active=false
	_update_visuals()

func end_interaction()->void:
	interaction_held=false
	if phase=="rest" or phase=="withdraw":return
	_withdraw_start=_hand_tip;_withdraw_pose="touch" if contact_active else "reach";_phase_elapsed=0;phase="withdraw";contact_active=false
	_update_visuals()

func reset_sample()->void:
	phase="rest";approach_progress=0;contact_active=false;touch_count=0;interaction_held=false;_mouse_held=false;_key_held=false
	ripples.clear();_clock=0;_phase_elapsed=0;_hand_tip=_rest_tip;_approach_start=_rest_tip;_withdraw_start=_rest_tip
	fish_state="idle";fish_progress=0;fish_position=_fish_home;_fish_heading="left";_fish_shelter="left";_fish_elapsed=0;_fish_idle_clock=0;_fish_rotation=0
	fish_speed=0;fish_motion_amplitude=float(_fish_swim.get("idle_amplitude",1.4));fish_motion_frequency=float(_fish_swim.get("idle_hz",1.2));_fish_swim_phase=0
	if reading!=null:reading.text=TEXT;reading.show()
	_update_visuals()

func _smooth(t:float)->float:
	var n:=clampf(t,0,1);return n*n*(3-2*n)

func _bezier(a:Vector2,b:Vector2,c:Vector2,d:Vector2,t:float)->Vector2:
	var u:=1-t;return a*u*u*u+3*b*u*u*t+3*c*u*t*t+d*t*t*t

func step_simulation(delta:float)->void:
	var remaining:=maxf(0,delta)
	while remaining>.000001:
		var slice:=minf(remaining,.025);_step(slice);remaining-=slice
	_update_visuals()

func _step(delta:float)->void:
	_clock+=delta;_phase_elapsed+=delta
	if phase=="approach":
		approach_progress=clampf(_phase_elapsed/_approach_seconds,0,1)
		var t:=_smooth(approach_progress)
		_hand_tip=_bezier(_approach_start,_approach_start+Vector2(-125,-70),contact_point+Vector2(30,-68),contact_point,t)
		if approach_progress>=1:_touch_water()
	elif phase=="touch":_hand_tip=contact_point
	elif phase=="withdraw":
		var t:=_smooth(_phase_elapsed/_withdraw_seconds)
		_hand_tip=_bezier(_withdraw_start,_withdraw_start+Vector2(20,-60),_rest_tip+Vector2(-90,-55),_rest_tip,t)
		if _phase_elapsed>=_withdraw_seconds:phase="rest";approach_progress=0;_hand_tip=_rest_tip
	else:_hand_tip=_rest_tip
	for ripple in ripples:ripple.age+=delta
	ripples=ripples.filter(func(item):return item.age<2.25)
	_step_fish(delta)

func _touch_water()->void:
	if phase!="approach":return
	phase="touch";_phase_elapsed=0;contact_active=true;touch_count+=1;_hand_tip=contact_point
	_last_ripple_tip=_tip_position_for("touch",contact_point)
	for delay in [0.0,-.15,-.32]:ripples.append({"age":delay,"origin":_last_ripple_tip,"position":_last_ripple_tip})
	if ripples.size()>6:ripples=ripples.slice(ripples.size()-6)
	if fish_state=="idle" or fish_state=="return":_begin_flee()

func _begin_flee()->void:
	fish_state="flee";fish_progress=0;_fish_elapsed=0
	_fish_shelter="left" if _fish_heading=="left" else "right"
	var data:Dictionary=manifest.get("fish",{})
	if _fish_shelter=="left":
		_fish_path=PackedVector2Array([fish_position,_coord(data.get("left_control1"),BASE*Vector2(.46,.52)),_coord(data.get("left_control2"),BASE*Vector2(.35,.56)),_fish_left_hide])
	else:
		_fish_path=PackedVector2Array([fish_position,_coord(data.get("right_control1"),BASE*Vector2(.65,.47)),_coord(data.get("right_control2"),BASE*Vector2(.84,.40)),_fish_right_hide])

func _step_fish(delta:float)->void:
	var previous_position:=fish_position
	_fish_elapsed+=delta
	if fish_state=="idle":
		_fish_idle_clock+=delta;fish_position=_fish_home+Vector2(sin(_fish_idle_clock*.54)*9,sin(_fish_idle_clock*.77)*3);_fish_rotation=lerp_angle(_fish_rotation,0,minf(1,delta*2))
	elif fish_state=="flee" or fish_state=="return":
		var duration:=_fish_flee_seconds if fish_state=="flee" else _fish_return_seconds
		fish_progress=clampf(_fish_elapsed/duration,0,1)
		var t:=1-pow(1-fish_progress,1.6) if fish_state=="flee" else _smooth(fish_progress)
		# The fish begins turning before its first strong escape stroke.
		if fish_state=="flee":t*=_smooth(_fish_elapsed/.14)
		var point:=_bezier(_fish_path[0],_fish_path[1],_fish_path[2],_fish_path[3],t)
		var lookahead:=minf(1,t+.035)
		var u:=1.0-lookahead
		var tangent:=3.0*u*u*(_fish_path[1]-_fish_path[0])+6.0*u*lookahead*(_fish_path[2]-_fish_path[1])+3.0*lookahead*lookahead*(_fish_path[3]-_fish_path[2])
		if tangent.length()>.01:
			var angle:=wrapf(tangent.angle()-(PI if _fish_heading=="left" else 0),-PI,PI)
			_fish_rotation=lerp_angle(_fish_rotation,clampf(angle,-1.50,1.50),1.0-exp(-delta*16.0))
		fish_position=point
		if fish_progress>=1:
			if fish_state=="flee":fish_state="hide";_fish_elapsed=0;_fish_heading="right" if _fish_shelter=="left" else "left"
			else:fish_state="idle";_fish_elapsed=0;_fish_idle_clock=0
	elif fish_state=="hide":
		if not interaction_held and phase=="rest" and _fish_elapsed>1.0:
			fish_state="return";fish_progress=0;_fish_elapsed=0
			_fish_path=PackedVector2Array([fish_position,_fish_path[2],_fish_path[1],_fish_home])
	fish_speed=fish_position.distance_to(previous_position)/maxf(delta,.000001)
	var idle_amplitude:=float(_fish_swim.get("idle_amplitude",1.4));var idle_hz:=float(_fish_swim.get("idle_hz",1.2))
	var amplitude_target:=idle_amplitude;var frequency_target:=idle_hz
	if fish_state=="flee":
		var effort:=.4+.6*clampf(fish_speed/200.0,0,1)
		amplitude_target=lerpf(idle_amplitude,float(_fish_swim.get("flee_amplitude",4.8)),effort)
		frequency_target=lerpf(idle_hz,float(_fish_swim.get("flee_hz",2.8)),effort)
	elif fish_state=="return":
		var effort:=clampf(fish_speed/80.0,0,1)
		amplitude_target=lerpf(idle_amplitude,float(_fish_swim.get("return_amplitude",2.5)),effort)
		frequency_target=lerpf(idle_hz,float(_fish_swim.get("return_hz",1.5)),effort)
	fish_motion_amplitude=lerpf(fish_motion_amplitude,amplitude_target,1.0-exp(-delta*10.0))
	fish_motion_frequency=lerpf(fish_motion_frequency,frequency_target,1.0-exp(-delta*10.0))
	_fish_swim_phase+=delta*TAU*fish_motion_frequency

func _process(delta:float)->void:
	if embedded or not visible:return
	step_simulation(delta)
	if _audio_enabled:
		if not stream.playing:stream.play()
		if not wind.playing:wind.play()
		stream.volume_db=move_toward(stream.volume_db,-9 if interaction_held else -11,delta*3)
		wind.volume_db=move_toward(wind.volume_db,-14 if interaction_held else -12,delta*3)

func _pose_info(name:String)->Dictionary:
	return hand_data.get(name,{})

func _tip_position_for(name:String,tip:Vector2)->Vector2:
	var info:=_pose_info(name)
	if info.is_empty() or not info.has("position"):return tip
	var texture:Texture2D=info.get("texture")
	if texture==null:return tip
	var factor:float=float(info.width_px)/texture.get_width();var size_px:=texture.get_size()*factor
	var offset:Vector2=(info.tip_uv-info.pivot_uv)*size_px
	return _coord(info.position,contact_point)+offset.rotated(float(info.rotation))+tip-contact_point

func _place_pose(name:String,tip:Vector2,opacity:float)->void:
	var node:Sprite2D=hand_nodes[name];var info:=_pose_info(name);var texture:Texture2D=info.get("texture")
	node.visible=texture!=null and opacity>.001;node.modulate.a=1.0
	if node.material!=null:node.material.set_shader_parameter("layer_opacity",opacity)
	if texture==null:return
	var factor:float=float(info.width_px)/texture.get_width();node.scale=Vector2.ONE*factor;node.rotation=float(info.rotation);node.offset=-texture.get_size()*info.pivot_uv
	var local_tip:Vector2=(info.tip_uv-info.pivot_uv)*texture.get_size()*factor
	node.position=_tip_position_for(name,tip)-local_tip.rotated(node.rotation)

func _update_visuals()->void:
	if background==null:return
	for key in hand_nodes:_place_pose(key,_hand_tip,0)
	if phase=="rest":active_hand_pose="rest"
	elif phase=="approach":
		# The large rest/reach change occurs outside the frame. Only one hand is drawn.
		active_hand_pose="rest" if approach_progress<.07 else "touch" if approach_progress>.96 else "reach"
	elif phase=="touch":active_hand_pose="touch"
	elif phase=="withdraw":
		var t:=_phase_elapsed/_withdraw_seconds
		active_hand_pose=_withdraw_pose if t<.06 else "rest" if t>.94 else "withdraw"
	_place_pose(active_hand_pose,_hand_tip,1)
	_update_fish_sprite(fish_left,fish_left_frames,_fish_heading=="left")
	_update_fish_sprite(fish_right,fish_right_frames,_fish_heading=="right")
	water_effects.queue_redraw()
	contact_shadow.queue_redraw()

func _update_fish_sprite(node:Sprite2D,frames:Array[Texture2D],active:bool)->void:
	node.visible=active and fish_state!="hide" and not frames.is_empty()
	if frames.is_empty():return
	var speed:=1.55 if fish_state=="flee" else .8 if fish_state=="return" else .45
	node.texture=frames[int(_clock*_fish_fps*speed)%frames.size()]
	var factor:=_fish_width/node.texture.get_width();node.scale=Vector2.ONE*factor;node.position=fish_position;node.rotation=_fish_rotation;node.centered=true
	var heading:="left" if node==fish_left else "right"
	_update_fish_mesh(heading,node.texture)

func _draw_water()->void:
	for ripple in ripples:
		var age:float=ripple.age
		if age<0:continue
		var t:=clampf(age/2.25,0,1);var radius:=6+96*(1-pow(1-t,2));var alpha:=pow(1-t,1.8)*.37
		water_effects.draw_set_transform(ripple.origin,0,Vector2(1,.38))
		water_effects.draw_arc(Vector2.ZERO,radius,0,TAU,88,Color(.91,.99,.98,alpha),1.1,true)
		water_effects.draw_arc(Vector2.ZERO,radius+2,0,TAU,88,Color(.91,.99,.98,alpha*.10),3.0,true)
	water_effects.draw_set_transform(Vector2.ZERO)
	if touch_count==0 and phase=="rest" and sample_ready:
		var a:=.12+.07*sin(_clock*1.5)
		water_effects.draw_circle(contact_point,4.0,Color(.97,1,.98,a*.4));water_effects.draw_circle(contact_point,1.5,Color(.97,1,.98,a))

func _draw_contact_shadow()->void:
	var near_water:=0.0
	if phase=="approach":near_water=_smooth((approach_progress-.68)/.32)
	elif phase=="touch":near_water=1.0
	elif phase=="withdraw":near_water=1.0-_smooth(_phase_elapsed/(_withdraw_seconds*.45))
	if near_water<=0:return
	var tip:=get_hand_tip()
	var center:=Vector2(tip.x,contact_point.y+3)
	contact_shadow.draw_set_transform(center,0,Vector2(1,.30))
	for i in range(4,0,-1):
		contact_shadow.draw_circle(Vector2.ZERO,float(i)*(3.8-near_water*.7),Color(.055,.16,.17,.009*near_water))
	contact_shadow.draw_set_transform(Vector2.ZERO)

func get_hand_tip()->Vector2:
	return _tip_position_for(active_hand_pose,_hand_tip)

func get_fish_position()->Vector2:return fish_position

func _gui_input(event:InputEvent)->void:
	if embedded:return
	if event is InputEventMouseMotion:
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if is_interaction_point(get_local_mouse_position()) else Control.CURSOR_ARROW
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and is_interaction_point(get_local_mouse_position()):_mouse_held=true;begin_interaction();accept_event()
		elif not event.pressed and _mouse_held:
			_mouse_held=false
			if not _key_held:end_interaction()
			accept_event()

func _input(event:InputEvent)->void:
	if embedded or not visible:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _mouse_held:
		_mouse_held=false
		if not _key_held:end_interaction()
	if event is InputEventKey and not event.echo:
		if event.physical_keycode==KEY_E:
			_key_held=event.pressed
			if _key_held:begin_interaction()
			elif not _mouse_held:end_interaction()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode==KEY_R:reset_sample();get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode in [KEY_F11,KEY_F]:_toggle_fullscreen();get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode==KEY_ESCAPE:
			end_interaction();_mouse_held=false;_key_held=false
			if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:get_window().mode=Window.MODE_WINDOWED
			get_viewport().set_input_as_handled()

func _toggle_fullscreen()->void:
	get_window().mode=Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_EXCLUSIVE_FULLSCREEN

func _exit_tree()->void:
	stop_audio()
	hand_data.clear();fish_meshes.clear();_fish_mesh_data.clear()

func stop_audio()->void:
	_audio_enabled=false
	if is_instance_valid(stream):stream.stop();stream.stream=null
	if is_instance_valid(wind):wind.stop();wind.stream=null

func set_embedded_active(value:bool)->void:
	visible=value
	if not value:end_interaction()
	if embedded:set_process(false)
