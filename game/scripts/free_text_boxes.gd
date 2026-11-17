extends "res://scripts/text_box_copies.gd"
const STAGES=["prologue_cover.gd","prologue_comic.gd","sensor_introduction.gd","grassland_comic.gd","grassland_motion_page.gd","morning_after.gd","ending_entry.gd","ending_comic.gd","ending_descent.gd","ending_archive_sequence.gd","sunset_experience.gd","stone_experience.gd"]
var hosts:Dictionary={}

func _signature(stage:Node)->String:
	var parts:PackedStringArray=[]
	var script:Script=stage.get_script();var file:=script.resource_path.get_file() if script!=null else "world"
	parts.append(file)
	for field in ["page_index","scene_index","scene","mode","modal_kind"]:
		if field in stage and (stage.get(field) is int or stage.get(field) is String):parts.append(field+"="+str(stage.get(field)))
	if "page" in stage and stage.page is Dictionary:parts.append(str(stage.page.get("id",stage.page.get("kind",""))))
	if "morning" in stage and stage.morning!=null:parts.append("morning="+str(stage.morning.active))
	if file in ["ending_descent.gd","sunset_experience.gd","stone_experience.gd"]:
		for field in ["phase","card_id"]:
			if field in stage:parts.append(field+"="+str(stage.get(field)))
	return "|".join(parts)

func _current_host()->Control:
	var scene:Node=editor.get_tree().current_scene
	if scene==null:return null
	if scene.has_method("text_page"):return scene.text_page()
	var best:Dictionary={};editor._find_stage(editor.get_tree().root,best)
	var stage:Node=best.get("node",scene)
	var parent:Node=stage
	if stage==scene and "ui" in scene:parent=scene.ui
	if not parent is Control:return null
	var context:String=editor._context(stage)+"/free-page/"+_signature(stage)
	for key in hosts.keys():
		var old:Control=hosts[key].get_ref()
		if is_instance_valid(old):old.visible=key==context
		else:hosts.erase(key)
	var host:Control=hosts[context].get_ref() if hosts.has(context) else null
	if not is_instance_valid(host):
		host=Control.new();host.name="AuthorTextCanvas";host.size=Vector2(1280,720);host.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.z_index=90;host.set_meta("text_scope",context);parent.add_child(host);hosts[context]=weakref(host)
	return host

func _ensure_anchor(host:Control)->Label:
	var anchor:Label=host.get_node_or_null("FreeTextAnchor")
	if anchor==null:
		anchor=Label.new();anchor.name="FreeTextAnchor";anchor.text="";anchor.size=Vector2.ONE;anchor.mouse_filter=Control.MOUSE_FILTER_IGNORE;host.add_child(anchor)
	editor.sync_node(anchor);return anchor

func create_at(point:Vector2)->Label:
	var host:=_current_host()
	if host==null:return null
	var anchor:=_ensure_anchor(host)
	var local:=host.get_global_transform_with_canvas().affine_inverse()*point
	local.x=clampf(local.x,0,1280-320);local.y=clampf(local.y,0,720-72)
	var id:="free_%x_%x"%[Time.get_ticks_usec(),randi()]
	boxes[id]={"anchor":editor._context(anchor),"anchor_source":"","source":"在这里输入文字","font":"KaiTi","font_size":24,"font_weight":400,"color":"fff7eaff","position":[local.x,local.y],"box":[320,72],"scale":[1,1],"rotation":0,"alignment":0,"vertical_alignment":0,"z_index":30}
	return _spawn(id,anchor)

func reconcile()->void:
	if not boxes.is_empty():
		var host:=_current_host()
		if host!=null:_ensure_anchor(host)
	super.reconcile()
