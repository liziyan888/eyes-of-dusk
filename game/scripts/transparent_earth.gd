extends Control
## Final film: one registered 16:9 presentation for paintings, movies and the live globe.
signal return_to_title_requested
const CONFIG:="res://data/transparent_earth.json"
const ART:="res://assets/transparent-earth/"
const Pace=preload("res://scripts/reading_pace.gd")
var data:Dictionary={}
var shot_index:=-1
var shot_clock:=0.0
var film_clock:=0.0
var running:=false
var finishing:=false
var serial:=0
var layers:Array[Dictionary]=[]
var active_slot:=0
var transition_clock:=0.0
var transition_duration:=.9
var transition_kind:="dissolve"
var switching:=false
var pending_index:=-1
var switched:=false
var screen:ColorRect
var subtitle:Label
var subtitle_wash:ColorRect
var thanks:Control
var earth_root:TextureRect
var earth_viewport:SubViewport
var earth:Node3D
var reprise:AudioStreamPlayer
var reprise_played:=false
var audio_suspended:=false
var core_line:=-1
var film_tween:Tween
var core_sky:TextureRect

func _ready()->void:
	size=Vector2(1280,720);clip_contents=true;mouse_filter=MOUSE_FILTER_STOP
	data=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	var background:=ColorRect.new();background.size=size;background.color=Color.BLACK;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	for i in range(2):layers.append(_make_frame(i))
	core_sky=TextureRect.new();core_sky.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;core_sky.texture=preload("res://assets/transparent-earth/earth-paint-v2.png");core_sky.stretch_mode=TextureRect.STRETCH_SCALE;core_sky.size=size;core_sky.mouse_filter=MOUSE_FILTER_IGNORE;add_child(core_sky);core_sky.hide()
	earth_root=TextureRect.new();earth_root.size=size;earth_root.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;earth_root.stretch_mode=TextureRect.STRETCH_SCALE;earth_root.mouse_filter=MOUSE_FILTER_IGNORE;add_child(earth_root)
	earth_viewport=SubViewport.new();earth_viewport.size=Vector2i(2560,1440);earth_viewport.own_world_3d=true;earth_viewport.transparent_bg=true;earth_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;earth_viewport.msaa_3d=Viewport.MSAA_2X;earth_root.add_child(earth_viewport);earth_root.hide()
	earth_root.texture=earth_viewport.get_texture()
	var composite:=ShaderMaterial.new();composite.shader=preload("res://shaders/transparent_stage_composite.gdshader");earth_root.material=composite
	var gradient:=Gradient.new();gradient.set_color(0,Color(0,0,0,0));gradient.set_color(1,Color(0,0,0,.56))
	var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.fill_from=Vector2(.5,0);texture.fill_to=Vector2(.5,1)
	subtitle_wash=ColorRect.new();subtitle_wash.position=Vector2(0,545);subtitle_wash.size=Vector2(1280,175);subtitle_wash.mouse_filter=MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();var shader:=Shader.new();shader.code="shader_type canvas_item; void fragment(){COLOR=vec4(0.015,0.035,0.06,pow(UV.y,1.6)*0.58);}";material.shader=shader;subtitle_wash.material=material;add_child(subtitle_wash)
	subtitle=Label.new();subtitle.name="FinalFilmSubtitle";subtitle.position=Vector2(95,612);subtitle.size=Vector2(1090,78);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;subtitle.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"]);font.font_weight=400
	subtitle.add_theme_font_override("font",font);subtitle.add_theme_font_size_override("font_size",25);subtitle.add_theme_color_override("font_color",Color("f5f0e5"));subtitle.add_theme_constant_override("outline_size",0);add_child(subtitle)
	screen=ColorRect.new();screen.color=Color.BLACK;screen.size=size;screen.mouse_filter=MOUSE_FILTER_IGNORE;add_child(screen)
	thanks=Control.new();thanks.size=size;thanks.mouse_filter=MOUSE_FILTER_STOP;add_child(thanks)
	var end_title:=Label.new();end_title.name="ThanksTitle";end_title.text="谢谢体验";end_title.position=Vector2(0,276);end_title.size=Vector2(1280,65);end_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;end_title.add_theme_font_override("font",font);end_title.add_theme_font_size_override("font_size",34);thanks.add_child(end_title)
	var promise:=Label.new();promise.name="FinalPromise";promise.text="不管走到天涯海角，我离她都不会再远了。";promise.position=Vector2(160,360);promise.size=Vector2(960,50);promise.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;promise.add_theme_font_override("font",font);promise.add_theme_font_size_override("font_size",21);promise.modulate.a=.68;thanks.add_child(promise)
	var home:=Button.new();home.name="ReturnToMainMenu";home.text="返回开始界面";home.position=Vector2(475,466);home.size=Vector2(330,52);home.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","focus"]:home.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	home.pressed.connect(func():close();return_to_title_requested.emit());thanks.add_child(home);thanks.hide()
	reprise=AudioStreamPlayer.new();reprise.bus="Voice";reprise.volume_db=-3;add_child(reprise)
	process_mode=Node.PROCESS_MODE_ALWAYS;hide()

func _make_frame(index:int)->Dictionary:
	var root:=Control.new();root.name="FilmFrame"+str(index);root.size=size;root.mouse_filter=MOUSE_FILTER_IGNORE;add_child(root)
	var poster:=TextureRect.new();poster.size=size;poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;poster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;poster.mouse_filter=MOUSE_FILTER_IGNORE;root.add_child(poster)
	var video:=VideoStreamPlayer.new();video.size=size;video.expand=true;video.volume_db=-80;video.bus="Effects";video.mouse_filter=MOUSE_FILTER_IGNORE;root.add_child(video);video.hide()
	var result:={"root":root,"poster":poster,"video":video,"last":null,"decoding":false,"decode_clock":0.0,"reveal_clock":0.0}
	video.finished.connect(func():
		if result.last!=null:poster.texture=result.last
		video.hide();video.stop();result.decoding=false)
	root.hide();return result

func begin()->void:
	close();serial+=1;var token:=serial;show();thanks.hide();screen.color.a=1;reprise_played=false;core_line=-1;film_clock=0
	var first_shot:=10 if "--preview-earth-core" in OS.get_cmdline_user_args() else 0
	var shown:bool=await ChapterTransition.play(4,self,func():_show_shot(first_shot);screen.color.a=0;ChapterTransition.destination_ready(self))
	if token!=serial or not shown:return
	running=true;shot_clock=0;get_viewport().gui_release_focus()

func _show_shot(index:int)->void:
	shot_index=index;shot_clock=0;core_line=-1
	var spec:Dictionary=data.shots[index]
	if str(spec.get("kind",""))=="earth":
		for layer in layers:layer.root.hide();layer.video.stop()
		if earth!=null:earth.queue_free()
		earth=preload("res://scripts/transparent_earth_stage.gd").new();earth_viewport.add_child(earth)
		earth_root.show();core_sky.show();earth_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	else:
		earth_root.hide();core_sky.hide();earth_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
		var frame:Dictionary=layers[active_slot];frame.root.show();frame.root.modulate.a=1;frame.video.stop();frame.video.hide();frame.decoding=false
		var poster_path:=ART+str(spec.image)
		if spec.has("video") and ResourceLoader.exists(ART+str(spec.video)+"-first.png"):poster_path=ART+str(spec.video)+"-first.png"
		frame.poster.texture=load(poster_path);frame.last=null
		if spec.has("video") and ResourceLoader.exists(ART+str(spec.video)+".ogv"):
			frame.last=load(ART+str(spec.video)+"-last.png");frame.video.stream=load(ART+str(spec.video)+".ogv");frame.video.play();frame.decoding=true;frame.decode_clock=0;frame.reveal_clock=0
	_set_caption(str(spec.get("text","")),str(spec.id))

func _set_caption(text:String,scope:String)->void:
	subtitle.set_meta("text_scope","transparent-earth-"+scope);subtitle.text=text;subtitle.visible_characters=0;subtitle.set_meta("elapsed",0.0);subtitle.modulate.a=0
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null:studio.sync_node(subtitle)

func _next()->void:
	if switching or not running:return
	if shot_index+1>=data.shots.size():_finish();return
	pending_index=shot_index+1;switching=true;switched=false;transition_clock=0
	transition_kind=str(data.shots[pending_index].get("transition","dip"));transition_duration=1.0 if transition_kind=="dip" else .9
	if transition_kind=="dissolve":
		active_slot=1-active_slot;_show_shot(pending_index);layers[active_slot].root.modulate.a=0

func _process(delta:float)->void:
	if not visible:return
	var audio=get_node_or_null("/root/AudioSettings");var studio=get_node_or_null("/root/TextStudio")
	var suspended:bool=get_tree().paused or (audio!=null and audio.opened) or (studio!=null and studio.editing)
	if suspended!=audio_suspended:
		audio_suspended=suspended
		for frame in layers:frame.video.paused=suspended
		reprise.stream_paused=suspended
	if suspended:return
	if not running:return
	film_clock+=delta
	for frame in layers:
		if frame.decoding:
			frame.decode_clock+=delta
			var texture:Texture2D=frame.video.get_video_texture()
			if frame.video.stream_position>.02 and texture!=null and texture.get_width()>0:
				frame.video.show();frame.reveal_clock+=delta;frame.video.modulate.a=clampf(frame.reveal_clock/.16,0,1)
			elif frame.decode_clock>6.0:frame.video.stop();frame.decoding=false
	if switching:
		transition_clock+=delta;var t:=clampf(transition_clock/transition_duration,0,1)
		if transition_kind=="dip":
			if t<.4:screen.color.a=smoothstep(0.0,.4,t)
			else:
				if not switched:
					layers[active_slot].root.hide();active_slot=1-active_slot;_show_shot(pending_index);switched=true
				screen.color.a=1-smoothstep(.4,1.0,t)
		else:
			layers[active_slot].root.modulate.a=smoothstep(0.0,1.0,t);layers[1-active_slot].root.modulate.a=1-smoothstep(0.0,1.0,t)
		if t>=1:
			switching=false;screen.color.a=0;layers[1-active_slot].root.hide();layers[1-active_slot].video.stop()
		return
	shot_clock+=delta
	var spec:Dictionary=data.shots[shot_index]
	if str(spec.get("kind",""))=="earth":
		earth.step(delta)
		var index:=0
		for i in range(spec.lines.size()):
			if shot_clock>=float(spec.lines[i].at):index=i
		if index!=core_line:core_line=index;_set_caption(str(spec.lines[index].text),str(spec.lines[index].get("scope","core-"+str(index))))
		if shot_clock>=12.0 and not reprise_played:_play_reprise()
	var typing:=float(subtitle.get_meta("elapsed",0.0))+delta*Pace.CHARACTERS_PER_SECOND
	subtitle.set_meta("elapsed",typing);subtitle.visible_characters=mini(int(typing),subtitle.text.length());subtitle.modulate.a=minf(1.0,subtitle.modulate.a+delta*2.5)
	var duration:=float(spec.get("seconds",5.0))
	if shot_clock>=duration:_next()

func _play_reprise()->void:
	reprise_played=true
	var path:="res://assets/audio-polish-v1/A06_girl_moonlight_reprise.wav"
	if ResourceLoader.exists(path):reprise.stream=load(path);reprise.play()

func _finish()->void:
	running=false;finishing=true
	var token:=serial;var fade:=create_tween();film_tween=fade;fade.set_pause_mode(Tween.TWEEN_PAUSE_STOP);fade.tween_property(screen,"color:a",1.0,1.8)
	await fade.finished
	if token!=serial:return
	for frame in layers:frame.video.stop();frame.root.hide()
	earth_root.hide();core_sky.hide();earth_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	subtitle.hide();subtitle_wash.hide();thanks.modulate.a=0;thanks.show()
	film_tween=create_tween();film_tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP);film_tween.tween_property(thanks,"modulate:a",1.0,1.0)

func close()->void:
	serial+=1;running=false;finishing=false;switching=false;shot_index=-1
	if film_tween!=null and film_tween.is_valid():film_tween.kill()
	ChapterTransition.cancel(self)
	for frame in layers:frame.video.stop();frame.video.paused=false;frame.root.hide();frame.decoding=false
	if reprise!=null:reprise.stop()
	if earth_viewport!=null:earth_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	if earth_root!=null:earth_root.hide()
	if core_sky!=null:core_sky.hide()
	if earth!=null:earth.queue_free();earth=null
	if subtitle!=null:subtitle.show();subtitle_wash.show()
	hide()
