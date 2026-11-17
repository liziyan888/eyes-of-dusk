extends Control
## Owns the world-to-ending cover and keeps both readers isolated while it fades.
signal return_to_title_requested
signal fullscreen_requested
signal ending_completed(result:Dictionary)
signal ready_to_reveal
signal transparent_earth_requested
var module:Control
var serial:=0
var placeholder:=false
var transitioning:=false
var cover:ColorRect
var transition_tween:Tween
var completion_emitted:=false
var last_result:Dictionary={}
var preview_mode:=false

func _ready() -> void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_STOP;hide()

func begin(context:Dictionary={}) -> void:
	close();var token:=serial;show();transitioning=true
	last_result.clear();completion_emitted=false
	get_viewport().gui_release_focus()
	var shown:bool=await ChapterTransition.play(3,self,_prepare_module.bind(context,token))
	if not shown or token!=serial:return
	transitioning=false
	if is_instance_valid(module):
		module.set("input_locked",false);module.set_process_input(true);module.set_process_unhandled_input(true)
	get_viewport().gui_release_focus();ready_to_reveal.emit()

func _prepare_module(context:Dictionary,token:int)->void:
	if token!=serial:return
	var scene_path:="res://scenes/ending/ending_comic.tscn"
	if ResourceLoader.exists(scene_path):
		module=load(scene_path).instantiate();add_child(module)
		if module.has_signal("transparent_earth_requested"):
			module.connect("transparent_earth_requested",func():
				if token==serial:transparent_earth_requested.emit())
		if preview_mode:module.set("test_mode",true)
		module.set_process_input(false);module.set_process_unhandled_input(false)
		if module.has_signal("return_to_title_requested"):
			module.connect("return_to_title_requested",func():
				if token==serial:return_to_title_requested.emit())
		if module.has_signal("fullscreen_requested"):
			module.connect("fullscreen_requested",func():
				if token==serial:fullscreen_requested.emit())
		if module.has_signal("ending_completed"):
			module.connect("ending_completed",func(result:Dictionary):
				if token!=serial or completion_emitted:return
				completion_emitted=true;last_result=result.duplicate(true)
				ending_completed.emit(last_result))
		if module.has_signal("ready_to_reveal"):
			module.connect("ready_to_reveal",func():_reveal_module(token),CONNECT_ONE_SHOT)
		if module.has_method("begin"):module.call("begin",context)
		module.set("input_locked",true)
		if not module.has_signal("ready_to_reveal"):_reveal_module(token)
		return
	# A non-interactive bridge only. Do not claim this is the finished 41-panel ending.
	placeholder=true
	var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	var source:Texture2D=load("res://assets/ending-entry/01-reference.png")
	var crop:=AtlasTexture.new();crop.atlas=source;crop.region=Rect2(48,2,source.get_width()-50,source.get_height()-4)
	image.texture=crop;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;image.size=size;image.mouse_filter=MOUSE_FILTER_IGNORE;add_child(image)
	var text:=Label.new();text.text="又回到了灰色的生活和忙碌的工作中。";text.position=Vector2(60,625);text.size=Vector2(1150,60)
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Microsoft YaHei"]);text.add_theme_font_override("font",font);text.add_theme_font_size_override("font_size",23);text.add_theme_color_override("font_color",Color("eef1ed"));text.add_theme_color_override("font_shadow_color",Color(.01,.03,.04,.9));text.add_theme_constant_override("shadow_offset_y",2);text.mouse_filter=MOUSE_FILTER_IGNORE;add_child(text)
	_reveal_module(token)

func _reveal_module(token:int) -> void:
	if token!=serial:return
	ChapterTransition.destination_ready(self)

func close() -> void:
	serial+=1;placeholder=false;transitioning=false
	ChapterTransition.cancel(self)
	if is_instance_valid(transition_tween):transition_tween.kill()
	transition_tween=null
	if is_instance_valid(module) and module.has_method("close"):module.call("close")
	module=null;cover=null
	for child in get_children():remove_child(child);child.queue_free()
	hide()

func _input(event:InputEvent) -> void:
	if not visible:return
	if transitioning:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if not placeholder:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE:return_to_title_requested.emit()
		elif event.physical_keycode in [KEY_F,KEY_F11]:fullscreen_requested.emit()
		get_viewport().set_input_as_handled()
