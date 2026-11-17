extends Control
## Painted, non-video selection/inspection/blink and suit material interactions.
signal state_changed(state:Dictionary)
signal wear_covered
signal closed
const Point=preload("res://scripts/fixed_hold_point.gd")
const Observation=preload("res://shaders/sensor_observation.gdshader")
const Coolant=preload("res://shaders/sensor_coolant.gdshader")
const ART:="res://assets/sensor-introduction/"
const BASE:=Vector2(1280,720)
const GLASSES_POINT:=Vector2(.89,.82)*BASE
var entry_mode:=""
var scene:=""
var phase:="observe"
var selected_slot:=""
var worn:=false
var paused:=false
var clock:=0.0
var scene_clock:=0.0
var attention:=0.0
var effect_clock:=0.0
var wear_hold:=0.0
var holding:=""
var hold_input:=""
var covered:=false
var observed:Dictionary={"helmet":false,"fabric":false,"cooling":false}
var holds:Dictionary={"helmet":0.0,"fabric":0.0,"cooling":0.0}
var images:Dictionary={}
var glasses_observed:Dictionary={"lens":false,"sensor":false}
var glasses_holds:Dictionary={"lens":0.0,"sensor":0.0}
var points:Dictionary={}
var body:TextureRect
var material_fx:ShaderMaterial
var flow_root:Node2D
var flow_materials:Array[ShaderMaterial]=[]
var controls:Control
var director:Label
var thought:Label
var blink:Control
var menu:Control
var return_button:Button
var inspector_font:Font
var feedback_delay:=0.0
var audio_was_paused:=false

func _ready()->void:
	size=BASE;mouse_filter=MOUSE_FILTER_STOP;clip_contents=true
	inspector_font=WebSystemFont.new();inspector_font.font_names=PackedStringArray(["KaiTi","SimSun","Microsoft YaHei"])
	body=TextureRect.new();body.size=BASE;body.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;body.stretch_mode=TextureRect.STRETCH_SCALE;body.mouse_filter=MOUSE_FILTER_IGNORE;add_child(body)
	material_fx=ShaderMaterial.new();material_fx.shader=Observation;body.material=material_fx;_load_masks()
	flow_root=Node2D.new();add_child(flow_root);_make_coolant()
	director=_label(Rect2(74,60,690,105),24);thought=_label(Rect2(64,616,1000,85),24)
	thought.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	preload("res://scripts/dialogue_appearance.gd").attach(thought,"man")
	controls=Control.new();controls.size=BASE;controls.mouse_filter=MOUSE_FILTER_IGNORE;add_child(controls)
	return_button=_button(self,"收回视线",Rect2(1110,650,145,44),_request_close,17)
	blink=Control.new();blink.size=BASE;blink.mouse_filter=MOUSE_FILTER_IGNORE;add_child(blink);blink.draw.connect(_draw_blink)
	menu=Control.new();menu.size=BASE;menu.mouse_filter=MOUSE_FILTER_STOP;add_child(menu)
	var veil:=ColorRect.new();veil.size=BASE;veil.color=Color(.025,.045,.08,.88);veil.mouse_filter=MOUSE_FILTER_IGNORE;menu.add_child(veil)
	_button(menu,"继续",Rect2(450,238,380,55),func():set_paused(false),23)
	_button(menu,"整体音量",Rect2(450,310,380,55),_open_audio,21)
	_button(menu,"返回漫画",Rect2(450,382,380,55),_request_close,21)
	menu.hide();hide()
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null:audio.panel_toggled.connect(_audio_panel)

func _label(rect:Rect2,font_size:int)->Label:
	var node:=Label.new();node.position=rect.position;node.size=rect.size;node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;node.mouse_filter=MOUSE_FILTER_IGNORE
	node.add_theme_font_override("font",inspector_font);node.add_theme_font_size_override("font_size",font_size);node.add_theme_color_override("font_color",Color(.97,.98,.96));node.add_theme_color_override("font_shadow_color",Color(.025,.05,.1,.8));node.add_theme_constant_override("shadow_offset_y",1);add_child(node);return node

func _button(parent:Node,text:String,rect:Rect2,action:Callable,font_size:int)->Button:
	var button:=Button.new();button.position=rect.position;button.size=rect.size;button.text=text;button.add_theme_font_size_override("font_size",font_size)
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_color_override("font_color",Color(.94,.97,.98));button.add_theme_color_override("font_shadow_color",Color(.04,.08,.14,.8));button.add_theme_constant_override("shadow_offset_y",1)
	button.mouse_default_cursor_shape=CURSOR_POINTING_HAND;button.pressed.connect(action);parent.add_child(button);return button

func _load_masks()->void:
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ART+"effect-masks.json"))
	var coords:=PackedVector2Array();var counts:=Vector3i.ZERO
	for i in range(3):
		var shape:Array=data.helmetLeds[i];counts[i]=shape.size()
		for p in shape:coords.append(Vector2(float(p[0])/1280.0,float(p[1])/720.0))
	coords.resize(64);material_fx.set_shader_parameter("led_points",coords);material_fx.set_shader_parameter("led_sizes",counts)

func _tube_point(side:int,t:float)->Vector2:
	var p:Array=[Vector2(408,421),Vector2(304,452),Vector2(247,542),Vector2(228,641)] if side==0 else [Vector2(871,421),Vector2(977,452),Vector2(1033,542),Vector2(1047,641)]
	var u:=1.0-t
	return p[0]*u*u*u+p[1]*3*u*u*t+p[2]*3*u*t*t+p[3]*t*t*t

func _make_coolant()->void:
	for side in range(2):
		var vertices:=PackedVector3Array();var uv:=PackedVector2Array();var indices:=PackedInt32Array()
		for i in range(41):
			var t:=float(i)/40.0;var p:=_tube_point(side,t)
			var tangent:=(_tube_point(side,minf(1,t+.01))-_tube_point(side,maxf(0,t-.01))).normalized();var normal:=Vector2(-tangent.y,tangent.x)*9
			vertices.append(Vector3(p.x-normal.x,p.y-normal.y,0));vertices.append(Vector3(p.x+normal.x,p.y+normal.y,0));uv.append(Vector2(t,0));uv.append(Vector2(t,1))
			if i<40:indices.append_array(PackedInt32Array([i*2,i*2+2,i*2+1,i*2+1,i*2+2,i*2+3]))
		var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uv;arrays[Mesh.ARRAY_INDEX]=indices
		var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var renderer:=MeshInstance2D.new();renderer.mesh=mesh
		var mat:=ShaderMaterial.new();mat.shader=Coolant;mat.set_shader_parameter("direction",1.0 if side==0 else -1.0);renderer.material=mat;flow_materials.append(mat);flow_root.add_child(renderer)

func _art(key:String)->Texture2D:
	if not images.has(key):
		var file:String={"cabinet":"cabinet.png","poster":"glasses-close.png","equipment":"equipment-flow.png","helmet":"helmet.png","fabric":"fabric.png","cooling":"cooling-flow.png"}[key]
		var texture:Texture2D=load(ART+file)
		if key=="cabinet":
			var cropped:=AtlasTexture.new();cropped.atlas=texture;cropped.region=Rect2(13,13,1646,914);texture=cropped
		images[key]=texture
	return images[key]

func begin(mode:String,saved:Dictionary={})->void:
	for key in observed:
		observed[key]=bool(saved.get(key,saved.get("suit",false) if key=="fabric" else observed[key]));holds[key]=1.0 if observed[key] else holds[key]
	show();paused=false;menu.hide();return_button.show()
	if mode=="equipment":entry_mode=mode;_enter("equipment")
	elif entry_mode!=mode or scene.is_empty() or worn:
		entry_mode=mode;selected_slot="";worn=false;phase="observe";_enter("cabinet")

func _clear_points()->void:
	_end_hold()
	for point in points.values():controls.remove_child(point);point.queue_free()
	points.clear()

func reset_flow()->void:
	halt();entry_mode="";scene="";worn=false;wear_hold=0;selected_slot=""
	observed={"helmet":false,"fabric":false,"cooling":false};holds={"helmet":0.0,"fabric":0.0,"cooling":0.0}
	glasses_observed={"lens":false,"sensor":false};glasses_holds={"lens":0.0,"sensor":0.0}

func _open_audio()->void:
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null:audio.open_panel()

func _point(key:String,center:Vector2,text:String,hold:=false)->Button:
	var button:=Point.new();button.position=center-Vector2(36,36);controls.add_child(button);button.set_hint(text);points[key]=button
	if hold:
		button.button_down.connect(func():_start_hold(key,"mouse"))
		button.button_up.connect(func():if hold_input=="mouse":_end_hold())
	else:button.pressed.connect(func():_activate(key))
	return button

func _enter(next:String)->void:
	_clear_points();scene=next;scene_clock=0;attention=0;material_fx.set_shader_parameter("attention",0.0);material_fx.set_shader_parameter("mode",0);material_fx.set_shader_parameter("flip_art",false)
	body.show();flow_root.hide();director.text="";thought.text="";return_button.show();blink.hide()
	if next=="cabinet":
		body.texture=_art("cabinet");director.text="主任：在外太空工作的人，很难回地球度假。挑一副“眼睛”，替他们看看。";thought.text="所谓“眼睛”，原来就是一副传感眼镜。"
		for i in range(3):_point("pick-"+str(i),Vector2([.285,.565,.855][i],.465)*BASE,"选这副眼镜")
	elif next=="glasses":
		body.texture=_art("poster");phase="observe";wear_hold=0;material_fx.set_shader_parameter("mode",3)
		director.text="主任：戴上它，你所见的风景，就能传到远方戴着同样眼镜的人那里。";thought.text="我接过这副传感眼镜，仔细看向镜片和传感部位。"
		for key in glasses_observed:
			var center:Vector2=Vector2(.47,.51)*BASE if key=="lens" else Vector2(.655,.415)*BASE
			var point:=_point("inspect-"+key,center,"按住，观察镜片" if key=="lens" else "按住，观察传感部位",true)
			point.progress=float(glasses_holds[key]);point.completed=glasses_observed[key]
		if glasses_observed.lens and glasses_observed.sensor:_finish_observe()
	elif next=="wearing":
		body.texture=_art("poster");return_button.hide();blink.show();covered=false;worn=true
	elif next=="equipment":
		body.texture=_art("equipment");thought.text="作为航天个人装备工程师，我注意到这套太空服很奇怪。"
		var targets:Dictionary={"helmet":Vector2(.735,.43),"fabric":Vector2(.525,.565),"cooling":Vector2(.385,.655)}
		for key in targets:
			var button:=_point(key,targets[key]*BASE,{"helmet":"看向头盔","fabric":"细看衣料","cooling":"留意温控装置"}[key]);button.completed=observed[key]
		if all_observed():thought.text="没有强光防护，没有熟悉的防辐射系统……隔热和冷却，却异常发达。"
	elif next in ["helmet","fabric","cooling"]:
		body.texture=_art(next);material_fx.set_shader_parameter("mode",1 if next=="helmet" else 2 if next=="fabric" else 0);material_fx.set_shader_parameter("flip_art",next=="fabric");flow_root.visible=next=="cooling"
		thought.text=_finding(next) if observed[next] else {"helmet":"灯光映在面罩边缘。我仔细辨认着这顶头盔的结构。","fabric":"光线掠过衣料，我留意着织物、袖口和接缝。","cooling":"冷却液沿着管路流动。这套温控系统格外醒目。"}[next]
		var center:Vector2={"helmet":Vector2(.83,.56),"fabric":Vector2(.81,.50),"cooling":Vector2(.86,.52)}[next]*BASE
		var button:=_point("attend",center,{"helmet":"按住，凝视头盔灯光","fabric":"按住，细看衣料反光","cooling":"按住，观察冷却液流动"}[next],true);button.progress=float(holds[next]);button.completed=observed[next]
		_point("back",Vector2(.925,.89)*BASE,"收回视线");return_button.hide()

func _activate(key:String)->void:
	if paused or feedback_delay>0:return
	if key.begins_with("pick-"):selected_slot=key;_enter("glasses")
	elif key in ["helmet","fabric","cooling"]:_enter(key)
	elif key=="back":_enter("equipment")

func _start_hold(key:String,input:String)->void:
	if paused or feedback_delay>0 or not visible:return
	_end_hold();holding=key;hold_input=input

func _end_hold()->void:
	holding="";hold_input=""

func _finish_observe()->void:
	if phase=="ready" or scene!="glasses":return
	phase="ready";_clear_points();director.text="主任：现在，连触觉和味觉，也能一起传过去。";thought.text="替远方的人带上一双眼睛，让他们也能分享这趟旅行。"
	_point("wear",GLASSES_POINT,"按住，戴上眼镜",true);feedback_delay=.18

func _finding(key:String)->String:
	return {"helmet":"头盔的面罩上，看不到常见的强光防护。","fabric":"服装上，也没有我熟悉的防辐射系统。","cooling":"隔热和冷却系统，却异常发达。"}[key]

func all_observed()->bool:return bool(observed.helmet) and bool(observed.fabric) and bool(observed.cooling)
func export_state()->Dictionary:return {"worn":worn,"selected_slot":selected_slot,"helmet":observed.helmet,"fabric":observed.fabric,"cooling":observed.cooling}

func _process(delta:float)->void:
	if not is_visible_in_tree() or paused:return
	clock+=delta;scene_clock+=delta;feedback_delay=maxf(0,feedback_delay-delta)
	if scene=="glasses":
		if phase=="observe":
			attention=move_toward(attention,1.0 if holding.begins_with("inspect-") else 0.0,delta*3.5);effect_clock+=delta
			material_fx.set_shader_parameter("attention",attention);material_fx.set_shader_parameter("effect_clock",effect_clock)
			if holding.begins_with("inspect-"):
				var key:=holding.trim_prefix("inspect-");material_fx.set_shader_parameter("glass_focus",1 if key=="lens" else 2)
				if not glasses_observed[key]:
					glasses_holds[key]=minf(1,float(glasses_holds[key])+delta/1.1);points[holding].progress=float(glasses_holds[key])
					if glasses_holds[key]>=1:
						glasses_observed[key]=true;points[holding].completed=true
						director.text="主任：镜片采集你看到的景象，由超高频信息波传向远方。" if key=="lens" else "主任：传感部位还能采集脑电波，把触觉和味觉也一同传出去。"
						thought.text="原来，我能替一个难以回到地球的人，带去这一路的风景。" if key=="lens" else "这样，她不仅能看见草原，也能感受到风、水和花的气息。"
						if glasses_observed.lens and glasses_observed.sensor:_finish_observe()
		elif phase=="ready":
			wear_hold=clampf(wear_hold+(delta/.82 if holding=="wear" else -delta*1.3),0,1);points.wear.progress=wear_hold
			if wear_hold>=1:_enter("wearing")
	elif scene=="wearing":
		if scene_clock>=.43 and not covered:
			covered=true;wear_covered.emit();body.hide()
		blink.queue_redraw()
		if scene_clock>=1.2:closed.emit()
	elif scene in ["helmet","fabric","cooling"]:
		attention=lerpf(attention,1.0 if holding=="attend" else 0.0,1.0-exp(-delta*(5.5 if holding=="attend" else 3.5)))
		effect_clock+=delta*(1.0 if holding=="attend" else .25)
		material_fx.set_shader_parameter("attention",attention);material_fx.set_shader_parameter("effect_clock",effect_clock)
		for mat in flow_materials:mat.set_shader_parameter("attention",attention);mat.set_shader_parameter("effect_clock",effect_clock)
		if holding=="attend" and not observed[scene]:
			holds[scene]=minf(1,float(holds[scene])+delta/1.25);points.attend.progress=float(holds[scene])
			if float(holds[scene])>=1:observed[scene]=true;points.attend.completed=true;thought.text=_finding(scene);state_changed.emit(export_state())

func _draw_blink()->void:
	if scene!="wearing":return
	var closure:=smoothstep(0,.38,scene_clock) if scene_clock<.38 else 1.0 if scene_clock<.66 else 1.0-smoothstep(.66,1.16,scene_clock)
	# Extend the offscreen polygon edge so the curved lid cannot cross it near
	# fully open. Keeping this simple avoids self-intersecting triangulation.
	var reach:=closure*412.0;var upper:=PackedVector2Array([Vector2(0,-100),Vector2(1280,-100)]);var lower:=PackedVector2Array([Vector2(0,820),Vector2(1280,820)])
	for i in range(41):
		var x:=1280.0*(1.0-float(i)/40.0);var curve:=sin(x/1280.0*PI)*32
		upper.append(Vector2(x,reach-28+curve));lower.append(Vector2(x,720-reach+28-curve))
	blink.draw_colored_polygon(upper,Color(.031,.055,.09));blink.draw_colored_polygon(lower,Color(.031,.055,.09))

func set_paused(value:bool)->void:
	paused=value;_end_hold();menu.visible=value
	if value:menu.get_child(1).grab_focus()

func halt()->void:
	_end_hold();hide();menu.hide()

func _request_close()->void:
	if scene=="wearing":return
	_end_hold();state_changed.emit(export_state());closed.emit()

func _audio_panel(opened:bool)->void:
	if not is_visible_in_tree():return
	if opened:audio_was_paused=paused;set_paused(true)
	elif not audio_was_paused:set_paused(false)

func _focus_controls()->Array[Control]:
	var result:Array[Control]=[]
	if paused:
		for child in menu.get_children():
			if child is Button and child.visible:result.append(child)
	else:
		for point in points.values():result.append(point)
		if return_button.visible:result.append(return_button)
	return result

func _input(event:InputEvent)->void:
	if not is_visible_in_tree():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and hold_input=="mouse":_end_hold()
	if not event is InputEventKey or event.echo:return
	var code:int=event.physical_keycode
	if code==KEY_ESCAPE and event.pressed:
		if scene!="wearing":set_paused(not paused)
		get_viewport().set_input_as_handled();return
	if code==KEY_TAB and event.pressed:
		var candidates:=_focus_controls()
		if not candidates.is_empty():
			var at:=candidates.find(get_viewport().gui_get_focus_owner());candidates[posmod(at+(-1 if event.shift_pressed else 1),candidates.size())].grab_focus()
		get_viewport().set_input_as_handled();return
	if code in [KEY_SPACE,KEY_ENTER,KEY_E] and not paused:
		var inspect:="inspect-lens" if not glasses_observed.lens else "inspect-sensor"
		var key:=inspect if scene=="glasses" and phase=="observe" else "wear" if scene=="glasses" and phase=="ready" else "attend" if scene in ["helmet","fabric","cooling"] else ""
		if not key.is_empty():
			if event.pressed:_start_hold(key,"keyboard")
			elif hold_input=="keyboard":_end_hold()
			get_viewport().set_input_as_handled()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT and is_visible_in_tree():_end_hold()
