extends Control
const Mix=preload("res://scripts/audio_mix.gd")
## Story progress is monotonic. Reopening an interaction never selects or re-unlocks a panel.
signal finished
signal arrival_revealed
signal fullscreen_requested
const ART := "res://assets/prologue/"
const SAVE := "user://prologue-v1.json"
const PAPER := Color("ffffff")
const INK := Color("eff3ed")
const DIALOGUE_INK := Color("283b48")
const ART_SHADER = preload("res://shaders/prologue_art.gdshader")
const TURN_SHADER = preload("res://shaders/comic_page_turn.gdshader")
const OBSERVE_SHADER = preload("res://shaders/comic_observation.gdshader")
const Hotspot = preload("res://scripts/comic_hotspot.gd")
const PageCurl = preload("res://scripts/comic_page_curl.gd")
const ComicPanel = preload("res://scripts/comic_panel.gd")
const SensorIntroduction = preload("res://scripts/sensor_introduction.gd")
var sensor_introduction:Control
var data: Dictionary
var page_index := 0
var panel_index := -1
var frontier := -1
var done: Dictionary = {}
var observations: Dictionary = {}
var muted := false
var transitioning := false
var page_turning := false
var intro_blocked := false
var test_mode := false
var serial := 0
var clock := 0.0
var ink_font: Font
var ui_font: Font
var paper: ColorRect
var page_root: Control
var back_curl: Control
var curl: Control
var panels: Array[Dictionary] = []
var modal: Control
var modal_body: Label
var modal_photo: TextureRect
var modal_kind := ""
var modal_scan := false
var scan_point := Vector2(-1000,-1000)
var clue_points: Array[Dictionary] = []
var observation_material: ShaderMaterial
var scan_lens: Control
var clue_glow := 0.0
var pencil_views: Array[Dictionary] = []
var pencil_impulse := 0.0
var pencil_turn := 0.0
var active_label: Label
var transition_layer: Control
var transition_plate: TextureRect
var transition_audio: AudioStreamPlayer
var ambience: AudioStreamPlayer
var ambience_old: AudioStreamPlayer
var effects: Array[AudioStreamPlayer] = []
var ambience_name := ""
var audio_tweens: Array[Tween] = []
var last_unlock_origin := Vector2(.5,.5)
var cabinet_paragraphs:Array[String]=[]
var cabinet_paragraph_index:=0
var cabinet_reveal:=0.0
var cabinet_counter:Label
var cabinet_hint:Label
var cabinet_continue:Button

func _ready() -> void:
	ChapterTransition.title_leaving.connect(_chapter_title_leaving)
	position=Vector2.ZERO
	size=Vector2(1280,720)
	mouse_filter=MOUSE_FILTER_STOP
	data=JSON.parse_string(FileAccess.get_file_as_string("res://data/prologue.json"))
	ui_font=WebSystemFont.new();ui_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC","sans-serif"])
	ink_font=WebSystemFont.new();ink_font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"])
	paper=_rect(self,Rect2(0,0,1280,720),PAPER)
	page_root=Control.new();page_root.size=size;page_root.mouse_filter=MOUSE_FILTER_IGNORE;add_child(page_root)
	curl=PageCurl.new();curl.z_index=9;curl.turn_requested.connect(func():turn_page(1));add_child(curl);curl.hide()
	back_curl=PageCurl.new();back_curl.backwards=true;back_curl.z_index=9;back_curl.turn_requested.connect(func():turn_page(-1));add_child(back_curl);back_curl.hide()
	ambience=AudioStreamPlayer.new();ambience.bus="Ambience";add_child(ambience)
	ambience_old=AudioStreamPlayer.new();ambience_old.bus="Ambience";add_child(ambience_old)
	transition_audio=AudioStreamPlayer.new();transition_audio.bus="Effects";transition_audio.volume_db=-7;add_child(transition_audio)
	for i in range(2):
		var effect:=AudioStreamPlayer.new();effect.bus="Effects";effect.volume_db=-8;add_child(effect);effects.append(effect)
	hide()

func _rect(parent:Node,r:Rect2,color:Color)->ColorRect:
	var node:=ColorRect.new();node.position=r.position;node.size=r.size;node.color=color;node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func _label(parent:Node,text:String,r:Rect2,font_size:int,color:=INK,serif:=false)->Label:
	var node:=Label.new();node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_override("font",ink_font if serif else ui_font);node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color);node.text=text;node.position=r.position;node.size=r.size;node.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(node);return node

func _button(parent:Node,text:String,r:Rect2,action:Callable,font_size:=19)->Button:
	var node:=Button.new();node.position=r.position;node.size=r.size;node.text=text
	node.add_theme_font_override("font",ui_font);node.add_theme_font_size_override("font_size",font_size)
	for state in ["normal","hover","pressed","disabled"]:node.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	var focus:=StyleBoxFlat.new();focus.bg_color=Color.TRANSPARENT;focus.border_width_bottom=1;focus.border_color=Color(1,1,1,.75);node.add_theme_stylebox_override("focus",focus)
	for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:node.add_theme_color_override(key,INK)
	node.mouse_default_cursor_shape=CURSOR_POINTING_HAND;node.pressed.connect(action);parent.add_child(node);return node

func _source(id:String)->Texture2D:
	if id=="21":return load(ART+"pencil-background.png")
	if ResourceLoader.exists(ART+id+"-closed.png"):return load(ART+id+"-closed.png")
	return load(ART+id+".png")

func _image(parent:Node,tex:Texture2D,r:Rect2,focus:=Vector2(.5,.5),bounds:=Rect2())->TextureRect:
	var src:=bounds if bounds.size.x>0 else Rect2(Vector2.ZERO,tex.get_size())
	var ratio:=r.size.x/r.size.y
	if src.size.x/src.size.y>ratio:
		var width:=src.size.y*ratio
		src.position.x+=clampf(focus.x*src.size.x-width/2,0,src.size.x-width);src.size.x=width
	else:
		var height:=src.size.x/ratio
		src.position.y+=clampf(focus.y*src.size.y-height/2,0,src.size.y-height);src.size.y=height
	var atlas:=AtlasTexture.new();atlas.atlas=tex;atlas.region=src
	var image:=TextureRect.new();image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_SCALE
	image.texture=atlas;image.position=r.position;image.size=r.size;image.mouse_filter=MOUSE_FILTER_IGNORE
	image.set_meta("source_region",src);image.set_meta("source_size",tex.get_size());parent.add_child(image);return image

func _flat(p:int,i:int)->int:
	var result:=i
	for n in range(p):result+=data.pages[n].panels.size()
	return result

func begin(fresh:=false)->void:
	ChapterTransition.cancel(self)
	serial+=1;_cancel_audio_tweens();transition_audio.stop();_close_modal(false)
	if is_instance_valid(sensor_introduction):sensor_introduction.reset_flow()
	if is_instance_valid(transition_layer):transition_layer.queue_free()
	transition_layer=null;transition_plate=null
	page_index=0;panel_index=-1;frontier=-1;done.clear();observations.clear()
	transitioning=false;page_turning=false;intro_blocked=false
	if not fresh and not test_mode and FileAccess.file_exists(SAVE):
		var saved=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
		if saved is Dictionary:
			muted=false # Master mute now lives in AudioSettings, independently of comic progress.
			if not saved.get("complete",false):
				page_index=clampi(int(saved.get("page",0)),0,data.pages.size()-1)
				frontier=clampi(int(saved.get("frontier",-1)),-1,27)
				done=saved.get("done",{});observations=saved.get("observations",{})
	paper.show();page_root.show();show();_set_sound_levels();_build_page();_save()

func _save(complete:=false)->void:
	if test_mode:return
	var file:=FileAccess.open(SAVE,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"version":3,"page":page_index,"frontier":frontier,"done":done,"observations":observations,"muted":muted,"complete":complete}))

func _layout_rect(item:Dictionary)->Rect2:
	var a:Array=item.rect
	var f:=Vector2(1280.0/1176.0,720.0/510.0)
	var r:=Rect2(Vector2(a[0],a[1])*f,Vector2(a[2],a[3])*f)
	var old_gap:=Vector2(12,12)*f
	var finish:=r.end
	if r.position.x>0:r.position.x-=(old_gap.x-5)/2
	if r.position.y>0:r.position.y-=(old_gap.y-5)/2
	if finish.x<1279:finish.x+=(old_gap.x-5)/2
	if finish.y<719:finish.y+=(old_gap.y-5)/2
	r.size=finish-r.position
	return r

func _build_page(preserve_modal:=false)->void:
	if not preserve_modal:_close_modal(false)
	for child in page_root.get_children():page_root.remove_child(child);child.queue_free()
	panels.clear();pencil_views.clear();active_label=null;panel_index=-1
	_ambient(str(data.pages[page_index].ambience))
	var items:Array=data.pages[page_index].panels
	for i in range(items.size()):
		var item:Dictionary=items[i]
		var r:=_layout_rect(item)
		var container:=ComicPanel.new();container.position=r.position;container.size=r.size
		container.set_meta("text_scope","prologue-panel-"+str(item.id))
		container.mouse_filter=MOUSE_FILTER_STOP;container.clip_contents=false
		page_root.add_child(container)
		container.gui_input.connect(func(event:InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
				_press_panel(i,event.position/r.size);container.accept_event()
			elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE,KEY_ENTER]:
				_press_panel(i);container.accept_event())
		var art_parent:Node=container
		var picture:=Rect2(Vector2.ZERO,r.size)
		if item.has("slant"):
			var mask:=Polygon2D.new();var w:=r.size.x;var h:=r.size.y;var skew:=14.0
			mask.polygon=PackedVector2Array([Vector2(0,0),Vector2(w,0),Vector2(w-skew,h),Vector2(0,h)]) if item.slant=="right" else PackedVector2Array([Vector2(0,0),Vector2(w,0),Vector2(w,h),Vector2(-skew,h)])
			container.hit_polygon=mask.polygon
			mask.clip_children=CanvasItem.CLIP_CHILDREN_ONLY;container.add_child(mask);art_parent=mask
			if item.slant=="left":picture.position.x=-skew;picture.size.x+=skew
		var b:Array=item.source_bounds
		var image:=_image(art_parent,_source(str(item.id)),picture,Vector2(item.focus[0],item.focus[1]),Rect2(b[0],b[1],b[2],b[3]))
		var mat:=ShaderMaterial.new();mat.shader=ART_SHADER;mat.set_shader_parameter("rect_size",picture.size);image.material=mat
		var text:Label
		var narrative:Control
		if item.kind=="speech":
			var bubble:Array=item.bubble
			var box:=Rect2(bubble[0]*r.size.x,bubble[1]*r.size.y,minf(bubble[2]*r.size.x,350),70)
			var measured:=ink_font.get_multiline_string_size(str(item.text),HORIZONTAL_ALIGNMENT_LEFT,box.size.x-30,18)
			box.size.y=measured.y+42
			box.position.x=clampf(box.position.x,12,r.size.x-box.size.x-12)
			box.position.y=clampf(box.position.y,10,r.size.y-box.size.y-10)
			narrative=Panel.new();narrative.position=box.position;narrative.size=box.size;narrative.mouse_filter=MOUSE_FILTER_IGNORE
			var style:=StyleBoxFlat.new();style.bg_color=Color.TRANSPARENT;style.set_border_width_all(0)
			style.corner_radius_top_left=24;style.corner_radius_top_right=29;style.corner_radius_bottom_left=27;style.corner_radius_bottom_right=22
			narrative.add_theme_stylebox_override("panel",style);container.add_child(narrative)
			_label(narrative,str(item.who),Rect2(15,8,box.size.x-30,17),11,Color("9ec8ed") if str(item.who) in ["她","女孩"] else Color("ffce8d"))
			text=_label(narrative,str(item.text),Rect2(15,27,box.size.x-30,box.size.y-33),18,Color("fff9ed"),true)
			preload("res://scripts/dialogue_appearance.gd").attach(text,"her" if str(item.who) in ["她","女孩"] else "man")
			text.set_meta("text_frame",weakref(narrative));text.set_meta("text_frame_padding",Vector2(30,33))
		else:
			var chars:=maxf(10,minf(r.size.x-44,880)/20.0)
			var height:=maxf(53,ceilf(float(str(item.text).length())/chars)*28+22)
			narrative=Control.new();narrative.position=Vector2(0,r.size.y-height);narrative.size=Vector2(r.size.x,height);narrative.mouse_filter=MOUSE_FILTER_IGNORE;container.add_child(narrative)
			_shade(narrative,Rect2(0,-36,r.size.x,height+36),.58)
			text=_label(narrative,str(item.text),Rect2(22,8,minf(r.size.x-44,880),height-12),20,INK,true);_text_shadow(text)
			text.set_meta("text_move_target",weakref(narrative))
		var entry:Dictionary={"node":container,"data":item,"image":image,"material":mat,"text":text,"narrative":narrative,"buttons":[],"index":i,"reveal_tween":null}
		panels.append(entry)
		if item.id=="21":_add_pencil(container,picture,mat,false,i)
		_add_hotspots(entry)
	_refresh_panels();curl.reset();back_curl.reset();_update_curl()

func _shade(parent:Node,r:Rect2,opacity:float)->void:
	var g:=Gradient.new();g.set_color(0,Color(0.02,.04,.07,0));g.set_color(1,Color(0.02,.04,.07,opacity))
	var tex:=GradientTexture2D.new();tex.gradient=g;tex.fill_from=Vector2(0,0);tex.fill_to=Vector2(0,1)
	var shade:=TextureRect.new();shade.texture=tex;shade.position=r.position;shade.size=r.size;shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;shade.mouse_filter=MOUSE_FILTER_IGNORE;parent.add_child(shade)

func _text_shadow(text:Label)->void:
	text.add_theme_color_override("font_shadow_color",Color(0,0,0,.8));text.add_theme_constant_override("shadow_offset_y",1)

func _next_index()->int:
	for i in range(panels.size()):
		if _flat(page_index,i)==frontier+1:return i
	return -1

func _blocked_by_glasses()->bool:
	return frontier>=5 and not done.has("take")

func _page_ready()->bool:
	return not panels.is_empty() and _flat(page_index,panels.size()-1)<=frontier and not _blocked_by_glasses() and not _blocked_by_equipment()

func _blocked_by_equipment()->bool:
	return page_index==3 and frontier>=12 and not (observations.get("helmet",false) and observations.get("suit",false) and observations.get("cooling",false))

func _refresh_panels()->void:
	var eligible:=_next_index()
	for entry in panels:
		var unlocked:=_flat(page_index,int(entry.index))<=frontier
		var next:=int(entry.index)==eligible and not _blocked_by_glasses()
		if entry.reveal_tween!=null and entry.reveal_tween.is_valid():entry.reveal_tween.kill()
		entry.material.set_shader_parameter("reveal",1.0 if unlocked else 0.0)
		entry.material.set_shader_parameter("eligible",1.0 if next else 0.0)
		entry.material.set_shader_parameter("rest",1.0)
		entry.narrative.visible=unlocked;entry.text.visible_characters=-1
		if entry.data.id=="06" and done.has("take"):entry.text.text="我接过了她的眼睛。"
		entry.node.focus_mode=FOCUS_ALL if next else FOCUS_NONE
		entry.node.mouse_default_cursor_shape=CURSOR_POINTING_HAND if next else CURSOR_ARROW
		if unlocked:panel_index=int(entry.index);active_label=entry.text
		for spot in entry.buttons:
			var enabled:bool=unlocked and not (spot.action=="take" and done.has("take"))
			spot.button.visible=enabled;spot.button.disabled=not enabled
	_update_curl()

func _update_curl()->void:
	if is_instance_valid(back_curl):back_curl.visible=visible and page_index>0 and modal==null and not transitioning and not page_turning and not intro_blocked
	if is_instance_valid(curl):curl.visible=visible and _page_ready() and page_index<data.pages.size()-1 and modal==null and not transitioning and not page_turning and not intro_blocked

func unlock(index:int,origin:=Vector2(.5,.5))->bool:
	if not visible or intro_blocked or transitioning or page_turning or modal!=null:return false
	if index<0 or index>=panels.size() or index!=_next_index() or _blocked_by_glasses():return false
	frontier+=1;panel_index=index;last_unlock_origin=origin
	_refresh_panels()
	var entry:Dictionary=panels[index]
	entry.material.set_shader_parameter("reveal_origin",origin)
	entry.material.set_shader_parameter("reveal",0.0)
	entry.reveal_tween=create_tween();entry.reveal_tween.tween_property(entry.material,"shader_parameter/reveal",1.0,.54)
	entry.narrative.modulate.a=0
	create_tween().tween_property(entry.narrative,"modulate:a",1.0,.30)
	_sfx("page");_save();get_viewport().gui_release_focus()
	return true

func _press_panel(index:int,origin:=Vector2(.5,.5))->void:
	# Revealing artwork and entering its interaction are separate gestures.
	# Read panels stay inert; only their visible circle can open a full-screen view.
	unlock(index,origin)

func advance()->void:
	if not visible or intro_blocked or transitioning or page_turning or modal!=null:return
	var next:=_next_index()
	if next>=0:unlock(next)
	elif _blocked_by_glasses():
		for entry in panels:
			for spot in entry.buttons:
				if spot.action=="take" and spot.button.visible:spot.button.grab_focus()
	elif _blocked_by_equipment():
		for entry in panels:
			for spot in entry.buttons:
				if spot.action=="equipment" and spot.button.visible:spot.button.grab_focus()
	elif _page_ready():
		if page_index<data.pages.size()-1:turn_page(1)
		else:activate("depart")

func previous()->void:
	if visible and not intro_blocked and not transitioning and not page_turning and modal==null and page_index>0:turn_page(-1)

func turn_page(direction:int)->void:
	if intro_blocked or transitioning or page_turning or modal!=null:return
	if direction>0 and (not _page_ready() or page_index>=data.pages.size()-1):return
	if direction<0 and page_index<=0:return
	page_turning=true;curl.hide();back_curl.hide();get_viewport().gui_release_focus()
	var token:=serial
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if token!=serial:return
	var snapshot:=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var layer:=TextureRect.new();layer.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;layer.texture=snapshot;layer.size=size;layer.mouse_filter=MOUSE_FILTER_STOP;layer.z_index=20
	var mat:=ShaderMaterial.new();mat.shader=TURN_SHADER;mat.set_shader_parameter("direction",float(direction));mat.set_shader_parameter("progress",0.0);layer.material=mat;add_child(layer)
	page_index+=direction;_build_page();curl.hide();back_curl.hide()
	var t:=create_tween();t.tween_method(func(v:float):mat.set_shader_parameter("progress",v),0.0,1.0,.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished
	if is_instance_valid(layer):layer.hide();layer.mouse_filter=MOUSE_FILTER_IGNORE;layer.queue_free()
	if token!=serial:return
	page_turning=false;_update_curl();_save()

func _source_point(image:TextureRect,point:Vector2)->Vector2:
	var region:Rect2=image.get_meta("source_region")
	var source_size:Vector2=image.get_meta("source_size")
	return image.position+(point*source_size-region.position)/region.size*image.size

func _add_hotspots(entry:Dictionary)->void:
	var action:=str(entry.data.get("action",""))
	if action.is_empty():return
	var points:Dictionary={"take":Vector2(.54,.49),"cabinet":Vector2(.52,.49),"equipment":Vector2(.42,.64),"pencil":Vector2(.65,.38),"depart":Vector2(.68,.67)}
	var key:=action
	var point:Vector2=points[action]
	var center:=_source_point(entry.image,point)
	if key=="pencil":center=Vector2(entry.node.size.x*.64,entry.node.size.y*.38)
	center.x=clampf(center.x,24,entry.node.size.x-24);center.y=clampf(center.y,24,entry.node.size.y-24)
	var button:=Hotspot.new();button.position=center-Vector2(20,20);button.accessibility_name={"take":"接过眼镜","cabinet":"观察眼镜","equipment":"观察太空服","pencil":"仔细看看铅笔","depart":"带上她的眼睛启程"}[key]
	button.pressed.connect(func():activate(key));entry.node.add_child(button)
	entry.buttons.append({"button":button,"action":key})

func activate(action:String)->void:
	if not visible or intro_blocked or transitioning or page_turning or modal!=null:return
	var entry:Dictionary={}
	for p in panels:
		if _flat(page_index,int(p.index))>frontier:continue
		for spot in p.buttons:
			if spot.action==action and spot.button.visible and not spot.button.disabled:entry=p;break
	if entry.is_empty():return
	match action:
		"take":
			_open_sensor_introduction("glasses")
		"depart":
			done.depart=true;_depart(false);return
		_:
			_inspect(action,entry.data)
	_save()

func _add_pencil(parent:Node,area:Rect2,material:ShaderMaterial,large:bool,index:int)->void:
	var sprite:=TextureRect.new();sprite.texture=load(ART+"pencil.png");sprite.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;sprite.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size=Vector2(area.size.x*.56,area.size.x*.28);sprite.position=area.position+Vector2(area.size.x*.38,area.size.y*.25);sprite.pivot_offset=sprite.size/2;sprite.mouse_filter=MOUSE_FILTER_IGNORE
	if material:sprite.material=material
	parent.add_child(sprite);pencil_views.append({"node":sprite,"base":sprite.position,"large":large,"index":index})

func _modal_shell()->void:
	modal=Control.new();modal.size=size;modal.mouse_filter=MOUSE_FILTER_STOP;modal.z_index=30;add_child(modal)
	curl.hide();modal.gui_input.connect(_modal_pointer)

func _inspect(action:String,source_data:Dictionary={})->void:
	if action in ["cabinet","equipment"]:
		_open_sensor_introduction("glasses" if action=="cabinet" else "equipment");return
	_modal_shell();modal_kind=action;modal_scan=false;scan_point=Vector2(-1000,-1000);clue_glow=0
	pencil_impulse=0;pencil_turn=0
	var tex:=_source("21" if action=="pencil" else "05" if action=="cabinet" else "13")
	var focus:=Vector2(.5,.36) if action=="pencil" else Vector2(.5,.52)
	var clean_bounds:=Rect2()
	if action=="cabinet" and source_data.has("source_bounds"):
		var b:Array=source_data.source_bounds;clean_bounds=Rect2(b[0],b[1],b[2],b[3])
	modal_photo=_image(modal,tex,Rect2(0,0,1280,720),focus,clean_bounds)
	observation_material=ShaderMaterial.new();observation_material.shader=OBSERVE_SHADER;modal_photo.material=observation_material
	if action=="pencil":
		_add_pencil(modal,Rect2(0,0,1280,720),null,true,-1)
		var touch:=Hotspot.new();touch.position=Vector2(850,350)-Vector2(20,20);touch.accessibility_name="轻触漂浮的铅笔";touch.pressed.connect(_touch_pencil);modal.add_child(touch)
	elif action=="equipment":
		_add_clue("helmet",Vector2(.78,.42))
		_add_clue("suit",Vector2(.26,.50))
		_add_clue("cooling",Vector2(.42,.66))
	if action=="equipment":
		scan_lens=Hotspot.new();scan_lens.radius=42;scan_lens.disabled=true;scan_lens.mouse_filter=MOUSE_FILTER_IGNORE;scan_lens.focus_mode=FOCUS_NONE;modal.add_child(scan_lens);scan_lens.hide()
	_shade(modal,Rect2(0,505,1280,215),.77)
	var initial:Dictionary={"pencil":"它没有落下。轻轻碰一碰它。","cabinet":"这些“眼睛”，正等待着下一位旅伴。","equipment":"沿着服装慢慢移动视线，看看这些反常的细节。"}
	modal_body=_label(modal,initial.get(action,"仔细看看。"),Rect2(48,582,1060,82) if action=="cabinet" else Rect2(46,608,1090,90),21,INK,true);_text_shadow(modal_body)
	var close:=_button(modal,"继续" if action=="cabinet" else "收回视线",Rect2(1100,655,140,40),_advance_cabinet_intro if action=="cabinet" else _close_modal,16);close.add_theme_color_override("font_color",Color(.86,.92,.92,.8))
	if action=="cabinet":cabinet_continue=close;_start_cabinet_intro()
	get_viewport().gui_release_focus()

func _open_sensor_introduction(mode:String)->void:
	if not is_instance_valid(sensor_introduction):
		sensor_introduction=SensorIntroduction.new();sensor_introduction.name="SensorIntroduction";sensor_introduction.z_index=30;add_child(sensor_introduction)
		sensor_introduction.state_changed.connect(_sensor_state_changed)
		sensor_introduction.wear_covered.connect(_sensor_wear_covered)
		sensor_introduction.closed.connect(_close_modal)
	modal=sensor_introduction;modal_kind="sensor_glasses" if mode=="glasses" else "sensor_equipment"
	curl.hide();back_curl.hide();get_viewport().gui_release_focus()
	sensor_introduction.begin(mode,{"helmet":observations.get("helmet",false),"fabric":observations.get("suit",false),"cooling":observations.get("cooling",false)})

func _sensor_state_changed(state:Dictionary)->void:
	for pair in [["helmet","helmet"],["fabric","suit"],["cooling","cooling"]]:
		if state.get(pair[0],false):observations[pair[1]]=true
	_refresh_panels();_save()

func _sensor_wear_covered()->void:
	var first_take:=not done.has("take")
	done.take=true;observations.cabinet=true;observations.cabinet_intro=true;observations.sensor_interactive=true
	# The interactive selection replaces redundant panel 06; reveal the next page only
	# while both eyelids cover the screen. No receiving-view demonstration is added.
	if first_take and page_index<=1:
		frontier=maxi(frontier,5);page_index=2;_build_page(true)
	else:_refresh_panels()
	_save()

func _start_cabinet_intro()->void:
	cabinet_paragraphs.clear()
	var intro:Dictionary=data.get("sensor_glasses_intro",{})
	for paragraph in intro.get("paragraphs",[]):cabinet_paragraphs.append(str(paragraph))
	if cabinet_paragraphs.is_empty():cabinet_paragraphs.append("传感眼镜，能把我看到的景象传给远方戴着同样设备的人。")
	var heading:=_label(modal,str(intro.get("title","传感眼镜")),Rect2(48,550,600,24),14,Color(.8,.88,.93,.8));_text_shadow(heading)
	cabinet_counter=_label(modal,"",Rect2(48,681,70,22),12,Color(.86,.92,.92,.62))
	cabinet_hint=_label(modal,"",Rect2(128,681,600,22),12,Color(.86,.92,.92,.5))
	_show_cabinet_paragraph(0)

func _show_cabinet_paragraph(index:int)->void:
	cabinet_paragraph_index=clampi(index,0,cabinet_paragraphs.size()-1);cabinet_reveal=0
	modal_body.text=cabinet_paragraphs[cabinet_paragraph_index];modal_body.visible_characters=0
	cabinet_counter.text="%d / %d"%[cabinet_paragraph_index+1,cabinet_paragraphs.size()]
	_refresh_cabinet_controls()

func _refresh_cabinet_controls()->void:
	if modal_kind!="cabinet" or cabinet_continue==null:return
	var last:bool=cabinet_paragraph_index==cabinet_paragraphs.size()-1
	var revealed:bool=modal_body.visible_characters<0 or modal_body.visible_characters>=modal_body.text.length()
	cabinet_continue.text="收回视线" if last and revealed else "继续  ›"
	cabinet_hint.text="轻点收回视线" if last and revealed else "轻点或按空格继续"

func _advance_cabinet_intro()->void:
	if modal_kind!="cabinet" or modal_body==null:return
	var length:=modal_body.text.length()
	if modal_body.visible_characters>=0 and modal_body.visible_characters<length:
		modal_body.visible_characters=-1;cabinet_reveal=float(length);_refresh_cabinet_controls();return
	if cabinet_paragraph_index<cabinet_paragraphs.size()-1:_show_cabinet_paragraph(cabinet_paragraph_index+1)
	else:
		observations.cabinet=true;observations.cabinet_intro=true;_save();_close_modal()

func _add_clue(key:String,source_uv:Vector2)->void:
	var point:=_source_point(modal_photo,source_uv)
	point.x=clampf(point.x,35,1245);point.y=clampf(point.y,50,555)
	var marker:=Hotspot.new();marker.position=point-Vector2(20,20);marker.accessibility_name="观察"+key
	marker.completed=observations.has(key) if key!="cabinet" else false
	marker.pressed.connect(func():_discover(key,point));modal.add_child(marker)
	clue_points.append({"key":key,"point":point,"button":marker})

func _modal_pointer(event:InputEvent)->void:
	if modal==null:return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:_close_modal();get_viewport().set_input_as_handled();return
		if event.button_index==MOUSE_BUTTON_LEFT:
			if modal_kind=="cabinet" and event.pressed:_advance_cabinet_intro()
			elif modal_kind=="pencil" and event.pressed:
				if Rect2(450,180,730,310).has_point(event.position):_touch_pencil()
				else:_close_modal()
			elif modal_kind=="equipment":
				modal_scan=event.pressed
				if modal_scan:_scan(event.position)
				elif is_instance_valid(scan_lens):scan_lens.hide()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and modal_scan:
		_scan(event.position);get_viewport().set_input_as_handled()

func _scan(point:Vector2)->void:
	if observation_material==null:return
	scan_point=point;observation_material.set_shader_parameter("scan_point",point);observation_material.set_shader_parameter("scan_strength",1.0)
	if is_instance_valid(scan_lens):scan_lens.position=point-Vector2(20,20);scan_lens.show()
	for clue in clue_points:
		if point.distance_to(clue.point)<74:_discover(str(clue.key),clue.point);break

func _discover(key:String,point:Vector2)->void:
	if modal==null:return
	if modal_kind=="cabinet":return
	var descriptions:Dictionary={"helmet":"头盔的面罩上，看不到常见的强光防护。","suit":"服装上，也没有我熟悉的防辐射系统。","cooling":"隔热和冷却系统，却异常发达。","cabinet":"我看到的风景，能通过它传递给远方的她。"}
	observations[key]=true
	for clue in clue_points:
		if clue.key==key:clue.button.completed=true
	modal_body.text=descriptions[key]
	observation_material.set_shader_parameter("clue_point",point);clue_glow=1.0
	if key!="cabinet" and observations.has("helmet") and observations.has("suit") and observations.has("cooling"):
		modal_body.text+="\n这些反常之处，让我记住了这套服装。"
	_save()

func _touch_pencil()->void:
	if modal==null:return
	pencil_impulse=1.0;pencil_turn+=PI;observations.pencil=true
	modal_body.text="铅笔轻轻转了半圈，仍然没有落下。";_save()

func _close_modal(refocus:=true)->void:
	if modal!=null:
		if modal==sensor_introduction:sensor_introduction.halt()
		else:modal.queue_free()
	modal=null;modal_photo=null;modal_body=null;modal_kind="";modal_scan=false;observation_material=null;scan_lens=null;clue_points.clear()
	cabinet_paragraphs.clear();cabinet_paragraph_index=0;cabinet_reveal=0;cabinet_counter=null;cabinet_hint=null;cabinet_continue=null
	pencil_views=pencil_views.filter(func(p):return not p.large)
	if refocus:get_viewport().gui_release_focus()
	_update_curl()

func _pause_menu()->void:
	_modal_shell();modal_kind="pause";_rect(modal,Rect2(0,0,1280,720),Color(.03,.06,.09,.97))
	_label(modal,"暂停阅读",Rect2(460,130,360,55),30,INK,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_button(modal,"继续阅读",Rect2(460,225,360,52),_close_modal,23)
	var audio_button:=_button(modal,"整体音量",Rect2(460,300,360,52),func():pass,21)
	audio_button.pressed.connect(AudioSettings.open_panel)
	_button(modal,"从头阅读",Rect2(460,375,360,52),func():_close_modal(false);begin(true),21)
	_button(modal,"直接前往草原",Rect2(460,450,360,52),func():_close_modal(false);_ask_skip(),21)
	get_viewport().gui_release_focus()

func _ask_skip()->void:
	if modal!=null or transitioning:return
	_modal_shell();modal_kind="pause";_rect(modal,Rect2(0,0,1280,720),Color(.03,.06,.09,.97))
	_label(modal,"现在前往草原？",Rect2(430,230,500,70),28,INK,true)
	_label(modal,"序章的阅读进度会保留。",Rect2(430,310,500,45),20,INK,true)
	_button(modal,"继续阅读",Rect2(350,415,250,60),_close_modal,23)
	_button(modal,"前往草原",Rect2(690,415,250,60),func():_close_modal(false);_depart(true),23)

func _depart(skipped:bool)->void:
	if transitioning or page_turning:return
	transitioning=true;curl.hide();back_curl.hide();get_viewport().gui_release_focus();_save(not skipped)
	var token:=serial
	_cancel_audio_tweens();ambience_name=""
	for player in [ambience,ambience_old]:
		var fade:=create_tween();audio_tweens.append(fade);fade.tween_property(player,"volume_db",-60.0,.7);fade.tween_callback(player.stop)
	var shown:bool=await ChapterTransition.play(2,self,_prepare_grassland_chapter.bind(token))
	if not shown or token!=serial:return
	hide();arrival_revealed.emit()
	var quiet:=create_tween();audio_tweens.append(quiet);quiet.tween_property(transition_audio,"volume_db",-60.0,1.4);quiet.tween_callback(transition_audio.stop)

func _prepare_grassland_chapter(token:int)->void:
	if token!=serial:return
	page_root.hide();paper.hide();finished.emit()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if token!=serial:return
	ChapterTransition.destination_ready(self)

func _chapter_title_leaving(number:int)->void:
	if number!=2 or not ChapterTransition.belongs_to(self) or muted:return
	transition_audio.stream=Mix.stream(ART+"audio/wind-minimax.wav");transition_audio.volume_db=-60;transition_audio.play()
	var rise:=create_tween();audio_tweens.append(rise);rise.tween_property(transition_audio,"volume_db",-11.0,.55)

func _ambient(name:String)->void:
	var selected:="wind-minimax" if name=="wind" else "room-minimax"
	if selected==ambience_name and ambience.playing:return
	_cancel_audio_tweens();ambience_name=selected
	var swap:=ambience_old;ambience_old=ambience;ambience=swap;ambience.stop()
	var stream:AudioStreamWAV=Mix.stream(ART+"audio/"+selected+".wav")
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD;stream.loop_begin=0;stream.loop_end=int(round(stream.get_length()*stream.mix_rate))
	ambience.stream=stream;ambience.volume_db=-60;ambience.play()
	var rise:=create_tween();rise.tween_property(ambience,"volume_db",-60.0 if muted else -25.0,1.0)
	var fall:=create_tween();fall.tween_property(ambience_old,"volume_db",-60.0,.7);fall.tween_callback(ambience_old.stop)
	audio_tweens.assign([rise,fall])

func _cancel_audio_tweens()->void:
	for t in audio_tweens:
		if t.is_valid():t.kill()
	audio_tweens.clear()

func _set_sound_levels()->void:
	_cancel_audio_tweens();ambience.volume_db=-60 if muted else -25;ambience_old.volume_db=-60;transition_audio.volume_db=-60 if muted else -7
	for p in effects:p.volume_db=-60 if muted else -8

func _toggle_sound()->void:
	AudioSettings.toggle_mute()

func _sfx(name:String)->void:
	if muted or name!="page":return
	for effect in effects:
		if not effect.playing:effect.stream=Mix.stream(ART+"audio/page-minimax.wav");effect.play();return

func _process(delta:float)->void:
	if not visible:return
	clock+=delta
	if modal_kind=="cabinet" and is_instance_valid(modal_body) and modal_body.visible_characters>=0:
		cabinet_reveal+=delta*preload("res://scripts/reading_pace.gd").CHARACTERS_PER_SECOND
		modal_body.visible_characters=mini(floori(cabinet_reveal),modal_body.text.length());_refresh_cabinet_controls()
	var next:=_next_index()
	for entry in panels:
		var hovered:bool=int(entry.index)==next and (entry.node.get_global_rect().has_point(get_global_mouse_position()) or entry.node.has_focus())
		entry.material.set_shader_parameter("hovered",1.0 if hovered and not _blocked_by_glasses() else 0.0)
	pencil_impulse=move_toward(pencil_impulse,0.0,delta*.45)
	for p in pencil_views:
		if not is_instance_valid(p.node):continue
		if not p.large and _flat(page_index,int(p.index))>frontier:continue
		var movement:=Vector2(sin(clock*.37)*4,sin(clock*.65)*6)
		if p.large:
			movement+=Vector2(sin(clock*2.0)*pencil_impulse*27,-pencil_impulse*22)
			p.node.rotation=lerp_angle(p.node.rotation,pencil_turn+sin(clock*.34)*.055,minf(delta*1.6,1))
		else:p.node.rotation=sin(clock*.34)*.055
		p.node.position=p.base+movement
	if observation_material!=null:
		clue_glow=move_toward(clue_glow,0.0,delta*.18);observation_material.set_shader_parameter("clue_glow",clue_glow)
	_update_curl()

func _focus_candidates()->Array[Control]:
	var candidates:Array[Control]=[]
	if modal!=null:
		for child in modal.get_children():
			if child is Button and child.visible and not child.disabled:candidates.append(child)
	else:
		var next:=_next_index()
		if next>=0 and not _blocked_by_glasses():candidates.append(panels[next].node)
		for entry in panels:
			for spot in entry.buttons:
				if spot.button.visible and not spot.button.disabled:candidates.append(spot.button)
		if curl.visible:candidates.append(curl)
		if back_curl.visible:candidates.append(back_curl)
	return candidates

func _input(event:InputEvent)->void:
	if not visible:return
	if is_instance_valid(sensor_introduction) and modal==sensor_introduction:return
	if intro_blocked or transitioning or page_turning:
		if event is InputEventKey or event is InputEventMouseButton:get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_TAB:
			var candidates:=_focus_candidates()
			if not candidates.is_empty():
				var current:=candidates.find(get_viewport().gui_get_focus_owner())
				var index:=posmod(current+(-1 if event.shift_pressed else 1),candidates.size()) if current>=0 else candidates.size()-1 if event.shift_pressed else 0
				candidates[index].grab_focus()
			else:get_viewport().gui_release_focus()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_F,KEY_F11]:fullscreen_requested.emit();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_ESCAPE:
			if modal!=null:_close_modal()
			else:_pause_menu()
			get_viewport().set_input_as_handled()
		elif modal_kind=="cabinet" and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_RIGHT]:
			_advance_cabinet_intro();get_viewport().set_input_as_handled()
		elif modal_kind=="cabinet" and event.physical_keycode==KEY_LEFT:
			_show_cabinet_paragraph(cabinet_paragraph_index-1);get_viewport().set_input_as_handled()
		elif event.physical_keycode in [KEY_SPACE,KEY_ENTER] and modal!=null and get_viewport().gui_get_focus_owner()==null:
			_close_modal();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_M:_toggle_sound();get_viewport().set_input_as_handled()

func _unhandled_input(event:InputEvent)->void:
	if not visible or intro_blocked or transitioning or page_turning or modal!=null:return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_RIGHT]:advance();get_viewport().set_input_as_handled()
		elif event.physical_keycode==KEY_LEFT:previous();get_viewport().set_input_as_handled()
