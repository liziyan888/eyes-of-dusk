extends Control
## Shared interaction UI for movies, registered alpha frames and original artwork layers.
signal action_completed
signal replay_requested
signal next_requested
signal previous_requested
signal fullscreen_requested
const BASE:=Vector2(1280,720)
const Typer=preload("res://scripts/label_typewriter.gd")
var typers:Array[Node]=[]
signal speech_started(who:String,text:String)
var speech_queue:Array[Dictionary]=[]
var speech_role:=""
var speech_wait:=0.0
const SPEECH_HOLD:=.85
const Point=preload("res://scripts/comic_hotspot.gd")
const Chroma=preload("res://shaders/grassland_video_chroma.gdshader")
const Alpha=preload("res://shaders/grassland_video_alpha.gdshader")
const View=preload("res://shaders/grassland_video_view.gdshader")
const FrameSequence=preload("res://scripts/alpha_frame_sequence.gd")
const LayerArtwork=preload("res://scripts/grassland_vignette.gd")
const CoverCutout=preload("res://shaders/creek_sample_alpha.gdshader")
const DialogueWash=preload("res://shaders/dialogue_color_wash.gdshader")
const SubtitleStyle=preload("res://scripts/subtitle_style.gd")
var subtitle_settings:Dictionary={}
var debug_blocked:=false
var girl_name:Label
var page:Dictionary={}
var media:Dictionary={}
var kind:=""
var background:TextureRect
var thicket:TextureRect
var rest:TextureRect
var videos:Array[VideoStreamPlayer]=[]
var fx:Array[ShaderMaterial]=[]
var sequence:FrameSequence
var layer_artwork:LayerArtwork
var foreground:Array[TextureRect]=[]
var action_sound:AudioStreamPlayer
var marker:Button
var hint:Label
var girl:Label
var man:Label
var girl_wash:ColorRect
var man_wash:ColorRect
var menu:Control
var active:=false
var paused:=false
var completed:=false
var busy:=false
var phase:="invite"
var energy:=0.0
var gaze:=Vector2.ZERO
var pointer:=Vector2.ZERO
var target:=Vector2.ZERO
var clock:=0.0
var action_clock:=0.0
var response_clock:=0.0
var holding:=false
var guided:=false
var pressed_at:=0.0
var last_pointer:=Vector2.ZERO
var camera:=Vector2.ZERO
var wanted_camera:=Vector2.ZERO
var manual_until:=0.0
var current_video:=0
var standby_started:=false
var blending:=0.0
var contact_shown:=false
var audio_pause_was:=false

func configure(data:Dictionary)->void:
	page=data.duplicate(true);media=page.get("motion_media",{});kind=str(media.get("mode",""))
	set_meta("text_scope","grassland-page-"+str(page.get("id",page.get("kind",page.get("background","")))))
	var p:Array=media.get("marker",[.5,.5]);target=Vector2(float(p[0]),float(p[1]))*BASE;pointer=target

func _ready()->void:
	size=BASE;mouse_filter=MOUSE_FILTER_IGNORE;clip_contents=true
	if kind=="layers":
		layer_artwork=LayerArtwork.new();layer_artwork.name="OriginalLayerArtwork";layer_artwork.configure(page);add_child(layer_artwork);layer_artwork.set_active(false);background=layer_artwork.background
	else:background=_picture(str(page.background),Rect2(Vector2.ZERO,BASE),0)
	if media.has("grass_layer"):
		thicket=_picture(str(media.grass_layer),Rect2(Vector2.ZERO,BASE),1)
	var r:Array=media.get("rect",[0,0,1280,720]);var rect:=Rect2(float(r[0]),float(r[1]),float(r[2]),float(r[3]))
	if kind=="frames":
		sequence=FrameSequence.new();sequence.name="RegisteredAlphaFrames";sequence.position=rect.position;sequence.size=rect.size;sequence.z_index=3;add_child(sequence);sequence.configure(str(media.manifest));sequence.finished.connect(_finish_action)
	elif media.has("rest"):
		rest=_picture(str(media.rest),rect,2)
		if kind=="chroma":
			var chroma:=ShaderMaterial.new();chroma.shader=Chroma;rest.material=chroma
	for i in range(0 if kind in ["frames","layers"] else (2 if kind=="panorama" else 1)):
		var video:=VideoStreamPlayer.new();video.name="ContinuousMotion"+str(i);video.stream=load(str(media.video));video.expand=true;video.position=rect.position;video.size=rect.size;video.z_index=3+i;video.volume_db=-80;video.mouse_filter=MOUSE_FILTER_IGNORE
		var material:=ShaderMaterial.new();material.shader=View if kind=="panorama" else (Chroma if kind=="chroma" else Alpha);video.material=material;fx.append(material)
		add_child(video);videos.append(video);video.finished.connect(_movie_finished.bind(i));video.hide()
	for cover in media.get("foreground_layers",[]):
		var bounds:Array=cover.rect
		var artwork:=_picture(str(cover.file),Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3])),5)
		if cover.has("alpha_cutoff"):
			var cutout:=ShaderMaterial.new();cutout.shader=CoverCutout;cutout.set_shader_parameter("alpha_cutoff",float(cover.alpha_cutoff));cutout.set_shader_parameter("alpha_feather",float(cover.get("alpha_feather",.06)));artwork.material=cutout
		foreground.append(artwork)
	if media.has("action_sound"):
		action_sound=AudioStreamPlayer.new();action_sound.stream=load(str(media.action_sound));action_sound.bus="Ambience";action_sound.volume_db=-3;add_child(action_sound)
	girl=_label(Rect2(760,61,449,145),24);man=_label(Rect2(70,612,1010,84),24)
	for label in [girl,man]:
		var typer:=Typer.new();typer.setup(label);add_child(typer);typers.append(typer)
	girl_wash=_dialogue_wash("FemaleDialogueWash",Color(.48,.72,.94,.12))
	man_wash=_dialogue_wash("MaleDialogueWash",Color(1.0,.72,.38,.10))
	girl_name=_label(Rect2(760,39,100,22),14);girl_name.text="她";girl_name.modulate.a=.7
	var man_name:=_label(Rect2(70,590,100,22),14);man_name.name="MaleSpeaker";man_name.text="我";man_name.modulate.a=.7
	marker=Point.new();marker.name="FixedInteractionCircle";marker.z_index=12;add_child(marker);marker.custom_minimum_size=Vector2(76,76);marker.size=Vector2(76,76);marker.radius=11;marker.position=target-marker.size*.5;marker.accessibility_name=str(page.get("gesture_label","互动"));marker.gui_input.connect(_marker_input)
	hint=_label(Rect2(target+Vector2(-170,37),Vector2(340,38)),15);hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.z_index=12
	menu=Control.new();menu.size=BASE;menu.z_index=40;menu.mouse_filter=MOUSE_FILTER_STOP;add_child(menu)
	var veil:=ColorRect.new();veil.size=BASE;veil.color=Color(.03,.07,.06,.76);veil.mouse_filter=MOUSE_FILTER_IGNORE;menu.add_child(veil)
	_menu_button("继续",230,func():set_paused(false))
	_menu_button("整体音量",305,func():var audio=get_node_or_null("/root/AudioSettings");if audio!=null:audio.open_panel())
	_menu_button("重新体验",380,func():replay_requested.emit())
	menu.hide()
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null:audio.panel_toggled.connect(_audio_panel)
	reset_vignette();hide()

func _picture(path:String,rect:Rect2,depth:int)->TextureRect:
	var node:=TextureRect.new();node.texture=load(path);node.position=rect.position;node.size=rect.size;node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE;node.mouse_filter=MOUSE_FILTER_IGNORE;node.z_index=depth;add_child(node)
	# Reviewed alpha-frame pages use design dimensions AFTER disabling the
	# image's native minimum size. Other movie pages keep their previous layout.
	if kind=="frames":node.size=rect.size
	return node

func _label(rect:Rect2,font_size:int)->Label:
	var node:=Label.new();node.position=rect.position;node.size=rect.size;node.mouse_filter=MOUSE_FILTER_IGNORE;node.z_index=11;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	SubtitleStyle.regular_font(node,font_size);add_child(node);return node

func _menu_button(text:String,y:float,action:Callable)->void:
	var button:=Button.new();button.text=text;button.position=Vector2(450,y);button.size=Vector2(380,54);button.add_theme_font_size_override("font_size",23)
	for key in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	button.pressed.connect(action);menu.add_child(button)

func _dialogue_wash(node_name:String,tint:Color)->ColorRect:
	var node:=ColorRect.new();node.name=node_name;node.color=tint;node.z_index=10;node.mouse_filter=MOUSE_FILTER_IGNORE
	var soft:=ShaderMaterial.new();soft.shader=DialogueWash;node.material=soft;add_child(node);return node

func _sync_dialogue_washes()->void:
	if girl==null or girl_wash==null:return
	var settings:=SubtitleStyle.normalize(subtitle_settings)
	SubtitleStyle.apply("her",girl,girl_name,girl_wash,settings)
	SubtitleStyle.apply("man",man,get_node_or_null("MaleSpeaker"),man_wash,settings)

func apply_subtitle_style(value:Dictionary)->void:
	subtitle_settings=SubtitleStyle.normalize(value);_sync_dialogue_washes()

func set_active(value:bool)->void:
	active=value;visible=value
	if layer_artwork!=null:layer_artwork.set_active(value)
	if not value:
		holding=false;guided=false
		for video in videos:video.stop()
		if sequence!=null:sequence.stop()
		if action_sound!=null:action_sound.stop()
	elif kind=="panorama" and not videos.is_empty():
		videos[0].show();videos[1].show();videos[0].play();fx[1].set_shader_parameter("opacity",0.0)

func reset_vignette()->void:
	speech_queue.clear();speech_role="";speech_wait=0
	phase="invite";completed=false;busy=false;paused=false;holding=false;guided=false;clock=0;action_clock=0;response_clock=0;contact_shown=false;energy=0;gaze=Vector2.ZERO;camera=Vector2.ZERO;wanted_camera=Vector2.ZERO;current_video=0;standby_started=false;blending=0
	for video in videos:video.stop();video.paused=false;video.hide()
	if sequence!=null:sequence.reset()
	if layer_artwork!=null:layer_artwork.reset_vignette()
	if action_sound!=null:action_sound.stop()
	if rest!=null:rest.show()
	if marker!=null:marker.show();marker.modulate.a=1;marker.completed=false;hint.text="轻点或按住，慢慢环顾" if kind=="panorama" else str(page.get("gesture_label","互动"))
	if girl!=null:
		girl.text=str(page.get("dialogue",[{}])[0].get("text",""));man.text="";get_node("MaleSpeaker").hide();menu.hide()
		for typer in typers:typer.previous="";typer.refresh()
		speech_role="her"
	if active and kind=="panorama":
		videos[0].show();videos[1].show();videos[0].play();fx[1].set_shader_parameter("opacity",0.0)
	_sync_dialogue_washes()

func restore_completed()->void:
	phase="complete";completed=true;busy=false;_response_lines(true);hint.text="";marker.completed=true
	if sequence!=null:sequence.hold_end()
	if layer_artwork!=null:
		layer_artwork.end_hold()
		if layer_artwork.kind=="listen":layer_artwork.bird_progress=1.1
		layer_artwork.step(0.0)

func interaction_target()->Vector2:return target
func is_interaction_point(point:Vector2)->bool:return point.distance_to(target)<=42

func _marker_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:begin_hold(get_local_mouse_position())
		elif kind=="panorama":end_hold()
		marker.accept_event()

func begin_hold(point:Vector2)->void:
	if not active or paused or busy or (phase=="response" and not completed):return
	finish_typing()
	speech_queue.clear();speech_role="";speech_wait=0
	busy=true;completed=false;phase="action";action_clock=0;contact_shown=false;response_clock=0;pointer=point;last_pointer=point;holding=kind=="panorama";pressed_at=clock;guided=false
	marker.modulate.a=.45;marker.completed=false;_enqueue_speech([page.get("dialogue",[{},{}])[1]]);hint.text="松开停留；轻轻拖动可选择方向" if kind=="panorama" else "慢慢来，停留一会儿"
	if kind=="frames":sequence.play()
	elif kind=="layers":layer_artwork.reset_vignette();layer_artwork.begin_hold(target)
	elif kind!="panorama":
		if rest!=null:rest.hide()
		videos[0].show();videos[0].play()
	if action_sound!=null:action_sound.stream_paused=false;action_sound.play()

func drag_hold(point:Vector2,relative:Vector2)->void:
	if kind!="panorama" or not holding:return
	pointer=point;wanted_camera.x=clampf(wanted_camera.x+relative.x*.028,-5.4,5.4);wanted_camera.y=clampf(wanted_camera.y-relative.y*.018,-1.35,1.35);manual_until=clock+1.5

func end_hold()->void:
	if kind!="panorama" or not holding:return
	holding=false;guided=true;hint.text="正在慢慢环顾…"

func _response_lines(instant:=false)->void:
	var lines:Array=page.get("response",[])
	if not instant:_enqueue_speech(lines);return
	speech_queue.clear();speech_role="";speech_wait=0
	for line in lines:
		if str(line.get("who","")) in ["她","女孩"]:girl.text=str(line.get("text",""))
		else:man.text=str(line.get("text",""))
	for typer in typers:typer.refresh();typer.label.visible_characters=-1
	get_node("MaleSpeaker").show()

func _finish_action()->void:
	if phase!="action":return
	if layer_artwork!=null:layer_artwork.end_hold()
	busy=false;holding=false;guided=false;phase="response";response_clock=0;marker.modulate.a=1;hint.text="";_response_lines()

func _movie_finished(index:int)->void:
	if not active:return
	if kind=="panorama":
		if index==current_video:_switch_loop()
	else:_finish_action()

func _switch_loop()->void:
	var old:=current_video;current_video=1-current_video
	if not standby_started:videos[current_video].play()
	videos[old].stop();standby_started=false;blending=0

func step(delta:float)->void:
	if not active or paused:return
	var dt:=minf(delta,.05);clock+=dt
	_step_speech(dt)
	if layer_artwork!=null:layer_artwork.step(dt)
	if kind=="panorama":
		var duration:=float(media.get("duration",5.166667));var pos:=videos[current_video].stream_position
		if pos>=duration-.28 and not standby_started:videos[1-current_video].play();standby_started=true
		blending=clampf((pos-(duration-.28))/.28,0,1) if standby_started else 0
		fx[0].set_shader_parameter("opacity",1.0);fx[1].set_shader_parameter("opacity",blending if current_video==0 else 1.0-blending)
		if blending>=.985:_switch_loop()
		if busy and (holding or guided):
			action_clock+=dt
			if clock>manual_until:wanted_camera=Vector2(sin(action_clock*.60)*5.4,sin(action_clock*.23)*.65)
			if action_clock>=4.7 and not holding:_finish_action()
		camera.x+=clampf((wanted_camera.x-camera.x)*(1-exp(-3*dt)),-5.4*dt,5.4*dt);camera.y+=clampf((wanted_camera.y-camera.y)*(1-exp(-3*dt)),-2.2*dt,2.2*dt);gaze=camera/5.4
		for effect in fx:effect.set_shader_parameter("camera",Vector2(deg_to_rad(camera.x),deg_to_rad(camera.y)))
	else:
		if kind=="frames" and phase=="action":sequence.advance(dt)
		if kind=="layers" and phase=="action":
			action_clock+=dt
			if action_clock>=float(media.get("duration",5.45)):_finish_action()
		var position_in_action:float=action_clock if kind=="layers" else (sequence.elapsed if sequence!=null else videos[0].stream_position)
		if phase=="action" and position_in_action>1.9 and not contact_shown:
			contact_shown=true;_enqueue_speech([{"who":"她","text":str(media.get("during_dialogue","嗯……轻轻的就好。" if kind in ["chroma","frames"] else "看见了……先这样停一会儿。"))}])
	if phase=="response":
		response_clock+=dt
		if response_clock>=1.2 and speech_role.is_empty() and speech_queue.is_empty():completed=true;phase="complete";hint.text="";marker.completed=true;action_completed.emit()
	energy=move_toward(energy,1.0 if busy else 0.0,dt)
	_sync_dialogue_washes()

func set_paused(value:bool,show_menu:=true)->void:
	paused=value;holding=false
	for video in videos:video.paused=value
	if action_sound!=null:action_sound.stream_paused=value
	menu.visible=value and show_menu
	if not value and busy and kind=="panorama":guided=true

func _audio_panel(opened:bool)->void:
	if not active:return
	if opened:audio_pause_was=paused;set_paused(true,false)
	else:set_paused(audio_pause_was)

func _input(event:InputEvent)->void:
	if not active:return
	if debug_blocked:return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not is_interaction_point(get_local_mouse_position()):
		if finish_typing():get_viewport().set_input_as_handled();return
	if event is InputEventMouseMotion and holding:
		var point:=get_local_mouse_position();drag_hold(point,point-last_pointer);last_pointer=point
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and holding:end_hold()
	if not event is InputEventKey or event.echo:return
	var code:int=event.physical_keycode
	if code==KEY_ESCAPE and event.pressed:set_paused(not paused);get_viewport().set_input_as_handled();return
	if paused:return
	if code in [KEY_SPACE,KEY_ENTER,KEY_E]:
		if event.pressed:
			if finish_typing():get_viewport().set_input_as_handled();return
			begin_hold(target)
		elif holding:end_hold()
		get_viewport().set_input_as_handled()
	elif event.pressed:
		if code==KEY_RIGHT and completed:next_requested.emit()
		elif code==KEY_LEFT:previous_requested.emit()
		elif code==KEY_R:replay_requested.emit()
		elif code in [KEY_F,KEY_F11]:fullscreen_requested.emit()
		else:return
		get_viewport().set_input_as_handled()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and active:set_paused(true)

func dialogue_typing()->bool:
	if not speech_queue.is_empty():return true
	for typer in typers:
		if typer.typing():return true
	return false

func finish_typing()->bool:
	if speech_role.is_empty():return false
	var typer:Node=typers[0 if speech_role=="her" else 1]
	if typer.finish():return true
	speech_role="";speech_wait=0;_show_next_speech();return true

func _enqueue_speech(lines:Array)->void:
	for line in lines:
		if line is Dictionary and not str(line.get("text","")).is_empty():speech_queue.append(line.duplicate())
	if speech_role.is_empty():_show_next_speech()

func _show_next_speech()->void:
	if speech_queue.is_empty():speech_role="";return
	var line:Dictionary=speech_queue.pop_front()
	var who:=str(line.get("who","我"));speech_role="her" if who in ["她","女孩"] else "man";speech_wait=0
	var label:Label=girl if speech_role=="her" else man
	label.text=str(line.text)
	var typer:Node=typers[0 if speech_role=="her" else 1];typer.refresh()
	if speech_role=="man":get_node("MaleSpeaker").show()
	speech_started.emit(who,label.text)

func _step_speech(delta:float)->void:
	if speech_role.is_empty():
		if not speech_queue.is_empty():_show_next_speech()
		return
	var typer:Node=typers[0 if speech_role=="her" else 1]
	if typer.typing():speech_wait=0;return
	speech_wait+=delta
	if speech_wait>=SPEECH_HOLD:speech_role="";speech_wait=0;_show_next_speech()
