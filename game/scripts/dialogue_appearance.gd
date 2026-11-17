extends ColorRect
## A bottom rule and upward-fading wash, attached to real editable text.
const SHADER=preload("res://shaders/dialogue_rule.gdshader")
static func defaults(role:String)->Dictionary:
	var c:="#7ab8f0" if role=="her" else "#ffb861"
	return {"background_color":c,"background_opacity":.12 if role=="her" else .10,"gradient_power":1.65,"gradient_height":100.0,"line_color":c,"line_opacity":.58,"line_width":1.3}
static func clean(raw:Variant)->Dictionary:
	var result:Dictionary={}
	if not raw is Dictionary:return result
	for key in ["background_color","line_color"]:
		if raw.get(key) is String and Color.html_is_valid(raw[key]):result[key]="#"+Color.html(raw[key]).to_html(false)
	var limits={"background_opacity":Vector2(0,1),"gradient_power":Vector2(.2,5),"gradient_height":Vector2(10,100),"line_opacity":Vector2(0,1),"line_width":Vector2(0,4)}
	for key in limits:
		if (raw.get(key) is int or raw.get(key) is float) and is_finite(float(raw[key])):result[key]=clampf(float(raw[key]),limits[key].x,limits[key].y)
	return result
static func attach(label:Label,role:String,fallback:Dictionary={})->void:
	label.set_meta("dialogue_role",role);label.set_meta("dialogue_defaults",fallback)
	if label.has_node("DialogueAppearance"):return
	var wash=load("res://scripts/dialogue_appearance.gd").new();wash.name="DialogueAppearance";label.add_child(wash)
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;mouse_filter=MOUSE_FILTER_IGNORE;show_behind_parent=true
	var mat:=ShaderMaterial.new();mat.shader=SHADER;material=mat;refresh()
func _process(_delta:float)->void:refresh()
func refresh()->void:
	var label:=get_parent() as Label
	if label==null:return
	visible=not label.text.is_empty()
	var role:=str(label.get_meta("dialogue_role","man"));var values:=defaults(role);values.merge(clean(label.get_meta("dialogue_defaults",{})),true)
	var studio:=get_node_or_null("/root/TextStudio")
	if studio!=null and studio.has_method("dialogue_style"):values=studio.dialogue_style(role,values)
	var font:Font=label.get_theme_font("font");var fs:=label.get_theme_font_size("font_size");var count:=maxi(1,label.get_line_count())
	var h:=minf(label.size.y,font.get_height(fs)*count+maxi(0,count-1)*label.get_theme_constant("line_spacing"))
	position=Vector2(-18,-6);size=Vector2(label.size.x+36,h+24)
	var ink:=Color(values.background_color);ink.a=values.background_opacity
	material.set_shader_parameter("ink",ink);material.set_shader_parameter("rule_color",Color(values.line_color))
	material.set_shader_parameter("gradient_power",values.gradient_power);material.set_shader_parameter("gradient_height",values.gradient_height/100.0)
	material.set_shader_parameter("line_alpha",values.line_opacity);material.set_shader_parameter("line_width",values.line_width);material.set_shader_parameter("height",size.y)
