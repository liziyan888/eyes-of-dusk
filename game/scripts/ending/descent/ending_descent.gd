extends "res://scripts/ending/qte_preview/qte_preview.gd"
## Full historical reconstruction. All three results are gated by player input.
signal archive_finished(result:Dictionary)
const FULL="res://assets/ending/descent/"
const Q3_LIMIT=2.5
const GRIP=Vector2(496,549)
var embedded:=false
var host_paused:=false
var stopped:=false
var order_card_shown:=false
var fracture_sounded:=false
var card_id:=""
var card:Control
var card_title:Label
var card_text:Label
var card_button:Button
var seat:Control
var seated:TextureRect
var seat_glow:TextureRect
var surface:AudioStreamPlayer
var fracture:AudioStreamPlayer
var final_button:Button
var caption_back:ColorRect
var card_diagram:Node2D
var card_marker:Label

func _ready()->void:
	super._ready()
	for id in ["launch","lava","descent","cabin","rear","fracture","reaction","sinking","ground"]:
		var player:=VideoStreamPlayer.new();player.stream=load(FULL+id+".ogv");player.expand=true;player.size=BASE;player.mouse_filter=MOUSE_FILTER_IGNORE;player.volume_db=-80
		stage.add_child(player);stage.move_child(player,qte_art.get_index());player.hide();player.finished.connect(_movie_finished.bind(id));movies[id]=player
	seat=Control.new();seat.size=BASE;seat.mouse_filter=MOUSE_FILTER_IGNORE;stage.add_child(seat);stage.move_child(seat,cue_draw.get_index())
	art(FULL+"seat.png",seat);seated=art(FULL+"seat-reach.png",seat)
	var clean:=ShaderMaterial.new();clean.shader=CLEAN;clean.set_shader_parameter("remove_red_fringe",true);seated.material=clean
	seat_glow=art(ASSET+"alarm-reflection.png",seat);seat.hide()
	caption_back=ColorRect.new();caption_back.position=Vector2(40,607);caption_back.size=Vector2(1200,82);caption_back.color=Color(.025,.045,.065,.27);caption_back.mouse_filter=MOUSE_FILTER_IGNORE
	stage.add_child(caption_back);stage.move_child(caption_back,caption.get_index());caption_back.hide()
	caption.position=Vector2(66,624);caption.size=Vector2(1140,64)
	card=Control.new();card.size=BASE;card.mouse_filter=MOUSE_FILTER_IGNORE;stage.add_child(card)
	var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.75,1]);gradient.colors=PackedColorArray([Color(.015,.035,.065,.8),Color(.015,.035,.065,.48),Color(.015,.035,.065,0)])
	var shade_texture:=GradientTexture2D.new();shade_texture.gradient=gradient;shade_texture.fill_to=Vector2(0,1)
	var shade:=TextureRect.new();shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shade.texture=shade_texture;shade.size=Vector2(1280,330);shade.mouse_filter=MOUSE_FILTER_IGNORE;card.add_child(shade)
	card_diagram=Node2D.new();card.add_child(card_diagram);card_diagram.draw.connect(_draw_card_diagram)
	card_marker=label("",Rect2(740,432,460,65),19,card)
	card_title=label("",Rect2(78,64,1100,50),30,card)
	card_text=label("",Rect2(80,135,1080,155),23,card);card_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	card_button=action("继续回顾",Rect2(1000,642,210,44),advance_card,card);card.hide()
	final_button=action("继续档案",Rect2(1020,650,190,44),finish_archive,stage);final_button.hide()
	for n in [pause_shade,pause_label]:stage.move_child(n,stage.get_child_count()-1)
	surface=sound(FULL+"launch.wav","Effects",-7)
	fracture=sound(FULL+"fracture.wav","Effects",-5)
	alarm.finished.connect(func():if phase in ["q3_wait","q3_late"]:alarm.play())
	if embedded:set_process_input(false)
	_layout()
	if not embedded:
		var labels:=intro.get_children()
		labels[0].text="落日六号 · 事故档案"
		labels[1].text="发射、下潜与紧急操控"
		labels[2].text="确认：E　　推杆：拖动 / D　　抓稳：F　　暂停：Esc"

func _layout()->void:
	if stage==null:return
	if embedded:stage.scale=Vector2.ONE;stage.position=Vector2.ZERO
	else:super._layout()

func _blocked()->bool:return host_paused or super._blocked()
func start()->void:
	if phase=="intro" and not _blocked():begin_archive()
func begin_archive()->void:
	super.restart();stopped=false;order_card_shown=false;fracture_sounded=false
	intro.hide();replay.hide();seat.hide();final_button.hide();get_viewport().gui_release_focus()
	room.stop()
	if not embedded:
		var score_path:="res://assets/audio-polish-v1/A01_ending_depth_loop.wav"
		if ResourceLoader.exists(score_path):music.stream=Mix.stream(score_path)
		music.volume_db=-8;music.play()
	else:music.stop()
	_show_card("direction","direction.png","落日工程","落日飞船潜入地球深处。原计划的十次发射，因为落日六号的失事而中断。\n\n以下是地面保存的历史影像与航行记录。")
func _show_card(id:String,file:String,title:String,text:String)->void:
	for player in movies.values():player.stop();player.hide()
	decode_wait=false;movie_name="";qte_art.hide();seat.hide();_cue(false);caption.text=""
	poster.texture=load(FULL+file);poster.show();card.show();card_id=id;card_title.text=title;card_text.text=text;enter("archive_card");card_button.grab_focus()
	match id:
		"direction":card_marker.text="航向：地球深处";card_marker.position=Vector2(740,480)
		"strata":card_marker.text="3100 公里 · 已有的潜航记录";card_marker.position=Vector2(740,400)
		"fissure":card_marker.text="2500 公里 · 提前进入铁镍区域";card_marker.position=Vector2(735,480)
func advance_card()->void:
	if phase!="archive_card" or _blocked():return
	card.hide();get_viewport().gui_release_focus()
	match card_id:
		"direction":_play_movie("launch")
		"strata":_play_movie("descent")
		"fissure":_play_movie("order")

func _play_movie(id:String)->void:
	if id=="order" and not order_card_shown:
		order_card_shown=true
		_show_card("fissure","fissure.png","异常深度 · 2500 公里","密度从 6.3 猛增到 9.5 克/立方厘米，主要成分变为铁镍。\n\n他们撞进了一条从地核延伸上来的裂隙——在 2500 公里的深度，提前闯入了地核。")
		return
	seat.hide();card.hide();final_button.hide();surface.stop()
	if id in ["alarm","order","turn"]:
		super._play_movie(id);return
	_cue(false);qte_art.hide();caption.text="";movie_name=id;decode_clock=0;decode_wait=true
	for player in movies.values():player.stop();player.hide()
	poster.texture=load(FULL+id+"-first.png");poster.show();video=movies[id];video.paused=false;video.play();enter(id+"_movie")
	match id:
		"launch":caption.text="四年前，我在电视中看到过落日一号发射时的情景。";music.volume_db=-23
		"lava":caption.text="远处的人们，也能感觉到飞船穿过地层时的微微振动。";strain.volume_db=-17;strain.play()
		"descent":caption.text="落日六号依靠前方的烧熔发动机切开物质，向地球深处航行。";music.volume_db=-16
		"cabin":caption.text="他们只能凭感觉，触摸周围不断向上移去的高密度物质。"
		"rear":caption.text="一种地面上的人难以理解的压抑感，折磨着每一个地航员。"
		"fracture":caption.text="发动机与主舱的接合部断裂了。";fracture_sounded=false;strain.volume_db=-7;strain.play()
		"reaction":caption.text="没有烧熔发动机，落日六号在地层中寸步难行。";alarm.stop();music.volume_db=-21
		"sinking":caption.text="浮力小于飞船的自重。落日六号，就这样向地心沉下去。";music.volume_db=-19
		"ground":caption.text="事故影像回放结束。地面的记录里，信号仍在。";room.volume_db=-20

func _movie_finished(id:String)->void:
	if stopped or movie_name!=id or phase!=id+"_movie":return
	if id in ["alarm","order"]:super._movie_finished(id);return
	var dir:=ASSET if id=="turn" else FULL
	poster.texture=load(dir+id+"-last.png");poster.show();video.hide();video.stop();decode_wait=false
	match id:
		"launch":_play_movie("lava")
		"lava":_show_card("strata","strata.png","正常潜航","前五艘飞船都安全返回，落日五号创造了 3100 公里的深度记录。\n\n地幔与地核的交界面在约 3400—3500 公里深处。落日六号的设计强度，不允许它进入液态铁镍的地核。")
		"descent":_play_movie("cabin")
		"cabin":_play_movie("rear")
		"rear":_play_movie("alarm")
		"turn":
			poster.texture=load(FULL+"joint-warning.png");caption.text="发动机接合处正在承受巨大的压力。";strain.volume_db=-7;strain.play();enter("joint_alert")
		"fracture":_play_movie("reaction")
		"reaction":_play_movie("sinking")
		"sinking":_play_movie("ground")
		"ground":
			enter("archive_hold");final_button.show();final_button.grab_focus();alarm.stop();strain.stop();music.volume_db=-24

func _show_grip()->void:
	qte_art.hide();seat.show();seated.texture=load(FULL+"seat-reach.png")
	seat_glow.modulate.a=.24;deadline=Q3_LIMIT;caption.text="指令长：抓稳！";alarm.volume_db=-7;alarm.play();enter("q3_enter")
func grip()->void:
	if phase!="q3_wait" or _blocked():return
	results.q3="timely";_grip_result()
func _grip_result()->void:
	seated.texture=load(FULL+"seat-grip.png");_cue(false);alarm.stop();click_sound.play();confirmation.play()
	seat_glow.modulate.a=.07;caption.text="";enter("q3_result")
func finish_archive()->void:
	if phase!="archive_hold" or _blocked() or stopped:return
	stopped=true;final_button.hide();get_viewport().gui_release_focus()
	for audio in sounds:audio.stop()
	archive_finished.emit({"qte":results.duplicate(true),"history":history.duplicate(),"archive":"sunset6-descent-v1"})
func shutdown()->void:
	stopped=true;_clear_inputs();set_process(false);set_process_input(false)
	for player in movies.values():player.stop()
	for audio in sounds:audio.stop()
	hide()

func _process(delta:float)->void:
	if stopped:return
	super._process(delta)
	if card==null:return
	card_button.disabled=_blocked();final_button.disabled=_blocked()
	caption_back.visible=not caption.text.is_empty() and not card.visible
	if suspended:return
	if card.visible:card_diagram.queue_redraw()
	if phase=="launch_movie" and not decode_wait and not surface.playing and video.stream_position<.35:surface.play()
	match phase:
		"joint_alert":
			if phase_clock>=1.1:_show_grip()
		"q3_enter":
			if phase_clock>=.35:enter("q3_wait");_cue(true)
		"q3_wait":
			deadline=maxf(0,deadline-delta);seat_glow.modulate.a=.18+.08*sin(clock*4);alarm.volume_db=lerpf(-3,-8,deadline/Q3_LIMIT)
			if deadline<=0:
				results.q3="late";_cue(false);seated.texture=load(FULL+"seat-miss.png");strain.play();enter("q3_late")
		"q3_late":
			if phase_clock>=.42:_grip_result()
		"q3_result":
			if phase_clock>=.75:_play_movie("fracture")
		"fracture_movie":
			if not decode_wait and video.stream_position>=3.2 and not fracture_sounded:fracture_sounded=true;fracture.play()
	if phase=="q3_wait":_cue_layout()

func _cue_layout()->void:
	if phase!="q3_wait":super._cue_layout();return
	cue_letter.text="F";cue_letter.position=GRIP-Vector2(22,22)
	cue_title.position=GRIP+Vector2(48,-22);cue_detail.position=GRIP+Vector2(49,12)
	cue_title.text="抓稳扶手";cue_detail.text="点击或按 F";cue_draw.queue_redraw()
func _draw_card_diagram()->void:
	var tint:=Color(.76,.88,1,.72)
	var start:=Vector2(640,385);var end:=Vector2(640,510)
	if card_id=="strata":start=Vector2(640,310);end=Vector2(640,428)
	elif card_id=="fissure":start=Vector2(640,365);end=Vector2(640,510);tint=Color(1,.7,.4,.82)
	var progress:=smoothstep(0,1.2,phase_clock)
	var point:=start.lerp(end,progress)
	card_diagram.draw_line(start,point,tint,1.5,true)
	card_diagram.draw_circle(point,4,tint)
	card_diagram.draw_arc(point,10,-PI/2,TAU-PI/2,48,Color(tint,.25+.12*sin(clock*2)),1,true)
	if progress>.99:
		card_diagram.draw_line(end,end+Vector2(78,0),Color(tint,.45),1,true)
		card_diagram.draw_line(end-Vector2(5,8),end,tint,1.5,true);card_diagram.draw_line(end-Vector2(-5,8),end,tint,1.5,true)
func _draw_cue()->void:
	if phase!="q3_wait":super._draw_cue();return
	var remaining:=deadline/Q3_LIMIT;var color:=Color("edf4fb") if remaining>.35 else Color("edac79")
	cue_draw.draw_circle(GRIP,24,Color(.025,.07,.12,.3));cue_draw.draw_arc(GRIP,24,0,TAU,64,Color(1,1,1,.4),1.2,true)
	cue_draw.draw_arc(GRIP,29,-PI/2,-PI/2+TAU*remaining,64,color,2.3,true)
func _input(event:InputEvent)->void:handle_event(event)
func handle_event(event:InputEvent)->void:
	if stopped:return
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null and studio.editing:return
	if not _blocked():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.physical_keycode==KEY_F and phase=="q3_wait":grip();get_viewport().set_input_as_handled();return
			if event.physical_keycode in [KEY_ENTER,KEY_SPACE] and phase in ["archive_card","archive_hold"]:
				if phase=="archive_card":advance_card()
				else:finish_archive()
				get_viewport().set_input_as_handled();return
		if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and phase=="q3_wait":
			var point:Vector2=stage.get_global_transform_with_canvas().affine_inverse()*event.position
			if point.distance_to(GRIP)<65:grip();get_viewport().set_input_as_handled();return
	super._input(event)
