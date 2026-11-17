extends Control
## Isolated review slice. It neither loads nor writes formal chapter progress.
signal phase_changed(value:String)
const ASSET:="res://assets/ending/qte-preview/"
const BASE:=Vector2(1280,720)
const Hand=preload("res://scripts/ending/qte_preview/authored_hand.gd")
const CLEAN=preload("res://shaders/ending/qte_layer_clean.gdshader")
const Mix=preload("res://scripts/audio_mix.gd")
const Q1_LIMIT:=2.5
const Q2_LIMIT:=3.0
const KEY_CENTER:=Vector2(777,515)
const LEVER_START:=Vector2(694,445)
const LEVER_TRAVEL:=Vector2(190,5)
var phase:="intro"
var phase_clock:=0.0
var clock:=0.0
var deadline:=0.0
var progress:=0.0
var drag_active:=false
var key_active:=false
var drag_origin:=0.0
var drag_progress:=0.0
var manual_pause:=false
var suspended:=false
var test_mode:=false
var decode_clock:=0.0
var decode_wait:=false
var movie_name:=""
var results:Dictionary={}
var history:Array[String]=[]
var stage:Control
var poster:TextureRect
var movies:Dictionary={}
var video:VideoStreamPlayer
var qte_art:Control
var console_art:TextureRect
var key_cap:TextureRect
var lever:TextureRect
var key_hand:TextureRect
var lever_hand:TextureRect
var glow:TextureRect
var screen_view:SubViewport
var screen_mesh:Polygon2D
var screen_draw:Node2D
var monitor_title:Label
var monitor_value:Label
var monitor_detail:Label
var monitor_footer:Label
var cue_draw:Node2D
var cue_letter:Label
var cue_title:Label
var cue_detail:Label
var caption:Label
var intro:Control
var start_button:Button
var replay:Button
var pause_label:Label
var pause_shade:ColorRect
var music:AudioStreamPlayer
var room:AudioStreamPlayer
var alarm:AudioStreamPlayer
var strain:AudioStreamPlayer
var click_sound:AudioStreamPlayer
var confirmation:AudioStreamPlayer
var sounds:Array[AudioStreamPlayer]=[]
var movie_failed:=false

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=MOUSE_FILTER_STOP
	test_mode="--qte-test" in OS.get_cmdline_user_args()
	var bg:=ColorRect.new();bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT);bg.color=Color("080d15");bg.mouse_filter=MOUSE_FILTER_IGNORE;add_child(bg)
	stage=Control.new();stage.size=BASE;stage.mouse_filter=MOUSE_FILTER_IGNORE;stage.clip_contents=true;add_child(stage)
	poster=art(ASSET+"alarm-first.png",stage)
	for id in ["alarm","order","turn"]:
		var player:=VideoStreamPlayer.new();player.stream=load(ASSET+id+".ogv");player.expand=true;player.size=BASE;player.mouse_filter=MOUSE_FILTER_IGNORE;player.volume_db=-80;stage.add_child(player);player.hide();player.finished.connect(_movie_finished.bind(id));movies[id]=player
	qte_art=Control.new();qte_art.size=BASE;qte_art.mouse_filter=MOUSE_FILTER_IGNORE;stage.add_child(qte_art)
	console_art=art(ASSET+"key-console.png",qte_art)
	_make_monitor()
	key_cap=art(ASSET+"key-pressed.png",qte_art)
	lever=art(ASSET+"lever.png",qte_art);var clean:=ShaderMaterial.new();clean.shader=CLEAN;lever.material=clean
	key_hand=Hand.new();key_hand.configure(ASSET,"key");qte_art.add_child(key_hand)
	lever_hand=Hand.new();lever_hand.configure(ASSET,"lever");qte_art.add_child(lever_hand)
	glow=art(ASSET+"alarm-reflection.png",qte_art)
	cue_draw=Node2D.new();stage.add_child(cue_draw);cue_draw.draw.connect(_draw_cue)
	cue_letter=label("E",Rect2(0,0,44,44),22,stage);cue_letter.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;cue_letter.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	cue_title=label("确认警报",Rect2(0,0,300,32),22,stage)
	cue_detail=label("点击或按 E",Rect2(0,0,300,28),15,stage);cue_detail.modulate=Color("aebfce")
	caption=label("",Rect2(64,620,1040,60),24,stage);caption.set_meta("text_scope","qte-preview-caption");caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	intro=Control.new();intro.size=BASE;intro.mouse_filter=MOUSE_FILTER_IGNORE;stage.add_child(intro)
	label("落日六号 · 航行记录",Rect2(70,477,700,45),31,intro)
	label("航行第 15 小时 40 分",Rect2(72,527,650,32),20,intro)
	label("确认警报：E 或点击　　转向：向右拖动 或按住 D",Rect2(72,576,1040,32),18,intro)
	start_button=action("进入回顾",Rect2(73,636,180,45),start,intro)
	replay=action("重新回顾  R",Rect2(1010,642,200,42),restart,stage);replay.hide()
	pause_shade=ColorRect.new();pause_shade.size=BASE;pause_shade.color=Color(0,.015,.03,.55);pause_shade.mouse_filter=MOUSE_FILTER_IGNORE;stage.add_child(pause_shade);pause_shade.hide()
	pause_label=label("已暂停 · Esc 继续",Rect2(350,315,580,60),26,stage);pause_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pause_label.hide()
	music=sound("res://assets/ending/audio/bgm_depth.mp3","Music",-12)
	room=sound("res://assets/ending/audio/room-minimax.wav","Ambience",-20)
	alarm=sound(ASSET+"alarm.wav","Effects",-8)
	strain=sound(ASSET+"strain.wav","Effects",-10)
	click_sound=sound(ASSET+"click.wav","Effects",-5)
	confirmation=sound(ASSET+"confirm.wav","Effects",-9)
	alarm.finished.connect(func():if phase in ["q1_wait","q1_late","q2_wait","q2_late"]:alarm.play())
	room.finished.connect(func():if phase!="intro" and phase!="complete":room.play())
	music.finished.connect(func():if phase!="intro" and phase!="complete":music.play())
	resized.connect(_layout);get_window().focus_exited.connect(_focus_lost)
	_layout();restart()

func art(path:String,parent:Node)->TextureRect:
	var node:=TextureRect.new();node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE;node.texture=load(path);node.size=BASE;node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node
func label(value:String,rect:Rect2,points:int,parent:Node)->Label:
	var node:=Label.new();node.text=value;node.position=rect.position;node.size=rect.size;node.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"]);font.font_weight=400
	node.add_theme_font_override("font",font);node.add_theme_font_size_override("font_size",points);node.add_theme_color_override("font_color",Color("e7edf4"));parent.add_child(node);return node
func action(value:String,rect:Rect2,callback:Callable,parent:Node)->Button:
	var b:=Button.new();b.text=value;b.position=rect.position;b.size=rect.size;b.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus"]:b.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Microsoft YaHei"]);font.font_weight=400;b.add_theme_font_override("font",font);b.add_theme_font_size_override("font_size",22)
	b.pressed.connect(callback);parent.add_child(b);return b
func sound(path:String,bus:String,level:float)->AudioStreamPlayer:
	var p:=AudioStreamPlayer.new();p.stream=Mix.stream(path);p.bus=bus;p.volume_db=level;add_child(p);sounds.append(p);return p
func _layout()->void:
	if stage==null:return
	var available:=get_viewport_rect().size;var factor:=minf(available.x/BASE.x,available.y/BASE.y)
	stage.scale=Vector2.ONE*factor;stage.position=(available-BASE*factor)*.5

func _make_monitor()->void:
	screen_view=SubViewport.new();screen_view.size=Vector2i(900,500);screen_view.transparent_bg=false;screen_view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;qte_art.add_child(screen_view)
	var bg:=ColorRect.new();bg.size=Vector2(900,500);bg.color=Color("0c1c30");screen_view.add_child(bg)
	screen_draw=Node2D.new();screen_view.add_child(screen_draw);screen_draw.draw.connect(_draw_monitor)
	monitor_title=label("密度异常",Rect2(50,35,800,60),36,screen_view)
	monitor_value=label("6.3 → 9.5 g/cm³",Rect2(50,111,800,66),45,screen_view)
	monitor_detail=label("物质成分：铁 · 镍",Rect2(52,191,780,48),29,screen_view)
	monitor_footer=label("等待确认",Rect2(52,420,780,45),24,screen_view)
	var poly:=Polygon2D.new();poly.texture=screen_view.get_texture();poly.antialiased=true;qte_art.add_child(poly);screen_mesh=poly
	_monitor_geometry(false)

func _monitor_geometry(is_lever:bool)->void:
	var points:=PackedVector2Array();var uv:=PackedVector2Array();var cells:Array[PackedInt32Array]=[]
	# All four inner monitor corners, in the 1280x720 reference canvas.
	var a:=Vector2(602,129);var b:=Vector2(1176,49);var c:=Vector2(1090,394);var d:=Vector2(525,383)
	if is_lever:a=Vector2(601,120);b=Vector2(1177,31);c=Vector2(1090,380);d=Vector2(525,374)
	for y in range(9):
		for x in range(17):
			var u:=float(x)/16;var v:=float(y)/8;points.append(a.lerp(b,u).lerp(d.lerp(c,u),v));uv.append(Vector2(u*900,v*500))
	for y in range(8):
		for x in range(16):
			var i:=y*17+x;cells.append(PackedInt32Array([i,i+1,i+18,i+17]))
	screen_mesh.polygon=points;screen_mesh.uv=uv;screen_mesh.polygons=cells

func restart()->void:
	for p in movies.values():p.stop();p.hide()
	for s in sounds:s.stop()
	video=null;movie_name="";decode_wait=false;movie_failed=false;results.clear();history.clear();clock=0;manual_pause=false;suspended=false;progress=0;drag_active=false;key_active=false
	poster.texture=load(ASSET+"alarm-first.png");poster.show();qte_art.hide();intro.show();replay.hide();caption.text="";_cue(false);enter("intro")
	start_button.grab_focus();_refresh_pause()
func start()->void:
	if phase!="intro" or _blocked():return
	intro.hide();get_viewport().gui_release_focus();music.volume_db=-12;room.volume_db=-20;alarm.volume_db=-8;music.play();room.play();_play_movie("alarm")
func enter(value:String)->void:
	phase=value;phase_clock=0;history.append(value);phase_changed.emit(value)
func _blocked()->bool:
	var settings=get_node_or_null("/root/AudioSettings")
	return manual_pause or get_tree().paused or Engine.time_scale==0 or (settings!=null and settings.opened)
func _focus_lost()->void:
	if not test_mode and phase not in ["intro","complete"]:manual_pause=true;_clear_inputs()
func _clear_inputs()->void:drag_active=false;key_active=false
func _refresh_pause()->void:
	var value:=_blocked()
	if value and not suspended:_clear_inputs()
	suspended=value
	for p in movies.values():p.paused=value
	for s in sounds:s.stream_paused=value
	key_hand.set_process(not value);lever_hand.set_process(not value)
	pause_shade.visible=manual_pause;pause_label.visible=manual_pause
	start_button.disabled=value;replay.disabled=value

func _play_movie(id:String)->void:
	_cue(false);qte_art.hide();caption.text="";movie_name=id;decode_clock=0;decode_wait=true
	for p in movies.values():p.stop();p.hide()
	poster.texture=load(ASSET+id+"-first.png");poster.show();video=movies[id];video.paused=false;video.play();enter(id+"_movie")
	if id=="alarm":caption.text="航行到十五小时四十分钟时，第一声警报响了。"
	elif id=="order":caption.text="指令长：转向！"
	elif id=="turn":strain.volume_db=-9;strain.play();caption.text=""
func _movie_finished(id:String)->void:
	if movie_name!=id or phase!=id+"_movie":return
	poster.texture=load(ASSET+id+"-last.png");poster.show();video.hide();video.stop();decode_wait=false
	match id:
		"alarm":_show_key()
		"order":_show_lever()
		"turn":
			enter("complete");alarm.stop();room.volume_db=-25;music.volume_db=-20;caption.text="转向已经执行。发动机接合处，仍在承受巨大的压力。";replay.show()

func _show_key()->void:
	_monitor_geometry(false)
	qte_art.show();console_art.texture=load(ASSET+"key-console.png");key_cap.hide();lever.hide();key_hand.show();lever_hand.hide();key_hand.reach(0);key_hand.settle();key_hand.modulate.a=1
	monitor_title.text="密度异常";monitor_value.text="6.3 → 9.5 g/cm³";monitor_detail.text="物质成分：铁 · 镍";monitor_footer.text="确认警报 · 保持操控"
	caption.text="";deadline=Q1_LIMIT;alarm.volume_db=-8;alarm.play();music.volume_db=-16;enter("q1_enter")
func _show_lever()->void:
	_monitor_geometry(true)
	qte_art.show();console_art.texture=load(ASSET+"lever-console.png");key_cap.hide();lever.show();key_hand.hide();lever_hand.show();lever_hand.pose(0);lever_hand.settle();lever.position=Vector2.ZERO;progress=0
	monitor_title.text="紧急转向";monitor_value.text="转向指令待执行";monitor_detail.text="推至锁定位 · 脱离异常区域";monitor_footer.text="操纵杆未到位"
	caption.text="";deadline=Q2_LIMIT;alarm.volume_db=-11;alarm.play();strain.volume_db=-14;strain.play();enter("q2_enter")
func _cue(on:bool)->void:
	cue_draw.visible=on;cue_letter.visible=on;cue_title.visible=on;cue_detail.visible=on
func _cue_layout()->void:
	var first:=phase=="q1_wait"
	var center:=KEY_CENTER if first else LEVER_START+LEVER_TRAVEL*progress
	cue_letter.text="E" if first else "D";cue_letter.position=center-Vector2(22,22)
	if first:
		cue_title.position=center+Vector2(45,-20);cue_detail.position=center+Vector2(46,14);cue_title.text="确认警报";cue_detail.text="点击或按 E"
	else:
		cue_title.position=Vector2(684,580);cue_detail.position=Vector2(685,614);cue_title.text="向右推至锁定位";cue_detail.text="拖动握柄　或按住 D / →"
	cue_draw.queue_redraw()
func confirm_alarm()->void:
	if phase!="q1_wait" or _blocked():return
	results.q1="timely";_resolve_alarm()
func _resolve_alarm()->void:
	_cue(false);click_sound.play();alarm.stop();confirmation.play();monitor_footer.text="警报已确认 · 故障持续";enter("q1_result")
func _set_lever(value:float)->void:
	progress=clampf(value,0,1);lever.position=LEVER_TRAVEL*progress;lever_hand.pose(progress);screen_draw.queue_redraw()
	if phase=="q2_wait" and progress>=.985:
		results.q2="timely";_resolve_lever()
func _resolve_lever()->void:
	_set_lever_finished();_clear_inputs();_cue(false);alarm.stop();click_sound.play();confirmation.play();monitor_value.text="转向指令已执行";monitor_footer.text="操纵杆已锁定";enter("q2_result")
func _set_lever_finished()->void:
	progress=1;lever.position=LEVER_TRAVEL;lever_hand.pose(1);lever_hand.settle()

func _process(delta:float)->void:
	_refresh_pause()
	if suspended:return
	# No global time scaling: local QTE clocks and sounds cannot drift with movies.
	clock+=delta;phase_clock+=delta
	if decode_wait:
		decode_clock+=delta;var texture:=video.get_video_texture()
		if video.stream_position>=.001 and texture!=null and texture.get_width()>0:video.show();decode_wait=false
		elif decode_clock>6:
			movie_failed=true;manual_pause=true;pause_label.text="影片暂未加载 · Esc 重试";return
	match phase:
		"alarm_movie":
			if phase_clock>.55 and not alarm.playing:alarm.play()
		"q1_enter":
			key_hand.reach(smoothstep(0,.45,phase_clock))
			if phase_clock>=.55:key_hand.pose(0);enter("q1_wait");_cue(true)
		"q1_wait":
			deadline=maxf(0,deadline-delta);alarm.volume_db=lerpf(-3,-8,deadline/Q1_LIMIT)
			if deadline<=0:results.q1="late";_cue(false);monitor_footer.text="确认延迟";enter("q1_late")
		"q1_late":
			key_hand.pose(0,sin(minf(phase_clock/.55,1)*PI))
			if phase_clock>=.55:_resolve_alarm()
		"q1_result":
			var amount:=smoothstep(0,.24,phase_clock);key_hand.pose(amount);key_cap.visible=amount>.52
			if phase_clock>=.95:_play_movie("order")
		"q2_enter":
			if phase_clock>=.45:enter("q2_wait");_cue(true)
		"q2_wait":
			if key_active:_set_lever(progress+delta/.95)
			if phase=="q2_wait":
				deadline=maxf(0,deadline-delta);alarm.volume_db=lerpf(-4,-11,deadline/Q2_LIMIT)
				if deadline<=0:results.q2="late";drag_progress=progress;_clear_inputs();_cue(false);monitor_footer.text="转向延迟 · 继续推杆";strain.play();enter("q2_late")
		"q2_late":
			_set_lever(lerpf(drag_progress,1,smoothstep(.3,.95,phase_clock)))
			if phase_clock>=1:_resolve_lever()
		"q2_result":
			if phase_clock>=.5:_play_movie("turn")
	if qte_art.visible:
		var strength:=.14 if phase in ["q1_result","q2_result"] else .3
		glow.modulate.a=strength*(.7+.3*sin(clock*4.8));screen_draw.queue_redraw()
	if cue_draw.visible:_cue_layout()

func _input(event:InputEvent)->void:
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null and studio.editing:return
	if event is InputEventKey:
		if event.physical_keycode in [KEY_D,KEY_RIGHT] and not event.pressed:key_active=false
		if event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
			if movie_failed:
				movie_failed=false;manual_pause=false;pause_label.text="已暂停 · Esc 继续";_play_movie(movie_name);get_viewport().set_input_as_handled();return
			manual_pause=not manual_pause;_clear_inputs();get_viewport().set_input_as_handled();return
		if _blocked() or event.echo:return
		if event.physical_keycode in [KEY_D,KEY_RIGHT] and phase=="q2_wait":
			key_active=event.pressed;get_viewport().set_input_as_handled()
		elif event.pressed:
			match event.physical_keycode:
				KEY_E,KEY_SPACE:
					if phase=="q1_wait":confirm_alarm();get_viewport().set_input_as_handled()
				KEY_ENTER:
					if phase=="intro":start();get_viewport().set_input_as_handled()
				KEY_R:
					if phase=="complete":restart();get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and not event.pressed:drag_active=false;lever_hand.settle()
	if _blocked():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
		if phase=="q1_wait" and Rect2(KEY_CENTER-Vector2(68,65),Vector2(310,140)).has_point(point):confirm_alarm();get_viewport().set_input_as_handled()
		elif phase=="q2_wait" and Rect2(LEVER_START+LEVER_TRAVEL*progress-Vector2(62,62),Vector2(130,145)).has_point(point):
			drag_active=true;drag_origin=point.x;drag_progress=progress;get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and drag_active and phase=="q2_wait":
		var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
		_set_lever(drag_progress+(point.x-drag_origin)/LEVER_TRAVEL.x);get_viewport().set_input_as_handled()

func _draw_cue()->void:
	if phase not in ["q1_wait","q2_wait"]:return
	var first:=phase=="q1_wait";var center:=KEY_CENTER if first else LEVER_START+LEVER_TRAVEL*progress
	var remaining:=deadline/(Q1_LIMIT if first else Q2_LIMIT)
	var color:=Color("eef5fc") if remaining>.35 else Color("efad79")
	cue_draw.draw_circle(center,24,Color(.025,.07,.12,.27))
	cue_draw.draw_arc(center,24,0,TAU,64,Color(1,1,1,.35),1.2,true)
	cue_draw.draw_arc(center,29,-PI/2,-PI/2+TAU*remaining,64,color,2.3,true)
	if not first:
		var end:=LEVER_START+LEVER_TRAVEL
		cue_draw.draw_line(LEVER_START+Vector2(0,79),end+Vector2(0,79),Color(1,1,1,.35),1.5,true)
		cue_draw.draw_line(LEVER_START+Vector2(0,79),center+Vector2(0,79),Color("a9dce3"),2.5,true)
		cue_draw.draw_line(end+Vector2(0,72),end+Vector2(0,86),color,2,true)
		cue_draw.draw_line(center+Vector2(41,0),center+Vector2(59,0),color,1.5,true)
		cue_draw.draw_line(center+Vector2(51,-7),center+Vector2(59,0),color,1.5,true)
		cue_draw.draw_line(center+Vector2(51,7),center+Vector2(59,0),color,1.5,true)
func _draw_monitor()->void:
	var color:=Color("e0a16b") if phase.begins_with("q1") else Color("80b9c7")
	for x in range(50,860,60):screen_draw.draw_line(Vector2(x,270),Vector2(x,394),Color(.3,.5,.65,.12),1)
	for y in range(270,400,31):screen_draw.draw_line(Vector2(50,y),Vector2(850,y),Color(.3,.5,.65,.12),1)
	if phase.begins_with("q1"):
		var points:=PackedVector2Array()
		for x in range(50,851,4):
			var wave:=sin(x*.045-clock*1.4)*4+sin(x*.13)*2
			var step:=smoothstep(340.0,385.0,float(x))*65
			points.append(Vector2(x,371-step+wave))
		screen_draw.draw_polyline(points,color,2.3,true)
	else:
		screen_draw.draw_line(Vector2(52,337),Vector2(848,337),Color(.3,.5,.65,.45),4,true)
		screen_draw.draw_line(Vector2(52,337),Vector2(52+796*progress,337),color,5,true)
		screen_draw.draw_circle(Vector2(52+796*progress,337),7,color)

func _exit_tree()->void:
	for p in movies.values():if is_instance_valid(p):p.stop()
	for s in sounds:if is_instance_valid(s):s.stop()
