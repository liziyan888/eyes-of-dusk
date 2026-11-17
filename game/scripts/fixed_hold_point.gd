extends Button
## The hit area and visual center stay fixed for the whole action.
var progress:=0.0
var completed:=false
var clock:=0.0
var pulse:=0.0
var hint:Label
func _ready()->void:
	size=Vector2(72,72);custom_minimum_size=size;keep_pressed_outside=true
	mouse_default_cursor_shape=CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:add_theme_stylebox_override(state,StyleBoxEmpty.new())
	hint=Label.new();hint.position=Vector2(-89,64);hint.size=Vector2(250,50)
	hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.mouse_filter=MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size",15);hint.add_theme_color_override("font_color",Color(.97,.99,1))
	hint.add_theme_color_override("font_shadow_color",Color(.05,.10,.18,.8));hint.add_theme_constant_override("shadow_offset_y",1)
	add_child(hint)
func set_hint(value:String)->void:
	accessibility_name=value
	if hint!=null:hint.text=value
func _process(delta:float)->void:
	if not is_visible_in_tree():return
	clock+=delta;pulse=move_toward(pulse,1.0 if is_hovered() or has_focus() or button_pressed else 0.0,delta*4)
	queue_redraw()
func _draw()->void:
	var center:=size*.5
	var radius:=10.0+(sin(clock*3.0)*.65 if pulse>0 and not button_pressed else 0.0)
	draw_arc(center+Vector2(0,1),radius,0,TAU,48,Color(.04,.08,.15,.35),3,true)
	if pulse>.01:draw_arc(center,radius+3,0,TAU,48,Color(1,1,1,pulse*.14),3,true)
	draw_arc(center,radius,0,TAU,48,Color(1,1,1,.72 if completed else .95),1.5,true)
	if progress>.001:draw_arc(center,14,-PI*.5,-PI*.5+TAU*clampf(progress,0,1),64,Color(1,1,1,.96),2,true)
