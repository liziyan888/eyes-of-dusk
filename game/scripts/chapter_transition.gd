extends CanvasLayer
## One black cover owns the handoff; destinations prepare only after it is opaque.
signal completed(success:bool)
signal title_leaving(chapter_id:int)
var active:=false
var chapter_id:=0
var phase:="idle"
var phase_time:=0.0
var ready_for_reveal:=false
var fast_mode:=false
var config:Dictionary={}
var chapter_data:Dictionary={}
var owner_ref:WeakRef
var prepare_destination:Callable
var serial:=0
var ui:Control
var black:ColorRect
var title_motion:Control
var title_label:Label
var volume_button_was_visible:=false
var advance_released:=false

func _ready()->void:
	layer=900
	config=JSON.parse_string(FileAccess.get_file_as_string("res://data/chapters.json"))
	ui=Control.new();ui.name="ChapterCover";ui.size=Vector2(1280,720);ui.mouse_filter=Control.MOUSE_FILTER_STOP;ui.gui_input.connect(_cover_input);add_child(ui)
	black=ColorRect.new();black.name="Black";black.size=ui.size;black.color=Color.BLACK;black.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(black)
	title_motion=Control.new();title_motion.name="TitleMotion";title_motion.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(title_motion)
	title_label=Label.new();title_label.name="ChapterTitle";title_label.position=Vector2(0,291);title_label.size=Vector2(1280,80);title_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER;title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["SimSun","Noto Serif CJK SC","Microsoft YaHei"]);font.font_weight=400
	title_label.add_theme_font_override("font",font);title_label.add_theme_font_size_override("font_size",42);title_label.add_theme_color_override("font_color",Color("f1ede5"));title_label.add_theme_constant_override("outline_size",0);title_label.add_theme_color_override("font_shadow_color",Color.TRANSPARENT)
	title_motion.add_child(title_label);ui.hide()
	get_tree().node_added.connect(func(node:Node):
		if node.get_parent()==get_tree().root:_input_priority.call_deferred())
	_input_priority.call_deferred()

func _input_priority()->void:
	if is_inside_tree():get_tree().root.move_child(self,get_tree().root.get_child_count()-1)

func play(number:int,source:Node,prepare:Callable)->bool:
	if active or not config.chapters.has(str(number)):return false
	serial+=1;chapter_id=number;chapter_data=config.chapters[str(number)];owner_ref=weakref(source);prepare_destination=prepare
	active=true;ready_for_reveal=false;phase="fade_to_black";phase_time=0;advance_released=false
	black.color.a=0;title_motion.modulate.a=0;title_motion.position=Vector2(0,4)
	title_label.set_meta("text_scope","chapter-"+str(number));title_label.text=str(chapter_data.title)
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null:studio.sync_node(title_label)
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null:volume_button_was_visible=audio.toggle_button.visible;audio.toggle_button.hide()
	get_viewport().gui_release_focus();ui.show()
	var success:bool=await completed
	return success

func belongs_to(source:Node)->bool:
	return active and owner_ref!=null and owner_ref.get_ref()==source

func destination_ready(source:Node)->void:
	if belongs_to(source):ready_for_reveal=true

func cancel(source:Node=null)->void:
	if active and (source==null or belongs_to(source)):_finish(false)

func _finish(success:bool)->void:
	if not active:return
	active=false;phase="idle";ui.hide();prepare_destination=Callable();owner_ref=null
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null:audio.toggle_button.visible=volume_button_was_visible
	get_viewport().gui_release_focus();completed.emit(success)

func _duration(key:String)->float:
	var value:=float(config.get(key,.5))
	if key=="title_hold":value+=float(chapter_data.get("extra_hold",0))
	return value*(.08 if fast_mode else 1.0)

func _set_phase(value:String)->void:
	phase=value;phase_time=0
	if value=="title_out":title_leaving.emit(chapter_id)

func _process(delta:float)->void:
	if not active:return
	var source:Node=owner_ref.get_ref() if owner_ref!=null else null
	if not is_instance_valid(source) or not source.is_inside_tree():_finish(false);return
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null and audio.opened:return
	for action in ["move_left","move_right","slow_walk","interact","advance"]:
		if InputMap.has_action(action):Input.action_release(action)
	phase_time+=delta
	var t:=clampf(phase_time/_duration(phase),0,1)
	var eased:=t*t*(3.0-2.0*t)
	match phase:
		"fade_to_black":
			black.color.a=eased
			if t>=1:
				_set_phase("black_settle")
				if prepare_destination.is_valid():prepare_destination.call()
				else:cancel()
		"black_settle":
			if t>=1:_set_phase("title_in")
		"title_in":
			title_motion.modulate.a=eased;title_motion.position.y=4*(1-eased)
			if t>=1:_set_phase("title_hold")
		"title_hold":
			if t>=1:_set_phase("title_out")
		"title_out":
			title_motion.modulate.a=1-eased
			if t>=1:_set_phase("reveal" if ready_for_reveal else "waiting_for_destination")
		"waiting_for_destination":
			if ready_for_reveal:_set_phase("reveal")
		"reveal":
			black.color.a=1-eased
			if t>=1:_finish(true)

func _try_skip()->void:
	if advance_released and phase=="title_hold" and phase_time>=minf(.2,_duration("title_hold")*.5):_set_phase("title_out")

func _cover_input(event:InputEvent)->void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:_try_skip()
		else:advance_released=true
	ui.accept_event()

func _input(event:InputEvent)->void:
	if not active:return
	if event is InputEventKey:
		if event.physical_keycode==KEY_ESCAPE:return
		if event.physical_keycode in [KEY_F10,KEY_M]:return
		if event.physical_keycode==KEY_F2 and event.pressed and not event.echo:
			get_node("/root/TextStudio").open_editor();get_viewport().set_input_as_handled();return
		if event.physical_keycode in [KEY_F,KEY_F11] and event.pressed and not event.echo:
			get_window().mode=Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_EXCLUSIVE_FULLSCREEN
			get_viewport().set_input_as_handled();return
		if event.physical_keycode in [KEY_SPACE,KEY_ENTER]:
			if not event.pressed:advance_released=true
			elif not event.echo:_try_skip()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed:_try_skip()
			else:advance_released=true
		get_viewport().set_input_as_handled()

func _exit_tree()->void:
	if active:active=false;completed.emit(false)
