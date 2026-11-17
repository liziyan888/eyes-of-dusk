extends CanvasLayer
## One master control across the cover, both comics, vignettes and walkable world.
signal panel_toggled(opened:bool)
signal volume_changed(value:float,muted:bool)
var volume:=.8
var muted:=false
var opened:=false
var settings_path:="user://audio-settings-v1.cfg"
var no_save:=false
var dirty:=false
var save_serial:=0
var root_ui:Control
var toggle_button:Button
var gate:Control
var panel:Panel
var slider:HSlider
var number:Label
var mute_button:CheckButton
var close_button:Button
var blocked:Array[Dictionary]=[]
var syncing:=false

func _ready()->void:
	layer=1000;process_mode=Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg=="--no-audio-settings-save":no_save=true
		if arg.begins_with("--audio-settings-path="):settings_path=arg.trim_prefix("--audio-settings-path=")
	for name in ["Music","Ambience","Effects","Voice"]:
		if AudioServer.get_bus_index(name)<0:
			AudioServer.add_bus();var i:=AudioServer.bus_count-1;AudioServer.set_bus_name(i,name);AudioServer.set_bus_send(i,"Master")
	var limiter:=AudioEffectLimiter.new();limiter.ceiling_db=-1.0
	AudioServer.add_bus_effect(0,limiter)
	var saved:=ConfigFile.new()
	if not no_save and saved.load(settings_path)==OK:
		var value:Variant=saved.get_value("audio","master",.8)
		if (value is float or value is int) and is_finite(float(value)):volume=clampf(float(value),0,1)
		muted=bool(saved.get_value("audio","muted",false))
	_make_ui();_apply();get_tree().node_added.connect(_node_added);_make_input_priority.call_deferred()

func _make_ui()->void:
	root_ui=Control.new();root_ui.size=Vector2(1280,720);root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(root_ui)
	toggle_button=Button.new();toggle_button.name="MasterVolume";toggle_button.text="音量";toggle_button.tooltip_text="整体音量 · F10";toggle_button.position=Vector2(1210,72);toggle_button.size=Vector2(54,28)
	for key in ["normal","hover","pressed","focus"]:toggle_button.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	toggle_button.add_theme_font_size_override("font_size",13);toggle_button.add_theme_color_override("font_color",Color(1,1,.97,.52));toggle_button.add_theme_color_override("font_hover_color",Color.WHITE)
	toggle_button.pressed.connect(toggle_panel);root_ui.add_child(toggle_button)
	gate=Control.new();gate.name="VolumeOverlay";gate.size=Vector2(1280,720);gate.mouse_filter=Control.MOUSE_FILTER_STOP;root_ui.add_child(gate);gate.hide()
	gate.gui_input.connect(func(event:InputEvent):
		if event is InputEventMouseButton and event.pressed and not panel.get_global_rect().has_point(event.position):close_panel();gate.accept_event())
	panel=Panel.new();panel.position=Vector2(930,110);panel.size=Vector2(330,174)
	var glass:=StyleBoxFlat.new();glass.bg_color=Color(.10,.16,.20,.90);glass.border_color=Color(.9,.95,1,.32);glass.set_border_width_all(1);glass.set_corner_radius_all(8);panel.add_theme_stylebox_override("panel",glass);gate.add_child(panel)
	_label("整体音量",Vector2(22,16),18);number=_label("80%",Vector2(245,20),15)
	slider=HSlider.new();slider.name="MasterSlider";slider.min_value=0;slider.max_value=100;slider.step=1;slider.position=Vector2(22,63);slider.size=Vector2(282,30);slider.focus_mode=Control.FOCUS_ALL;panel.add_child(slider)
	slider.value_changed.connect(func(value:float):if not syncing:set_volume(value/100.0))
	mute_button=CheckButton.new();mute_button.text="静音";mute_button.position=Vector2(13,112);mute_button.size=Vector2(120,40);panel.add_child(mute_button)
	mute_button.toggled.connect(func(value:bool):if not syncing:set_muted(value))
	var close:=Button.new();close.text="完成";close.position=Vector2(238,119);close.size=Vector2(67,30)
	close_button=close
	for key in ["normal","hover","pressed","focus"]:close.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	close.pressed.connect(close_panel);panel.add_child(close)

func _label(text:String,at:Vector2,size_value:int)->Label:
	var node:=Label.new();node.text=text;node.position=at;node.add_theme_font_size_override("font_size",size_value);node.mouse_filter=Control.MOUSE_FILTER_IGNORE;panel.add_child(node);return node

func _apply()->void:
	AudioServer.set_bus_mute(0,muted or volume<=.0001)
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,.0001)))
	if slider!=null:
		syncing=true;slider.value=roundf(volume*100);number.text=str(roundi(volume*100))+"%";mute_button.button_pressed=muted;syncing=false
	volume_changed.emit(volume,muted)

func set_volume(value:float,persist:=true)->void:
	if not is_finite(value):return
	volume=clampf(value,0,1);_apply()
	if persist:_schedule_save()

func set_muted(value:bool,persist:=true)->void:
	muted=value;_apply()
	if persist:_schedule_save()

func toggle_mute()->void:set_muted(not muted)
func toggle_panel()->void:
	if opened:close_panel()
	else:open_panel()

func open_panel()->void:
	if opened:return
	opened=true;gate.show();panel_toggled.emit(true)
	_block_branch(get_tree().root);slider.grab_focus()

func close_panel()->void:
	if not opened:return
	opened=false;gate.hide()
	for info in blocked:
		var node:Node=info.node.get_ref()
		if is_instance_valid(node):node.set_process_input(info.input);node.set_process_unhandled_input(info.unhandled)
	blocked.clear();get_viewport().gui_release_focus();panel_toggled.emit(false);save_settings()

func _block_branch(node:Node)->void:
	if node==self or is_ancestor_of(node):return
	_block_node(node)
	for child in node.get_children():_block_branch(child)

func _block_node(node:Node)->void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():return
	var input:=node.is_processing_input();var unhandled:=node.is_processing_unhandled_input()
	if not input and not unhandled:return
	blocked.append({"node":weakref(node),"input":input,"unhandled":unhandled});node.set_process_input(false);node.set_process_unhandled_input(false)

func _node_added(node:Node)->void:
	if node!=self and node.get_parent()==get_tree().root:_make_input_priority.call_deferred()
	if opened and node!=self and not is_ancestor_of(node):_block_node.call_deferred(node)

func _make_input_priority()->void:
	if is_inside_tree():get_tree().root.move_child(self,get_tree().root.get_child_count()-1)

func _process(_delta:float)->void:
	if get_tree().get_first_node_in_group("game_settings")!=null:toggle_button.hide()
	if opened:
		for action in ["move_left","move_right","slow_walk","interact","advance"]:
			if InputMap.has_action(action):Input.action_release(action)

func _input(event:InputEvent)->void:
	var text_studio=get_node_or_null("/root/TextStudio")
	if text_studio!=null and text_studio.editing:return
	if opened and event is InputEventMouseButton and not panel.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		if event.pressed:close_panel()
		return
	if not event is InputEventKey:return
	if opened:get_viewport().set_input_as_handled()
	if not event.pressed:return
	var code:int=event.physical_keycode
	if code==KEY_ESCAPE and not opened and event.pressed and not event.echo:
		var settings=get_tree().get_first_node_in_group("game_settings")
		if settings!=null:
			if settings.opened:settings.close_menu()
			else:settings.open_menu()
			get_viewport().set_input_as_handled();return
	if event.echo and not (opened and code in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]):return
	if code==KEY_F10:toggle_panel();get_viewport().set_input_as_handled()
	elif code==KEY_M:toggle_mute();get_viewport().set_input_as_handled()
	elif opened:
		if code==KEY_ESCAPE:close_panel()
		elif code in [KEY_F,KEY_F11]:get_window().mode=Window.MODE_WINDOWED if get_window().mode in [Window.MODE_FULLSCREEN,Window.MODE_EXCLUSIVE_FULLSCREEN] else Window.MODE_EXCLUSIVE_FULLSCREEN
		elif code in [KEY_LEFT,KEY_DOWN]:set_volume(volume-.01)
		elif code in [KEY_RIGHT,KEY_UP]:set_volume(volume+.01)
		elif code==KEY_HOME:set_volume(0)
		elif code==KEY_END:set_volume(1)
		elif code==KEY_TAB:
			var controls:Array[Control]=[slider,mute_button,close_button]
			var index:int=controls.find(get_viewport().gui_get_focus_owner())
			controls[posmod(index+(-1 if event.shift_pressed else 1),controls.size())].grab_focus()
		elif code in [KEY_SPACE,KEY_ENTER]:
			var focus:=get_viewport().gui_get_focus_owner()
			if focus==mute_button:toggle_mute()
			elif focus==close_button:close_panel()

func _schedule_save()->void:
	dirty=true;save_serial+=1;var token:=save_serial
	await get_tree().create_timer(.25).timeout
	if token==save_serial:save_settings()

func save_settings()->void:
	if no_save or not dirty:return
	var config:=ConfigFile.new();config.set_value("audio","master",volume);config.set_value("audio","muted",muted)
	if config.save(settings_path)==OK:dirty=false

func _exit_tree()->void:save_settings()
