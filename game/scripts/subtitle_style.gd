extends RefCounted
## Shared, validated screen-space subtitle and independent soft-background settings.
const Wash=preload("res://shaders/dialogue_color_wash.gdshader")
const Appearance=preload("res://scripts/dialogue_appearance.gd")

static func defaults(role:String)->Dictionary:
	var her:=role=="her"
	return {"text_x":760.0 if her else 70.0,"text_y":61.0 if her else 612.0,"text_width":449.0 if her else 1010.0,"text_height":145.0 if her else 84.0,"background_color":"#7ab8f0" if her else "#ffb861","background_opacity":.12 if her else .10,"background_auto":true,"background_x":736.0 if her else 46.0,"background_y":51.0 if her else 602.0,"background_width":497.0 if her else 1058.0,"background_height":64.0}

static func normalize(value:Variant)->Dictionary:
	var result:Dictionary={}
	for role in ["her","man"]:
		var entry:Dictionary=defaults(role)
		var raw:Variant=value.get(role,{}) if value is Dictionary else {}
		if raw is Dictionary:
			for key in entry:
				var v:Variant=raw.get(key,entry[key])
				if key=="background_auto":
					if v is bool:entry[key]=v
				elif key=="background_color":
					if v is String and Color.html_is_valid(v):entry[key]="#"+Color.html(v).to_html(false)
				elif (v is int or v is float) and is_finite(float(v)):
					var limits:=Vector2(-1280,2560)
					if key.ends_with("width"):limits=Vector2(40,2560)
					elif key.ends_with("height"):limits=Vector2(24,1440)
					elif key=="background_opacity":limits=Vector2(0,1)
					entry[key]=clampf(float(v),limits.x,limits.y)
		result[role]=entry
	return result

static func regular_font(label:Label,font_size:=24)->void:
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["KaiTi","STKaiti","Microsoft YaHei"]);font.font_weight=400
	label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",Color(.99,.99,.94))
	label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	label.add_theme_constant_override("shadow_offset_x",0);label.add_theme_constant_override("shadow_offset_y",0)
	label.add_theme_constant_override("shadow_outline_size",0);label.add_theme_constant_override("outline_size",0)

static func make_wash()->ColorRect:
	var node:=ColorRect.new();node.z_index=10;node.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var material:=ShaderMaterial.new();material.shader=Wash;node.material=material;return node

static func apply(role:String,label:Label,name_label:Label,wash:ColorRect,settings:Dictionary)->void:
	var data:Dictionary=settings.get(role,defaults(role))
	label.position=Vector2(data.text_x,data.text_y);label.size=Vector2(data.text_width,data.text_height)
	var studio=label.get_node_or_null("/root/TextStudio")
	if studio!=null:studio.sync_node(label)
	if name_label!=null:name_label.position=label.position-Vector2(0,22)
	Appearance.attach(label,role,data)
	wash.hide()
	var color:=Color.html(str(data.background_color));color.a=float(data.background_opacity);wash.color=color
	if bool(data.background_auto):
		var font:Font=label.get_theme_font("font");var fs:int=label.get_theme_font_size("font_size")
		var width:float=minf(label.size.x,font.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x)
		var height:float=minf(label.size.y,font.get_height(fs)*maxi(1,label.get_line_count()))
		wash.position=label.position-Vector2(24,10);wash.size=Vector2(width+48,height+22)
	else:
		wash.position=Vector2(data.background_x,data.background_y)+label.position-Vector2(data.text_x,data.text_y);wash.size=Vector2(data.background_width,data.background_height)
