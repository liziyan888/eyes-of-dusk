extends "res://scripts/text_studio_base.gd"
## Compact, persistent text authoring and shared dialogue appearance.
const FreeBoxes=preload("res://scripts/free_text_boxes.gd")
const DialogueAppearance=preload("res://scripts/dialogue_appearance.gd")
var color_picker:ColorPickerButton
var style_picker:OptionButton
var align_picker:OptionButton
var line_spacing:SpinBox
var fold_button:Button
var add_button:Button
var column:VBoxContainer
var folded:=false
var placing:=false
var styled_fonts:Dictionary={}
var dialogue_styles:Dictionary={}
var appearance_panel:Control
var appearance_controls:Dictionary={}
var role_picker:OptionButton
var editing_role:="man"
var appearance_open:=false

func _ready()->void:
	copies=FreeBoxes.new()
	super._ready()

func load_settings()->void:
	super.load_settings()
	dialogue_styles.clear()
	for source in [PROJECT_FILE,path]:
		if not FileAccess.file_exists(source):continue
		var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
		if saved is Dictionary:
			for role in ["man","her"]:
				if saved.get("dialogue_styles",{}).get(role) is Dictionary:dialogue_styles[role]=DialogueAppearance.clean(saved.dialogue_styles[role])
			for key in saved.get("entries",{}):
				var raw:Variant=saved.entries[key]
				if not raw is Dictionary or not entries.has(key):continue
				if raw.get("font_color") is String and Color.html_is_valid(raw.font_color):entries[key].font_color=raw.font_color
				for field in ["font_style","alignment","line_spacing"]:
					if raw.get(field) is int or raw.get(field) is float:entries[key][field]=clampi(int(raw[field]),-4,32)
	if not inspector_manual:inspector_manual=true;inspector_position=Vector2(18,82)

func _make_ui()->void:
	super._make_ui()
	column=inspector.get_child(0)
	column.add_theme_constant_override("separation",6)
	inspector.scale=Vector2.ONE*.78
	heading.add_theme_font_size_override("font_size",15)
	var header:=HBoxContainer.new();column.add_child(header);column.move_child(header,0)
	heading.reparent(header);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	fold_button=Button.new();fold_button.text="收起";fold_button.custom_minimum_size=Vector2(44,26);fold_button.pressed.connect(toggle_fold);header.add_child(fold_button)
	# The existing three-line instruction is in the title tooltip instead.
	for child in column.get_children():
		if child is Label and str(child.text).begins_with("拖标题栏"):child.hide();child.set_meta("always_hidden",true)
	heading.tooltip_text="拖动标题栏移动面板；收起后只留标题。双击画面文字编辑，拖动文字和角点调整位置、大小。"
	content.custom_minimum_size=Vector2(270,70)
	copy_button.text="复制";paste_button.text="粘贴";remove_box_button.text="删除"
	add_button=Button.new();add_button.text="＋文本框";add_button.pressed.connect(begin_placing);copy_button.get_parent().add_child(add_button)
	var size_row:Control=font_size.get_parent();var size_index:=size_row.get_index()
	var style_row:=HBoxContainer.new();column.add_child(style_row);column.move_child(style_row,size_index)
	size_row.reparent(style_row);font_size.custom_minimum_size.x=72
	style_picker=OptionButton.new();style_picker.custom_minimum_size.x=78
	for text in ["常规","粗体","斜体","粗斜体"]:style_picker.add_item(text)
	style_picker.item_selected.connect(func(i:int):if not rebuilding:set_property_value("font_style",i));style_row.add_child(style_picker)
	color_picker=ColorPickerButton.new();color_picker.custom_minimum_size=Vector2(36,28);color_picker.edit_alpha=true;color_picker.tooltip_text="文字颜色";style_row.add_child(color_picker)
	color_picker.color_changed.connect(func(c:Color):if not rebuilding:set_property_value("font_color",c.to_html(true)))
	var row:=HBoxContainer.new();column.add_child(row);column.move_child(row,style_row.get_index()+1)
	_ui_label(row,"排列",13);align_picker=OptionButton.new()
	for text in ["左对齐","居中","右对齐","两端"]:align_picker.add_item(text)
	align_picker.item_selected.connect(func(i:int):if not rebuilding:set_property_value("alignment",i));row.add_child(align_picker)
	line_spacing=_spin(row,"行距",-4,32,1,func(v):set_property_value("line_spacing",int(v)));line_spacing.custom_minimum_size.x=65
	box_w.get_parent().get_child(0).text="行宽"
	box_h.get_parent().get_child(0).text="框高"
	_make_appearance_controls()
	_keep_inspector_on_screen.call_deferred()

func _keep_inspector_on_screen()->void:
	if not is_instance_valid(inspector):return
	inspector.size=inspector.get_combined_minimum_size().max(Vector2(312,0))
	var actual:=inspector.size*inspector.scale
	inspector.position=Vector2(clampf(inspector_position.x,4,maxf(4,1280-actual.x-4)),clampf(inspector_position.y,4,maxf(4,720-actual.y-4)))

func toggle_fold()->void:
	_finish_inline();folded=not folded;fold_button.text="展开" if folded else "收起"
	for child in column.get_children():
		if child==heading.get_parent():continue
		child.visible=not folded and not child.get_meta("always_hidden",false)
	appearance_panel.visible=not folded and appearance_open
	inspector.reset_size();_keep_inspector_on_screen.call_deferred()

func _base(node:Control)->Dictionary:
	var result:=super._base(node)
	result.font_color=node.get_theme_color("default_color" if node is RichTextLabel else "font_color")
	result.color_override=node.has_theme_color_override("default_color" if node is RichTextLabel else "font_color")
	result.line_spacing=node.get_theme_constant("line_spacing");result.spacing_override=node.has_theme_constant_override("line_spacing")
	if node is Label:result.alignment=node.horizontal_alignment
	elif node is Button:result.alignment=node.alignment
	return result

func _restore(node:Control,record:Dictionary,preserve_external:bool)->void:
	var old:Dictionary=record.last;var original:Dictionary=record.base
	if old.has("font_color"):
		var key:="default_color" if node is RichTextLabel else "font_color"
		if original.color_override:node.add_theme_color_override(key,original.font_color)
		else:node.remove_theme_color_override(key)
	if old.has("line_spacing"):
		if original.spacing_override:node.add_theme_constant_override("line_spacing",original.line_spacing)
		else:node.remove_theme_constant_override("line_spacing")
	if old.has("alignment") and original.has("alignment"):
		if node is Label:node.horizontal_alignment=original.alignment
		elif node is Button:node.alignment=original.alignment
	super._restore(node,record,preserve_external)

func _apply(node:Control,record:Dictionary)->void:
	super._apply(node,record)
	var spec:Dictionary=entries.get(record.key,{})
	if spec.has("font_style"):
		var base_font:Font=node.get_theme_font(_font_key(node));var family:=base_font.get_font_name()
		if base_font is WebSystemFont and not base_font.font_names.is_empty():family=base_font.font_names[0]
		var key:=family+":"+str(spec.font_style)
		if not styled_fonts.has(key):
			var f:=WebSystemFont.new();f.font_names=PackedStringArray([family]);f.font_weight=700 if int(spec.font_style) in [1,3] else 400;f.font_italic=int(spec.font_style) in [2,3];styled_fonts[key]=f
		node.add_theme_font_override(_font_key(node),styled_fonts[key]);record.last.font=styled_fonts[key]
	if spec.has("font_color"):
		var ink:=Color.from_string(str(spec.font_color),Color.WHITE);node.add_theme_color_override("default_color" if node is RichTextLabel else "font_color",ink);record.last.font_color=ink
	if spec.has("alignment"):
		if node is Label:node.horizontal_alignment=clampi(int(spec.alignment),0,3)
		elif node is Button:node.alignment=clampi(int(spec.alignment),0,2)
		record.last.alignment=spec.alignment
	if spec.has("line_spacing"):node.add_theme_constant_override("line_spacing",int(spec.line_spacing));record.last.line_spacing=spec.line_spacing

func _fill_inspector()->void:
	super._fill_inspector()
	if _selected().is_empty():return
	var record:=_selected();var node:Control=record.node.get_ref();var spec:Dictionary=entries.get(record.key,{})
	rebuilding=true
	color_picker.color=node.get_theme_color("default_color" if node is RichTextLabel else "font_color")
	style_picker.select(clampi(int(spec.get("font_style",0)),0,3))
	align_picker.select(node.horizontal_alignment if node is Label else clampi(int(node.alignment),0,3) if node is Button else 0)
	line_spacing.value=node.get_theme_constant("line_spacing");rebuilding=false
	if node.has_meta("dialogue_role"):editing_role=str(node.get_meta("dialogue_role"));_fill_appearance()

func begin_placing()->void:
	_finish_inline();placing=true;_status("点击画面任意位置，放置新的文本框");gate.mouse_default_cursor_shape=Control.CURSOR_CROSS

func _canvas_input(event:InputEvent)->void:
	if placing and event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		placing=false;var node:Label=copies.create_at(event.position)
		if node!=null:select_node(node);_changed();_begin_inline();inline_edit.select_all()
		gate.mouse_default_cursor_shape=Control.CURSOR_ARROW;gate.accept_event();return
	super._canvas_input(event)

func close_editor()->void:
	placing=false;_dismiss_picker_popups();super.close_editor()

func _dismiss_picker_popups()->bool:
	var dismissed:=false
	var pickers:Array=[font_menu,color_picker,style_picker,align_picker,role_picker]
	for control in appearance_controls.values():
		if control is ColorPickerButton:pickers.append(control)
	for picker in pickers:
		if not is_instance_valid(picker):continue
		var popup:Window=picker.get_popup()
		if popup.visible:popup.hide();dismissed=true
	return dismissed

func _input(event:InputEvent)->void:
	var settings=get_tree().get_first_node_in_group("game_settings")
	if settings!=null and settings.opened:return
	if editing and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		if _dismiss_picker_popups():get_viewport().set_input_as_handled();return
	super._input(event)

func _make_appearance_controls()->void:
	var toggle:=Button.new();toggle.text="对白底色与横线 ▾";column.add_child(toggle);column.move_child(toggle,content.get_index())
	appearance_panel=VBoxContainer.new();column.add_child(appearance_panel);column.move_child(appearance_panel,toggle.get_index()+1);appearance_panel.hide()
	toggle.pressed.connect(func():appearance_open=not appearance_open;appearance_panel.visible=appearance_open;inspector.reset_size())
	var row:=HBoxContainer.new();appearance_panel.add_child(row)
	role_picker=OptionButton.new();role_picker.add_item("男主 · 所有对白");role_picker.add_item("女孩 · 所有对白");row.add_child(role_picker)
	role_picker.item_selected.connect(func(i:int):editing_role="her" if i==1 else "man";_fill_appearance())
	for field in ["background_color","line_color"]:
		var r:=HBoxContainer.new();appearance_panel.add_child(r);_ui_label(r,"底色" if field=="background_color" else "横线颜色",12)
		var picker:=ColorPickerButton.new();picker.custom_minimum_size=Vector2(90,24);picker.edit_alpha=false;r.add_child(picker);appearance_controls[field]=picker
		picker.color_changed.connect(func(c:Color):if not rebuilding:set_dialogue_value(field,"#"+c.to_html(false)))
	var numeric=[ ["background_opacity","底色不透明度 %",0,100,1,100.0], ["gradient_power","渐变强度",.2,5,.1,1.0], ["gradient_height","渐变覆盖高度 %",10,100,1,1.0], ["line_opacity","横线不透明度 %",0,100,1,100.0], ["line_width","横线粗细",0,4,.25,1.0] ]
	for item in numeric:
		var spin:=_spin(appearance_panel,item[1],item[2],item[3],item[4],func(v):set_dialogue_value(item[0],float(v)/float(item[5])));appearance_controls[item[0]]=spin
	var reset:=Button.new();reset.text="恢复此角色默认样式";appearance_panel.add_child(reset)
	reset.pressed.connect(func():dialogue_styles.erase(editing_role);_changed();_fill_appearance())
	_fill_appearance()

func dialogue_style(role:String,fallback:Dictionary={})->Dictionary:
	var result:=DialogueAppearance.defaults(role);result.merge(DialogueAppearance.clean(fallback),true);result.merge(dialogue_styles.get(role,{}),true);return result

func set_dialogue_value(field:String,value:Variant)->void:
	if rebuilding:return
	if not dialogue_styles.has(editing_role):dialogue_styles[editing_role]={}
	dialogue_styles[editing_role].merge(DialogueAppearance.clean({field:value}),true);_changed()

func _fill_appearance()->void:
	if not is_instance_valid(role_picker):return
	var fallback:Dictionary={};var selected:=_selected()
	if not selected.is_empty():
		var node:Control=selected.node.get_ref()
		if is_instance_valid(node) and str(node.get_meta("dialogue_role",""))==editing_role:fallback=node.get_meta("dialogue_defaults",{})
	var values:=dialogue_style(editing_role,fallback);rebuilding=true;role_picker.select(1 if editing_role=="her" else 0)
	for field in appearance_controls:
		var control:Control=appearance_controls[field]
		if control is ColorPickerButton:control.color=Color(values[field])
		else:control.value=float(values[field])*(100 if field in ["background_opacity","line_opacity"] else 1)
	rebuilding=false

func extra_settings()->Dictionary:return {"dialogue_styles":dialogue_styles}

func _find_stage(node:Node,best:Dictionary)->void:
	if _ignored(node):return
	if node is Control and node.is_visible_in_tree():
		var script:Script=node.get_script();var file:=script.resource_path.get_file() if script!=null else ""
		if file in FreeBoxes.STAGES:
			var depth:=0;var z:=0;var cursor:Node=node
			while cursor!=null:
				depth+=1
				if cursor is CanvasItem:z+=cursor.z_index
				cursor=cursor.get_parent()
			var score:=z*100+depth
			if score>=int(best.get("depth",-100)):best.node=node;best.depth=score
	for child in node.get_children():_find_stage(child,best)
