extends CanvasLayer
## In-game text authoring: four inspector properties plus direct box movement.
## Original game nodes remain the playback source.
const PROJECT_FILE:="res://data/text_overrides.json"
const TextBoxCopies=preload("res://scripts/text_box_copies.gd")
var copies=TextBoxCopies.new()
var copy_button:Button
var paste_button:Button
var remove_box_button:Button
var entries:Dictionary={}
var records:Dictionary={}
var fonts:Dictionary={}
var editing:=false
var rebuilding:=false
var dirty:=false
var save_at:=0
var scan_at:=0
var path:=PROJECT_FILE
var selected_id:=0
var hovered_id:=0
var resizing:=""
var moving:=false
var move_engaged:=false
var move_pointer:=Vector2.ZERO
var move_origin:=Vector2.ZERO
var move_inverse:=Transform2D.IDENTITY
var previous_pause:=false
var previous_scale:=1.0
var inline_previous_visible:=-1
var inline_changed:=false
var inspector_font_value:=""
var inspector_manual:=false
var inspector_position:=Vector2(950,84)
var inspector_dragging:=false
var inspector_drag_engaged:=false
var inspector_drag_pointer:=Vector2.ZERO
var inspector_drag_origin:=Vector2.ZERO
var ui:Control
var gate:Control
var outline:Node2D
var inspector:PanelContainer
var heading:Label
var font_name:LineEdit
var font_menu:MenuButton
var font_size:SpinBox
var box_w:SpinBox
var box_h:SpinBox
var content:TextEdit
var inline_edit:TextEdit
var status:Label
var available_fonts:PackedStringArray=[]
var active_stage:Node

func _ready()->void:
	# Above AudioSettings (1000), below embedded popup windows (1024).
	layer=1010;process_mode=Node.PROCESS_MODE_ALWAYS;process_priority=10000
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--text-settings-path="):path=arg.trim_prefix("--text-settings-path=")
	if path==PROJECT_FILE:path="user://text-overrides-v1.json"
	copies.editor=self
	load_settings();_make_ui();get_tree().node_added.connect(_node_added)
	_scan.call_deferred()
	if "--text-editor" in OS.get_cmdline_user_args():
		get_window().title="带上她的眼睛 · 文字编辑 F2";open_editor.call_deferred()

func load_settings()->void:
	entries.clear()
	copies.clear()
	inspector_manual=false
	for source in [PROJECT_FILE,path]:
		if not FileAccess.file_exists(source):continue
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(source))
		if value is Dictionary and value.get("version",0)==1 and value.get("entries",null) is Dictionary:
			copies.load_data(value.get("text_boxes",{}))
			var preferences:Variant=value.get("editor_ui",{})
			var panel_at:Variant=preferences.get("panel_position",null) if preferences is Dictionary else null
			if panel_at is Array and panel_at.size()==2 and (panel_at[0] is float or panel_at[0] is int) and (panel_at[1] is float or panel_at[1] is int):
				if is_finite(float(panel_at[0])) and is_finite(float(panel_at[1])):
					inspector_position=Vector2(float(panel_at[0]),float(panel_at[1]));inspector_manual=true
			for key in value.entries:
				if not value.entries[key] is Dictionary:continue
				var raw:Dictionary=value.entries[key];var clean:Dictionary={}
				for field in ["source","context","font","text"]:
					if raw.get(field,null) is String:clean[field]=str(raw[field])
				if raw.get("font_size",null) is float or raw.get("font_size",null) is int:clean.font_size=clampi(int(raw.font_size),6,240)
				if raw.get("box",null) is Array and raw.box.size()==2:clean.box=[clampf(float(raw.box[0]),24,2560),clampf(float(raw.box[1]),16,1440)]
				var location:Variant=raw.get("position",null)
				if location is Array and location.size()==2 and (location[0] is float or location[0] is int) and (location[1] is float or location[1] is int):
					if is_finite(float(location[0])) and is_finite(float(location[1])):clean.position=[float(location[0]),float(location[1])]
				entries[str(key)]=clean
	if is_instance_valid(inspector) and inspector_manual:inspector.position=inspector_position;_keep_inspector_on_screen()

func _make_ui()->void:
	ui=Control.new();ui.name="TextStudioUI";ui.size=Vector2(1280,720);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	gate=Control.new();gate.size=ui.size;gate.mouse_filter=Control.MOUSE_FILTER_STOP;gate.gui_input.connect(_canvas_input);ui.add_child(gate)
	outline=Node2D.new();ui.add_child(outline);outline.draw.connect(_draw_boxes)
	inline_edit=TextEdit.new();inline_edit.name="InlineTextBox";inline_edit.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;inline_edit.scroll_past_end_of_file=false
	inline_edit.text_changed.connect(_inline_changed);ui.add_child(inline_edit);inline_edit.hide()
	inspector=PanelContainer.new();inspector.name="FourTextProperties";inspector.position=inspector_position;inspector.size=Vector2(312,432);ui.add_child(inspector)
	var theme:=Theme.new();var font:=WebSystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"]);font.font_weight=400;theme.default_font=font;theme.default_font_size=14;inspector.theme=theme
	for type_name in ["LineEdit","TextEdit"]:
		var field:=StyleBoxFlat.new();field.bg_color=Color.WHITE;field.border_color=Color("b7c5d8");field.set_border_width_all(1);field.set_corner_radius_all(3);field.content_margin_left=6;field.content_margin_right=6;field.content_margin_top=5;field.content_margin_bottom=5
		theme.set_stylebox("normal",type_name,field);var focus:=field.duplicate() as StyleBoxFlat;focus.border_color=Color("4287d7");theme.set_stylebox("focus",type_name,focus)
		theme.set_color("font_color",type_name,Color("20354c"));theme.set_color("caret_color",type_name,Color("2461a8"));theme.set_color("selection_color",type_name,Color("a9cfee"))
	var action:=StyleBoxFlat.new();action.bg_color=Color("326fb4");action.set_corner_radius_all(4);action.content_margin_top=7;action.content_margin_bottom=7
	for state in ["normal","hover","pressed","focus"]:theme.set_stylebox(state,"Button",action)
	theme.set_color("font_color","Button",Color.WHITE)
	var paper:=StyleBoxFlat.new();paper.bg_color=Color("f5f7fb");paper.border_color=Color("8aa5c7");paper.set_border_width_all(1);paper.set_corner_radius_all(7)
	paper.content_margin_left=14;paper.content_margin_right=14;paper.content_margin_top=12;paper.content_margin_bottom=12;inspector.add_theme_stylebox_override("panel",paper)
	var column:=VBoxContainer.new();column.add_theme_constant_override("separation",9);inspector.add_child(column)
	heading=_ui_label(column,"文字编辑 · F2 关闭",17)
	heading.custom_minimum_size.y=28;heading.mouse_filter=Control.MOUSE_FILTER_STOP;heading.mouse_default_cursor_shape=Control.CURSOR_MOVE
	heading.tooltip_text="按住标题栏拖动操作面板";heading.gui_input.connect(_inspector_input)
	_ui_label(column,"拖标题栏移开面板 · 双击文字编辑\n拖文字框移动 · 拖角点调整大小\nCtrl+C / V 复制粘贴框 · Delete 删除副本",12)
	_ui_label(column,"字体",13)
	var font_row:=HBoxContainer.new();column.add_child(font_row)
	font_name=LineEdit.new();font_name.name="FontFamily";font_name.placeholder_text="输入字体名称后按回车";font_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;font_row.add_child(font_name)
	font_name.text_submitted.connect(func(_value:String):_apply_font_field())
	font_name.focus_exited.connect(_apply_font_field)
	font_menu=MenuButton.new();font_menu.text="选择";font_menu.custom_minimum_size=Vector2(45,32);font_row.add_child(font_menu)
	for state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:font_menu.add_theme_color_override(state,Color("285686"))
	var catalog:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/font_families.json"))
	available_fonts=PackedStringArray(catalog) if catalog is Array else PackedStringArray();available_fonts.sort()
	for family in ["KaiTi","SimSun","Microsoft YaHei","SimHei","Arial"]:
		if not family in available_fonts:available_fonts.append(family)
	for family in available_fonts:font_menu.get_popup().add_item(family)
	font_menu.get_popup().max_size=Vector2i(360,500)
	font_menu.get_popup().id_pressed.connect(func(index:int):font_name.text=available_fonts[index];set_property_value("font",font_name.text))
	font_size=_spin(column,"字号",6,240,1,func(value):set_property_value("font_size",roundi(value)))
	var dimensions:=HBoxContainer.new();column.add_child(dimensions)
	box_w=_spin(dimensions,"宽",24,2560,1,func(value):_set_box(Vector2(value,box_h.value)))
	box_h=_spin(dimensions,"高",16,1440,1,func(value):_set_box(Vector2(box_w.value,value)))
	_ui_label(column,"文字内容",13)
	content=TextEdit.new();content.name="TextContent";content.custom_minimum_size=Vector2(270,112);content.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY;content.scroll_past_end_of_file=false;column.add_child(content)
	content.text_changed.connect(func():if not rebuilding:_set_content(content.text,false))
	var clipboard_row:=HBoxContainer.new();column.add_child(clipboard_row)
	copy_button=Button.new();copy_button.text="复制文本框";copy_button.pressed.connect(copy_text_box);clipboard_row.add_child(copy_button)
	paste_button=Button.new();paste_button.text="粘贴文本框";paste_button.pressed.connect(paste_text_box);clipboard_row.add_child(paste_button)
	remove_box_button=Button.new();remove_box_button.text="删除副本";remove_box_button.pressed.connect(remove_text_box);clipboard_row.add_child(remove_box_button)
	for button in [copy_button,paste_button,remove_box_button]:button.add_theme_font_size_override("font_size",13)
	copy_button.disabled=true;remove_box_button.disabled=true
	var close:=Button.new();close.text="保存并返回游戏";close.pressed.connect(close_editor);column.add_child(close)
	status=_ui_label(column,"请选择画面上的文字",12);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	for node in [heading,status]:node.add_theme_color_override("font_color",Color("29415e"))
	ui.hide()
	_keep_inspector_on_screen.call_deferred()

func _keep_inspector_on_screen()->void:
	if not is_instance_valid(inspector) or not is_instance_valid(ui):return
	var compact:=inspector.get_combined_minimum_size().max(Vector2(312,432))
	if not inspector.size.is_equal_approx(compact):inspector.size=compact
	var desired:=inspector_position if inspector_manual else inspector.position
	var clamped:=Vector2(clampf(desired.x,4,maxf(4,ui.size.x-inspector.size.x-4)),clampf(desired.y,4,maxf(4,ui.size.y-inspector.size.y-4)))
	if not inspector.position.is_equal_approx(clamped):inspector.position=clamped

func _inspector_input(event:InputEvent)->void:
	if not editing:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		_apply_font_field();get_viewport().gui_release_focus()
		inspector_dragging=true;inspector_drag_engaged=false;inspector_drag_pointer=heading.get_global_transform_with_canvas()*event.position;inspector_drag_origin=inspector.position
		heading.accept_event()

func _drag_inspector(point:Vector2)->void:
	if not inspector_drag_engaged and point.distance_to(inspector_drag_pointer)<3:return
	inspector_drag_engaged=true
	var desired:=inspector_drag_origin+point-inspector_drag_pointer
	if inspector.position.is_equal_approx(desired):return
	inspector_manual=true;inspector_position=desired;_keep_inspector_on_screen();inspector_position=inspector.position;_changed()

func _ui_label(parent:Node,value:String,points:int)->Label:
	var node:=Label.new();node.text=value;node.add_theme_font_size_override("font_size",points);node.add_theme_color_override("font_color",Color("29415e"));parent.add_child(node);return node

func _spin(parent:Node,title:String,low:float,high:float,step_value:float,callback:Callable)->SpinBox:
	var row:=HBoxContainer.new();parent.add_child(row);row.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	_ui_label(row,title,13)
	var node:=SpinBox.new();node.min_value=low;node.max_value=high;node.step=step_value;node.custom_minimum_size.x=96;node.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(node)
	node.value_changed.connect(func(value):if not rebuilding:callback.call(value))
	return node

func _candidate(node:Node)->bool:
	return node is Label or node is RichTextLabel or (node is Button and not node is OptionButton and not node is MenuButton)

func _ignored(node:Node)->bool:
	var cursor:Node=node
	while cursor!=null:
		if cursor==self or cursor.get_meta("text_editor_ignore",false):return true
		var script:Script=cursor.get_script()
		if script!=null and script.resource_path.ends_with("/debug_editor.gd"):return true
		cursor=cursor.get_parent()
	return false

func _node_added(node:Node)->void:
	if _candidate(node):_register_later.call_deferred(weakref(node))

func _register_later(reference:WeakRef)->void:
	var node:Node=reference.get_ref()
	if is_inside_tree() and is_instance_valid(node) and node.is_inside_tree():sync_node(node)

func _scan()->void:
	_visit(get_tree().root)
	for id in records.keys():
		if not is_instance_valid(records[id].node.get_ref()):records.erase(id)
	copies.reconcile()

func _visit(node:Node)->void:
	if _ignored(node):return
	if _candidate(node):sync_node(node)
	for child in node.get_children():_visit(child)

func _font_key(node:Control)->String:return "normal_font" if node is RichTextLabel else "font"
func _size_key(node:Control)->String:return "normal_font_size" if node is RichTextLabel else "font_size"

func _move_target(node:Control)->Control:
	for key in ["text_move_target","text_frame"]:
		var ref:Variant=node.get_meta(key,false)
		if ref is WeakRef and is_instance_valid(ref.get_ref()) and ref.get_ref() is Control:return ref.get_ref()
	return node

func _segment(node:Node)->String:
	if node.has_meta("text_scope"):return str(node.get_meta("text_scope"))
	var script:Script=node.get_script()
	if script!=null and not script.resource_path.is_empty():return script.resource_path.get_file().get_basename()
	var value:=str(node.name)
	if not value.begins_with("@"):return value
	var index:=0
	if node.get_parent()!=null:
		for sibling in node.get_parent().get_children():
			if sibling==node:break
			if sibling.has_meta("text_copy_id"):continue
			if sibling.get_class()==node.get_class():index+=1
	return node.get_class()+"["+str(index)+"]"

func _context(node:Node)->String:
	var parts:PackedStringArray=[];var cursor:=node
	while cursor!=null and cursor!=get_tree().root:
		parts.insert(0,_segment(cursor));cursor=cursor.get_parent()
	return "/".join(parts)

func _base(node:Control)->Dictionary:
	var key:=_font_key(node);var size_key:=_size_key(node)
	var result:={"font":node.get_theme_font(key),"font_override":node.has_theme_font_override(key),"points":node.get_theme_font_size(size_key),"points_override":node.has_theme_font_size_override(size_key),"size":node.size,"minimum":node.custom_minimum_size,"flags_h":node.size_flags_horizontal,"flags_v":node.size_flags_vertical}
	if node is Label:result["wrap"]=node.autowrap_mode;result["clip"]=node.clip_text
	var frame:Variant=node.get_meta("text_frame",false)
	if frame is WeakRef and is_instance_valid(frame.get_ref()):result["frame_size"]=frame.get_ref().size
	result["position"]=_move_target(node).position
	return result

func sync_node(node:Node)->void:
	if not is_instance_valid(node) or not _candidate(node) or not node.is_inside_tree() or _ignored(node):return
	var control:Control=node;var id:=node.get_instance_id();var observed:=str(node.text)
	if not records.has(id):
		var scope:=_context(node)
		records[id]={"node":weakref(node),"raw":observed,"shown":observed,"context":scope,"key":(scope+"\n"+observed).sha256_text(),"base":_base(control),"last":{}}
	var record:Dictionary=records[id]
	if observed!=str(record.raw) and observed!=str(record.shown):
		_restore(control,record,true)
		record.raw=observed;record.shown=observed;record.context=_context(node);record.key=(str(record.context)+"\n"+observed).sha256_text();record.base=_base(control);record.last={}
	_apply(control,record)

func _font(family:String)->Font:
	if not fonts.has(family):
		var value:=WebSystemFont.new();value.font_names=PackedStringArray([family]);value.font_weight=400;fonts[family]=value
	return fonts[family]

func _restore(node:Control,record:Dictionary,preserve_external:bool)->void:
	var old:Dictionary=record.last;var original:Dictionary=record.base
	var fk:=_font_key(node);var sk:=_size_key(node)
	if old.has("font") and (not preserve_external or node.get_theme_font(fk)==old.font):
		if original.font_override:node.add_theme_font_override(fk,original.font)
		else:node.remove_theme_font_override(fk)
	if old.has("font_size") and (not preserve_external or node.get_theme_font_size(sk)==int(old.font_size)):
		if original.points_override:node.add_theme_font_size_override(sk,int(original.points))
		else:node.remove_theme_font_size_override(sk)
	if old.has("box"):
		node.custom_minimum_size=original.minimum;node.size_flags_horizontal=original.flags_h;node.size_flags_vertical=original.flags_v
		if not preserve_external or node.size.is_equal_approx(old.box):node.size=original.size
		if node is Label:node.autowrap_mode=original.wrap;node.clip_text=original.clip
		var frame:Variant=node.get_meta("text_frame",false)
		if frame is WeakRef and is_instance_valid(frame.get_ref()) and original.has("frame_size"):frame.get_ref().size=original.frame_size
	if old.has("position"):
		var target:=_move_target(node)
		if not preserve_external or target.position.is_equal_approx(old.position):
			target.position=original.position;_redraw_move(target)
	if str(node.text)==str(record.shown):node.text=record.raw
	record.shown=record.raw;record.last={}

func _apply(node:Control,record:Dictionary)->void:
	var spec:Dictionary=entries.get(record.key,{})
	if spec.is_empty():
		if not record.last.is_empty():_restore(node,record,false)
		return
	var applied:Dictionary={}
	if spec.has("font") and not str(spec.font).is_empty():
		var family_font:=_font(str(spec.font));node.add_theme_font_override(_font_key(node),family_font);applied.font=family_font
	if spec.has("font_size"):
		var points:=clampi(int(spec.font_size),6,240);node.add_theme_font_size_override(_size_key(node),points);applied.font_size=points
	if spec.has("box") and spec.box is Array and spec.box.size()==2:
		var box:=Vector2(clampf(float(spec.box[0]),24,2560),clampf(float(spec.box[1]),16,1440))
		if node.get_parent() is Container:
			node.custom_minimum_size=box;node.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN;node.size_flags_vertical=Control.SIZE_SHRINK_BEGIN
		elif node.custom_minimum_size!=Vector2.ZERO:node.custom_minimum_size=Vector2.ZERO
		if node is Label:node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.clip_text=true
		node.size=box;applied.box=node.size
		var ref:Variant=node.get_meta("text_frame",false)
		if ref is WeakRef and is_instance_valid(ref.get_ref()):
			var frame:Control=ref.get_ref();frame.size=box+Vector2(node.get_meta("text_frame_padding",Vector2.ZERO))
			var backdrop:Variant=node.get_meta("text_backdrop",false)
			if backdrop is WeakRef and is_instance_valid(backdrop.get_ref()):backdrop.get_ref().size=frame.size+Vector2(node.get_meta("text_backdrop_padding",Vector2.ZERO))
	if spec.has("position"):
		var location:=Vector2(float(spec.position[0]),float(spec.position[1]));var target:=_move_target(node)
		if not target.position.is_equal_approx(location):target.position=location;_redraw_move(target)
		applied.position=location
	var rendered:=str(spec.get("text",record.raw));node.text=rendered;record.shown=rendered;record.last=applied

func _redraw_move(target:Control)->void:
	target.queue_redraw()
	if target.get_parent() is CanvasItem:target.get_parent().queue_redraw()

func _visible(node:Control)->bool:
	if not node.is_visible_in_tree() or node.size.x<1 or node.size.y<1:return false
	var current:Node=node
	while current!=null:
		if current is CanvasItem and (current.modulate.a<.04 or current.self_modulate.a<.04):return false
		current=current.get_parent()
	if active_stage!=null and not active_stage.is_ancestor_of(node) and active_stage!=node:
		var layer_node:Node=node
		while layer_node!=null:
			if layer_node is CanvasLayer and layer_node.layer>=1000:return true
			layer_node=layer_node.get_parent()
		return false
	return true

func _find_stage(node:Node,best:Dictionary)->void:
	if _ignored(node):return
	if node is Control and node.is_visible_in_tree():
		var script:Script=node.get_script()
		var file:=script.resource_path.get_file() if script!=null else ""
		if file in ["prologue_cover.gd","prologue_comic.gd","grassland_comic.gd","morning_after.gd","ending_entry.gd","sunset_experience.gd","stone_experience.gd"]:
			var depth:int=node.z_index
			if depth>=int(best.get("depth",-100)):best.node=node;best.depth=depth
	for child in node.get_children():_find_stage(child,best)

func visible_records()->Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for id in records:
		var record:Dictionary=records[id];var node:Control=record.node.get_ref()
		if is_instance_valid(node) and _visible(node) and (not str(record.raw).is_empty() or entries.has(record.key)):result.append(record)
	return result

func open_editor()->void:
	if editing:return
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null and audio.opened:audio.close_panel()
	var scene:=get_tree().current_scene
	if scene!=null and "debug_editor" in scene and scene.debug_editor!=null:scene.debug_editor.hide()
	_scan();var stage:Dictionary={};_find_stage(get_tree().root,stage);active_stage=stage.get("node",null)
	var chapter_cover=get_node_or_null("/root/ChapterTransition")
	if chapter_cover!=null and chapter_cover.active:active_stage=chapter_cover
	previous_pause=get_tree().paused;previous_scale=Engine.time_scale
	editing=true;get_tree().paused=true;Engine.time_scale=0.0
	get_viewport().gui_release_focus()
	ui.show();selected_id=0;hovered_id=0;content.editable=false;heading.text="文字编辑 · F2 关闭";status.text="单击选中，按住拖动位置";copy_button.disabled=true;remove_box_button.disabled=true;outline.queue_redraw()

func close_editor()->void:
	if not editing:return
	_finish_inline();_apply_font_field();flush();font_menu.get_popup().hide();editing=false;resizing="";moving=false;move_engaged=false;inspector_dragging=false;inspector_drag_engaged=false;ui.hide();get_viewport().gui_release_focus()
	Engine.time_scale=previous_scale;get_tree().paused=previous_pause

func _selected()->Dictionary:return records.get(selected_id,{})

func select_node(node:Control)->void:
	sync_node(node);_finish_inline();get_viewport().gui_release_focus();selected_id=node.get_instance_id();_fill_inspector();outline.queue_redraw()

func _fill_inspector()->void:
	var record:=_selected()
	if record.is_empty():return
	var node:Control=record.node.get_ref()
	if not is_instance_valid(node):return
	rebuilding=true
	var current_font:Font=node.get_theme_font(_font_key(node));var family:=""
	if current_font is WebSystemFont and not current_font.font_names.is_empty():family=current_font.font_names[0]
	else:family=current_font.get_font_name()
	font_name.text=family;inspector_font_value=family;font_size.value=node.get_theme_font_size(_size_key(node));box_w.value=node.size.x;box_h.value=node.size.y
	content.editable=true;content.text=str(node.text);heading.text="文字编辑 · 已选中文本框";rebuilding=false
	copy_button.disabled=false;remove_box_button.disabled=not node.has_meta("text_copy_id")
	if not inspector_manual:
		var rect:=node.get_global_rect();inspector.position=Vector2(18 if rect.get_center().x>640 and rect.position.y<520 else 950,84)
	_keep_inspector_on_screen()
	status.text="修改实时生效 · 自动保存"

func copy_text_box()->bool:
	if not editing:return false
	var copied:bool=copies.copy_selected();_status("已复制文本框 · 可在当前画面或其他页面粘贴" if copied else "请先选中一个文本框")
	get_viewport().gui_release_focus();return copied

func paste_text_box()->Control:
	if not editing:return null
	_finish_inline();_apply_font_field()
	var node:Control=copies.paste_box()
	if node==null:_status("请先复制文本框，并在目标画面选中一个文字框");return null
	select_node(node);_changed();flush();_status("已粘贴独立文本框 · 可拖动、改字和调整样式");return node

func remove_text_box()->void:
	if not editing:return
	_finish_inline()
	if not copies.remove_selected():_status("只能删除粘贴的副本，原剧情文字保留");return
	selected_id=0;content.editable=false;copy_button.disabled=true;remove_box_button.disabled=true;heading.text="文字编辑 · F2 关闭";_changed();flush();outline.queue_redraw()

func _entry(record:Dictionary)->Dictionary:
	if not entries.has(record.key):entries[record.key]={"source":record.raw,"context":record.context}
	return entries[record.key]

func set_property_value(property:String,value:Variant)->void:
	if rebuilding or not editing:return
	var record:=_selected()
	if record.is_empty():return
	var node:Control=record.node.get_ref()
	if not is_instance_valid(node):return
	var entry:=_entry(record)
	if entry.get(property,null)==value:return
	entry[property]=value
	if property=="font":inspector_font_value=str(value);font_name.text=str(value)
	_apply(node,record);_changed()
	if property!="text":_update_inline_style()
	outline.queue_redraw()

func _set_box(value:Vector2)->void:
	set_property_value("box",[value.x,value.y])
	if editing and not _selected().is_empty():
		var node:Control=_selected().node.get_ref()
		rebuilding=true;box_w.value=node.size.x;box_h.value=node.size.y;rebuilding=false

func _set_content(value:String,from_inline:bool)->void:
	if not editing or _selected().is_empty():return
	set_property_value("text",value)
	var node:Control=_selected().node.get_ref()
	if node is Label or node is RichTextLabel:node.visible_characters=-1
	var cursor:Node=node.get_parent()
	while cursor!=null:
		var script:Script=cursor.get_script()
		if script!=null and script.resource_path.ends_with("/dialogue_view.gd") and cursor.active_label==node:
			cursor.full_text=value;cursor.reveal=value.length();break
		cursor=cursor.get_parent()
	rebuilding=true
	if from_inline:content.text=value
	elif inline_edit.visible:inline_edit.text=value
	rebuilding=false;inline_changed=true

func _changed()->void:
	dirty=true;save_at=Time.get_ticks_msec()+450;status.text="修改实时生效，正在保存…"

func _apply_font_field()->void:
	if editing and not rebuilding and selected_id!=0 and not font_name.text.strip_edges().is_empty() and font_name.text.strip_edges()!=inspector_font_value:set_property_value("font",font_name.text.strip_edges())

func _begin_inline()->void:
	if _selected().is_empty():return
	var node:Control=_selected().node.get_ref()
	if not is_instance_valid(node):return
	inline_previous_visible=node.visible_characters if node is Label or node is RichTextLabel else -1;inline_changed=false
	rebuilding=true;inline_edit.text=str(node.text);rebuilding=false
	_update_inline_style();inline_edit.show();inline_edit.grab_focus();inline_edit.set_caret_line(inline_edit.get_line_count()-1);inline_edit.set_caret_column(inline_edit.get_line(inline_edit.get_caret_line()).length())
	if node is Label or node is RichTextLabel:node.visible_characters=0

func _update_inline_style()->void:
	if _selected().is_empty():return
	var node:Control=_selected().node.get_ref()
	if not is_instance_valid(node):return
	var xform:=node.get_global_transform_with_canvas();inline_edit.position=xform.origin;inline_edit.rotation=xform.get_rotation();inline_edit.scale=xform.get_scale();inline_edit.size=node.size
	inline_edit.add_theme_font_override("font",node.get_theme_font(_font_key(node)));inline_edit.add_theme_font_size_override("font_size",node.get_theme_font_size(_size_key(node)))
	var ink:=node.get_theme_color("default_color" if node is RichTextLabel else "font_color");inline_edit.add_theme_color_override("font_color",ink)
	var box:=StyleBoxFlat.new();box.bg_color=Color(.025,.05,.09,.94) if ink.get_luminance()>.45 else Color(.99,.99,.97,.96);box.border_color=Color("4287d7");box.set_border_width_all(1)
	for state in ["normal","focus"]:inline_edit.add_theme_stylebox_override(state,box)
	inline_edit.add_theme_color_override("caret_color",Color("549dff"))

func _inline_changed()->void:
	if not rebuilding:_set_content(inline_edit.text,true)

func _finish_inline()->void:
	if not inline_edit.visible:return
	if not _selected().is_empty():
		var node:Control=_selected().node.get_ref()
		if is_instance_valid(node) and (node is Label or node is RichTextLabel):node.visible_characters=-1 if inline_changed else inline_previous_visible
	inline_edit.hide();flush()

func _corners(node:Control)->PackedVector2Array:
	var xf:=node.get_global_transform_with_canvas();return PackedVector2Array([xf*Vector2.ZERO,xf*Vector2(node.size.x,0),xf*node.size,xf*Vector2(0,node.size.y)])

func _handles(node:Control)->Dictionary:
	var xf:=node.get_global_transform_with_canvas()
	return {"width":xf*Vector2(node.size.x,node.size.y*.5),"height":xf*Vector2(node.size.x*.5,node.size.y),"both":xf*node.size}

func _move_handle(node:Control)->Vector2:
	return node.get_global_transform_with_canvas()*Vector2(node.size.x*.5,-10)

func _begin_move(node:Control,point:Vector2)->void:
	var target:=_move_target(node);var record:=_selected()
	if not record.last.has("position"):record.base.position=target.position
	moving=true;move_engaged=false;move_pointer=point;move_origin=target.position
	move_inverse=(target.get_global_transform_with_canvas()*target.get_transform().affine_inverse()).affine_inverse()
	gate.mouse_default_cursor_shape=Control.CURSOR_MOVE

func _drag_move(point:Vector2)->void:
	if _selected().is_empty():return
	if not move_engaged and point.distance_to(move_pointer)<4:return
	move_engaged=true
	var location:=move_origin+(move_inverse*point-move_inverse*move_pointer)
	set_property_value("position",[location.x,location.y])

func _draw_boxes()->void:
	if not editing:return
	for record in visible_records():
		var node:Control=record.node.get_ref();var points:=_corners(node);points.append(points[0])
		var selected:=node.get_instance_id()==selected_id
		outline.draw_polyline(points,Color(.27,.57,.95,.94 if selected else .20),1.8 if selected else .8,true)
		if selected:
			for point in _handles(node).values():outline.draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),Color("eff6ff"));outline.draw_rect(Rect2(point-Vector2(4,4),Vector2(8,8)),Color("3276cc"),false,1,true)
			var grip:=_move_handle(node);outline.draw_line((points[0]+points[1])*.5,grip,Color("3276cc"),1,true)
			outline.draw_rect(Rect2(grip-Vector2(9,4),Vector2(18,8)),Color("eff6ff"));outline.draw_rect(Rect2(grip-Vector2(9,4),Vector2(18,8)),Color("3276cc"),false,1,true)
			outline.draw_line(grip-Vector2(5,0),grip+Vector2(5,0),Color("3276cc"),1,true)

func _pick(point:Vector2)->Control:
	var found:Control;var order:=-999999
	for record in visible_records():
		var node:Control=record.node.get_ref();var local:=node.get_global_transform_with_canvas().affine_inverse()*point
		if not Rect2(Vector2.ZERO,node.size).has_point(local):continue
		var ancestor:Node=node;var depth:=0;var z:=0;var layer_value:=0
		while ancestor!=null:
			depth+=1
			if ancestor is CanvasItem:z+=ancestor.z_index
			if ancestor is CanvasLayer:layer_value=ancestor.layer
			ancestor=ancestor.get_parent()
		var score:=layer_value*100000+z*100+depth
		if score>=order:found=node;order=score
	return found

func _canvas_input(event:InputEvent)->void:
	if not editing:return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if not _selected().is_empty():
			var node:Control=_selected().node.get_ref()
			if is_instance_valid(node):
				for handle in _handles(node):
					if event.position.distance_to(_handles(node)[handle])<=10:_finish_inline();resizing=handle;gate.accept_event();return
				if event.position.distance_to(_move_handle(node))<=11:_finish_inline();_begin_move(node,event.position);gate.accept_event();return
		_finish_inline();_apply_font_field()
		var chosen:=_pick(event.position)
		if chosen!=null:
			select_node(chosen)
			if event.double_click:_begin_inline()
			else:_begin_move(chosen,event.position)
		gate.accept_event()
	elif event is InputEventMouseMotion and not moving and resizing.is_empty():
		gate.mouse_default_cursor_shape=Control.CURSOR_MOVE if _pick(event.position)!=null else Control.CURSOR_ARROW

func _input(event:InputEvent)->void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F2:
			if editing:close_editor()
			else:open_editor()
			get_viewport().set_input_as_handled();return
		if editing and event.physical_keycode==KEY_ESCAPE:
			if font_menu.get_popup().visible:font_menu.get_popup().hide()
			elif inline_edit.visible:_finish_inline()
			else:close_editor()
			get_viewport().set_input_as_handled();return
		if editing and event.ctrl_pressed and event.physical_keycode==KEY_S:
			_apply_font_field();flush();get_viewport().set_input_as_handled();return
		if editing:
			var focused:=get_viewport().gui_get_focus_owner()
			var typing:=focused is LineEdit or focused is TextEdit
			if not typing and event.ctrl_pressed and event.physical_keycode in [KEY_C,KEY_V,KEY_D]:
				if event.physical_keycode==KEY_C:copy_text_box()
				elif event.physical_keycode==KEY_V:paste_text_box()
				elif copy_text_box():paste_text_box()
				get_viewport().set_input_as_handled();return
			if not typing and event.physical_keycode==KEY_DELETE:
				remove_text_box();get_viewport().set_input_as_handled();return
		if editing:
			var focused:=get_viewport().gui_get_focus_owner()
			if focused==null or not ui.is_ancestor_of(focused):get_viewport().set_input_as_handled();return
	if not editing:return
	if inspector_dragging:
		if event is InputEventMouseMotion:_drag_inspector(event.position);get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:inspector_dragging=false;inspector_drag_engaged=false;flush();get_viewport().set_input_as_handled()
		return
	if moving:
		if event is InputEventMouseMotion:
			_drag_move(event.position);get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			moving=false;move_engaged=false;flush();get_viewport().set_input_as_handled()
		return
	if resizing.is_empty():return
	if event is InputEventMouseMotion and not _selected().is_empty():
		var node:Control=_selected().node.get_ref();var local:Vector2=node.get_global_transform_with_canvas().affine_inverse()*event.position
		_set_box(Vector2(node.size.x if resizing=="height" else local.x,node.size.y if resizing=="width" else local.y));get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:resizing="";flush();get_viewport().set_input_as_handled()

func extra_settings()->Dictionary:return {}

func flush()->bool:
	if not dirty:return true
	var save_path:=path
	var settings:={"version":1,"entries":entries}
	settings.merge(extra_settings())
	if not copies.boxes.is_empty():settings["text_boxes"]=copies.boxes
	if inspector_manual:settings["editor_ui"]={"panel_position":[inspector_position.x,inspector_position.y]}
	var text:=JSON.stringify(settings,"  ")
	var temporary:=save_path+".tmp";var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if file==null:
		_status("无法保存，请检查项目配置目录权限。");return false
	file.store_string(text);file.flush();file.close()
	if not JSON.parse_string(FileAccess.get_file_as_string(temporary)) is Dictionary:_status("保存校验失败，原配置保留。");return false
	var error:=DirAccess.rename_absolute(temporary,save_path)
	if error!=OK:_status("无法替换配置，原文件保留。");return false
	dirty=false;_status("已保存 · 下次运行沿用");return true

func _status(value:String)->void:
	if is_instance_valid(status):status.text=value

func _process(_delta:float)->void:
	var now:=Time.get_ticks_msec()
	if now>=scan_at:_scan();scan_at=now+250
	for id in records.keys():
		var node:Node=records[id].node.get_ref()
		if is_instance_valid(node) and node.is_inside_tree() and (node.is_visible_in_tree() or editing):sync_node(node)
	if not copies.boxes.is_empty():copies.reconcile()
	if dirty and now>=save_at:flush()
	if editing:
		_keep_inspector_on_screen()
		outline.queue_redraw()

func _exit_tree()->void:
	if dirty:flush()
	if editing:Engine.time_scale=previous_scale;get_tree().paused=previous_pause
