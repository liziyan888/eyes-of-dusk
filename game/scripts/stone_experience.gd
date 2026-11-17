extends Control
## The tired narrator hangs the glasses on a branch before going to sleep.
signal finished
signal cancelled
const Hotspot=preload("res://scripts/comic_hotspot.gd")
const Pair=preload("res://scripts/subtitle_pair.gd")
const ViewShader=preload("res://shaders/stone_glasses_view.gdshader")
var game:Node
var phase:=""
var serial:=0
var holding:=false
var guided:=false
var press_time:=0.0
var elevation:=0.0
var clock:=0.0
var debug_blocked:=false
var fast_mode:=false
var context:Dictionary={}
var marker:Button
var label:Label
var subtitles:Control
var view:TextureRect
var view_material:ShaderMaterial
var veil:ColorRect
var tweens:Array[Tween]=[]
var modal_paused:=false

func _ready()->void:
	size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_STOP
	view=TextureRect.new();view.size=size;view.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;view.mouse_filter=MOUSE_FILTER_IGNORE;view_material=ShaderMaterial.new();view_material.shader=ViewShader;view.material=view_material;add_child(view);view.hide()
	subtitles=Pair.new();add_child(subtitles)
	marker=Hotspot.new();marker.name="BranchFixedCircle";marker.radius=11;add_child(marker);marker.button_down.connect(_button_down);marker.button_up.connect(_button_up)
	label=Label.new();label.mouse_filter=MOUSE_FILTER_IGNORE;label.size=Vector2(460,36);label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;Pair.Style.regular_font(label,17);add_child(label)
	veil=ColorRect.new();veil.size=size;veil.color=Color(.03,.05,.08,0);veil.mouse_filter=MOUSE_FILTER_IGNORE;veil.z_index=40;add_child(veil)
	hide()

func apply_subtitle_style(value:Dictionary)->void:subtitles.apply_style(value)
func duration(value:float)->float:return .035 if fast_mode else value
func _tween()->Tween:
	var t:=create_tween();tweens.append(t);return t

func begin(controller:Node)->void:
	serial+=1;var token:=serial;game=controller;phase="opening";clock=0;holding=false;guided=false;elevation=0;debug_blocked=false;modal_paused=false
	context={"camera_x":game.camera_x,"anchor":game.camera_anchor,"zoom":game.zoom,"actor":game.actor_canvas.visible,"markers":game.marker_canvas.visible,"buttons":[]}
	for child in game.ui.get_children():
		if child is Button:context.buttons.append([child,child.visible]);child.hide()
	game.playing=false;game.moving=false;game.pose="idle";game.action_override="";game.action_player.reset();game.sensor.stop_voice();game.sensor.hide();game.hint.hide();game.dialogue_panel.hide();game.debug_editor.hide();game.actor_canvas.hide();game.marker_canvas.hide()
	game.dialogue.clear();game.active_id="";view.hide();show();subtitles.hide();marker.hide();label.hide();veil.color.a=0;game.queue_redraw()
	var audio_visible:bool=AudioSettings.visible;AudioSettings.hide()
	await get_tree().process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		view.texture=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	else:view.texture=game.textures.psd_moon5_sky
	AudioSettings.visible=audio_visible
	if token!=serial:return
	show();subtitles.show();marker.hide();label.hide();veil.color.a=0;subtitles.apply_style(game.layout.subtitles())
	subtitles.set_lines("","我困得有些恼火。你倒像个十八世纪的多愁善感的诗人，一点也不像个宇航员。")
	var support:Vector2=game.glasses_support_position();var close_zoom:=2.3
	var anchor_y:float=(445.0-(support.y+game.layout.offset().y)*close_zoom)/(1.0-close_zoom)
	var t:=_tween().set_parallel(true)
	t.tween_property(game,"camera_x",support.x+game.layout.offset().x-640,duration(.65));t.tween_property(game,"camera_anchor",Vector2(640,anchor_y),duration(.65));t.tween_property(game,"zoom",close_zoom,duration(.65))
	await t.finished
	if token!=serial:return
	phase="place";_position_marker(game._screen(game.glasses_support_position()));_hint("把眼镜挂到枝上");marker.show();label.show()
	if bool(game.night.placement.get("placed",false)):_place()

func _position_marker(p:Vector2)->void:
	marker.position=p-marker.size*.5;label.position=p+Vector2(-230,34)

func _hint(text:String)->void:
	label.text=text;marker.accessibility_name=text

func _button_down()->void:
	if debug_blocked or AudioSettings.opened:return
	if phase=="place":_place()
	elif phase=="confirm":_finish()

func _button_up()->void:
	holding=false

func _place()->void:
	game.night.place(game,0.0);phase="confirm"
	subtitles.set_lines("","你自己看月亮吧。我真的得睡了，明天还要赶回航天中心。")
	_hint("回旅馆睡觉")

func _process(delta:float)->void:
	if not visible:return
	var paused:bool=debug_blocked or AudioSettings.opened
	if paused!=modal_paused:
		modal_paused=paused
		for t in tweens:
			if t.is_valid():
				if paused:t.pause()
				else:t.play()
	if paused:return
	clock+=delta

func _finish()->void:
	if phase!="confirm":return
	game.night.place(game,elevation);phase="closing";marker.hide();label.hide()
	var token:=serial;var t:=_tween();t.tween_property(veil,"color:a",1.0,duration(.22));await t.finished
	if token!=serial:return
	_restore_camera();view.hide();subtitles.set_lines("","")
	t=_tween();t.tween_property(veil,"color:a",0.0,duration(.45));await t.finished
	if token!=serial:return
	_restore_controls();hide();phase="";finished.emit()

func _restore_camera()->void:
	game.camera_x=context.camera_x;game.camera_anchor=context.anchor;game.zoom=context.zoom
	game.actor_canvas.visible=bool(context.actor);game.marker_canvas.visible=bool(context.markers);game.queue_redraw()

func _restore_controls()->void:
	for entry in context.buttons:
		if is_instance_valid(entry[0]):entry[0].visible=bool(entry[1])

func close()->void:
	serial+=1
	for t in tweens:
		if t.is_valid():t.kill()
	tweens.clear();holding=false;guided=false
	if visible and game!=null and not context.is_empty():_restore_camera();_restore_controls()
	hide();phase=""

func _input(event:InputEvent)->void:
	if not visible or debug_blocked or AudioSettings.opened:return
	if event is InputEventKey and not event.echo:
		if event.physical_keycode in [KEY_E,KEY_SPACE,KEY_ENTER]:
			if event.pressed:_button_down()
			else:_button_up()
			get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode==KEY_ESCAPE:
			close();cancelled.emit();get_viewport().set_input_as_handled()
		elif event.pressed and event.physical_keycode in [KEY_F,KEY_F11]:
			game._toggle_fullscreen();get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:_button_up()

func _notification(what:int)->void:
	if what==NOTIFICATION_WM_WINDOW_FOCUS_OUT:holding=false;guided=false
