extends Control
signal start_requested
signal fullscreen_requested
var fading := false
var poster: TextureRect
var heading: Control
var start_button: Button
var line_top: TextureRect
var line_bottom: TextureRect
var dark: ColorRect
func _ready() -> void:
	size=Vector2(1280,720)
	mouse_filter=Control.MOUSE_FILTER_STOP
	poster=TextureRect.new()
	poster.texture=load("res://assets/prologue/cover-cinematic.png")
	poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	poster.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.size=size;poster.pivot_offset=size/2;poster.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(poster)
	var font:=WebSystemFont.new()
	font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"])
	heading=Control.new();heading.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(heading)
	for row in [["带 上 她 的",Vector2(205,132),38],["眼 睛",Vector2(205,188),84]]:
		var label:=Label.new();label.text=row[0];label.position=row[1];label.size=Vector2(460,112)
		label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",row[2])
		label.add_theme_color_override("font_color",Color("f7f8f2"))
		label.add_theme_color_override("font_shadow_color",Color(0.02,.06,.12,.35))
		label.add_theme_constant_override("shadow_offset_y",2)
		label.mouse_filter=Control.MOUSE_FILTER_IGNORE;heading.add_child(label)
	start_button=Button.new();start_button.text="开 始 游 戏"
	start_button.position=Vector2(248,531);start_button.size=Vector2(298,76)
	start_button.add_theme_font_override("font",font);start_button.add_theme_font_size_override("font_size",24)
	for state in ["normal","hover","pressed","focus","disabled"]:start_button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for key in ["font_color","font_hover_color","font_focus_color","font_pressed_color"]:start_button.add_theme_color_override(key,Color("f7f8f3"))
	start_button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	start_button.pressed.connect(_start)
	add_child(start_button)
	line_top=_line(start_button,4);line_bottom=_line(start_button,72)
	start_button.mouse_entered.connect(func():_highlight(true))
	start_button.mouse_exited.connect(func():_highlight(false))
	start_button.focus_entered.connect(func():_highlight(true))
	start_button.focus_exited.connect(func():_highlight(false))
	dark=ColorRect.new();dark.size=size;dark.color=Color("101923");dark.modulate.a=0;dark.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(dark)
	start_button.grab_focus()
func _line(parent:Control,y:float)->TextureRect:
	var gradient:=Gradient.new();gradient.set_color(0,Color(1,1,1,0));gradient.set_color(1,Color(1,1,1,0));gradient.add_point(.27,Color(1,1,1,.86));gradient.add_point(.73,Color(1,1,1,.86))
	var tex:=GradientTexture2D.new();tex.gradient=gradient
	var line:=TextureRect.new();line.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;line.texture=tex;line.position=Vector2(0,y);line.size=Vector2(298,1)
	line.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(line)
	return line
func _highlight(on:bool)->void:
	if fading:return
	for line in [line_top,line_bottom]:
		var t:=create_tween();t.tween_property(line,"modulate:a",1.0 if on else .72,.3)
func _start()->void:
	if fading:return
	fading=true;start_button.disabled=true;start_requested.emit()
func fade_to_comic()->void:
	var first:=create_tween().set_parallel(true)
	first.tween_property(heading,"modulate:a",0.0,.4)
	first.tween_property(start_button,"modulate:a",0.0,.4)
	first.tween_property(poster,"scale",Vector2(1.025,1.025),1.4)
	first.tween_property(dark,"modulate:a",.68,.65)
	await get_tree().create_timer(.65).timeout
	var reveal:=create_tween();reveal.tween_property(self,"modulate:a",0.0,.8)
	await reveal.finished
	hide();modulate.a=1.0
func _input(event:InputEvent)->void:
	if not is_visible_in_tree():return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_F,KEY_F11]:fullscreen_requested.emit();get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_SPACE,KEY_ENTER] and not fading:_start();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_TAB:start_button.grab_focus();get_viewport().set_input_as_handled()

func show_menu()->void:
	fading=false;show();modulate.a=1.0;heading.modulate.a=1.0;start_button.modulate.a=1.0;start_button.disabled=false;poster.scale=Vector2.ONE;dark.modulate.a=0.0
	start_button.grab_focus()
