extends Control
const Studio=preload("res://scripts/preview/reading_text_studio.gd")
const Dialogue=preload("res://scripts/preview/reading_dialogue.gd")
const FOLDER="res://../output/reading-polish-preview-20261116"
var page:Control
var bar:PanelContainer
var mode:=0
var beat:=0
var daylight:=true
var seam_after:=true
var studio:CanvasLayer
var man:Control
var girl:Control
var note:Label

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	get_window().title="带上她的眼睛 · 对白与文字编辑预览"
	_install_editor.call_deferred()
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei"])
	theme=Theme.new();theme.default_font=font;theme.default_font_size=14
	show_page(0)

func _install_editor()->void:
	var previous:=get_node_or_null("/root/TextStudio")
	if previous!=null:
		# Free after the scene has entered the tree, cancelling the old editor's deferred scans.
		previous.free()
	studio=Studio.new();studio.name="TextStudio";get_tree().root.add_child(studio)

func text_page()->Control:return page

func _image(path:String,rect:Rect2)->TextureRect:
	var node:=TextureRect.new();node.mouse_filter=MOUSE_FILTER_IGNORE
	if path.begins_with("res://../"):
		var img:=Image.load_from_file(ProjectSettings.globalize_path(path));node.texture=ImageTexture.create_from_image(img)
	else:node.texture=load(path)
	node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;node.stretch_mode=TextureRect.STRETCH_SCALE
	node.position=rect.position;node.size=rect.size;page.add_child(node);return node

func _background(night:bool)->void:
	if not night:
		_image("res://assets/grassland-v2/00-background.png",Rect2(0,0,1280,720));return
	var layers=[ ["sky",Rect2(-400,0,1920,720)],["clouds",Rect2(-400,0,1920,501.923)], ["far",Rect2(-400,368.942,1917.404,344.135)], ["forest",Rect2(-400,275.481,1920,428.942)],["ground",Rect2(-400,554.423,1920,211.731)],["tree",Rect2(513.846,368.942,411.635,298.558)] ]
	for item in layers:_image("res://assets/moon5-psb/"+item[0]+".png",item[1])

func _pair(her_line:String,his_line:String)->void:
	girl=Dialogue.new();girl.name="GirlDialogue";girl.role="her";girl.position=Vector2(728,98);page.add_child(girl)
	girl.text.size=Vector2(470,100);girl.set_line(her_line);girl.visible=not her_line.is_empty()
	man=Dialogue.new();man.name="ManDialogue";man.position=Vector2(54,552);page.add_child(man)
	man.text.size=Vector2(810,100);man.set_line(his_line);man.visible=not his_line.is_empty()

func show_page(value:int)->void:
	mode=value
	if is_instance_valid(page):remove_child(page);page.queue_free()
	if is_instance_valid(bar):remove_child(bar);bar.queue_free()
	page=Control.new();page.name="Page";page.size=Vector2(1280,720);page.mouse_filter=MOUSE_FILTER_IGNORE
	page.set_meta("text_scope","reading_preview_%d_%d"%[mode,beat if mode==1 else 0]);add_child(page)
	var anchor:=Label.new();anchor.name="FreeTextAnchor";anchor.text="";anchor.size=Vector2.ONE;anchor.mouse_filter=MOUSE_FILTER_IGNORE;page.add_child(anchor)
	if mode==0:
		_background(not daylight)
		_pair("草叶中间有一小片亮光，在跳呢。", "我把草轻轻拨开。这样，你看得清楚吗？")
	elif mode==1:
		_background(true)
		var script=[
			["月亮正从云中穿过……再带我出去看看，好吗？","困意被打断，我有些恼火，还是不情愿地走了出去。"],
			["", "你倒像个十八世纪的多愁善感的诗人，一点也不像个宇航员。"],
			["", "你自己看月亮吧。我真的得睡了，明天还要赶回航天中心。"],
			["", "眼镜里传来她细细的声音。我没有听清，便径自回去了。"]]
		_pair(script[beat][0],script[beat][1])
		if beat==1:
			var circle:Button=load("res://scripts/comic_hotspot.gd").new();circle.position=Vector2(695,506);circle.pressed.connect(func():beat=2;show_page(1));page.add_child(circle)
			var label:=Label.new();label.position=Vector2(665,543);label.text="挂好眼镜，回去睡觉";label.add_theme_font_size_override("font_size",15);page.add_child(label)
		if beat>=2:
			var glasses:=_image("res://assets/props/sensor_glasses_v2/hang.png",Rect2(676,522,42,21));glasses.modulate=Color(.68,.76,.90,.94)
			var material:=ShaderMaterial.new();material.shader=load("res://shaders/sensor_prop.gdshader");glasses.material=material
			note=Label.new();note.name="Narration";note.position=Vector2(54,490);note.size=Vector2(820,48);note.text="困倦和恼火让我失去了耐心。我摘下眼镜，挂到身旁的红柳枝上。" if beat==2 else "树上的眼镜还望着月亮，脚步声渐渐远了。"
			var font:=WebSystemFont.new();font.font_names=PackedStringArray(["KaiTi"]);note.add_theme_font_override("font",font);note.add_theme_font_size_override("font_size",21);note.modulate=Color("d3dde9");page.add_child(note)
	else:
		_image(FOLDER.path_join("seam-after.png" if seam_after else "seam-before.png"),Rect2(0,0,1280,720))
	_make_bar()

func _button(row:Node,title:String,callback:Callable)->Button:
	var b:=Button.new();b.text=title;b.pressed.connect(callback);row.add_child(b);return b

func _make_bar()->void:
	bar=PanelContainer.new();bar.name="PreviewToolbar";bar.position=Vector2(14,12);bar.set_meta("text_editor_ignore",true);add_child(bar)
	var bg:=StyleBoxFlat.new();bg.bg_color=Color(.025,.045,.075,.82);bg.set_corner_radius_all(5);bg.content_margin_left=10;bg.content_margin_right=10;bg.content_margin_top=6;bg.content_margin_bottom=6;bar.add_theme_stylebox_override("panel",bg)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",10);bar.add_child(row)
	_button(row,"对白样式",func():show_page(0));_button(row,"挂镜剧情",func():show_page(1));_button(row,"接缝对比",func():show_page(2))
	if mode==0:_button(row,"切换夜景" if daylight else "切换白天",func():daylight=not daylight;show_page(0))
	elif mode==1:
		_button(row,"上一段",func():beat=maxi(0,beat-1);show_page(1))
		var label:=Label.new();label.text="%d / 4"%[beat+1];row.add_child(label)
		_button(row,"下一段",func():beat=mini(3,beat+1);show_page(1))
	else:_button(row,"当前：调整后 · 点击看原来" if seam_after else "当前：原来 · 点击看调整后",func():seam_after=not seam_after;show_page(2))
	_button(row,"F2 编辑文字",func():studio.open_editor())
	var help:=Label.new();help.text="独立预览 · 编辑自动保存到预览副本";help.add_theme_font_size_override("font_size",12);help.modulate=Color("a2b4c9");row.add_child(help)

func _unhandled_key_input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F11:
		get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN;get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_SPACE and mode==1 and not studio.editing:
		beat=mini(3,beat+1);show_page(1);get_viewport().set_input_as_handled()
