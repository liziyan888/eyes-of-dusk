extends "res://scripts/text_box_copies.gd"

func create_at(point:Vector2)->Label:
	var scene:=editor.get_tree().current_scene
	if scene==null or not scene.has_method("text_page"):return null
	var parent:Control=scene.text_page()
	var anchor:Label=parent.get_node_or_null("FreeTextAnchor")
	if anchor==null:
		anchor=Label.new();anchor.name="FreeTextAnchor";anchor.text="";anchor.size=Vector2.ONE;anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE;parent.add_child(anchor)
	editor.sync_node(anchor)
	var local:=parent.get_global_transform_with_canvas().affine_inverse()*point
	local.x=clampf(local.x,0,1280-320);local.y=clampf(local.y,0,720-72)
	var id:="free_%x_%x"%[Time.get_ticks_usec(),randi()]
	boxes[id]={"anchor":editor._context(anchor),"anchor_source":"","source":"在这里输入文字","font":"KaiTi","font_size":24,"font_weight":400,"color":"fff7eaff","position":[local.x,local.y],"box":[320,72],"scale":[1,1],"rotation":0,"alignment":0,"vertical_alignment":0,"z_index":30}
	return _spawn(id,anchor)
