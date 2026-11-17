extends RefCounted
## Independent painted-page text boxes. Source anchors scope visibility, never content.
var editor:Node
var boxes:Dictionary={}
var nodes:Dictionary={}
var clipboard:Dictionary={}
var paste_number:=0

func clear()->void:
	for reference in nodes.values():
		var node:Node=reference.get_ref()
		if is_instance_valid(node):node.queue_free()
	boxes.clear();nodes.clear()

func _pair(value:Variant,fallback:Array)->Array:
	if value is Array and value.size()==2 and (value[0] is float or value[0] is int) and (value[1] is float or value[1] is int):
		if is_finite(float(value[0])) and is_finite(float(value[1])):return [float(value[0]),float(value[1])]
	return fallback.duplicate()

func load_data(value:Variant)->void:
	if not value is Dictionary:return
	for id in value:
		var raw:Variant=value[id]
		if not raw is Dictionary or not raw.get("anchor",null) is String or not raw.get("source",null) is String:continue
		var spec:Dictionary={"anchor":raw.anchor,"source":raw.source}
		for field in ["anchor_source","font","color","font_shadow_color","font_outline_color"]:
			if raw.get(field,null) is String:spec[field]=str(raw[field])
		for field in ["font_size","font_weight","alignment","vertical_alignment","shadow_offset_x","shadow_offset_y","shadow_outline_size","outline_size","z_index"]:
			if raw.get(field,null) is int or raw.get(field,null) is float:
				if is_finite(float(raw[field])):spec[field]=clampi(int(raw[field]),-4096,4096)
		spec.font_size=clampi(int(spec.get("font_size",22)),6,240);spec.font_weight=clampi(int(spec.get("font_weight",400)),100,900)
		spec.position=_pair(raw.get("position"),[0,0]);spec.box=_pair(raw.get("box"),[320,72]);spec.scale=_pair(raw.get("scale"),[1,1])
		spec.box=[clampf(spec.box[0],24,2560),clampf(spec.box[1],16,1440)]
		spec.rotation=float(raw.rotation) if (raw.get("rotation") is int or raw.get("rotation") is float) and is_finite(float(raw.rotation)) else 0.0
		boxes[str(id)]=spec

func _anchor(context:String,source:Variant=null)->Control:
	for record in editor.records.values():
		if record.context!=context or (source is String and str(record.raw)!=source):continue
		var node:Control=record.node.get_ref()
		if is_instance_valid(node) and node.is_inside_tree() and not node.has_meta("text_copy_id"):return node
	return null

func _host(node:Control)->Control:
	var fallback:Control;var cursor:Node=node.get_parent()
	while cursor!=null:
		if cursor is Control:
			if cursor.has_meta("text_scope"):return cursor
			if fallback==null and not cursor is Container:fallback=cursor
		cursor=cursor.get_parent()
	return fallback

func _spawn(id:String,anchor:Control)->Label:
	var spec:Dictionary=boxes[id];var parent:=_host(anchor)
	if parent==null:return null
	var label:=Label.new();label.name="TextBox_"+id.validate_node_name();label.set_meta("text_copy_id",id);label.set_meta("text_scope","text-box-"+id);label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.clip_text=true;label.text=spec.source
	var font:=WebSystemFont.new();font.font_names=PackedStringArray([str(spec.get("font","SimSun"))]);font.font_weight=int(spec.get("font_weight",400));label.add_theme_font_override("font",font);label.add_theme_font_size_override("font_size",int(spec.get("font_size",22)))
	label.add_theme_color_override("font_color",Color.from_string(str(spec.get("color","f1eee5ff")),Color.WHITE))
	for field in ["font_shadow_color","font_outline_color"]:
		if spec.has(field):label.add_theme_color_override(field,Color.from_string(str(spec[field]),Color.TRANSPARENT))
	for field in ["shadow_offset_x","shadow_offset_y","shadow_outline_size","outline_size"]:
		if spec.has(field):label.add_theme_constant_override(field,int(spec[field]))
	label.horizontal_alignment=clampi(int(spec.get("alignment",0)),0,3);label.vertical_alignment=clampi(int(spec.get("vertical_alignment",0)),0,3)
	label.size=Vector2(spec.box[0],spec.box[1]);label.position=Vector2(spec.position[0],spec.position[1]);label.scale=Vector2(spec.scale[0],spec.scale[1]);label.rotation=spec.rotation;label.z_index=clampi(int(spec.get("z_index",0)),-4096,4096)
	parent.add_child(label);nodes[id]=weakref(label);editor.sync_node(label);return label

func reconcile()->void:
	var by_context:Dictionary={}
	for record in editor.records.values():
		var source:Control=record.node.get_ref()
		if is_instance_valid(source) and source.is_inside_tree() and not source.has_meta("text_copy_id"):by_context[str(record.context)]=record
	for id in boxes:
		var node:Control=nodes[id].get_ref() if nodes.has(id) else null
		var record:Dictionary=by_context.get(str(boxes[id].anchor),{})
		var anchor:Control=record.node.get_ref() if not record.is_empty() and (not boxes[id].has("anchor_source") or str(record.raw)==str(boxes[id].anchor_source)) else null
		if anchor==null:
			if is_instance_valid(node):node.hide()
			continue
		if is_instance_valid(node) and node.get_parent()!=_host(anchor):node.queue_free();node=null
		if not is_instance_valid(node):node=_spawn(id,anchor)
		if not is_instance_valid(node):continue
		var alpha:=1.0;var cursor:Node=anchor
		while cursor!=null and cursor!=node.get_parent():
			if cursor is CanvasItem:alpha*=cursor.modulate.a*cursor.self_modulate.a
			cursor=cursor.get_parent()
		node.visible=anchor.is_visible_in_tree() and alpha>.001;node.modulate.a=alpha

func _snapshot(node:Control)->Dictionary:
	var parent:=_host(node);var transform:=parent.get_global_transform_with_canvas().affine_inverse()*node.get_global_transform_with_canvas()
	var font:Font=node.get_theme_font(editor._font_key(node));var family:=font.get_font_name()
	if font is WebSystemFont and not font.font_names.is_empty():family=font.font_names[0]
	var anchor:String=str(boxes[str(node.get_meta("text_copy_id"))].anchor) if node.has_meta("text_copy_id") else editor._context(node)
	var source:String=str(boxes[str(node.get_meta("text_copy_id"))].get("anchor_source","")) if node.has_meta("text_copy_id") else str(editor.records[node.get_instance_id()].raw)
	var depth:=0;var cursor:Node=node
	while cursor!=null and cursor!=parent:
		if cursor is CanvasItem:depth+=cursor.z_index
		cursor=cursor.get_parent()
	var spec:={"anchor":anchor,"owner":editor._context(parent),"source":node.get_parsed_text() if node is RichTextLabel and node.bbcode_enabled else str(node.text),"font":family,"font_size":node.get_theme_font_size(editor._size_key(node)),"font_weight":font.font_weight if font is WebSystemFont else 400,"box":[node.size.x,node.size.y],"position":[transform.origin.x,transform.origin.y],"scale":[transform.get_scale().x,transform.get_scale().y],"rotation":transform.get_rotation(),"alignment":int(node.horizontal_alignment) if node is Label else int(node.alignment) if node is Button else 0,"vertical_alignment":int(node.vertical_alignment) if node is Label else 1,"color":node.get_theme_color("default_color" if node is RichTextLabel else "font_color").to_html(true),"z_index":depth}
	spec.anchor_source=source
	for field in ["font_shadow_color","font_outline_color"]:spec[field]=node.get_theme_color(field).to_html(true)
	for field in ["shadow_offset_x","shadow_offset_y","shadow_outline_size","outline_size"]:spec[field]=node.get_theme_constant(field)
	return spec

func copy_selected()->bool:
	var selected:Dictionary=editor._selected();var node:Control=selected.node.get_ref() if not selected.is_empty() else null
	if not is_instance_valid(node):return false
	editor._finish_inline();editor._apply_font_field();clipboard=_snapshot(node);paste_number=0
	# Keep ordinary text usable when pasting into WPS or an active text-edit field.
	DisplayServer.clipboard_set(str(clipboard.source));return true

func _target()->Control:
	var selected:Dictionary=editor._selected();var node:Control=selected.node.get_ref() if not selected.is_empty() else null
	if is_instance_valid(node) and editor._visible(node):return node
	for record in editor.visible_records():
		node=record.node.get_ref()
		if editor.active_stage!=null and editor.active_stage.is_ancestor_of(node) and not str(node.text).is_empty():return node
	return null

func paste_box()->Label:
	var target:=_target()
	if target==null:return null
	var plain:=DisplayServer.clipboard_get();var spec:Dictionary
	if not clipboard.is_empty() and plain==str(clipboard.source):spec=clipboard.duplicate(true)
	else:
		if plain.is_empty():return null
		spec=_snapshot(target);spec.source=plain;paste_number=0
	var binding:Dictionary=boxes[str(target.get_meta("text_copy_id"))] if target.has_meta("text_copy_id") else {"anchor":editor._context(target),"anchor_source":str(editor.records[target.get_instance_id()].raw)}
	var anchor:=_anchor(str(binding.anchor),binding.get("anchor_source"))
	if anchor==null:return null
	var parent:=_host(anchor)
	if parent==null:return null
	var position:=Vector2(spec.position[0],spec.position[1])
	if str(spec.get("owner",""))!=editor._context(parent):position=(parent.get_global_transform_with_canvas().affine_inverse()*target.get_global_transform_with_canvas()).origin
	paste_number+=1;position+=Vector2(24,24)*paste_number;spec.position=[position.x,position.y];spec.anchor=editor._context(anchor);spec.anchor_source=str(editor.records[anchor.get_instance_id()].raw);spec.erase("owner")
	var id:="%x_%x"%[Time.get_ticks_usec(),randi()];boxes[id]=spec
	var node:=_spawn(id,anchor);reconcile();return node

func remove_selected()->bool:
	var selected:Dictionary=editor._selected();var node:Control=selected.node.get_ref() if not selected.is_empty() else null
	if not is_instance_valid(node) or not node.has_meta("text_copy_id"):return false
	var id:=str(node.get_meta("text_copy_id"));boxes.erase(id);nodes.erase(id);editor.entries.erase(str(selected.key));editor.records.erase(node.get_instance_id());node.queue_free();return true
