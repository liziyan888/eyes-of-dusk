extends PanelContainer
signal layout_changed
var game: Node
var selected_id := ""
var picker: OptionButton
var x_field: SpinBox
var y_field: SpinBox
var ground_field: SpinBox
var status: Label
var rebuilding := false
var dragging := false
var export_dialog: FileDialog
var import_dialog: FileDialog
var tabs: TabContainer
var layer_picker: OptionButton
var layer_id := "house"
var layer_scene_index := -1
var layer_f: SpinBox
var layer_slider: HSlider
var layer_x: SpinBox
var layer_y: SpinBox
var layer_scale: SpinBox
var layer_visible: CheckButton
var layer_note: Label
var subtitle_role:="her"
var subtitle_picker:OptionButton
var subtitle_color:ColorPickerButton
var subtitle_auto:CheckButton
var subtitle_fields:Dictionary={}
var subtitle_note:Label

func setup(controller: Node, font: Font) -> void:
	game = controller
	z_index=200
	position = Vector2(914,74)
	size = Vector2(340,604)
	add_theme_font_override("font",font)
	add_theme_font_size_override("font_size",14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.085,0.07,0.97)
	style.border_color = Color("87bda4")
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.content_margin_left = 15
	style.content_margin_right = 15
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel",style)
	tabs=TabContainer.new()
	add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.name="人物与互动"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	var heading := Label.new()
	heading.text = "场景调试 · F3 关闭"
	column.add_child(heading)
	var help := Label.new()
	help.text = "拖动十字标记或填写坐标。\n编辑时暂停移动与自动剧情。"
	column.add_child(help)
	ground_field = number(column,"人物脚底线",700,400,740,1,func(v):
		game.layout.data.grounds[str(int(game.current_scene().id))] = v
		layout_changed.emit())
	number(column,"前景重叠深度",12,4,30,1,func(v): game.layout.data.overlap=v;layout_changed.emit())
	number(column,"人物比例",1,0.25,3,0.05,func(v): game.layout.data.player_scale=v;layout_changed.emit())
	number(column,"全局 X 偏移",0,-400,400,1,func(v): game.layout.data.offset_x=v;layout_changed.emit())
	number(column,"全局 Y 偏移",0,-300,300,1,func(v): game.layout.data.offset_y=v;layout_changed.emit())
	picker = OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.item_selected.connect(func(index): selected_id=str(picker.get_item_metadata(index));refresh_point())
	column.add_child(picker)
	x_field = number(column,"互动点 X / 世界坐标",0,0,12000,1,func(v): update_point(Vector2(v,y_field.value)))
	y_field = number(column,"互动点 Y / 根部位置",660,0,720,1,func(v): update_point(Vector2(x_field.value,v)))
	var note := Label.new()
	note.text = "靠近触发与互动范围共用此坐标。\n根部放在脚底线附近可藏入草丛。"
	note.add_theme_font_size_override("font_size",12)
	column.add_child(note)
	button(column,"查看 / 移动到所选点",func():
		var point := selected_point()
		if not point.is_empty():
			game.player_x = game.point_position(point).x - 65
			game.camera_x = clampf(game.player_x-512,float(game.current_scene().start),maxf(float(game.current_scene().start),float(game.current_scene().end)-1280))
		layout_changed.emit())
	button(column,"保存并记住配置",func(): status.text="配置已保存，下次运行沿用。" if game.layout.save() else "保存失败，请导出 JSON。")
	button(column,"导出 JSON…",func(): export_dialog.popup_centered(Vector2i(760,480)))
	button(column,"导入 JSON…",func(): import_dialog.popup_centered(Vector2i(760,480)))
	button(column,"恢复默认（保存后永久生效）",func(): game.layout.reset();refresh();layout_changed.emit())
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 285
	status.add_theme_font_size_override("font_size",12)
	column.add_child(status)
	make_layer_page()
	make_subtitle_page()
	export_dialog = file_dialog(FileDialog.FILE_MODE_SAVE_FILE)
	export_dialog.current_file = "eyes-layout.json"
	export_dialog.file_selected.connect(func(path):status.text="已导出配置。" if game.layout.save(path) else "导出失败。")
	import_dialog = file_dialog(FileDialog.FILE_MODE_OPEN_FILE)
	import_dialog.file_selected.connect(func(path):
		if game.layout.apply(JSON.parse_string(FileAccess.get_file_as_string(path))):
			refresh();layout_changed.emit();status.text="已导入；点击保存可记住配置。"
		else:status.text="配置格式不正确。")
	hide()

func make_layer_page() -> void:
	var scroll:=ScrollContainer.new()
	scroll.name="场景图层"
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var column:=VBoxContainer.new()
	column.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	layer_note=Label.new()
	layer_note.text="当前场景 PS 图层\n位置单位：设计像素；缩放保持比例。"
	layer_note.add_theme_font_size_override("font_size",12)
	column.add_child(layer_note)
	layer_picker=OptionButton.new()
	layer_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	column.add_child(layer_picker)
	layer_picker.item_selected.connect(func(index):layer_id=str(layer_picker.get_item_metadata(index));refresh_layer())
	layer_f=number(column,"视差系数",1,0,1.5,.01,func(v):change_layer("f",v))
	layer_slider=HSlider.new()
	layer_slider.min_value=0;layer_slider.max_value=1.5;layer_slider.step=.01
	column.add_child(layer_slider)
	layer_slider.value_changed.connect(func(v):
		if not rebuilding:change_layer("f",v))
	layer_x=number(column,"图层 X",0,-4000,6000,1,func(v):change_layer("x",v))
	layer_y=number(column,"图层 Y / 原画布",0,-2000,2500,1,func(v):change_layer("y",v))
	layer_scale=number(column,"缩放 %",100,10,300,1,func(v):change_layer("scale",v/100.0))
	layer_visible=CheckButton.new()
	layer_visible.text="显示此图层"
	column.add_child(layer_visible)
	layer_visible.toggled.connect(func(v):
		if not rebuilding:change_layer("visible",v))
	button(column,"恢复本层默认",func():game.layout.reset_layer(layer_id);refresh_layer();layout_changed.emit())
	button(column,"恢复本场图层默认",func():
		for id in game.editable_layers():game.layout.reset_layer(str(id))
		refresh_layer();layout_changed.emit())
	button(column,"查看所选图层",func():
		var entry: Dictionary=game.layout.layer_parameters(layer_id)
		if entry.is_empty():return
		var sc: Dictionary=game.current_scene()
		var start:=float(entry.get("region_start",sc.start))
		var end:=float(entry.get("region_end",sc.end))
		game.camera_x=clampf(start+float(entry.x)+float(entry.w)*float(entry.scale)*.5-640,maxf(0,start-640),maxf(start,end-640))
		layout_changed.emit())
	button(column,"保存图层与其他配置",func():layer_note.text="配置已保存，下次运行沿用。" if game.layout.save() else "保存失败，请导出 JSON。")
	button(column,"导出 JSON…",func():export_dialog.popup_centered(Vector2i(760,480)))
	button(column,"导入 JSON…",func():import_dialog.popup_centered(Vector2i(760,480)))

func make_subtitle_page()->void:
	var column:=VBoxContainer.new();column.name="文字编辑";column.add_theme_constant_override("separation",12);tabs.add_child(column)
	subtitle_note=Label.new();subtitle_note.text="文字编辑已统一到 F2。\n单击文字选中，双击原位编辑。\n只保留字体、字号、文本框大小、内容。";subtitle_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;column.add_child(subtitle_note)
	button(column,"打开文字编辑 · F2",func():
		hide()
		var studio=get_node_or_null("/root/TextStudio")
		if studio!=null:studio.open_editor())

func _edit_subtitle_number(value:float,field:String)->void:
	change_subtitle(field,value/100.0 if field=="background_opacity" else value)

func change_subtitle(field:String,value:Variant)->void:
	if rebuilding:return
	game.layout.set_subtitle(subtitle_role,field,value);refresh_subtitles();layout_changed.emit()

func refresh_subtitles()->void:
	if subtitle_picker==null:return
	var previous:=rebuilding;rebuilding=true
	var styles:Dictionary=game.layout.subtitles();var data:Dictionary=styles[subtitle_role]
	subtitle_picker.select(0 if subtitle_role=="her" else 1);subtitle_color.color=Color.html(str(data.background_color));subtitle_auto.button_pressed=bool(data.background_auto)
	for field in subtitle_fields:subtitle_fields[field].value=float(data[field])*(100.0 if field=="background_opacity" else 1.0)
	rebuilding=previous

func toggle_subtitles()->void:
	visible=not visible;dragging=false
	if visible:refresh();tabs.current_tab=2

func refresh_layers() -> void:
	var previous:=rebuilding
	rebuilding=true
	layer_picker.clear()
	var order: Array=game.editable_layers()
	if layer_scene_index!=game.scene_index or not layer_id in order:
		layer_id="passage12_ground" if game.in_passage12() else ("house" if game.scene_index==2 else ("creek2_ground" if game.scene_index==1 else ("meadow1_near" if game.scene_index==0 else "moon%d_ground"%[game.scene_index+1])))
		if not layer_id in order:layer_id=str(order[0]) if not order.is_empty() else ""
		layer_scene_index=game.scene_index
	for id in order:
		var entry: Dictionary=game.layout.layer_parameters(str(id))
		layer_picker.add_item(str(entry.name))
		var index:=layer_picker.item_count-1
		layer_picker.set_item_metadata(index,str(id))
		if str(id)==layer_id:layer_picker.select(index)
	layer_picker.disabled=order.is_empty()
	tabs.set_tab_disabled(1,order.is_empty())
	rebuilding=previous
	refresh_layer()

func refresh_layer() -> void:
	var entry: Dictionary=game.layout.layer_parameters(layer_id)
	if entry.is_empty():return
	var previous:=rebuilding
	rebuilding=true
	layer_f.value=float(entry.f);layer_slider.value=float(entry.f)
	layer_x.value=float(entry.x);layer_y.value=float(entry.y)
	layer_scale.value=float(entry.scale)*100;layer_visible.button_pressed=bool(entry.visible)
	layer_note.text=("场景一至二 · 过渡区" if game.in_passage12() else str(game.current_scene().no))+" · PS 分层素材\n地平线基准 Y%.0f；本场校准 %.0f\n图层 Y 保留参考画布坐标；微调独立保存。" % [game.layout.horizon_y(),game.layout.scene_vertical_offset(game.scene_index)]
	rebuilding=previous

func change_layer(field: String,value: Variant) -> void:
	if rebuilding or not layer_id in game.editable_layers():return
	if game.layout.set_layer(layer_id,field,value):
		refresh_layer()
		layout_changed.emit()

func file_dialog(mode: FileDialog.FileMode) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; 场景布局配置"])
	dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_child(dialog)
	return dialog

func number(parent: Node, title: String, value: float, minimum: float, maximum: float, step: float, change: Callable) -> SpinBox:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var spin := SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.step = step
	spin.value = value
	spin.custom_minimum_size.x = 104
	row.add_child(spin)
	spin.value_changed.connect(func(v):
		if not rebuilding: change.call(v))
	spin.set_meta("setting_label",title)
	return spin

func button(parent: Node, title: String, action: Callable) -> void:
	var result := Button.new()
	result.text = title
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(action)
	parent.add_child(result)

func toggle() -> void:
	visible = not visible
	dragging = false
	if visible:refresh()
	if visible:tabs.current_tab=1 if not game.editable_layers().is_empty() else 0

func refresh() -> void:
	rebuilding = true
	ground_field.value = game._ground()
	var spins := find_children("*","SpinBox",true,false)
	for spin in spins:
		match str(spin.get_meta("setting_label","")):
			"前景重叠深度":spin.value=game.layout.data.overlap
			"人物比例":spin.value=game.layout.data.player_scale
			"全局 X 偏移":spin.value=game.layout.data.offset_x
			"全局 Y 偏移":spin.value=game.layout.data.offset_y
	picker.clear()
	var index := 0
	for point in game.points():
		picker.add_item(str(point.prompt))
		picker.set_item_metadata(index,str(point.id))
		if str(point.id)==selected_id:picker.select(index)
		index+=1
	if picker.item_count>0:
		selected_id=str(picker.get_item_metadata(picker.selected))
	rebuilding=false
	refresh_point()
	refresh_layers()
	refresh_subtitles()

func selected_point() -> Dictionary:
	for point in game.points():
		if str(point.id)==selected_id:return point
	return {}

func refresh_point() -> void:
	var point := selected_point()
	if point.is_empty():return
	rebuilding=true
	var pos: Vector2 = game.point_position(point)
	y_field.max_value=game.layout.point_edit_max_y(point)
	x_field.min_value=float(game.current_scene().start)+46
	x_field.max_value=float(game.current_scene().end)-52
	x_field.value=pos.x
	y_field.value=pos.y
	rebuilding=false
	status.text="接近范围 ±%d；互动范围 ±%d。" % [game.approach_radius(point),game.interaction_radius(point)]

func update_point(value: Vector2) -> void:
	var point:=selected_point()
	if point.is_empty():return
	game.layout.set_point(point,value,game.camera_x)
	layout_changed.emit()

func pointer(event: InputEvent) -> bool:
	if not visible:return false
	if tabs.current_tab!=0:return false
	if event is InputEventMouse and not dragging and get_global_rect().has_point(event.position):return false
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			var point_screen: Vector2 = event.position
			for point in game.points():
				if game._screen(game.point_position(point)).distance_to(point_screen)<20:
					selected_id=str(point.id);dragging=true;refresh();return true
		else:
			var was_dragging:=dragging
			dragging=false
			return was_dragging
	if event is InputEventMouseMotion and dragging:
		update_point(game.screen_to_world(event.position))
		refresh_point()
		return true
	return false
