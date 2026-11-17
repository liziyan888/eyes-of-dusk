extends Control
const Style=preload("res://scripts/subtitle_style.gd")
var settings:Dictionary={}
var labels:Dictionary={}
var names:Dictionary={}
var washes:Dictionary={}

func _ready()->void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_IGNORE
	for role in ["her","man"]:
		var wash:=Style.make_wash();add_child(wash);washes[role]=wash
		var label:=Label.new();label.mouse_filter=MOUSE_FILTER_IGNORE;label.z_index=11;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;Style.regular_font(label);add_child(label);labels[role]=label
		var name_label:=Label.new();name_label.mouse_filter=MOUSE_FILTER_IGNORE;name_label.z_index=11;name_label.size=Vector2(100,22);name_label.text="她" if role=="her" else "我";name_label.modulate.a=.7;Style.regular_font(name_label,14);add_child(name_label);names[role]=name_label
	apply_style(settings)

func apply_style(value:Dictionary)->void:
	settings=Style.normalize(value);_sync()

func set_lines(her:String,man:String)->void:
	labels.her.text=her;labels.man.text=man;_sync()

func _sync()->void:
	for role in labels:
		names[role].visible=not labels[role].text.is_empty()
		Style.apply(role,labels[role],names[role],washes[role],settings)

func _process(_delta:float)->void:_sync()
