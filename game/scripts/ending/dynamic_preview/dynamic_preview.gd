extends Control
## Standalone, replayable sample. It does not load or save formal ending progress.
const ASSET:="res://assets/ending/dynamic-preview/"
const Mix=preload("res://scripts/audio_mix.gd")
const Pair=preload("res://scripts/subtitle_pair.gd")
const FontStyle=preload("res://scripts/subtitle_style.gd")
const Hotspot=preload("res://scripts/comic_hotspot.gd")
const Ship=preload("res://scripts/ending/dynamic_preview/ship_stage.gd")
const Pilot=preload("res://scripts/ending/dynamic_preview/pilot_mesh.gd")
const Lever=preload("res://scripts/ending/dynamic_preview/lever_stage.gd")
const ArtShader=preload("res://scripts/ending/dynamic_preview/dynamic_art.gdshader")
const AlphaShader=preload("res://scripts/ending/dynamic_preview/viewport_alpha.gdshader")
const Vignette=preload("res://scripts/ending/dynamic_preview/vignette.gdshader")
const HeatGlow=preload("res://scripts/ending/dynamic_preview/heat_glow.gdshader")
const MetalVeil=preload("res://scripts/ending/dynamic_preview/metal_veil.gdshader")
var phase:="intro"
var phase_clock:=0.0
var clock:=0.0
var paused:=false
var volume_was_paused:=false
var auto_demo:=false
var test_mode:=false
var quit_on_finish:=false
var turn_value:=0.0
var drag_active:=false
var drag_start:=0.0
var drag_initial:=0.0
var alarm_strength:=0.0
var pressure:=0.0
var completed:=false
var e_count:=0
var drag_count:=0
var cabin:Control
var cabin_art:TextureRect
var pilot:Node2D
var radar:Node2D
var radar_title:Label
var radar_density:Label
var outside:Control
var metal:TextureRect
var ship_view:SubViewport
var ship:Node3D
var ship_image:TextureRect
var metal_veil:TextureRect
var heat_glow:ColorRect
var lever_view:SubViewport
var lever:Node3D
var lever_image:TextureRect
var captions:Control
var e_button:Button
var lever_cue:Button
var lever_note:Label
var replay:Button
var pause_wash:ColorRect
var pause_label:Label
var fx:Node2D
var vignette:ColorRect
var music:AudioStreamPlayer
var room:AudioStreamPlayer
var alarm_sound:AudioStreamPlayer
var fracture:AudioStreamPlayer
var signals_audio:Array[AudioStreamPlayer]=[]
var overlay_points:Array[Dictionary]=[]
var visited:Array[String]=[]

func art(path:String,parent:Node,rect:Rect2)->TextureRect:
	var node:=TextureRect.new();node.texture=load(path);node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE
	node.position=rect.position;node.size=rect.size;node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func make_material(shader:Shader)->ShaderMaterial:
	var m:=ShaderMaterial.new();m.shader=shader;return m

func label(value:String,at:Vector2,shape:Vector2,font_size:=20)->Label:
	var node:=Label.new();node.text=value;node.position=at;node.size=shape;node.mouse_filter=MOUSE_FILTER_IGNORE;FontStyle.regular_font(node,font_size);add_child(node);return node

func sound(path:String,bus:String,level:float)->AudioStreamPlayer:
	var node:=AudioStreamPlayer.new();node.stream=Mix.stream(path);node.bus=bus;node.volume_db=level;add_child(node);signals_audio.append(node);return node

func make_view(parent:Node,shape:Vector2i)->SubViewport:
	var view:=SubViewport.new();view.size=shape;view.transparent_bg=true;view.own_world_3d=true;view.msaa_3d=Viewport.MSAA_4X;view.render_target_update_mode=SubViewport.UPDATE_ALWAYS;parent.add_child(view);return view

func viewport_art(view:SubViewport,parent:Node,rect:Rect2)->TextureRect:
	var node:=TextureRect.new();node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.texture=view.get_texture();node.position=rect.position;node.size=rect.size;node.stretch_mode=TextureRect.STRETCH_SCALE;node.material=make_material(AlphaShader);node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func _ready()->void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT);size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_IGNORE
	auto_demo="--preview-auto" in OS.get_cmdline_user_args();test_mode="--preview-test" in OS.get_cmdline_user_args();quit_on_finish="--preview-quit" in OS.get_cmdline_user_args()
	var clear:=ColorRect.new();clear.size=size;clear.color=Color("070d15");add_child(clear)
	cabin=Control.new();cabin.size=size;cabin.mouse_filter=MOUSE_FILTER_IGNORE;add_child(cabin)
	cabin_art=art(ASSET+"cockpit-2k.png",cabin,Rect2(Vector2.ZERO,size));cabin_art.material=make_material(ArtShader)
	radar=Node2D.new();cabin.add_child(radar);radar.draw.connect(_draw_radar.bind(radar))
	pilot=Pilot.new();pilot.position=Vector2(741,105);cabin.add_child(pilot)
	pilot.cloth.material=make_material(ArtShader)
	lever_view=make_view(cabin,Vector2i(520,480));lever=Lever.new();lever_view.add_child(lever)
	lever_image=viewport_art(lever_view,cabin,Rect2(421,420,260,240))
	outside=Control.new();outside.size=Vector2(572,322);outside.position=Vector2(48,111);outside.mouse_filter=MOUSE_FILTER_IGNORE;outside.clip_contents=true;add_child(outside)
	metal=art(ASSET+"metal-2k.png",outside,Rect2(Vector2.ZERO,outside.size));metal.material=make_material(ArtShader)
	ship_view=make_view(self,Vector2i(1920,1080));ship=Ship.new();ship_view.add_child(ship)
	ship_image=viewport_art(ship_view,outside,Rect2(Vector2.ZERO,outside.size));outside.hide()
	metal_veil=art(ASSET+"metal-2k.png",outside,Rect2(Vector2.ZERO,outside.size));metal_veil.material=make_material(MetalVeil)
	heat_glow=ColorRect.new();heat_glow.size=outside.size;heat_glow.material=make_material(HeatGlow);heat_glow.mouse_filter=MOUSE_FILTER_IGNORE;outside.add_child(heat_glow)
	vignette=ColorRect.new();vignette.size=size;vignette.mouse_filter=MOUSE_FILTER_IGNORE;vignette.material=make_material(Vignette);add_child(vignette)
	fx=Node2D.new();add_child(fx);fx.draw.connect(_draw_overlay.bind(fx))
	captions=Pair.new();add_child(captions);captions.names.her.text="领航员";captions.names.man.text="指令长"
	var radar_font:Font=captions.labels.man.get_theme_font("font")
	radar_title=label("地层雷达",screen_point(.10,.21)-Vector2(0,radar_font.get_ascent(17)),Vector2(240,30),17);radar_title.name="RadarTitle";radar_title.reparent(radar,false);radar_title.add_theme_color_override("font_color",Color(.65,.83,.9,.68))
	radar_density=label("6.3 g/cm³",screen_point(.11,.36)-Vector2(0,radar_font.get_ascent(22)),Vector2(240,38),22);radar_density.name="RadarDensity";radar_density.reparent(radar,false)
	e_button=Hotspot.new();e_button.radius=17;e_button.size=Vector2(52,52);e_button.position=Vector2(378,324);e_button.pressed.connect(stabilize);add_child(e_button)
	var glyph:=Label.new();glyph.text="E";glyph.size=e_button.size;glyph.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;glyph.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;glyph.mouse_filter=MOUSE_FILTER_IGNORE;FontStyle.regular_font(glyph,17);e_button.add_child(glyph)
	e_button.hide()
	lever_cue=Hotspot.new();lever_cue.radius=15;lever_cue.size=Vector2(56,56);lever_cue.pressed.connect(func():pass);add_child(lever_cue);lever_cue.hide()
	lever_note=label("向右拖动拉杆  /  A",Vector2(405,641),Vector2(320,32),17);lever_note.hide()
	replay=Button.new();replay.position=Vector2(1100,640);replay.size=Vector2(130,38);replay.text="重播  R"
	for state in ["normal","hover","pressed","focus"]:replay.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	replay.add_theme_font_override("font",captions.labels.man.get_theme_font("font"));replay.add_theme_font_size_override("font_size",20);replay.pressed.connect(restart);add_child(replay);replay.hide()
	pause_wash=ColorRect.new();pause_wash.size=size;pause_wash.color=Color(0,.015,.03,.64);pause_wash.mouse_filter=MOUSE_FILTER_IGNORE;add_child(pause_wash);pause_wash.hide()
	pause_label=label("已暂停 · Esc 继续",Vector2(420,325),Vector2(440,55),26);pause_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;pause_label.hide()
	music=sound("res://assets/ending/audio/bgm_depth.mp3","Music",-12)
	room=sound("res://assets/ending/audio/room-minimax.wav","Ambience",-21)
	alarm_sound=sound("res://assets/ending/audio/sfx_alarm.mp3","Effects",-11)
	fracture=sound("res://assets/ending/audio/sfx_fracture.mp3","Effects",-15);fracture.pitch_scale=.78
	var settings=get_node_or_null("/root/AudioSettings")
	if settings!=null:settings.panel_toggled.connect(_volume_panel)
	get_window().focus_exited.connect(func():if not auto_demo and not test_mode:set_paused(true))
	restart()

func restart()->void:
	phase="intro";phase_clock=0;clock=0;turn_value=0;alarm_strength=0;pressure=0;drag_active=false;completed=false;e_count=0;drag_count=0;visited=["intro"]
	outside.hide();outside.scale=Vector2.ONE;cabin.show();cabin.modulate=Color.WHITE;e_button.hide();lever_cue.hide();lever_note.hide();replay.hide();set_paused(false)
	lever.set_value(0);ship.turn=0;ship.strain=0;ship.time=0;pilot.clock=0
	captions.set_lines("", "飞船航行到十五小时四十分钟时。")
	captions.names.man.text="往事"
	music.volume_db=-12;music.play();room.play();alarm_sound.stop();fracture.stop()

func enter(next:String)->void:
	phase=next;phase_clock=0;visited.append(next)
	match phase:
		"wait_e":
			alarm_sound.play();e_button.show();captions.names.man.text="指令长";captions.set_lines("前面的物质密度……突然升高了！","稳住，准备转向！")
		"stabilized":
			e_button.hide();alarm_sound.stop();captions.set_lines("", "")
		"wait_lever":
			outside.show();lever_cue.show();lever_note.show();captions.set_lines("", "转向！向裂隙外！")
		"turn":
			lever_cue.hide();lever_note.hide();drag_active=false;captions.set_lines("", "")
		"strain":
			fracture.play();captions.set_lines("前部结合处……在震！", "")
		"complete":
			completed=true;captions.set_lines("", "抓紧扶手！");replay.show()

func stabilize()->void:
	if phase!="wait_e" or paused:return
	e_count+=1;enter("stabilized")

func lever_position()->Vector2:
	return lever_image.position+lever.knob_uv()*lever_image.size

func set_turn(value:float)->void:
	if phase!="wait_lever" or paused:return
	turn_value=clampf(value,0,1);lever.set_value(turn_value)
	if turn_value>=.93:
		turn_value=1;lever.set_value(1);drag_count+=1;enter("turn")

func set_paused(value:bool)->void:
	paused=value
	if pause_wash!=null:pause_wash.visible=paused;pause_label.visible=paused
	for node in signals_audio:node.stream_paused=paused

func _volume_panel(opened:bool)->void:
	if opened:
		volume_was_paused=paused;set_paused(true);pause_wash.hide();pause_label.hide()
	else:set_paused(volume_was_paused)

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:set_paused(not paused);get_viewport().set_input_as_handled();return
			KEY_R:restart();get_viewport().set_input_as_handled();return
			KEY_F11:get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN;return
		if not paused:
			if event.physical_keycode==KEY_E:stabilize()
			if event.physical_keycode==KEY_A:set_turn(1)
	if paused:return
	if phase=="wait_lever" and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.distance_to(lever_position())<=55:
			drag_active=true;drag_start=event.position.x;drag_initial=turn_value;get_viewport().set_input_as_handled()
		elif not event.pressed:drag_active=false
	elif phase=="wait_lever" and event is InputEventMouseMotion and drag_active:
		set_turn(drag_initial+(event.position.x-drag_start)/110.0);get_viewport().set_input_as_handled()

func _process(delta:float)->void:
	if paused:return
	clock+=delta;phase_clock+=delta
	match phase:
		"intro":if phase_clock>=1.8:enter("wait_e")
		"wait_e":if auto_demo and phase_clock>=1.4:stabilize()
		"stabilized":if phase_clock>=.85:enter("wait_lever")
		"wait_lever":if auto_demo and phase_clock>=.65:set_turn((phase_clock-.65)/1.20)
		"turn":if phase_clock>=2.6:enter("strain")
		"strain":if phase_clock>=3.5:enter("complete")
		"complete":if quit_on_finish and phase_clock>=2.2:get_tree().quit()
	alarm_strength=move_toward(alarm_strength,1.0 if phase=="wait_e" else .25,delta*1.2)
	radar_density.text="9.5 g/cm³" if phase!="intro" else "6.3 g/cm³";radar_density.add_theme_color_override("font_color",Color(Color("e88d73") if phase=="wait_e" else Color("8dc8d7"),.85))
	pressure=move_toward(pressure,1.0 if phase in ["strain","complete"] else .0,delta*.50)
	ship.turn=move_toward(ship.turn,turn_value,delta*.7);ship.strain=pressure;ship.update_pose(delta)
	pilot.stress=alarm_strength*.5+pressure*.6;pilot.update_pose(delta)
	lever_cue.position=lever_position()-lever_cue.size/2
	(cabin_art.material as ShaderMaterial).set_shader_parameter("clock",clock);(cabin_art.material as ShaderMaterial).set_shader_parameter("alarm",alarm_strength)
	(pilot.cloth.material as ShaderMaterial).set_shader_parameter("clock",clock);(pilot.cloth.material as ShaderMaterial).set_shader_parameter("alarm",alarm_strength)
	(metal.material as ShaderMaterial).set_shader_parameter("clock",clock);(metal.material as ShaderMaterial).set_shader_parameter("flow",.45+pressure)
	(vignette.material as ShaderMaterial).set_shader_parameter("clock",clock);(vignette.material as ShaderMaterial).set_shader_parameter("pressure",pressure)
	if outside.visible:
		var blend:=smoothstep(0,1,minf(phase_clock/.65,1)) if phase=="turn" else (1.0 if phase in ["strain","complete"] else 0.0)
		outside.position=Vector2(48,111).lerp(Vector2.ZERO,blend);outside.size=Vector2(572,322).lerp(size,blend)
		metal.size=outside.size;ship_image.size=outside.size
		metal_veil.size=outside.size;heat_glow.size=outside.size
		var nose_uv:Vector2=ship.camera.unproject_position(ship.craft.to_global(Vector3(-4.47,0,0)))/Vector2(ship_view.size)
		(heat_glow.material as ShaderMaterial).set_shader_parameter("nose_uv",nose_uv);(heat_glow.material as ShaderMaterial).set_shader_parameter("clock",clock);(heat_glow.material as ShaderMaterial).set_shader_parameter("pressure",pressure)
		(metal_veil.material as ShaderMaterial).set_shader_parameter("clock",clock);(metal_veil.material as ShaderMaterial).set_shader_parameter("pressure",pressure)
		cabin.modulate.a=1-blend
		if blend>=1:cabin.hide()
	if phase in ["strain","complete"]:
		outside.position=Vector2(sin(clock*29),cos(clock*23))*(pressure*1.4)
		outside.scale=Vector2.ONE*1.006
	if phase=="complete":music.volume_db=lerpf(music.volume_db,-21,delta*.8)
	radar.queue_redraw();fx.queue_redraw()

func screen_point(u:float,v:float)->Vector2:
	return Vector2(63,57).lerp(Vector2(552,169),u).lerp(Vector2(106,466).lerp(Vector2(612,461),u),v)

func _draw_radar(target:Node2D)->void:
	var amplitude:=18.0 if phase=="wait_e" else 4.0
	var points:=PackedVector2Array()
	for i in range(100):
		var u:=float(i)/99
		var v:=.59+sin(u*32-clock*5)*amplitude/350.0+sin(u*137-clock*13)*amplitude/700.0
		points.append(screen_point(u,v))
	var color:=Color("e88d73") if phase=="wait_e" else Color("8dc8d7")
	target.draw_polyline(points,Color(color,.12),6,true);target.draw_polyline(points,Color(color,.9),1.35,true)
	var sweep:=fmod(clock*.18,1.0);target.draw_line(screen_point(sweep,.16),screen_point(sweep,.89),Color(.5,.8,.9,.17),1,true)

func _draw_overlay(target:Node2D)->void:
	if outside.visible and phase=="wait_lever":
		target.draw_rect(Rect2(outside.position,outside.size),Color(.96,.95,.90,.75),false,2,true)
	if phase=="wait_lever":
		var start:=lever_position();var end:=start+Vector2(75,-18)
		target.draw_line(start+Vector2(23,0),end,Color(.85,.93,.95,.45),1.1,true)
		target.draw_line(end,end+Vector2(-11,-3),Color(.85,.93,.95,.45),1.1,true)
		target.draw_line(end,end+Vector2(-7,8),Color(.85,.93,.95,.45),1.1,true)
	if pressure>.02:
		var origin:Vector2=outside.position+ship.camera.unproject_position(ship.joint.global_position)/Vector2(ship_view.size)*outside.size
		for i in range(18):
			var k:=float(i);var life:=fmod(clock*1.1+k*.173,1.0)
			var direction:=Vector2(cos(k*2.4),sin(k*1.7))
			var p:Vector2=origin+direction*life*110+Vector2(0,life*life*80)
			var a:=sin(life*PI)*pressure*.6
			target.draw_line(p,p-direction*(2+life*5),Color(1,.7,.35,a),1.1,true)
