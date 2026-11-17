extends Control
const Mix=preload("res://scripts/audio_mix.gd")
## Morning is a skin and a state of scene five, never a sixth world scene.
signal prepared
signal arrived
signal glasses_recovered
signal bird_heard
signal interaction_cancelled
signal fullscreen_requested
const ROOT := "res://assets/moon5-morning/"
const Hotspot = preload("res://scripts/comic_hotspot.gd")
const Pair=preload("res://scripts/subtitle_pair.gd")
const W:=256
const H:=128
var active := false
var busy := false
var recovered := false
var heard := false
var fast_mode := false
var muted := false
var weather:Dictionary={"rain_opacity":.43,"mist_opacity":.28,"sunbeams_opacity":.10}
var mode := ""
var serial := 0
var clock := 0.0
var manifest: Dictionary
var skin_textures: Dictionary = {}
var props: Dictionary = {}
var veil: ColorRect
var caption: Label
var modal: Control
var glass_image: TextureRect
var lens_material: ShaderMaterial
var wipe_points := PackedVector4Array()
var probes: Array[Vector2] = []
var wiping := false
var wipe_progress := 0.0
var listening_ready := false
var rain: AudioStreamPlayer
var rain_level:=-17.0
var rain_focus_level:=-21.0
var bird: AudioStreamPlayer
var tweens: Array[Tween] = []
var prop=preload("res://scripts/sensor_glasses.gd").new()
var front_texture:Texture2D=preload("res://assets/props/sensor_glasses_v2/front.png")
var mask_texture:Texture2D=preload("res://assets/props/sensor_glasses_v2/lens_mask.png")
var mask_image:Image
var guided_running:=false
var debug_blocked:=false
var subtitle_settings:Dictionary={}
var subtitles:Control
var wipe_marker:Button
var wipe_hint:Label
var clean_data:=PackedByteArray()
var clean_image:Image
var clean_texture:ImageTexture
var wipe_dirty:=false
var last_wipe_uv:=Vector2(-1,-1)
var modal_paused:=false

func _ready() -> void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_STOP
	manifest=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for key in ["sky","clouds","far","forest","tree"]:skin_textures[key]=_texture(key)
	skin_textures["ground"]=load("res://assets/moon5-psb/ground.png")
	for key in ["rain","mist","sunbeams"]:props[key]=_texture(key)
	props["glasses"]=prop.IMAGE
	mask_image=mask_texture.get_image()
	if mask_image.is_compressed():mask_image.decompress()
	veil=ColorRect.new();veil.size=size;veil.color=Color(.025,.035,.05,0);veil.mouse_filter=MOUSE_FILTER_IGNORE;add_child(veil)
	caption=Label.new();caption.position=Vector2(64,625);caption.size=Vector2(1152,65);caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Microsoft YaHei"])
	caption.add_theme_font_override("font",font);caption.add_theme_font_size_override("font_size",21)
	caption.add_theme_color_override("font_color",Color("eff2ed"));caption.add_theme_color_override("font_shadow_color",Color(0,0,0,.75));caption.add_theme_constant_override("shadow_offset_y",2)
	caption.mouse_filter=MOUSE_FILTER_IGNORE;add_child(caption)
	rain=AudioStreamPlayer.new();rain.bus="Ambience";add_child(rain);bird=AudioStreamPlayer.new();bird.bus="Effects";add_child(bird)
	for x in range(40):
		for y in range(24):
			var uv:=Vector2((x+.5)/40.0,(y+.5)/24.0)
			if uv.x>.13 and uv.x<.87 and uv.y>.29 and uv.y<.74 and _inside_lens(uv):probes.append(uv)
	subtitles=Pair.new();subtitles.z_index=12;add_child(subtitles);subtitles.hide();subtitles.apply_style(subtitle_settings)
	_reset_wipe_surface()
	hide()

func apply_subtitle_style(value:Dictionary)->void:
	subtitle_settings=value.duplicate(true)
	if subtitles!=null:subtitles.apply_style(subtitle_settings)

func _reset_wipe_surface()->void:
	clean_data.resize(W*H);clean_data.fill(0);clean_image=Image.create_from_data(W,H,false,Image.FORMAT_L8,clean_data);clean_texture=ImageTexture.create_from_image(clean_image);wipe_dirty=false;last_wipe_uv=Vector2(-1,-1)

func _texture(key:String,trim:=true)->Texture2D:
	var source:Texture2D=load(ROOT+key+".png")
	if not trim:return source
	var b:Array=manifest.layers[key].runtime_region
	var texture:=AtlasTexture.new();texture.atlas=source;texture.region=Rect2(b[0],b[1],b[2],b[3]);return texture

func duration(value:float)->float:return .035 if fast_mode else value

func reset() -> void:
	serial+=1;active=false;busy=false;recovered=false;heard=false;mode="";wiping=false;guided_running=false;wipe_points.clear();wipe_progress=0;debug_blocked=false;modal_paused=false;_reset_wipe_surface()
	for t in tweens:
		if t.is_valid():t.kill()
	tweens.clear();rain.stop();bird.stop()
	if is_instance_valid(modal):modal.queue_free()
	modal=null;glass_image=null;lens_material=null;wipe_marker=null;veil.hide();caption.hide();subtitles.hide();hide()

func begin_return() -> void:
	if busy or active:return
	serial+=1;var token:=serial;busy=true;mode="transition";show();veil.show();caption.show();caption.modulate.a=1
	veil.color=Color(.025,.035,.05,0);caption.text="我回到旅馆，很快便睡着了。"
	var t:=create_tween();tweens.append(t);t.tween_property(veil,"color:a",1.0,duration(1.2));await t.finished
	if token!=serial:return
	await get_tree().create_timer(duration(1.5)).timeout
	if token!=serial:return
	caption.text="醒来时，窗外已经下起了小雨。";active=true;prepared.emit();_load_audio()
	await get_tree().create_timer(duration(1.3)).timeout
	if token!=serial:return
	t=create_tween().set_parallel(true);tweens.append(t);t.tween_property(veil,"color:a",0.0,duration(1.4));t.tween_property(caption,"modulate:a",0.0,duration(.8));await t.finished
	if token!=serial:return
	busy=false;mode="";hide();arrived.emit()

func _load_audio() -> void:
	var rain_path:="res://assets/audio-polish-v1/A05_morning_rain_loop.wav"
	if not ResourceLoader.exists(rain_path):rain_path=ROOT+"audio/rain.wav"
	rain_level=-6.0 if rain_path.contains("audio-polish-v1") else -17.0
	rain_focus_level=-12.0 if rain_path.contains("audio-polish-v1") else -21.0
	if ResourceLoader.exists(rain_path):
		var stream:AudioStreamWAV=Mix.stream(rain_path);stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_end=int(round(stream.get_length()*stream.mix_rate));rain.stream=stream;rain.volume_db=-60;rain.play()
		var fade:=create_tween();tweens.append(fade);fade.tween_property(rain,"volume_db",-60.0 if muted else rain_level,1.2)
	if ResourceLoader.exists(ROOT+"audio/bird.wav"):bird.stream=Mix.stream(ROOT+"audio/bird.wav")
	bird.volume_db=-60 if muted else -4

func draw_world(canvas:CanvasItem,game:Node) -> void:
	if not active or game.scene_index!=4:return
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	canvas.draw_texture_rect(props.sunbeams,Rect2(-80,0,1400,720),false,Color(1,1,1,float(weather.get("sunbeams_opacity",.10))))
	canvas.draw_texture_rect(props.mist,Rect2(-100+sin(clock*.12)*30,390,1480,160),false,Color(1,1,1,float(weather.get("mist_opacity",.28))))
	var offset:=fposmod(clock*112,720.0)
	for row in [-1,0,1]:canvas.draw_texture_rect(props.rain,Rect2(-70+fposmod(clock*28,65),row*720+offset,1420,720),false,Color(1,1,1,float(weather.get("rain_opacity",.43))))
	for point in game.points():
		if busy:continue
		if game.completed.has(point.id) or not game.point_available(point):continue
		if recovered and point.id=="s5-morning-glasses":continue
		var cue:Vector2=game.point_position(point) if point.id=="s5-morning-glasses" else game.interaction_cue_world(point)
		var p:Vector2=cue-Vector2(game.camera_x,0)
		var hover:bool=game._screen(cue).distance_to(game.get_global_mouse_position())<36
		var r:=8.0+(1.0+sin(clock*3.3))*.8 if hover else 8.0
		canvas.draw_arc(p+Vector2(0,1),r,0,TAU,48,Color(.04,.08,.1,.25),2.5,true)
		canvas.draw_arc(p,r,0,TAU,48,Color(1,1,1,.95 if hover else .66),1.4,true)
	canvas.draw_set_transform(Vector2.ZERO)

func draw_glasses(canvas:CanvasItem,game:Node)->void:
	if not active or game.scene_index!=4 or recovered or mode in ["retrieving","wipe","wearing"]:return
	var target:Vector2=game.glasses_support_position()-Vector2(game.camera_x,0)
	prop.draw_hanging(canvas,game,target,0,Color(.87,.92,.98,.96))

func _inside_lens(uv:Vector2)->bool:
	if uv.x<=0 or uv.y<=0 or uv.x>=1 or uv.y>=1:return false
	var x:=int(uv.x*(mask_image.get_width()-1));var y:=int(uv.y*(mask_image.get_height()-1))
	for offset in [Vector2i.ZERO,Vector2i(3,0),Vector2i(-3,0),Vector2i(0,3),Vector2i(0,-3)]:
		var pixel:=mask_image.get_pixel(clampi(x+offset.x,0,mask_image.get_width()-1),clampi(y+offset.y,0,mask_image.get_height()-1))
		if pixel.a*pixel.r<.8:return false
	return true

func begin_inspection() -> void:
	if busy or recovered or not active:return
	serial+=1;var token:=serial
	busy=true;mode="retrieving";wiping=false;guided_running=false;last_wipe_uv=Vector2(-1,-1);show();veil.show();veil.color=Color(.04,.07,.09,.25);caption.hide();subtitles.show();subtitles.set_lines("","眼镜仍挂在红柳枝上，镜片蒙着水雾。我轻轻取下来，擦干它。")
	modal=Control.new();modal.size=size;modal.mouse_filter=MOUSE_FILTER_IGNORE;add_child(modal)
	glass_image=TextureRect.new();glass_image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;glass_image.texture=front_texture;glass_image.position=Vector2(140,110);glass_image.size=Vector2(1000,500);glass_image.mouse_filter=MOUSE_FILTER_IGNORE;modal.add_child(glass_image)
	lens_material=ShaderMaterial.new();lens_material.shader=preload("res://shaders/morning_lens.gdshader");lens_material.set_shader_parameter("lens_mask",mask_texture);lens_material.set_shader_parameter("clean_mask",clean_texture);glass_image.material=lens_material;_update_lens()
	glass_image.modulate.a=0
	wipe_marker=Hotspot.new();wipe_marker.name="WipeFixedCircle";wipe_marker.radius=11;wipe_marker.position=Vector2(620,530);wipe_marker.accessibility_name="轻拭镜片";wipe_marker.pressed.connect(_guided_wipe);modal.add_child(wipe_marker);wipe_marker.hide()
	wipe_hint=Label.new();wipe_hint.text="轻拭镜片";wipe_hint.position=Vector2(440,500);wipe_hint.size=Vector2(400,32);wipe_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;wipe_hint.mouse_filter=MOUSE_FILTER_IGNORE;Pair.Style.regular_font(wipe_hint,17);modal.add_child(wipe_hint);wipe_hint.hide()
	get_viewport().gui_release_focus()
	var t:=create_tween();tweens.append(t);t.tween_property(glass_image,"modulate:a",1.0,duration(.3));await t.finished
	if token!=serial:return
	mode="wipe";wipe_marker.show();wipe_hint.show()

func _wipe(screen:Vector2) -> void:
	if mode!="wipe" or glass_image==null:return
	var uv:Vector2=(screen-glass_image.position)/glass_image.size
	if not Rect2(0,0,1,1).has_point(uv):last_wipe_uv=Vector2(-1,-1);return
	if last_wipe_uv.x>=0 and last_wipe_uv.distance_to(uv)<.012:return
	_paint_wipe_segment(last_wipe_uv if last_wipe_uv.x>=0 else uv,uv);last_wipe_uv=uv
	if wipe_points.size()<512:wipe_points.append(Vector4(uv.x,uv.y,0,0))
	var clean:=0
	for probe in probes:
		if clean_data[clampi(int(probe.y*H),0,H-1)*W+clampi(int(probe.x*W),0,W-1)]>=190:clean+=1
	wipe_progress=float(clean)/maxf(1,probes.size())
	if wipe_progress>=.70:_update_lens();_finish_wipe()

func _paint_wipe_segment(from:Vector2,to:Vector2)->void:
	var low:Vector2=(from.min(to)-Vector2(.078,.156))*Vector2(W,H)
	var high:Vector2=(from.max(to)+Vector2(.078,.156))*Vector2(W,H)
	var a:=from*Vector2(2,1);var b:=to*Vector2(2,1)
	for y in range(maxi(0,int(low.y)),mini(H,ceili(high.y))):
		for x in range(maxi(0,int(low.x)),mini(W,ceili(high.x))):
			var p:=Vector2((x+.5)/W*2.0,(y+.5)/H)
			var closest:Vector2=Geometry2D.get_closest_point_to_segment(p,a,b)
			var amount:=int(clampf((.15-p.distance_to(closest))/.05,0,1)*255)
			var index:int=y*W+x
			if amount>clean_data[index]:clean_data[index]=amount;wipe_dirty=true

func _update_lens() -> void:
	if not wipe_dirty:return
	clean_image.set_data(W,H,false,Image.FORMAT_L8,clean_data);clean_texture.update(clean_image);wipe_dirty=false

func _guided_wipe() -> void:
	if guided_running or mode!="wipe":return
	guided_running=true
	var token:=serial
	var bounds:=Rect2(probes[0],Vector2.ZERO)
	for probe in probes:bounds=bounds.expand(probe)
	for row in range(6):
		for col in range(13):
			if mode!="wipe" or token!=serial:guided_running=false;return
			while debug_blocked or AudioSettings.opened:
				await get_tree().process_frame
				if mode!="wipe" or token!=serial:guided_running=false;return
			var column:=col if row%2==0 else 12-col
			var uv:=bounds.position+Vector2((column+.5)/13.0,(row+.5)/6.0)*bounds.size
			_wipe(glass_image.position+uv*glass_image.size)
			await get_tree().create_timer(duration(.028)).timeout
	guided_running=false

func _finish_wipe() -> void:
	if mode!="wipe":return
	mode="wearing";wiping=false;last_wipe_uv=Vector2(-1,-1)
	wipe_marker.hide();wipe_hint.hide();subtitles.set_lines("","擦干净了。我重新戴上她的眼睛。")
	lens_material.set_shader_parameter("clear_amount",1.0)
	var token:=serial
	var upper:=ColorRect.new();upper.color=Color(.031,.055,.09);upper.size=Vector2(1280,0);upper.mouse_filter=MOUSE_FILTER_IGNORE;upper.z_index=40;modal.add_child(upper)
	var lower:=ColorRect.new();lower.color=upper.color;lower.position=Vector2(0,720);lower.size=Vector2(1280,0);lower.mouse_filter=MOUSE_FILTER_IGNORE;lower.z_index=40;modal.add_child(lower)
	var t:=create_tween().set_parallel(true);tweens.append(t)
	t.tween_property(upper,"size:y",361.0,duration(.3));t.tween_property(lower,"position:y",359.0,duration(.3));t.tween_property(lower,"size:y",361.0,duration(.3));await t.finished
	if token!=serial:return
	recovered=true;glass_image.hide();subtitles.hide();veil.color.a=0
	t=create_tween().set_parallel(true);tweens.append(t)
	t.tween_property(upper,"size:y",0.0,duration(.5));t.tween_property(lower,"position:y",720.0,duration(.5));t.tween_property(lower,"size:y",0.0,duration(.5));await t.finished
	if token!=serial:return
	_close_interaction();glasses_recovered.emit()

func begin_listening() -> void:
	if busy or heard or not recovered:return
	busy=true;mode="listen";listening_ready=false;show();veil.hide();caption.text="“听……”\n我停下来，仔细听着雨中的声音。";caption.modulate.a=1;caption.show()
	modal=Control.new();modal.size=size;modal.mouse_filter=MOUSE_FILTER_IGNORE;add_child(modal)
	var marker:=Hotspot.new();marker.position=Vector2(805,470);marker.accessibility_name="静静听一听";marker.pressed.connect(_hear_bird);modal.add_child(marker)
	var token:=serial;await get_tree().create_timer(duration(.35)).timeout
	if token==serial:listening_ready=true;marker.grab_focus()

func _hear_bird() -> void:
	if mode!="listen" or not listening_ready:return
	mode="hearing";heard=true
	if not muted:
		rain.volume_db=rain_focus_level;bird.volume_db=-4
		if bird.stream!=null:bird.play()
	caption.text="";var token:=serial
	await get_tree().create_timer(duration(1.8)).timeout
	if token!=serial:return
	var rain_fade:=create_tween();tweens.append(rain_fade);rain_fade.tween_property(rain,"volume_db",-60.0 if muted else rain_level,1.0)
	_close_interaction();bird_heard.emit()

func _close_interaction() -> void:
	serial+=1
	if is_instance_valid(modal):modal.queue_free()
	modal=null;glass_image=null;lens_material=null;wipe_marker=null;busy=false;mode="";wiping=false;guided_running=false;last_wipe_uv=Vector2(-1,-1);subtitles.hide();hide();get_viewport().gui_release_focus()

func fade_audio() -> void:
	var t:=create_tween();tweens.append(t);t.tween_property(rain,"volume_db",-60.0,1.5);t.tween_callback(rain.stop)

func _process(delta:float) -> void:
	var paused:bool=debug_blocked or AudioSettings.opened
	if paused!=modal_paused:
		modal_paused=paused
		for t in tweens:
			if t.is_valid():
				if paused:t.pause()
				else:t.play()
	if paused:wiping=false;last_wipe_uv=Vector2(-1,-1);return
	clock+=delta
	if wipe_dirty:_update_lens()

func _input(event:InputEvent) -> void:
	if not visible or debug_blocked or AudioSettings.opened:return
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:wiping=false;last_wipe_uv=Vector2(-1,-1)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F2:return
		if event.physical_keycode in [KEY_F,KEY_F11]:fullscreen_requested.emit()
		elif event.physical_keycode==KEY_M:
			AudioSettings.toggle_mute()
		elif mode=="wipe" and event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:_guided_wipe()
		elif mode=="listen" and event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:_hear_bird()
		elif mode in ["wipe","listen"] and event.physical_keycode==KEY_ESCAPE:_close_interaction();interaction_cancelled.emit()
		get_viewport().set_input_as_handled()

func _gui_input(event:InputEvent) -> void:
	if not visible or debug_blocked or AudioSettings.opened:return
	if event is InputEventMouseButton:
		if mode=="wipe" and event.button_index==MOUSE_BUTTON_LEFT:
			wiping=event.pressed
			if not wiping:last_wipe_uv=Vector2(-1,-1)
			if wiping:_wipe(event.position)
		elif mode=="listen" and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:_hear_bird()
		accept_event()
	elif event is InputEventMouseMotion and mode=="wipe" and wiping:
		_wipe(event.position);accept_event()
