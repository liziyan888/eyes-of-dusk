extends Control
const Mix=preload("res://scripts/audio_mix.gd")
## Full-screen, player-paced dusk and two rests. Owns no world coordinates.
signal prepare_moon_scene
signal moon_arrival_revealed
signal prepare_night_walk
signal night_walk_revealed
signal cancelled
signal fullscreen_requested

const Hotspot=preload("res://scripts/comic_hotspot.gd")
const ROOT:="res://assets/sunset/"
const FIRST_FRAME=preload("res://assets/sunset/sunset_first_registered.png")
const LAST_FRAME=preload("res://assets/sunset/sunset_end_registered.png")
var waiting_for_video:=false
var fast_mode:=false
var muted:=false
var kind:="sunset"
var phase:="closed"
var serial:=0
var watched:=false
var wind_heard:=false
var input_locked:=false
var paused:=false
var watch_was_paused:=false
var data:Dictionary={}
var background:TextureRect
var video:VideoStreamPlayer
var cover:ColorRect
var speaker:Label
var text:Label
var note:Label
var markers:Control
var pause_menu:Control
var wind:AudioStreamPlayer
var lines:Array=[]
var line_index:=0
var after_lines:=Callable()
var typing:=0.0
var tweens:Array[Tween]=[]
var note_serial:=0

func _ready()->void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_STOP;clip_contents=true
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/sunset_experience.json"))
	background=TextureRect.new();background.size=size;background.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode=TextureRect.STRETCH_SCALE;background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	video=VideoStreamPlayer.new();video.size=size;video.expand=true;video.mouse_filter=MOUSE_FILTER_IGNORE
	video.stream=load(ROOT+"runtime.ogv");video.volume_db=-80;video.finished.connect(_watch_finished);add_child(video);video.hide()
	markers=Control.new();markers.size=size;markers.mouse_filter=MOUSE_FILTER_IGNORE;add_child(markers)
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"])
	speaker=_label(font,17,Vector2(64,573),Vector2(300,30));text=_label(font,22,Vector2(64,605),Vector2(1152,90))
	text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	note=_label(font,16,Vector2(750,498),Vector2(410,35))
	cover=ColorRect.new();cover.size=size;cover.color=Color(.025,.035,.055,0);cover.mouse_filter=MOUSE_FILTER_IGNORE;cover.z_index=100;add_child(cover)
	wind=AudioStreamPlayer.new();wind.bus="Ambience";add_child(wind)
	var wind_path:="res://assets/audio-polish-v1/A04_sunset_wind_loop.wav"
	if not ResourceLoader.exists(wind_path):wind_path="res://assets/ending/audio/wind-minimax.wav"
	var stream:AudioStreamWAV=Mix.stream(wind_path)
	wind.set_meta("soft_delivery",wind_path.contains("audio-polish-v1"))
	stream=stream.duplicate();stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	wind.stream=stream;wind.volume_db=-60;hide()

func _label(font:Font,font_size:int,position_value:Vector2,size_value:Vector2)->Label:
	var label:=Label.new();label.position=position_value;label.size=size_value
	label.mouse_filter=MOUSE_FILTER_IGNORE;label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(.98,.97,.92));label.add_theme_color_override("font_shadow_color",Color(0,0,0,.82))
	label.add_theme_constant_override("shadow_offset_y",2);add_child(label);return label

func duration(value:float)->float:return .025 if fast_mode else value

func begin(context:Dictionary={})->void:
	close();var token:=serial;show();kind=str(context.get("kind","sunset"));muted=not bool(context.get("audio_enabled",true))
	watched=false;wind_heard=false;phase="opening";input_locked=true;paused=false
	background.texture=FIRST_FRAME if kind=="sunset" else load(ROOT+"inn_rest_cg.png");background.show()
	cover.color=Color(.025,.035,.055,1);cover.show()
	if kind=="sunset":wind.play();_wind_level(-24)
	await _fade(0,duration(.65))
	if token!=serial:return
	input_locked=false
	if kind=="sunset":_say(data.entry,_ready_to_watch)
	else:_say(data.second_rest,_request_night)

func close()->void:
	serial+=1;note_serial+=1;phase="closed";input_locked=false;paused=false
	waiting_for_video=false
	for tween in tweens:
		if tween.is_valid():tween.kill()
	tweens.clear();lines.clear();after_lines=Callable()
	if video!=null:video.stop();video.paused=false;video.hide()
	if wind!=null:wind.stop()
	if markers!=null:_clear_markers()
	if speaker!=null:speaker.hide();text.hide();note.hide()
	if is_instance_valid(pause_menu):remove_child(pause_menu);pause_menu.queue_free()
	pause_menu=null;hide()

func _fade(alpha:float,seconds:float)->void:
	var tween:=create_tween();tweens.append(tween);tween.tween_property(cover,"color:a",alpha,seconds);await tween.finished

func _say(items:Array,callback:Callable)->void:
	_clear_markers();lines=items.duplicate(true);line_index=0;after_lines=callback;phase="dialogue";_show_line()

func _show_line()->void:
	if line_index>=lines.size():
		speaker.hide();text.hide();lines.clear();var callback:=after_lines;after_lines=Callable()
		if callback.is_valid():callback.call()
		return
	var line:Dictionary=lines[line_index];speaker.text=str(line.get("who","旁白"));text.text=str(line.text)
	if speaker.text in ["我","她","女孩"]:
		preload("res://scripts/dialogue_appearance.gd").attach(text,"her" if speaker.text in ["她","女孩"] else "man")
		text.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	elif text.has_node("DialogueAppearance"):
		text.get_node("DialogueAppearance").queue_free()
	speaker.show();text.show();typing=0;text.visible_characters=0 if not fast_mode else -1

func advance()->void:
	if not visible or input_locked or paused:return
	if not lines.is_empty():
		if text.visible_characters>=0 and text.visible_characters<text.text.length():text.visible_characters=-1;return
		line_index+=1;_show_line()
	elif phase=="watch":toggle_watch_pause()
	elif markers.get_child_count()>0:
		var focus:=get_viewport().gui_get_focus_owner()
		if focus is Button and markers.is_ancestor_of(focus):focus.pressed.emit()
		else:markers.get_child(0).pressed.emit()

func _clear_markers()->void:
	for marker in markers.get_children():markers.remove_child(marker);marker.queue_free()

func _marker(name:String,uv:Vector2,callback:Callable)->void:
	var marker:=Hotspot.new();marker.position=uv*size-Vector2(20,20);marker.accessibility_name=name
	marker.pressed.connect(callback);markers.add_child(marker)

func _ready_to_watch()->void:
	phase="ready";_clear_markers()
	_marker("凝望晚霞",Vector2(.73,.59),start_watch)
	if not wind_heard:_marker("静下来听晚风",Vector2(.27,.73),listen_wind)

func start_watch()->void:
	if phase!="ready" or watched:return
	_clear_markers();phase="watch";video.hide();video.modulate.a=0;video.paused=false;video.play();video.size=size;waiting_for_video=true
	_marker("暂停片刻或继续凝望",Vector2(.73,.59),toggle_watch_pause)
	_short_note("轻点，让这一刻停留。")
	if fast_mode:
		var token:=serial;await get_tree().create_timer(.06).timeout
		if token==serial:_watch_finished()

func toggle_watch_pause()->void:
	if phase!="watch":return
	video.paused=not video.paused
	_short_note("再看一会儿。" if video.paused else "晚霞继续慢慢暗下去。")

func _watch_finished()->void:
	if phase!="watch" or watched:return
	watched=true;waiting_for_video=false;background.texture=LAST_FRAME;background.show();video.hide();video.stop();video.modulate.a=1;note.hide()
	_say(data.after_watch,_show_return_markers)

func _show_return_markers()->void:
	phase="watched";_clear_markers()
	_marker("回去休息",Vector2(.50,.81),return_to_inn)
	if not wind_heard:_marker("静下来听晚风",Vector2(.27,.73),listen_wind)

func listen_wind()->void:
	if phase not in ["ready","watched"] or wind_heard:return
	wind_heard=true;_wind_level(-20)
	_say(data.wind,func():
		_wind_level(-24)
		if watched:_show_return_markers()
		else:_ready_to_watch())

func return_to_inn()->void:
	if phase!="watched":return
	_say(data.return_lines,_first_rest)

func _first_rest()->void:
	var token:=serial;input_locked=true;phase="rest_transition"
	await _fade(1,duration(.7))
	if token!=serial:return
	background.texture=load(ROOT+"inn_rest_cg.png");wind.stop()
	await _fade(0,duration(.7))
	if token!=serial:return
	input_locked=false;_say(data.first_rest,_request_night)

func _request_night()->void:
	var token:=serial;input_locked=true;phase="preparing_night";note.hide();_clear_markers()
	await _fade(1,duration(.8))
	if token!=serial:return
	background.hide();video.hide()
	if kind=="sunset":prepare_moon_scene.emit()
	else:prepare_night_walk.emit()

func acknowledge_moon_ready()->void:
	if phase!="preparing_night":return
	var token:=serial;phase="revealing_night"
	await _fade(0,duration(1.0))
	if token!=serial:return
	wind.stop();hide();phase="closed";input_locked=false
	if kind=="sunset":moon_arrival_revealed.emit()
	else:night_walk_revealed.emit()

func _short_note(value:String)->void:
	note_serial+=1;var token:=note_serial;note.text=value;note.modulate.a=1;note.show()
	await get_tree().create_timer(duration(2.1)).timeout
	if token!=note_serial:return
	var tween:=create_tween();tweens.append(tween);tween.tween_property(note,"modulate:a",0.0,duration(.5))

func _wind_level(value:float)->void:
	if bool(wind.get_meta("soft_delivery",false)):value=0.0 if value> -24 else -5.0
	var tween:=create_tween();tweens.append(tween);tween.tween_property(wind,"volume_db",-60.0 if muted else value,duration(1.5))

func _open_pause()->void:
	if input_locked or paused:return
	paused=true;watch_was_paused=video.paused
	if phase=="watch":video.paused=true
	pause_menu=Control.new();pause_menu.size=size;pause_menu.mouse_filter=MOUSE_FILTER_STOP;pause_menu.z_index=90;add_child(pause_menu)
	var shade:=ColorRect.new();shade.size=size;shade.color=Color(.02,.04,.06,.42);pause_menu.add_child(shade)
	var resume:=_pause_button("继续",Vector2(500,300),_close_pause)
	if kind=="sunset":_pause_button("回到旅馆外",Vector2(500,365),cancel)
	resume.grab_focus()

func _pause_button(value:String,at:Vector2,callback:Callable)->Button:
	var button:=Button.new();button.text=value;button.position=at;button.size=Vector2(280,48)
	button.add_theme_font_override("font",text.get_theme_font("font"));button.add_theme_font_size_override("font_size",23)
	for state in ["normal","hover","focus","pressed"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.pressed.connect(callback);pause_menu.add_child(button);return button

func _close_pause()->void:
	if not paused:return
	paused=false
	if phase=="watch":video.paused=watch_was_paused
	remove_child(pause_menu);pause_menu.queue_free();pause_menu=null;get_viewport().gui_release_focus()

func cancel()->void:
	if kind!="sunset" or input_locked:return
	close();cancelled.emit()

func _process(delta:float)->void:
	if not visible or paused:return
	if waiting_for_video and phase=="watch" and video.stream_position>=1.0/48.0:
		var texture:Texture2D=video.get_video_texture()
		if texture!=null and texture.get_width()>0:
			waiting_for_video=false;video.show()
			var tween:=create_tween();tweens.append(tween);tween.tween_property(video,"modulate:a",1.0,.12)
	if not lines.is_empty() and text.visible_characters>=0:
		typing+=delta*preload("res://scripts/reading_pace.gd").CHARACTERS_PER_SECOND;text.visible_characters=mini(text.text.length(),int(typing))

func _cycle_focus(backwards:bool)->void:
	var list:Array=[]
	if paused:list=pause_menu.find_children("*","Button",true,false)
	else:list=markers.get_children()
	if list.is_empty():return
	var focus:=get_viewport().gui_get_focus_owner();var index:=list.find(focus)
	index=posmod(index+(-1 if backwards else 1),list.size()) if index>=0 else (list.size()-1 if backwards else 0)
	list[index].grab_focus()

func _input(event:InputEvent)->void:
	if not visible:return
	if event is InputEventKey and event.pressed and not event.echo:
		var code:int=event.physical_keycode
		if code in [KEY_F,KEY_F11]:fullscreen_requested.emit()
		elif code==KEY_M:AudioSettings.toggle_mute()
		elif input_locked:pass
		elif code==KEY_ESCAPE:
			if paused:_close_pause()
			else:_open_pause()
		elif code==KEY_TAB:_cycle_focus(event.shift_pressed)
		elif code in [KEY_E,KEY_ENTER,KEY_SPACE]:
			if paused:
				var focus:=get_viewport().gui_get_focus_owner()
				if focus is Button and pause_menu.is_ancestor_of(focus):focus.pressed.emit()
			else:advance()
		get_viewport().set_input_as_handled()
	elif input_locked and event is InputEventMouseButton:get_viewport().set_input_as_handled()

func _gui_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		if not input_locked and not paused and not lines.is_empty():advance()
		accept_event()
