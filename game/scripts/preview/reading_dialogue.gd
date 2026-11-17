extends Control
const WASH=preload("res://shaders/reading_dialogue_preview.gdshader")
var text:Label
var name_label:Label
var wash:ColorRect
var role:="man"
func _ready()->void:
	mouse_filter=MOUSE_FILTER_IGNORE
	wash=ColorRect.new();wash.mouse_filter=MOUSE_FILTER_IGNORE;var m:=ShaderMaterial.new();m.shader=WASH;wash.material=m;add_child(wash)
	name_label=Label.new();name_label.mouse_filter=MOUSE_FILTER_IGNORE;add_child(name_label)
	text=Label.new();text.name="Subtitle";text.mouse_filter=MOUSE_FILTER_IGNORE;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(text)
	for node in [text,name_label]:
		var font:=WebSystemFont.new();font.font_names=PackedStringArray(["KaiTi","STKaiti","Microsoft YaHei"]);font.font_weight=400;node.add_theme_font_override("font",font);node.add_theme_color_override("font_color",Color("fff9ed"));node.add_theme_constant_override("outline_size",0);node.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	text.add_theme_font_size_override("font_size",24);name_label.add_theme_font_size_override("font_size",14)
	text.position=Vector2(18,30);text.size=Vector2(540,70);name_label.position=Vector2(18,5)
	text.set_meta("text_move_target",weakref(self));text.set_meta("text_frame",weakref(self));text.set_meta("text_frame_padding",Vector2(36,43))
	set_role(role)
func set_role(value:String)->void:
	role=value
	if not is_instance_valid(wash):return
	name_label.text="女孩" if role=="her" else "我"
	var color:=Color("7ab8f0") if role=="her" else Color("ffb861");color.a=.12 if role=="her" else .10
	wash.material.set_shader_parameter("ink",color);name_label.modulate=Color(color, .85)
func set_line(value:String)->void:text.text=value
func _process(_delta:float)->void:
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null:studio.sync_node(text)
	var font:Font=text.get_theme_font("font");var fs:=text.get_theme_font_size("font_size")
	var h:=maxf(font.get_height(fs),float(text.get_line_count())*font.get_height(fs)+maxi(0,text.get_line_count()-1)*text.get_theme_constant("line_spacing"))
	wash.position=Vector2(0,20);wash.size=Vector2(text.size.x+36,minf(text.size.y,h)+32)
	wash.material.set_shader_parameter("height",wash.size.y)
