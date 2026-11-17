extends Control
## Six full-screen reading vignettes. Painted objects move; backgrounds stay intact.
signal finished
signal arrival_revealed
signal fullscreen_requested
signal experience_remembered(kind:String)
var subtitle_settings:Dictionary={}
const Curl=preload("res://scripts/comic_page_curl.gd")
const Turn=preload("res://shaders/comic_page_turn.gdshader")
const Vignette=preload("res://scripts/grassland_vignette.gd")
const MotionPage=preload("res://scripts/grassland_motion_page.gd")
const Creek=preload("res://scripts/creek_sample.gd")
const BASE:=Vector2(1280,720)
var caption_typer:Node
const DATA:="res://data/grassland_v2.json"
const Hotspot=preload("res://scripts/comic_hotspot.gd")
const Mix=preload("res://scripts/audio_mix.gd")
var page_index:=0
var frontier:=0
var interactions:Dictionary={}
var clock:=0.0
var energy:=0.0
var holding:=false
var dragging:=false
var drag_from:=Vector2.ZERO
var pan:=.5
var pages:Array=[]
var page_controls:Array=[]
var textures:Array[Texture2D]=[]
var picture:TextureRect
var caption:Label
var help:Label
var clock_label:Label
var next_curl:Control
var previous_curl:Control
var shade:ColorRect
var turning:=false
var transitioning:=false
var prepared:=false
var wind:AudioStreamPlayer
var sound:AudioStreamPlayer
var _mouse_held:=false
var _key_held:=false
var _audio_enabled:=false
var _current:Control
var _direction_effect:AudioEffectPanner
var _direction_bus_name:=""
var speaker:Label
var marker:Button
var dialogue_phase:="intro"
var dialogue_index:=0
var gesture_time:=0.0
var gesture_ready:=false
var page_states:Dictionary={}
var music:AudioStreamPlayer
var legacy_reading:Array=[]

func _ready()->void:
	size=BASE;mouse_filter=MOUSE_FILTER_STOP;clip_contents=true
	_make_reading()
	caption_typer=preload("res://scripts/label_typewriter.gd").new();caption_typer.setup(caption);add_child(caption_typer)
	next_curl=Curl.new();next_curl.name="NextPage";next_curl.z_index=16;next_curl.turn_requested.connect(func():turn_page(1));add_child(next_curl)
	previous_curl=Curl.new();previous_curl.name="PreviousPage";previous_curl.backwards=true;previous_curl.z_index=16;previous_curl.turn_requested.connect(func():turn_page(-1));add_child(previous_curl)
	wind=AudioStreamPlayer.new();wind.name="GrasslandWind";wind.bus="Ambience";wind.volume_db=-11;add_child(wind)
	sound=AudioStreamPlayer.new();sound.name="GrasslandNature";sound.bus="Ambience";sound.volume_db=-12;add_child(sound)
	music=AudioStreamPlayer.new();music.name="GrasslandTheme";music.bus="Music";music.volume_db=-4;add_child(music)
	# The parent MusicDirector owns M03 across all six pages. Keep this empty
	# legacy node for compatibility with saved authoring paths and previews.
	_audio_enabled=DisplayServer.get_name()!="headless"
	_load_pages();hide()
	marker=Hotspot.new();marker.name="DialogueGesture";marker.z_index=11;add_child(marker);marker.hide()
	marker.button_down.connect(func():_mouse_held=true;interact_at(target_screen()))
	marker.button_up.connect(func():if _mouse_held:_release_hold())

func _make_reading()->void:
	var gradient:=Gradient.new();gradient.set_color(0,Color(.025,.065,.07,0));gradient.set_color(1,Color(.025,.065,.07,.25))
	var tex:=GradientTexture2D.new();tex.gradient=gradient;tex.fill_from=Vector2(.5,0);tex.fill_to=Vector2(.5,1)
	var lower:=TextureRect.new();lower.name="ReadingVeil";lower.texture=tex;lower.position=Vector2(0,565);lower.size=Vector2(1280,155);lower.mouse_filter=MOUSE_FILTER_IGNORE;lower.z_index=12;add_child(lower)
	speaker=_label("",Rect2(165,577,950,24),14,false);speaker.name="Speaker";speaker.z_index=13
	caption=_label("",Rect2(165,603,950,74),22,true);caption.name="CharacterDialogue";caption.z_index=13
	help=_label("",Rect2(190,683,900,23),13,false);help.name="GestureHint";help.modulate.a=.68;help.z_index=13
	clock_label=_label("",Rect2(50,30,600,28),15,false);clock_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;clock_label.modulate.a=.65;clock_label.z_index=13
	var replay:=_button("重看  R",Rect2(1055,25,90,30));replay.pressed.connect(_replay_page)
	var fullscreen:=_button("全屏  F11",Rect2(1150,25,105,30));fullscreen.pressed.connect(func():fullscreen_requested.emit())
	legacy_reading=[lower,speaker,caption,help,clock_label,replay,fullscreen]

func _label(text:String,rect:Rect2,font_size:int,serif:bool)->Label:
	var node:=Label.new();node.text=text;node.position=rect.position;node.size=rect.size;node.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;node.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["Noto Serif CJK SC","SimSun","Microsoft YaHei"] if serif else ["Microsoft YaHei","Noto Sans CJK SC"])
	node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color(.97,.97,.91,.98));node.add_theme_color_override("font_shadow_color",Color(.025,.045,.055,.42));node.add_theme_constant_override("shadow_offset_x",0);node.add_theme_constant_override("shadow_offset_y",1);add_child(node);return node

func _button(text:String,rect:Rect2)->Button:
	var button:=Button.new();button.text=text;button.position=rect.position;button.size=rect.size;button.z_index=14
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size",13);button.add_theme_color_override("font_color",Color(.96,.97,.92,.7));button.add_theme_color_override("font_hover_color",Color(1,1,.96));button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND;add_child(button);return button

func _load_pages()->void:
	for old in page_controls:
		if old is MotionPage:old.set_active(false)
		old.hide();old.queue_free()
	page_controls.clear();pages.clear();textures.clear()
	_current=null
	if FileAccess.file_exists(DATA):
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(DATA))
		if parsed is Dictionary:pages=parsed.get("pages",[])
		elif parsed is Array:pages=parsed
	if pages.size()!=6:
		pages.clear()
		for i in range(6):pages.append({"id":str(i),"kind":["panorama","flower","grass","listen","creek","wind"][i],"title":"","dialogue":[{"who":"她","text":"陪我再看看这里，好吗？"},{"who":"我","text":"好，我慢慢来。"}],"response":[{"who":"她","text":"我想把这一刻记住。"}],"hint":"按住画面，松开后停留片刻","background":"res://assets/grassland-v2/%02d-background.png"%i,"layers":[]})
	for i in range(pages.size()):
		var node:Control
		if pages[i].has("motion_media"):
			node=MotionPage.new();node.name="ApprovedMotion"+str(i);node.subtitle_settings=subtitle_settings;node.configure(pages[i]);add_child(node);node.set_active(false)
			node.action_completed.connect(_on_motion_completed.bind(i));node.replay_requested.connect(_on_motion_replay.bind(i));node.next_requested.connect(turn_page.bind(1));node.previous_requested.connect(turn_page.bind(-1));node.fullscreen_requested.connect(func():fullscreen_requested.emit())
		elif str(pages[i].get("kind",""))=="creek":
			node=Creek.new();node.embedded=true;node.name="CreekPage"
			add_child(node);node.set_embedded_active(false)
		else:
			node=Vignette.new();node.name="Vignette"+str(i);node.configure(pages[i]);add_child(node);node.set_active(false)
		node.z_index=0;page_controls.append(node)
		textures.append(node.background.texture)
	prepared=true

func begin()->void:
	_release_hold(false);page_index=0;frontier=0;interactions.clear();page_states.clear();turning=false;transitioning=false;energy=0;pan=.5;clock=0;modulate.a=1
	# Read asset paths again so the production preview uses the freshly authored files.
	_load_pages();show();_show_page();_start_audio()

func _show_page()->void:
	_release_hold(false)
	for i in range(page_controls.size()):
		var node:Control=page_controls[i]
		if node is Creek:node.set_embedded_active(i==page_index)
		else:node.set_active(i==page_index)
	_current=page_controls[page_index]
	if _current is Creek:_current.reset_sample()
	else:_current.reset_vignette()
	for control in legacy_reading:control.visible=not _current is MotionPage
	picture=_current.background
	var data:Dictionary=pages[page_index]
	help.text=str(data.get("hint",""));help.hide();clock_label.text=str(data.get("title",""))
	dialogue_phase="complete" if page_states.has(page_index) else "intro";dialogue_index=0;gesture_time=0;gesture_ready=false
	if dialogue_phase=="complete":dialogue_index=maxi(0,data.get("response",[]).size()-1)
	if _current is MotionPage:
		dialogue_phase="complete" if page_states.has(page_index) else "gesture"
		if page_states.has(page_index):_current.restore_completed()
	_show_character_line();next_curl.reset();previous_curl.reset();_update_page_controls()
	energy=0;pan=.5

func _show_character_line()->void:
	if _current is MotionPage:return
	var lines:Array=pages[page_index].get("dialogue" if dialogue_phase in ["intro","gesture"] else "response",[])
	if lines.is_empty():speaker.text="";caption.text="";return
	var line:Dictionary=lines[clampi(dialogue_index,0,lines.size()-1)]
	speaker.text=str(line.get("who","她"));speaker.modulate=Color(.78,.9,1) if speaker.text=="她" else Color(1,.94,.77)
	caption.text="「%s」"%str(line.get("text",""))
	preload("res://scripts/dialogue_appearance.gd").attach(caption,"her" if speaker.text in ["她","女孩"] else "man")
	get_node("ReadingVeil").hide()

func advance_dialogue()->void:
	if turning or transitioning:return
	if caption_typer.finish():return
	if dialogue_phase not in ["intro","response"]:return
	var lines:Array=pages[page_index].get("dialogue" if dialogue_phase=="intro" else "response",[])
	if dialogue_index<lines.size()-1:dialogue_index+=1;_show_character_line();return
	if dialogue_phase=="intro":dialogue_phase="gesture"
	else:dialogue_phase="complete";page_states[page_index]=true
	_update_page_controls()

func _update_page_controls()->void:
	if next_curl==null:return
	if _current is MotionPage:
		next_curl.visible=not turning and not transitioning
		next_curl.set_turn_enabled(_current.completed and not _current.busy and not _current.paused and not turning and not transitioning)
		previous_curl.visible=page_index>0 and not _current.paused and not turning and not transitioning
		if marker!=null:marker.hide()
		return
	next_curl.visible=not turning and not transitioning
	next_curl.set_turn_enabled(dialogue_phase=="complete" and not turning and not transitioning)
	previous_curl.visible=page_index>0 and not turning and not transitioning
	if marker!=null:
		marker.visible=dialogue_phase in ["gesture","complete"] and not holding and not turning and not transitioning
		marker.position=target_screen()-marker.size*.5
		marker.accessibility_name=str(pages[page_index].get("gesture_label","互动"))

func _on_motion_completed(index:int)->void:
	if index!=page_index:return
	page_states[index]=true;interactions[index]=true;dialogue_phase="complete";_update_page_controls()
	experience_remembered.emit(str(pages[index].get("kind","")))

func apply_subtitle_style(value:Dictionary)->void:
	subtitle_settings=value.duplicate(true)
	for node in page_controls:
		if node is MotionPage:node.apply_subtitle_style(subtitle_settings)

func _on_motion_replay(index:int)->void:
	if index==page_index:_replay_page()

func picture_uv(screen:Vector2)->Vector2:
	return (screen-picture.position)/picture.size if picture!=null else screen/BASE

func target_screen()->Vector2:
	if _current is Creek:return _current.contact_point
	if _current!=null:return _current.interaction_target()
	return BASE*.5

func _can_interact(screen:Vector2)->bool:
	if _current is MotionPage:return false
	return dialogue_phase in ["gesture","complete"] and _current!=null and _current.is_interaction_point(screen)

func interact_at(screen:Vector2)->void:
	if turning or transitioning or not _can_interact(screen):return
	interactions[page_index]=true;holding=true;dragging=true;drag_from=screen;energy=maxf(energy,.2)
	gesture_time=0;gesture_ready=false
	if _current is Creek:_current.begin_interaction()
	else:_current.begin_hold(screen)

func _release_hold(allow_response:=true)->void:
	var respond:bool=allow_response and holding and gesture_ready and dialogue_phase=="gesture"
	holding=false;dragging=false;_mouse_held=false;_key_held=false
	if _current==null or not is_instance_valid(_current):return
	if _current is Creek:_current.end_interaction()
	else:_current.end_hold()
	if respond:dialogue_phase="response";dialogue_index=0;_show_character_line()
	_update_page_controls()

func _replay_page()->void:
	if turning or transitioning:return
	page_states.erase(page_index);interactions.erase(page_index)
	_show_page()

func _process(delta:float)->void:
	if not visible or not prepared:return
	clock+=delta
	if holding:
		gesture_time+=delta
		gesture_ready=(_current.contact_active if _current is Creek else gesture_time>=1.2)
	_update_page_controls()
	var first_hint:bool=page_index==0 and dialogue_phase=="intro" and dialogue_index==0
	help.text="轻点画面继续" if first_hint else str(pages[page_index].get("hint",""))
	help.visible=first_hint or (marker!=null and marker.visible and (marker.is_hovered() or marker.has_focus()))
	if _current is MotionPage:help.hide()
	if _current!=null and not turning and not transitioning:
		if _current is Creek:_current.step_simulation(delta);energy=move_toward(energy,1.0 if holding else 0.0,delta)
		else:_current.step(delta);energy=_current.energy;pan=clampf(.5+_current.gaze.x*.5,0,1)
	var media_paused:bool=_current is MotionPage and _current.paused
	wind.stream_paused=media_paused;music.stream_paused=media_paused
	sound.stream_paused=media_paused or _current is MotionPage
	if _audio_enabled and not transitioning and not media_paused:
		# This looping grass rustle belongs to the opening panorama only.
		# Action foley on later pages has its own player and must stay audible.
		if page_index==0:
			if not wind.playing:wind.play()
			wind.volume_db=move_toward(wind.volume_db,-5.0,96.0*delta)
		elif wind.playing:
			wind.volume_db=move_toward(wind.volume_db,-60.0,110.0*delta)
			if wind.volume_db<=-60.0:wind.stop()
		if _current is MotionPage:
			if sound.playing:sound.stop()
		else:
			if not sound.playing:sound.play()
			var nature_target:float=[-12,-13,-13,-10,-10,-15][page_index]+energy*(3 if page_index==3 else 1)
			sound.volume_db=lerpf(sound.volume_db,nature_target,1-exp(-delta*2))
		if _direction_effect!=null:
			var direction:=clampf((_current.pointer.x/BASE.x-.5)*1.3,-.65,.65) if page_index==3 else 0.0
			_direction_effect.pan=lerpf(_direction_effect.pan,direction,1-exp(-delta*3))

func _gui_input(event:InputEvent)->void:
	if _current is MotionPage:return
	if turning or transitioning:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and dialogue_phase in ["intro","response"]:advance_dialogue();accept_event()
		elif event.pressed and _can_interact(get_local_mouse_position()):
			_mouse_held=true;interact_at(get_local_mouse_position());accept_event()
		elif not event.pressed and _mouse_held:
			_mouse_held=false
			if not _key_held:_release_hold()
			accept_event()
	elif event is InputEventMouseMotion:
		mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if _can_interact(get_local_mouse_position()) else Control.CURSOR_ARROW
		if dragging:
			var point:=get_local_mouse_position();var relative:=point-drag_from;drag_from=point
			if not _current is Creek:_current.drag_hold(point,relative)

func _input(event:InputEvent)->void:
	if not visible or turning or transitioning:return
	if _current is MotionPage:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and _mouse_held:
		_mouse_held=false
		if not _key_held:_release_hold()
	if event is InputEventKey and not event.echo and event.physical_keycode==KEY_E:
		if event.pressed and dialogue_phase in ["intro","response"]:advance_dialogue();get_viewport().set_input_as_handled();return
		_key_held=event.pressed
		if _key_held:interact_at(target_screen())
		elif not _mouse_held:_release_hold()
		get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent)->void:
	if not visible or turning or transitioning:return
	if _current is MotionPage:return
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.physical_keycode in [KEY_F11,KEY_F]:fullscreen_requested.emit()
	elif event.physical_keycode==KEY_ESCAPE:
		_release_hold()
		if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN]:fullscreen_requested.emit()
	elif event.physical_keycode in [KEY_RIGHT,KEY_SPACE,KEY_ENTER]:
		if dialogue_phase in ["intro","response"]:advance_dialogue()
		else:turn_page(1)
	elif event.physical_keycode==KEY_LEFT:turn_page(-1)
	elif event.physical_keycode==KEY_R:_replay_page()
	else:return
	get_viewport().set_input_as_handled()

func turn_page(direction:int)->void:
	if turning or transitioning or (direction<0 and page_index==0):return
	if _current is MotionPage:
		if _current.paused:return
		if direction>0 and (not _current.completed or _current.busy):return
	if direction>0 and dialogue_phase!="complete":return
	if page_index==5 and direction>0:_depart();return
	turning=true;_release_hold(false);next_curl.hide();previous_curl.hide();marker.hide()
	if DisplayServer.get_name()=="headless":
		page_index=clampi(page_index+direction,0,5);frontier=maxi(frontier,page_index);_show_page();turning=false;_update_page_controls();return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var snap:=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var overlay:=TextureRect.new();overlay.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;overlay.texture=snap;overlay.size=size;overlay.z_index=30;overlay.mouse_filter=MOUSE_FILTER_STOP
	var material:=ShaderMaterial.new();material.shader=Turn;material.set_shader_parameter("direction",float(direction));overlay.material=material;add_child(overlay)
	page_index=clampi(page_index+direction,0,5);frontier=maxi(frontier,page_index);_show_page();next_curl.hide();previous_curl.hide()
	var tween:=create_tween();tween.tween_method(func(value:float):material.set_shader_parameter("progress",value),0.0,1.0,.72)
	await tween.finished;overlay.hide();overlay.mouse_filter=MOUSE_FILTER_IGNORE;overlay.queue_free();turning=false;_update_page_controls()

func _depart()->void:
	transitioning=true;_release_hold(false);next_curl.hide();previous_curl.hide();marker.hide()
	shade=ColorRect.new();shade.color=Color(.14,.16,.12,0);shade.size=size;shade.z_index=40;shade.mouse_filter=MOUSE_FILTER_STOP;add_child(shade)
	var tween:=create_tween();tween.tween_property(shade,"color:a",1,.65);tween.parallel().tween_property(wind,"volume_db",-55,.65);tween.parallel().tween_property(sound,"volume_db",-55,.65)
	tween.parallel().tween_property(music,"volume_db",-55,.65)
	await tween.finished
	# Hidden motion pages still receive _input unless explicitly deactivated.
	# The final motion page must release E/Space before world control returns.
	if _current is MotionPage:_current.set_active(false)
	finished.emit()
	await get_tree().process_frame
	tween=create_tween();tween.tween_property(self,"modulate:a",0,.85);await tween.finished
	wind.stop();sound.stop();music.stop();shade.queue_free();hide();modulate.a=1;transitioning=false;arrival_revealed.emit()

func _start_audio()->void:
	if not _audio_enabled:return
	if _direction_effect==null:
		_direction_bus_name="GrasslandDirection"+str(get_instance_id())
		AudioServer.add_bus();var bus:=AudioServer.bus_count-1;AudioServer.set_bus_name(bus,_direction_bus_name);AudioServer.set_bus_send(bus,"Ambience")
		_direction_effect=AudioEffectPanner.new();AudioServer.add_bus_effect(bus,_direction_effect);sound.bus=_direction_bus_name
	if wind.stream==null:
		wind.stream=load("res://assets/grassland-motion/environment.wav").duplicate()
		if wind.stream is AudioStreamWAV:
			wind.stream.loop_end=int(wind.stream.get_length()*wind.stream.mix_rate)
			wind.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	if sound.stream==null:sound.stream=Mix.stream("res://assets/grassland/nature-minimax.wav")
	wind.volume_db=-11;sound.volume_db=-12
	if page_index==0:wind.play()
	else:wind.stop()
	if _current is MotionPage:sound.stop()
	else:sound.play()
	if get_tree().get_first_node_in_group("new_game_score")!=null:music.stop()
	else:
		# Standalone six-page previews also get the new repaired score.
		if music.stream==null:
			var theme:=load("res://assets/music-v1/M03_six_vignettes_loop.wav").duplicate() as AudioStreamWAV
			theme.loop_mode=AudioStreamWAV.LOOP_FORWARD;theme.loop_end=roundi(theme.get_length()*theme.mix_rate);music.stream=theme
		music.volume_db=-32;music.play();create_tween().tween_property(music,"volume_db",-8.0,.4)

func _exit_tree()->void:
	if is_instance_valid(wind):wind.stop();wind.stream=null
	if is_instance_valid(sound):sound.stop();sound.stream=null
	if is_instance_valid(music):music.stop();music.stream=null
	if not _direction_bus_name.is_empty():
		var bus:=AudioServer.get_bus_index(_direction_bus_name)
		if bus>0:AudioServer.remove_bus(bus)
	_direction_effect=null

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:_release_hold()
