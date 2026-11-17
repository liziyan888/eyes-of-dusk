extends CanvasLayer
## One settings entry for the cover and Esc throughout the game.
var game:Node
var opened:=false
var was_paused:=false
var ui:Control
var overlay:Control
var settings_button:Button
func setup(context:Node)->void:game=context
func _ready()->void:
	layer=1050;process_mode=Node.PROCESS_MODE_ALWAYS;add_to_group("game_settings");set_meta("text_editor_ignore",true)
	ui=Control.new();ui.size=Vector2(1280,720);ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(ui)
	settings_button=_button(ui,"设置",Rect2(26,654,74,36),open_menu,16)
	overlay=Control.new();overlay.size=Vector2(1280,720);overlay.mouse_filter=Control.MOUSE_FILTER_STOP;ui.add_child(overlay)
	var veil:=ColorRect.new();veil.size=overlay.size;veil.color=Color(.025,.045,.07,.87);veil.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.add_child(veil)
	var title:=Label.new();title.text="设置";title.position=Vector2(500,105);title.size=Vector2(280,60);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;title.add_theme_font_size_override("font_size",27);overlay.add_child(title)
	_button(overlay,"继续体验",Rect2(450,190,380,44),close_menu)
	_button(overlay,"整体音量",Rect2(450,248,380,44),func():close_menu();get_node("/root/AudioSettings").open_panel())
	var subtitle:=Label.new();subtitle.text="选择章节";subtitle.position=Vector2(450,321);subtitle.size=Vector2(380,34);subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;subtitle.modulate.a=.65;overlay.add_child(subtitle)
	for i in range(4):
		var number:=i+1;var label:String=["一、前序","二、草原","三、落日六号","四、透明地球"][i]
		_button(overlay,label,Rect2(450,365+i*48,380,40),func():close_menu();game.open_chapter(number))
	_button(overlay,"返回主菜单",Rect2(450,584,380,44),func():close_menu();game.return_to_main_menu())
	overlay.hide()
func _button(parent:Node,text:String,rect:Rect2,callback:Callable,font_size:=20)->Button:
	var button:=Button.new();button.text=text;button.position=rect.position;button.size=rect.size;button.pressed.connect(callback)
	for state in ["normal","hover","pressed","focus"]:button.add_theme_stylebox_override(state,StyleBoxEmpty.new())
	button.add_theme_font_size_override("font_size",font_size);button.add_theme_color_override("font_color",Color(.94,.96,.95,.82));button.add_theme_color_override("font_hover_color",Color.WHITE);parent.add_child(button);return button
func open_menu()->void:
	if opened:return
	was_paused=get_tree().paused;opened=true;overlay.show();settings_button.hide();get_tree().paused=true
func close_menu()->void:
	if not opened:return
	opened=false;overlay.hide();get_tree().paused=was_paused;get_viewport().gui_release_focus()
func _process(_delta:float)->void:
	if is_instance_valid(game):settings_button.visible=game.title.visible and not opened
func _input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null and studio.editing:return
	var audio=get_node_or_null("/root/AudioSettings")
	if audio!=null and audio.opened:return
	if event.physical_keycode==KEY_ESCAPE:
		if opened:close_menu()
		else:open_menu()
		get_viewport().set_input_as_handled()
	elif opened:get_viewport().set_input_as_handled()
func _exit_tree()->void:
	if opened:get_tree().paused=was_paused
