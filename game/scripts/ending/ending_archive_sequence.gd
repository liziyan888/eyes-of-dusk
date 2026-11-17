extends "res://scripts/ending/ending_memory_video.gd"
## Only player commands cross the two archive gates. Movies cannot open the archive.
signal archive_opening
signal launch_started
const ZOOM = preload("res://shaders/ending/archive_screen_zoom.gdshader")
const Descent = preload("res://scripts/ending/descent/ending_descent.gd")
var archive_spec:Dictionary={}
var part:="room"
var archive:TextureRect
var archive_text:Control
var play_button:Button
var archive_button:Button
var continue_button:Button
var zoom_material:ShaderMaterial
var descent:Control
var archive_results:Dictionary={}

func _ready()->void:
	super._ready()
	archive=TextureRect.new();archive.size=size;archive.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;archive.stretch_mode=TextureRect.STRETCH_SCALE;archive.mouse_filter=MOUSE_FILTER_IGNORE;add_child(archive);archive.hide()
	archive_text=Control.new();archive_text.size=size;archive_text.mouse_filter=MOUSE_FILTER_IGNORE;archive.add_child(archive_text)
	var eyebrow:=_caption("历史影像档案",Rect2(390,221,500,32),16,Color("a9c2dd"));archive_text.add_child(eyebrow)
	var title:=_caption("落日工程",Rect2(340,279,600,64),38,Color("edf2fa"));archive_text.add_child(title)
	var detail:=_caption("飞船驶向的，不是天空，而是地球深处。",Rect2(250,367,780,38),21,Color("c3d0e2"));archive_text.add_child(detail)
	play_button=_action("播放",Rect2(826,308,140,44),request_play);play_button.accessibility_name="播放落日工程档案";add_child(play_button)
	archive_button=_action("进入回顾",Rect2(540,463,200,48),request_recap);archive_text.add_child(archive_button)
	continue_button=_action("继续回顾",Rect2(525,642,230,44),finish_recap);add_child(continue_button)
	play_button.hide();continue_button.hide()
	# Pause indicator stays above the archive and every video poster.
	move_child(note,get_child_count()-1)

func _caption(value:String,rect:Rect2,points:int,color:Color)->Label:
	var label:=Label.new();label.text=value;label.position=rect.position;label.size=rect.size;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;label.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"]);font.font_weight=400
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",points);label.add_theme_color_override("font_color",color)
	return label

func _action(value:String,rect:Rect2,callback:Callable)->Button:
	var button:=Button.new();button.text=value;button.position=rect.position;button.size=rect.size;button.mouse_default_cursor_shape=CURSOR_POINTING_HAND
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Microsoft YaHei"]);font.font_weight=400;button.add_theme_font_override("font",font);button.add_theme_font_size_override("font_size",21)
	for state in ["normal","hover","pressed","focus","disabled"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color("e0eaf5"));button.add_theme_color_override("font_hover_color",Color.WHITE);button.add_theme_color_override("font_focus_color",Color.WHITE)
	var gradient:=Gradient.new();gradient.offsets=PackedFloat32Array([0,.25,.75,1]);gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,.55),Color(1,1,1,.55),Color(1,1,1,0)])
	var texture:=GradientTexture2D.new();texture.gradient=gradient;texture.fill_to=Vector2(1,0)
	for y in [0.0,rect.size.y-1]:
		var line:=TextureRect.new();line.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;line.texture=texture;line.position=Vector2(0,y);line.size=Vector2(rect.size.x,1);line.mouse_filter=MOUSE_FILTER_IGNORE;button.add_child(line)
	button.pressed.connect(callback);return button

func begin(spec:Dictionary)->void:
	archive_spec=spec.archive;archive.texture=load(str(archive_spec.background));super.begin(spec)

func _paused_now()->bool:
	var audio=get_node_or_null("/root/AudioSettings")
	return manually_paused or get_tree().paused or Engine.time_scale==0 or (audio!=null and audio.opened)

func _process(delta:float)->void:
	super._process(delta)
	if is_instance_valid(descent):descent.host_paused=_paused_now()
	for button in [play_button,archive_button,continue_button]:
		if is_instance_valid(button):button.disabled=_paused_now()

func _movie_finished()->void:
	if done:return
	if part=="room":
		poster.texture=last_frame;poster.show();video.hide();video.stop();phase="wait_play";play_button.show();play_button.grab_focus()
	else:
		poster.texture=load(str(archive_spec.last_frame));poster.show();video.hide();video.stop();phase="launch_hold";continue_button.show();continue_button.grab_focus()

func request_play()->void:
	if phase!="wait_play" or _paused_now():return
	phase="zoom";play_button.hide();get_viewport().gui_release_focus();archive_opening.emit()
	zoom_material=ShaderMaterial.new();zoom_material.shader=ZOOM;zoom_material.set_shader_parameter("progress",0.0);poster.material=zoom_material
	archive.modulate.a=0;archive_text.hide();archive.show()
	motion_tween=create_tween()
	motion_tween.tween_method(func(value:float):zoom_material.set_shader_parameter("progress",value),0.0,1.0,1.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	motion_tween.tween_property(archive,"modulate:a",1.0,.45)
	motion_tween.tween_callback(_archive_ready)

func _archive_ready()->void:
	phase="archive";poster.hide();archive_text.modulate.a=0;archive_text.show()
	motion_tween=create_tween();motion_tween.tween_property(archive_text,"modulate:a",1.0,.45)
	archive_button.grab_focus()

func request_recap()->void:
	if phase!="archive" or _paused_now():return
	if bool(archive_spec.get("full_descent",false)):
		phase="descent_enter";part="descent";archive_button.release_focus();archive_text.hide();launch_started.emit()
		descent=Descent.new();descent.embedded=true;descent.size=size;descent.modulate.a=0;add_child(descent)
		descent.archive_finished.connect(_descent_finished)
		descent.begin_archive()
		motion_tween=create_tween();motion_tween.tween_property(descent,"modulate:a",1.0,.4)
		motion_tween.tween_callback(func():archive.hide();phase="descent")
		return
	phase="launch_enter";part="launch";archive_button.release_focus();archive_text.hide();launch_started.emit()
	poster.material=null;poster.texture=load(str(archive_spec.first_frame));poster.show()
	video.stream=load(str(archive_spec.stream));video.hide();video.modulate.a=0;video.volume_db=-60;decode_time=0
	motion_tween=create_tween();motion_tween.tween_property(archive,"modulate:a",0.0,.45)
	motion_tween.tween_callback(func():archive.hide();phase="decode";video.play())

func finish_recap()->void:
	if phase!="launch_hold" or _paused_now():return
	continue_button.hide();get_viewport().gui_release_focus();phase="hold";done=true;playback_finished.emit()

func handle_input(event:InputEvent)->void:
	if is_instance_valid(descent):
		descent.handle_event(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:
		match phase:
			"wait_play":request_play()
			"archive":request_recap()
			"launch_hold":finish_recap()
		get_viewport().set_input_as_handled()

func toggle_pause()->void:
	if is_instance_valid(descent):descent.manual_pause=not descent.manual_pause;descent._clear_inputs()
	else:super.toggle_pause()

func _descent_finished(result:Dictionary)->void:
	if done:return
	archive_results=result.duplicate(true);phase="hold";done=true;playback_finished.emit()

func close()->void:
	if is_instance_valid(descent):descent.shutdown()
	super.close()
