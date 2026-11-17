extends Node2D
## Native migration. Story coordinates and source artwork retain the web version's units.
const SIZE := Vector2(1280, 720)
const MusicDirector=preload("res://scripts/music_director.gd")
var music_director:Node
var narrative_audio:Node
var settings_menu:CanvasLayer
var transparent_earth:Control
var interaction_tip_until:=0.0
const SPEED := 190.0
const RunCycle = preload("res://scripts/run_cycle.gd")
const WALK_CYCLE := RunCycle.DURATION
const APPROACH_RADIUS := 210.0
const INTERACT_RADIUS := 118.0
const LayoutSettings = preload("res://scripts/layout_settings.gd")
const SensoryLink = preload("res://scripts/sensory_link.gd")
const DebugEditor = preload("res://scripts/debug_editor.gd")
const Panorama = preload("res://scripts/panorama.gd")
const ActionPlayer = preload("res://scripts/action_player.gd")
const WorldWater=preload("res://scripts/world_water.gd")
var water=WorldWater.new()
const StoneExperience=preload("res://scripts/stone_experience.gd")
var stone:Control
const NightScenes = preload("res://scripts/night_scenes.gd")
const NightSeam = preload("res://scripts/night_seam.gd")
const PrologueComic = preload("res://scripts/prologue_comic.gd")
const PrologueCover = preload("res://scripts/prologue_cover.gd")
const GrasslandComic = preload("res://scripts/grassland_comic.gd")
const InteractionMist = preload("res://scripts/interaction_mist.gd")
const MorningAfter = preload("res://scripts/morning_after.gd")
const EndingEntry = preload("res://scripts/ending_entry.gd")
const SunsetScene = preload("res://scenes/sunset/sunset_experience.tscn")
var sunset:Control
var sunset_done:=false
var second_night_ready:=false
var sunset_return_context:Dictionary={}
var glasses_canvas:Node2D
var morning: Control
var ending_entry: Control
var ending_result: Dictionary = {}
var morning_canvas: Node2D
var night5_textures: Dictionary = {}
var grassland: Control
var mist = InteractionMist.new()
var marker_canvas: Node2D
var action_override := ""
var prologue: Control
var night := NightScenes.new()
var night_seam:=NightSeam.new()
var visited_scenes: Dictionary = {}
var night_foregrounds: Array[Node2D] = []
var night_canvas: Node2D
var action_player := ActionPlayer.new()
var panorama := Panorama.new()
var layout := LayoutSettings.new()
var sensor: Control
var debug_editor: PanelContainer
var introduced: Dictionary = {}
var pending_intro_id := ""
var dialogue_phase := "enter"
const DialogueView = preload("res://scripts/dialogue_view.gd")
var walk_phase := 0.0
var pose_origins: Dictionary = {}
var pose_scales: Dictionary = {}
var pose_heights: Dictionary = {}
var camera_anchor := Vector2(640, 660)
var fullscreen_button: Button
var foreground_front: Node2D
var psd_foreground_front: Node2D
var psd_foliage_material: ShaderMaterial
var creek_foreground_front: Node2D
var creek_foliage_material: ShaderMaterial
var actor_canvas: Node2D
var actor_material: ShaderMaterial
var transition_front: Node2D
var passage_fog_front: Node2D
var debug_overlay: Node2D
var foliage_material: ShaderMaterial
var story: Dictionary
var scene_index := 0
var player_x := 150.0
var facing := 1.0
var camera_x := 0.0
var zoom := 1.0
var elapsed := 0.0
var animation_time := 0.0
var pose := "idle"
var moving := false
var playing := false
var finished := false
var completed: Dictionary = {}
var dialogue: Array = []
var line_index := 0
var active_id := ""
var near_point: Dictionary = {}
var textures: Dictionary = {}
var prop_regions: Dictionary = {}
var frames: Dictionary = {}
var font: Font
var edge_shade: GradientTexture2D
var ui: Control
var title: Control
var dialogue_panel: Control
var chapter: Label
var hint: Label
var progress: Label
var travel_memory:Dictionary={}
var subtitle_debug_was_paused:=false

func _ready() -> void:
	AudioSettings.panel_toggled.connect(_on_audio_panel_toggled)
	story = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	layout.setup(story, not "--no-user-layout" in OS.get_cmdline_user_args())
	var system_font := WebSystemFont.new()
	system_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	font = system_font
	edge_shade = GradientTexture2D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.015, 0.035, 0.025, 0.65))
	gradient.set_color(1, Color(0.015, 0.035, 0.025, 0))
	edge_shade.gradient = gradient
	edge_shade.fill_from = Vector2(0, 0)
	edge_shade.fill_to = Vector2(0, 1)
	for action in ["move_left", "move_right", "interact", "advance", "slow"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	_bind("move_left", [KEY_A, KEY_LEFT])
	_bind("move_right", [KEY_D, KEY_RIGHT])
	_bind("interact", [KEY_E])
	_bind("advance", [KEY_SPACE, KEY_ENTER])
	_bind("slow", [KEY_S, KEY_DOWN])
	for anim in ["idle", "crouch"]:
		frames[anim] = []
		var count: int = 4 if anim == "idle" else 8
		for i in range(1, count + 1):
			frames[anim].append(load("res://assets/char/%s/%02d.png" % [anim, i]))
	frames["walk_v2"] = RunCycle.load_frames()
	for action in ["water","wind"]:
		frames[action]=[load("res://assets/creek/pose-"+action+".png")]
	action_player.setup()
	water.setup(self)
	for action in action_player.clips:
		frames[action]=[]
		for i in range(int(action_player.clips[action].count)):
			frames[action].append(load("res://assets/actions/%s/%02d.png"%[action,i]))
	_prepare_origins()
	_make_ui()
	music_director=MusicDirector.new();music_director.name="MusicDirector";music_director.setup(self);add_child(music_director)
	narrative_audio=preload("res://scripts/narrative_audio_cues.gd").new();narrative_audio.name="NarrativeAudio";add_child(narrative_audio)
	actor_canvas=Node2D.new()
	actor_material=ShaderMaterial.new()
	actor_material.shader=preload("res://shaders/character_cutout.gdshader")
	actor_canvas.material=actor_material
	add_child(actor_canvas)
	actor_canvas.draw.connect(_draw_actor.bind(actor_canvas))
	foreground_front=Node2D.new()
	foreground_front.z_index=1
	foliage_material=ShaderMaterial.new()
	foliage_material.shader=preload("res://shaders/psd_grass_cover.gdshader")
	foreground_front.material=foliage_material
	add_child(foreground_front)
	foreground_front.draw.connect(_draw_foreground.bind(foreground_front))
	psd_foreground_front=Node2D.new()
	psd_foreground_front.z_index=1
	psd_foliage_material=ShaderMaterial.new()
	psd_foliage_material.shader=preload("res://shaders/psd_grass_cover.gdshader")
	psd_foreground_front.material=psd_foliage_material
	add_child(psd_foreground_front)
	psd_foreground_front.draw.connect(_draw_psd_foreground.bind(psd_foreground_front))
	creek_foreground_front=Node2D.new()
	creek_foreground_front.z_index=1
	creek_foliage_material=ShaderMaterial.new()
	creek_foliage_material.shader=preload("res://shaders/psd_grass_cover.gdshader")
	creek_foreground_front.material=creek_foliage_material
	add_child(creek_foreground_front)
	creek_foreground_front.draw.connect(_draw_creek_foreground.bind(creek_foreground_front))
	for index in [3,4]:
		var cover:=Node2D.new()
		cover.z_index=1
		var material:=ShaderMaterial.new()
		material.shader=preload("res://shaders/psd_grass_cover.gdshader")
		cover.material=material
		add_child(cover);night_foregrounds.append(cover)
		cover.draw.connect(_draw_night_foreground.bind(cover,index))
	night_canvas=Node2D.new();night_canvas.z_index=1;add_child(night_canvas)
	night_canvas.draw.connect(func():night.draw(night_canvas,self))
	passage_fog_front=Node2D.new()
	passage_fog_front.z_index=1
	add_child(passage_fog_front)
	passage_fog_front.draw.connect(func():panorama.draw_passage(passage_fog_front,self,"fog"))
	transition_front=Node2D.new()
	transition_front.z_index=2
	add_child(transition_front)
	transition_front.draw.connect(func():
		if morning==null or not morning.active:panorama.draw_trees(transition_front,self)
		panorama.draw_passage(transition_front,self,"cover")
		night.draw_transition(transition_front))
	debug_overlay=Node2D.new()
	debug_overlay.z_index=3
	add_child(debug_overlay)
	debug_overlay.draw.connect(_draw_debug.bind(debug_overlay))
	_load_backgrounds()
	night_seam.setup(self)
	settings_menu=preload("res://scripts/game_settings_menu.gd").new();settings_menu.name="GameSettings";settings_menu.setup(self);add_child(settings_menu)
	if "--preview-transparent-earth" in OS.get_cmdline_user_args() or "--preview-earth-core" in OS.get_cmdline_user_args():open_chapter(4)
	for web_argument in OS.get_cmdline_user_args():
		if web_argument.begins_with("--web-chapter="):open_chapter(clampi(int(web_argument.trim_prefix("--web-chapter=")),1,4))
	if "--preview-creek" in OS.get_cmdline_user_args():
		start_game()
		for point in points():completed[point.id]=true
		dialogue.clear()
		dialogue_panel.hide()
		_enter_scene(1)
		player_x=float(current_scene().start)+330
		camera_x=player_x-512
	if "--preview-inn" in OS.get_cmdline_user_args():
		start_game()
		for point in story.interactions:
			if int(point.scene)<3:completed[point.id]=true
		dialogue.clear()
		dialogue_panel.hide()
		_enter_scene(2)
		player_x=float(current_scene().start)+390
		camera_x=player_x-512
	if "--preview-passage12" in OS.get_cmdline_user_args():
		start_game()
		for point in points():completed[point.id]=true
		dialogue.clear();dialogue_panel.hide()
		player_x=float(story.world.passage12.start)+60
		camera_x=player_x-512
	for index in [3,4]:
		if ("--preview-scene%d"%[index+1]) in OS.get_cmdline_user_args():
			start_game()
			sunset_done=true;second_night_ready=index==4
			for point in story.interactions:
				if int(point.scene)<=index:completed[point.id]=true
			_enter_scene(index)
			player_x=float(current_scene().start)+180
			camera_x=player_x-512
	if "--preview-grassland" in OS.get_cmdline_user_args():
		start_game();dialogue.clear();dialogue_panel.hide();_begin_grassland()
	if "--preview-water-contact" in OS.get_cmdline_user_args():
		start_game();_enter_scene(1);dialogue.clear();dialogue_panel.hide()
		var point:=point_by_id("s2-water");var target:=point_position(point)
		player_x=target.x-60;camera_x=target.x-640;camera_anchor=Vector2(640,_ground());introduced[point.id]=true;interact(point)
	if "--preview-stone-placement" in OS.get_cmdline_user_args():
		start_game();sunset_done=true;second_night_ready=true;completed["s4-moon"]=true
		_enter_scene(4);dialogue.clear();dialogue_panel.hide();night.fade=0
		var point:=point_by_id("s5-willow");var target:=point_position(point)
		player_x=target.x-60;camera_x=target.x-640;camera_anchor=Vector2(640,_ground());introduced[point.id]=true;interact(point)
	if "--preview-prologue" in OS.get_cmdline_user_args():
		begin_prologue()
	if "--preview-sensor-introduction" in OS.get_cmdline_user_args():
		prologue.test_mode=true;begin_prologue();prologue.begin(true)
		prologue.page_index=1;prologue.frontier=3;prologue._build_page();prologue.unlock(1)
	if "--preview-morning" in OS.get_cmdline_user_args():
		start_game();dialogue.clear();dialogue_panel.hide()
		sunset_done=true;second_night_ready=true
		for point in story.interactions:
			if point.get("time_phase", "night")!="morning":completed[point.id]=true
		_enter_scene(4);dialogue.clear();dialogue_panel.hide();_begin_morning()
	if "--preview-ending" in OS.get_cmdline_user_args():
		start_game();dialogue.clear();dialogue_panel.hide()
		ending_entry.preview_mode=true;_begin_ending()
	if "--preview-sunset" in OS.get_cmdline_user_args():
		start_game();_enter_scene(2);dialogue.clear();dialogue_panel.hide();completed["s3-door"]=true
		var point:=point_by_id("s3-sunset");player_x=point_position(point).x;camera_x=float(story.scenes[2].end)-SIZE.x
		camera_anchor=Vector2(player_x-camera_x,_ground());introduced["s3-sunset"]=true;check_approach()
	if "--capture" in OS.get_cmdline_user_args():
		start_game()
		dialogue.clear()
		dialogue_panel.hide()
		player_x = 650
		camera_x = 140
		var capture_path := "res://preview.png"
		if "--capture-dialogue" in OS.get_cmdline_user_args():
			player_x = float(points()[0].x)
			interact(points()[0])
			zoom = 1.7
			capture_path = "res://preview-dialogue.png"
		dialogue_panel.finish_typing()
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		get_tree().quit()

func _bind(action: String, keys: Array) -> void:
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _label(text: String, size: int, color := Color("e9ecd4")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(ui)
	for bottom in [false,true]:
		var shade:=TextureRect.new()
		shade.texture=edge_shade
		shade.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
		shade.position=Vector2(0,610 if bottom else 0)
		shade.size=Vector2(1280,110 if bottom else 160)
		shade.flip_v=bottom
		ui.add_child(shade)
	chapter = _label("", 17)
	chapter.position = Vector2(40, 28)
	ui.add_child(chapter)
	progress = _label("", 12)
	progress.position = Vector2(40, 56)
	ui.add_child(progress)
	hint = _label("A / D 移动 · S 慢走 · E 互动 · 空格继续 · F11 全屏", 14)
	hint.position = Vector2(40, 682)
	ui.add_child(hint)
	dialogue_panel = DialogueView.new()
	ui.add_child(dialogue_panel)
	dialogue_panel.setup(font)
	fullscreen_button = Button.new()
	fullscreen_button.text = "全屏 F11"
	fullscreen_button.focus_mode = Control.FOCUS_NONE
	fullscreen_button.add_theme_font_override("font", font)
	fullscreen_button.add_theme_font_size_override("font_size", 14)
	fullscreen_button.position = Vector2(1140, 24)
	fullscreen_button.size = Vector2(108, 36)
	fullscreen_button.pressed.connect(_toggle_fullscreen)
	ui.add_child(fullscreen_button)
	title = PrologueCover.new()
	title.z_index = 120
	ui.add_child(title)
	title.start_requested.connect(func(): begin_prologue(true))
	title.fullscreen_requested.connect(_toggle_fullscreen)
	chapter.hide()
	progress.hide()
	hint.hide()
	sensor = SensoryLink.new()
	ui.add_child(sensor)
	sensor.setup(font)
	sensor.hide()
	debug_editor = DebugEditor.new()
	ui.add_child(debug_editor)
	debug_editor.setup(self,font)
	debug_editor.layout_changed.connect(func():
		if stone==null or not stone.visible:camera_anchor.y = _ground()
		near_point = {}
		_apply_subtitle_settings()
		queue_redraw())
	debug_editor.visibility_changed.connect(_subtitle_debug_visibility_changed)
	var debug_button := Button.new()
	debug_button.text = "图层调试 F3"
	debug_button.focus_mode = Control.FOCUS_NONE
	debug_button.position = Vector2(1010,24)
	debug_button.size = Vector2(110,36)
	debug_button.add_theme_font_override("font",font)
	debug_button.add_theme_font_size_override("font_size",14)
	debug_button.pressed.connect(debug_editor.toggle)
	ui.add_child(debug_button)
	prologue = PrologueComic.new()
	prologue.z_index = 100
	ui.add_child(prologue)
	prologue.finished.connect(_finish_prologue)
	prologue.arrival_revealed.connect(_reveal_arrival)
	prologue.fullscreen_requested.connect(_toggle_fullscreen)
	prologue.hide()
	grassland=GrasslandComic.new();grassland.z_index=110;ui.add_child(grassland)
	grassland.apply_subtitle_style(layout.subtitles())
	grassland.experience_remembered.connect(_remember_experience)
	grassland.finished.connect(_prepare_after_grassland)
	grassland.arrival_revealed.connect(_finish_grassland)
	grassland.fullscreen_requested.connect(_toggle_fullscreen)
	marker_canvas=Node2D.new();marker_canvas.z_index=4;add_child(marker_canvas);marker_canvas.draw.connect(_draw_mist)
	morning=MorningAfter.new();morning.z_index=110;ui.add_child(morning)
	morning.apply_subtitle_style(layout.subtitles())
	morning.prepared.connect(_prepare_morning)
	morning.arrived.connect(_arrive_morning)
	morning.glasses_recovered.connect(_recover_morning_glasses)
	morning.bird_heard.connect(_hear_morning_bird)
	morning.interaction_cancelled.connect(_cancel_morning_interaction)
	morning.fullscreen_requested.connect(_toggle_fullscreen)
	stone=StoneExperience.new();stone.z_index=111;ui.add_child(stone);stone.apply_subtitle_style(layout.subtitles());stone.finished.connect(_complete_stone_placement);stone.cancelled.connect(_cancel_stone_placement)
	ending_entry=EndingEntry.new();ending_entry.z_index=115;ui.add_child(ending_entry)
	ending_entry.transparent_earth_requested.connect(_begin_transparent_earth)
	ending_entry.fullscreen_requested.connect(_toggle_fullscreen)
	ending_entry.ending_completed.connect(func(result:Dictionary):ending_result=result.duplicate(true))
	ending_entry.return_to_title_requested.connect(_return_from_ending)
	morning_canvas=Node2D.new();morning_canvas.z_index=3;add_child(morning_canvas);morning_canvas.draw.connect(func():morning.draw_world(morning_canvas,self))
	glasses_canvas=Node2D.new();glasses_canvas.z_index=3;add_child(glasses_canvas)
	var prop_material:=ShaderMaterial.new();prop_material.shader=preload("res://shaders/sensor_prop.gdshader");glasses_canvas.material=prop_material
	glasses_canvas.draw.connect(func():
		if morning.active:morning.draw_glasses(glasses_canvas,self)
		else:night.draw_glasses(glasses_canvas,self))
	sunset=SunsetScene.instantiate();sunset.z_index=112;ui.add_child(sunset)
	sunset.prepare_moon_scene.connect(_prepare_moon_after_sunset)
	sunset.prepare_night_walk.connect(_prepare_second_night)
	sunset.moon_arrival_revealed.connect(_arrive_first_moon)
	sunset.night_walk_revealed.connect(_arrive_second_night)
	sunset.cancelled.connect(_cancel_sunset)
	sunset.fullscreen_requested.connect(_toggle_fullscreen)

func _load_backgrounds() -> void:
	for id in layout.source_layers:
		textures["psd_"+str(id)]=load(str(layout.source_layers[id].path))
	var files := {"sky":"scene1_original_sky.jpg", "far":"scene1_far_clean.png",
		"mid":"scene1_mid_clean.png", "ground":"scene1_filled_04.png", "near":"new_layer_05.png"}
	for key in files:
		textures[key] = load("res://assets/" + files[key])
	textures["flower"] = load("res://assets/prop_meadow.png")
	textures["transition_grove"]=load("res://assets/inn/transition-grove.png")
	for key in ["water","wind","view"]:
		textures["prop_"+key]=load("res://assets/creek/prop-"+key+".png")
		prop_regions[key]=Rect2(textures["prop_"+key].get_image().get_used_rect())
	textures["transition_tree"]=load("res://assets/creek/transition-tree.png")
	for key in ["sky","clouds","far","forest","ground","tree"]:
		night5_textures[key]=textures["psd_moon5_"+key]

func begin_prologue(from_cover := false) -> void:
	if ChapterTransition.active:return
	playing = false
	if not from_cover: title.hide()
	sensor.hide()
	chapter.hide()
	progress.hide()
	hint.hide()
	dialogue_panel.hide()
	debug_editor.hide()
	for child in ui.get_children():
		if child is Button: child.hide()
	if from_cover:
		prologue.intro_blocked = true
		var shown:bool=await ChapterTransition.play(1,self,_prepare_prologue_chapter)
		if not shown:return
		prologue.intro_blocked = false
		get_viewport().gui_release_focus()
	else:prologue.begin()

func _prepare_prologue_chapter()->void:
	title.hide();prologue.begin();prologue.intro_blocked=true
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	ChapterTransition.destination_ready(self)

func _finish_prologue() -> void:
	# Prepare gameplay under the opaque chapter cover; input and HUD stay held.
	start_game(true)
	playing = false
	sensor.stop_voice()
	sensor.hide()
	chapter.hide()
	progress.hide()
	hint.hide()
	dialogue_panel.hide()
	if not dialogue.is_empty():
		dialogue[0] = dialogue[0].duplicate(true)
		dialogue[0].text = "是这里……我们起航前来过的地方。"

func _reveal_arrival() -> void:
	playing = true
	sensor.show()
	progress.hide()
	chapter.hide()
	_show_line()

func start_game(keep_chapter_cover:=false) -> void:
	if not keep_chapter_cover:ChapterTransition.cancel()
	ending_result.clear()
	travel_memory.clear()
	if stone!=null:stone.close()
	actor_canvas.show();marker_canvas.show()
	sunset_done=false;second_night_ready=false;sunset_return_context.clear()
	if sunset!=null:sunset.close()
	if morning!=null:morning.reset()
	if ending_entry!=null:ending_entry.close()
	for key in night5_textures:textures["psd_moon5_"+key]=night5_textures[key]
	action_player.reset()
	night.reset();visited_scenes.clear()
	water.reset()
	completed.clear()
	introduced.clear()
	pending_intro_id = ""
	sensor.show()
	finished = false
	playing = true
	title.hide()
	chapter.hide()
	progress.hide()
	hint.show()
	_enter_scene(0)

func _enter_scene(index: int) -> void:
	action_player.reset()
	water.reset()
	action_override=""
	pose = "idle"
	animation_time = 0
	scene_index = index
	visited_scenes[index]=true
	var sc: Dictionary = story.scenes[index]
	player_x = float(sc.start) + 150.0
	camera_x = float(sc.start)
	zoom = 1.0
	active_id = ""
	near_point = {}
	chapter.text = sc.no + "  /  " + sc.name
	dialogue_phase = "enter"
	_open_dialogue(sc.get("enter", []))

func _open_dialogue(lines: Array) -> void:
	dialogue = lines.duplicate(true)
	line_index = 0
	_show_line()

func _show_line() -> void:
	if dialogue.is_empty():
		sensor.stop_voice()
		dialogue_panel.hide()
		return
	var line: Dictionary = dialogue[line_index]
	if line.get("pose","")=="wind" and action_override!="wind":
		action_player.finish(pose,animation_time);action_override="wind"
	dialogue_panel.show_line(line)
	if not narrative_audio.on_world_line(active_id,str(line.text)):
		sensor.start_voice(str(line.get("tone","sys")),str(line.text).length(),float(line.get("stimulus",0.6)))
	else:sensor.stop_voice()
	var point := point_by_id(active_id if not active_id.is_empty() else pending_intro_id)
	var channels: Dictionary = line.get("senses", {"sound":0.2,"vision":0.15})
	var profile := str(point.get("sensory",{}).get("profile","voice"))
	if dialogue_phase == "approach": channels = {"sound":0.25,"vision":0.25}
	sensor.transmit(channels,profile,float(line.get("stimulus",0.45)))
	dialogue_panel.follow_head(_dialogue_head())

func _dialogue_head() -> Vector2:
	if not dialogue.is_empty():
		var speaker := point_by_id(str(dialogue[line_index].get("speaker_point","")))
		if not speaker.is_empty():
			return _screen(point_position(speaker)-Vector2(0,82))
	var index := current_frame()
	var height: float = pose_heights[pose][index] * float(layout.data.player_scale)
	return _screen(Vector2(_actor_x(),_actor_ground()-height))

func advance_dialogue() -> void:
	if dialogue.is_empty():
		return
	if dialogue_panel.finish_typing():
		return
	line_index += 1
	if line_index < dialogue.size():
		_show_line()
		return
	dialogue.clear()
	sensor.stop_voice()
	dialogue_panel.hide()
	if dialogue_phase=="water_invitation":water.start_approach(self);return
	if dialogue_phase == "approach" and not pending_intro_id.is_empty():
		introduced[pending_intro_id] = true
		pending_intro_id = ""
	if dialogue_phase == "response" and not active_id.is_empty():
		var completed_id:=active_id
		action_player.finish(pose,animation_time)
		completed[active_id] = true
		if completed_id=="s2-water":water.finish(self)
		action_override=""
		active_id = ""
		if completed_id=="s4-moon":_begin_second_rest();return
		if completed_id=="s5-willow":night.hang_progress=1;_begin_morning();return
		if completed_id=="s5-morning-bird":_begin_ending();return

func points() -> Array:
	var result: Array = []
	for point in story.interactions:
		if int(point.scene) == scene_index + 1:
			if scene_index==4 and str(point.get("time_phase","night"))!=("morning" if morning!=null and morning.active else "night"):continue
			result.append(point)
	return result

func remaining() -> int:
	var count := 0
	for point in points():
		if bool(point.get("required",true)) and not completed.has(point.id):
			count += 1
	return count

func interact(point: Dictionary) -> void:
	if water.active:return
	if action_player.busy() or not dialogue.is_empty() or point.is_empty() or completed.has(point.id):
		return
	if not introduced.has(str(point.id)) or absf(player_x - point_position(point).x) > interaction_radius(point):
		return
	if not point_available(point):return
	if str(point.id)=="s5-willow":stone.begin(self);return
	mist.trigger(point_position(point)-Vector2(0,42))
	if point.get("kind","")=="sunset_experience":_begin_sunset();return
	if point.get("kind","")=="morning_glasses":
		playing=false;moving=false;pose="idle";sensor.hide();hint.hide();actor_canvas.hide();morning.begin_inspection();return
	if point.get("kind","")=="morning_bird":
		playing=false;moving=false;pose="idle";sensor.hide();hint.hide();morning.begin_listening();return
	if point.get("kind","")=="grassland_comic":
		_begin_grassland();return
	if str(point.get("type",""))=="water":water.begin(self,point);return
	action_override=str(point.get("animation","crouch"))
	active_id = point.id
	dialogue_phase = "response"
	var signal_data: Dictionary = point.get("sensory",{})
	sensor.sample(signal_data.get("channels",{"vision":0.6}),str(signal_data.get("profile","voice")),Vector2(signf(point_position(point).x-player_x),0.3))
	_open_dialogue(point.lines)

func _input(event: InputEvent) -> void:
	if ChapterTransition.active:return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F3:
		if grassland!=null and grassland.visible or morning!=null and morning.visible or stone!=null and stone.visible:
			debug_editor.toggle_subtitles();get_viewport().set_input_as_handled();return
	if stone!=null and stone.visible:return
	if sunset!=null and sunset.visible:return
	if (morning!=null and morning.visible) or (ending_entry!=null and ending_entry.visible):return
	if (grassland != null and grassland.visible) or (prologue != null and prologue.visible) or (title != null and title.visible):
		return
	if debug_editor != null and debug_editor.pointer(event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F3:
		debug_editor.toggle()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_F11, KEY_F]:
			_toggle_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_ESCAPE and get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]:
			get_window().mode = Window.MODE_WINDOWED
			fullscreen_button.text = "全屏 F11"
			get_viewport().set_input_as_handled()

func _toggle_fullscreen() -> void:
	var fullscreen := get_window().mode in [Window.MODE_FULLSCREEN, Window.MODE_EXCLUSIVE_FULLSCREEN]
	get_window().mode = Window.MODE_WINDOWED if fullscreen else Window.MODE_EXCLUSIVE_FULLSCREEN
	fullscreen_button.text = "退出全屏" if not fullscreen else "全屏 F11"

func _unhandled_input(event: InputEvent) -> void:
	if ChapterTransition.active:return
	if stone!=null and stone.visible:return
	if sunset!=null and sunset.visible:return
	if (morning!=null and morning.visible) or (ending_entry!=null and ending_entry.visible):return
	if (grassland != null and grassland.visible) or (prologue != null and prologue.visible) or (title != null and title.visible):
		return
	if debug_editor != null and debug_editor.visible:
		return
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("advance"):
		if not playing:
			begin_prologue()
		elif not dialogue.is_empty():
			advance_dialogue()
	elif event.is_action_pressed("interact") and playing:
		interact(near_point)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and playing:
		if not dialogue.is_empty():
			advance_dialogue()
		else:
			for point in points():
				var screen_pos := _screen(interaction_cue_world(point))
				if event.position.distance_to(screen_pos) < 45 * zoom:
					if absf(player_x-point_position(point).x)>interaction_radius(point):interaction_tip_until=elapsed+3.0
					else:interact(point)
					break

func _ground() -> float:
	return layout.ground(current_scene())

func _actor_ground() -> float:
	if water.active:return water.ground_y
	return _ground()

func _actor_x() -> float:
	return player_x

func _physics_process(delta: float) -> void:
	if narrative_audio!=null:narrative_audio.world_context(active_id,scene_index)
	if AudioSettings.opened:moving=false;return
	elapsed += delta
	if glasses_canvas!=null:glasses_canvas.queue_redraw()
	if morning_canvas!=null:morning_canvas.queue_redraw()
	mist.update(delta)
	if marker_canvas!=null:marker_canvas.queue_redraw()
	sensor.update_signal(delta)
	if debug_editor.visible:
		moving = false
		queue_redraw()
		return
	dialogue_panel.update_text(delta)
	if not playing:
		queue_redraw()
		return
	night.update(delta,self)
	action_player.update(delta)
	water.update(delta,self)
	moving = false
	var previous_x := player_x
	if dialogue.is_empty() and not action_player.busy() and not water.active:
		var direction := Input.get_axis("move_left", "move_right")
		moving = direction != 0
		if moving:
			facing = signf(direction)
		player_x += direction * SPEED * (0.42 if Input.is_action_pressed("slow") else 1.0) * delta
		var sc: Dictionary = story.scenes[scene_index]
		if morning!=null and morning.active:
			player_x=clampf(player_x,float(sc.start)+46,float(sc.end)-46)
		elif scene_index<continuous_count():
			var upper:=float(sc.end)-52 if remaining()>0 or scene_index==1 else float(story.scenes[continuous_count()-1].end)-40
			if scene_index==1:
				var exit_point:=point_by_id("s2-cloud")
				if not exit_point.is_empty():upper=minf(upper,point_position(exit_point).x+interaction_radius(exit_point)*.65)
			var lower:=46.0 if scene_index<2 else float(story.scenes[2].start)+46.0
			if scene_index==2 and not sunset_done:upper=minf(upper,float(sc.end)-46)
			if scene_index>=3 and sunset_done:lower=float(story.scenes[3].start)+46
			if scene_index==3 and not second_night_ready:upper=minf(upper,float(sc.end)-46)
			player_x=clampf(player_x,lower,upper)
			if scene_index!=1 and scene_index<continuous_count()-1 and player_x>=float(sc.end) and remaining()==0:
				_cross_creek_border(scene_index+1)
			elif scene_index>0 and scene_index!=2 and player_x<float(sc.start):
				_cross_creek_border(scene_index-1)
		else:
			player_x = clampf(player_x, float(sc.start) + 46, float(sc.end) - 40)
	moving=not is_equal_approx(player_x,previous_x)
	check_approach()
	var action_pose:=action_override if not action_override.is_empty() else str(point_by_id(active_id).get("animation","crouch"))
	var next_pose := action_player.returning if action_player.busy() else (water.actor_pose(self) if water.active else (action_pose if not active_id.is_empty() else ("walk_v2" if moving else "idle")))
	if next_pose != pose:
		pose = next_pose
		animation_time = 0
	animation_time += delta
	if moving:
		# Gait follows travelled distance, including slow-walk and boundary clamping.
		walk_phase = fposmod(walk_phase + absf(player_x - previous_x) / (SPEED * WALK_CYCLE), 1.0)
	near_point = {}
	var nearest := INF
	for point in points():
		var distance := absf(player_x - point_position(point).x)
		if distance <= interaction_radius(point) and distance < nearest and not completed.has(point.id) and introduced.has(str(point.id)) and point_available(point):
			near_point = point
			nearest = distance
	zoom = lerpf(zoom, 1.0, 1.0 - exp(-3.2 * delta))
	var sc: Dictionary = story.scenes[scene_index]
	var focus := player_x
	if not active_id.is_empty():
		for point in points():
			if point.id == active_id:
				focus = (player_x + point_position(point).x) * 0.5
	camera_anchor = Vector2(clampf(focus - camera_x, SIZE.x * 0.2, SIZE.x * 0.8), _ground())
	var min_camera:=0.0 if scene_index<2 else float(story.scenes[2].start) if scene_index<continuous_count() else float(sc.start)
	var max_camera:=float(story.scenes[1].end)-SIZE.x if scene_index<2 else float(story.scenes[continuous_count()-1].end)-SIZE.x if scene_index<continuous_count() else maxf(float(sc.start),float(sc.end)-SIZE.x)
	if morning!=null and morning.active:min_camera=float(sc.start);max_camera=float(sc.end)-SIZE.x
	elif scene_index==2 and not sunset_done:max_camera=float(story.scenes[2].end)-SIZE.x
	elif scene_index>=3 and sunset_done:min_camera=float(story.scenes[3].start)
	var target := clampf(player_x - 512,min_camera,max_camera)
	camera_x = lerpf(camera_x, target, 1.0 - exp(-5.0 * delta))
	sensor.set_context(_screen(Vector2(player_x,_ground()-110)),(player_x-previous_x)/maxf(delta,0.0001),zoom)
	dialogue_panel.follow_head(_dialogue_head())
	hint.visible = dialogue.is_empty() and not action_player.busy()
	progress.text = "风景  %d / %d" % [points().size() - remaining(), points().size()]
	hint.text = "A / D 移动 · S 慢走 · E 互动 · 空格继续"
	if not near_point.is_empty():
		hint.text = "[ E ]  " + str(near_point.prompt)
	elif elapsed<interaction_tip_until:hint.text="走近白色圆圈，再按 E 或点击圆圈互动"
	if player_x >= float(sc.end) - 55 and remaining() > 0:
		var missing:=nearest_unfinished_point()
		if not missing.is_empty():hint.text=("← 左侧还有：" if point_position(missing).x<player_x else "前面还有：")+str(missing.prompt)+" · 寻找白色圆圈"
	queue_redraw()

func _process(_delta: float) -> void:
	if is_instance_valid(dialogue_panel) and not pose_heights.is_empty():
		var index := current_frame()
		var height: float = pose_heights[pose][index] * float(layout.data.player_scale)
		sensor.set_context(_screen(Vector2(player_x+facing*12,_ground()-height*0.88)),sensor.travel_speed*SPEED,zoom)
		dialogue_panel.follow_head(_dialogue_head())

func _screen(point: Vector2) -> Vector2:
	var anchor := camera_anchor
	return (point - Vector2(camera_x, 0) + layout.offset() - anchor) * zoom + anchor

func _draw() -> void:
	if textures.is_empty():
		return
	night_seam.refresh(self)
	var anchor := camera_anchor
	draw_set_transform(_world_origin(), 0, Vector2.ONE * zoom)
	if scene_index < continuous_count():
		panorama.draw_back(self,self)
		if scene_index==1 and (active_id=="s2-cloud" or completed.has("s2-cloud")):
			var shadow:=0.5+0.5*sin(elapsed*0.36)
			var begin:=maxf(0,float(story.scenes[1].start)-camera_x)
			draw_polygon(PackedVector2Array([Vector2(begin,400),Vector2(begin+1280,400),Vector2(begin+1280,720),Vector2(begin,720)]),PackedColorArray([Color(0.12,0.21,0.31,0),Color(0.12,0.21,0.31,0),Color(0.12,0.21,0.31,shadow*0.16),Color(0.12,0.21,0.31,shadow*0.16)]))
	_draw_points()
	actor_material.set_shader_parameter("cutout",1.0 if pose in ["water","wind"] or action_player.contains(pose) else 0.0)
	actor_material.set_shader_parameter("standing_cleanup",pose=="idle")
	actor_canvas.queue_redraw()
	foreground_front.queue_redraw()
	psd_foreground_front.queue_redraw()
	creek_foreground_front.queue_redraw()
	for cover in night_foregrounds:cover.queue_redraw()
	night_canvas.queue_redraw()
	if morning_canvas!=null:morning_canvas.queue_redraw()
	if glasses_canvas!=null:glasses_canvas.queue_redraw()
	passage_fog_front.queue_redraw()
	transition_front.queue_redraw()
	debug_overlay.queue_redraw()

func _draw_actor(canvas: CanvasItem) -> void:
	if frames.is_empty():return
	var index:=current_frame()
	var texture: Texture2D = frames[pose][index]
	var origin: Vector2 = pose_origins[pose][index]
	var scale_factor: float = pose_scales[pose][index] * float(layout.data.player_scale)
	var x := _actor_x() - camera_x
	var body_breath:=1.0+sin(elapsed*2.1)*0.004 if pose in ["water","wind"] else 1.0
	canvas.draw_set_transform(_world_origin() + Vector2(x, _actor_ground()) * zoom, 0, Vector2(facing, body_breath) * zoom)
	canvas.draw_texture_rect(texture, Rect2(-origin * scale_factor, texture.get_size() * scale_factor), false)

func _tile(texture: Texture2D, offset: float) -> void:
	var width := 1697.0
	var first := int(floor(offset / width)) - 1
	for index in range(first, first + 5):
		var x := index * width - offset
		if index % 2 != 0:
			draw_set_transform(_world_origin() + Vector2(x + width, 0) * zoom, 0, Vector2(-zoom, zoom))
		else:
			draw_set_transform(_world_origin() + Vector2(x, 0) * zoom, 0, Vector2.ONE * zoom)
		draw_texture_rect(texture, Rect2(0, 0, width + 1, 720), false)
	draw_set_transform(_world_origin(), 0, Vector2.ONE * zoom)

func _prepare_origins() -> void:
	var opaque_bounds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/creek/pose-bounds.json"))
	for action in frames:
		pose_origins[action] = []
		pose_scales[action] = []
		pose_heights[action] = []
		if action == "walk_v2":
			RunCycle.prepare_origins(self)
			continue
		if action_player.contains(action):
			var clip: Dictionary=action_player.clips[action]
			for i in range(int(clip.count)):
				pose_origins[action].append(Vector2(float(clip.origins[i][0]),float(clip.origins[i][1])))
				pose_scales[action].append(float(clip.scale))
				pose_heights[action].append(float(clip.heights[i])*float(clip.scale))
			continue
		for texture: Texture2D in frames[action]:
			var image := texture.get_image()
			var bounds := image.get_used_rect()
			if opaque_bounds.has(action):
				var b: Array=opaque_bounds[action]
				bounds=Rect2i(int(b[0]),int(b[1]),int(b[2])-int(b[0]),int(b[3])-int(b[1]))
			var torso_left := image.get_width()
			var torso_right := 0
			var band_top := bounds.position.y + int(bounds.size.y * 0.25)
			var band_bottom := bounds.position.y + int(bounds.size.y * 0.45)
			for y in range(band_top, band_bottom, 3):
				for x in range(bounds.position.x, bounds.end.x):
					if image.get_pixel(x, y).a > 0.5:
						torso_left = mini(torso_left, x)
						torso_right = maxi(torso_right, x)
			var pivot_x := (torso_left + torso_right) * 0.5
			if action in ["water","wind"]:
				var foot_left:=image.get_width()
				var foot_right:=0
				for y in range(bounds.end.y-int(bounds.size.y*0.12),bounds.end.y,3):
					for x in range(bounds.position.x,bounds.end.x,2):
						if image.get_pixel(x,y).a>0.6:
							foot_left=mini(foot_left,x)
							foot_right=maxi(foot_right,x)
				pivot_x=(foot_left+foot_right)*0.5
			pose_origins[action].append(Vector2(pivot_x, bounds.end.y))
			var factor := 152.0 / 620.0 if action == "crouch" else 132.0 / maxf(1, bounds.size.y)
			if action=="water":factor=98.0/maxf(1,bounds.size.y)
			pose_scales[action].append(factor)
			pose_heights[action].append(bounds.size.y*factor)

func current_frame() -> int:
	if pose=="idle":return 0
	if action_player.contains(pose):return action_player.frame(pose,animation_time)
	if pose=="walk_v2":return mini(int(walk_phase*frames[pose].size()),frames[pose].size()-1)
	if pose=="crouch":return mini(int(animation_time/0.14),3)
	return int(animation_time/0.6)%frames[pose].size()

func current_scene() -> Dictionary:
	return story.scenes[scene_index]

func continuous_count() -> int:
	return int(story.world.get("continuous_scene_count",3))

func in_passage12() -> bool:
	var passage: Dictionary=story.world.get("passage12",{})
	return not passage.is_empty() and player_x>=float(passage.start) and player_x<float(passage.end)

func editable_layers() -> Array:
	return layout.passage_layer_order if in_passage12() else layout.layers_for_scene(scene_index)

func point_position(point: Dictionary) -> Vector2:
	if str(point.get("id",""))=="s5-morning-glasses":return glasses_support_position()
	return layout.point_position(point,camera_x)

func glasses_support_position()->Vector2:return night.support_position(self)

func interaction_cue_world(point:Dictionary)->Vector2:
	return point_position(point) if str(point.get("type",""))=="water" or str(point.get("id","")) in ["s5-willow","s5-morning-glasses"] else point_position(point)-Vector2(0,35)

func point_by_id(id: String) -> Dictionary:
	for point in points():
		if str(point.id)==id:return point
	return {}

func next_pending() -> Dictionary:
	for point in points():
		if not completed.has(point.id):return point
	return {}

func point_available(point:Dictionary)->bool:
	if point.id=="s5-willow" and not second_night_ready:return false
	for id in point.get("requires",[]):
		if not completed.has(id):return false
	return true

func check_approach() -> void:
	if action_player.busy() or not dialogue.is_empty() or not active_id.is_empty() or finished or debug_editor.visible:return
	for point in points():
		if point_available(point) and absf(player_x-point_position(point).x)<=approach_radius(point):introduced[str(point.id)]=true

func _world_origin() -> Vector2:
	return camera_anchor * (1.0-zoom) + layout.offset()*zoom

func screen_to_world(point: Vector2) -> Vector2:
	return (point-camera_anchor)/zoom+camera_anchor+Vector2(camera_x,0)-layout.offset()

func _tile_region(texture: Texture2D, offset: float, from_y: float, to_y: float) -> void:
	var width := 1697.0
	var first := int(floor(offset/width))-1
	var height := maxf(0,to_y-from_y)
	if height<=0:return
	var source := Rect2(0,texture.get_height()*from_y/720.0,texture.get_width(),texture.get_height()*height/720.0)
	for index in range(first,first+5):
		var x := index*width-offset
		if index%2!=0:
			draw_set_transform(_world_origin()+Vector2(x+width,0)*zoom,0,Vector2(-zoom,zoom))
		else:
			draw_set_transform(_world_origin()+Vector2(x,0)*zoom,0,Vector2.ONE*zoom)
		draw_texture_rect_region(texture,Rect2(0,from_y,width+1,height),source)
	draw_set_transform(_world_origin(),0,Vector2.ONE*zoom)

func _draw_points() -> void:
	if morning!=null and morning.active:return
	for point in points():
		var root_pos := point_position(point)-Vector2(camera_x,0)
		if root_pos.x < -150 or root_pos.x > 1430:continue
		if point.has("layer_id"):
			pass # The PSD layer draws its own pixels; only the interaction cue is added here.
		elif point.has("prop"):
			var key:=str(point.prop)
			var source: Rect2=prop_regions[key]
			var width:=float(point.get("prop_width",100))
			var height:=width*source.size.y/source.size.x
			var sway:=sin(elapsed*2.3)*0.025 if key=="wind" else 0.0
			draw_set_transform(_world_origin()+root_pos*zoom,sway,Vector2.ONE*zoom)
			draw_texture_rect_region(textures["prop_"+key],Rect2(-width/2,-height,width,height),source)
			draw_set_transform(_world_origin(),0,Vector2.ONE*zoom)
		elif scene_index==0 and str(point.type) in ["grass","flower"]:
			var texture: Texture2D = textures.flower
			var bounds := Rect2(120,150,1160,870)
			var plant_height := 64.0
			var plant_width := plant_height*bounds.size.x/bounds.size.y
			draw_texture_rect_region(texture,Rect2(root_pos-Vector2(plant_width/2,plant_height),Vector2(plant_width,plant_height)),bounds)
		elif not bool(point.get("action_only",false)):
			draw_circle(root_pos-Vector2(0,30),5,Color(0.85,0.9,0.67,0.55))
	water.draw_surface(self,self)


func _draw_debug(canvas: CanvasItem) -> void:
	if not debug_editor.visible:return
	canvas.draw_set_transform(_world_origin(),0,Vector2.ONE*zoom)
	canvas.draw_line(Vector2(0,_ground()),Vector2(1280,_ground()),Color("8bf4d7"),1,true)
	for point in points():
		var pos:=point_position(point)-Vector2(camera_x,0)
		var color:=Color("ffe5a5") if str(point.id)==debug_editor.selected_id else Color("9ff8e0")
		canvas.draw_arc(pos,12,0,TAU,32,color,1,true)
		canvas.draw_line(pos-Vector2(18,0),pos+Vector2(18,0),color,1,true)
		canvas.draw_line(pos-Vector2(0,18),pos+Vector2(0,18),color,1,true)
		canvas.draw_string(font,pos+Vector2(18,-14),str(point.id)+"  "+str(point_position(point).round()),HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
		if str(point.id)==debug_editor.selected_id:
			canvas.draw_line(pos+Vector2(-approach_radius(point),-30),pos+Vector2(approach_radius(point),-30),Color(color,0.4),1,true)

func approach_radius(point: Dictionary) -> float:
	return clampf(float(point.get("approach_radius",APPROACH_RADIUS)),8,300)

func interaction_radius(point: Dictionary) -> float:
	return clampf(float(point.get("interact_radius",INTERACT_RADIUS)),8,180)

func _draw_foreground(canvas: CanvasItem) -> void:
	if scene_index>=continuous_count() or textures.is_empty():return
	var entry: Dictionary=layout.layer_parameters(str(story.scenes[0].get("foreground_layer","meadow1_near")))
	if not entry.is_empty():
		foliage_material.set_shader_parameter("layer_position",layout.layer_position(entry))
		foliage_material.set_shader_parameter("layer_extent",Vector2(float(entry.w),float(entry.h))*float(entry.scale))
		foliage_material.set_shader_parameter("ground_y",layout.ground(story.scenes[0]))
		foliage_material.set_shader_parameter("overlap",float(layout.data.overlap))
	panorama.draw_front(canvas,self)

func _draw_psd_foreground(canvas: CanvasItem) -> void:
	if scene_index>=continuous_count() or textures.is_empty():return
	var entry: Dictionary=layout.layer_parameters("ground")
	if entry.is_empty() or not bool(entry.visible):return
	psd_foliage_material.set_shader_parameter("layer_position",layout.layer_position(entry))
	psd_foliage_material.set_shader_parameter("layer_extent",Vector2(float(entry.w),float(entry.h))*float(entry.scale))
	psd_foliage_material.set_shader_parameter("ground_y",layout.ground(story.scenes[2]))
	psd_foliage_material.set_shader_parameter("overlap",float(layout.data.overlap))
	panorama.draw_psd_ground_cover(canvas,self,entry)

func _draw_creek_foreground(canvas: CanvasItem) -> void:
	if scene_index>=continuous_count() or textures.is_empty():return
	var entry: Dictionary=layout.layer_parameters(str(story.scenes[1].get("foreground_layer","creek_ground")))
	if entry.is_empty() or not bool(entry.visible):return
	creek_foliage_material.set_shader_parameter("layer_position",layout.layer_position(entry))
	creek_foliage_material.set_shader_parameter("layer_extent",Vector2(float(entry.w),float(entry.h))*float(entry.scale))
	creek_foliage_material.set_shader_parameter("ground_y",layout.ground(story.scenes[1]))
	creek_foliage_material.set_shader_parameter("overlap",float(layout.data.overlap))
	var contact:=_actor_ground() if scene_index==1 else layout.ground(story.scenes[1])
	var rectangle: Rect2=panorama.psd_rect(self,entry)
	creek_foliage_material.set_shader_parameter("contact_center",Vector2(_actor_x()-camera_x-rectangle.position.x+float(entry.x),contact))
	creek_foliage_material.set_shader_parameter("contact_radius",65. if scene_index==1 and pose=="water" else 0.)
	panorama.draw_psd_ground_cover(canvas,self,entry)

func _draw_night_foreground(canvas: CanvasItem,index: int) -> void:
	if scene_index>=continuous_count() or textures.is_empty():return
	if not scenery_visible(index):return
	if night_seam.active(self):
		if index==3:night_seam.draw_front(canvas,self)
		return
	var entry: Dictionary=layout.layer_parameters("moon%d_ground"%[index+1])
	if entry.is_empty() or not bool(entry.visible):return
	var material: ShaderMaterial=canvas.material
	if material.shader!=preload("res://shaders/psd_grass_cover.gdshader"):material.shader=preload("res://shaders/psd_grass_cover.gdshader")
	var source_uv:=Vector4(0,0,1,1)
	material.set_shader_parameter("source_uv_rect",source_uv)
	material.set_shader_parameter("layer_position",layout.layer_position(entry))
	material.set_shader_parameter("layer_extent",Vector2(float(entry.w),float(entry.h))*float(entry.scale))
	material.set_shader_parameter("ground_y",layout.ground(story.scenes[index]))
	material.set_shader_parameter("overlap",float(layout.data.overlap))
	panorama.draw_psd_ground_cover(canvas,self,entry)

func _cross_creek_border(index: int) -> void:
	# Night four/five share continuous movement; cinematic time changes are explicit.
	scene_index=index
	var sc: Dictionary=current_scene()
	chapter.text=sc.no+"  /  "+sc.name
	near_point={}
	pending_intro_id=""
	if not visited_scenes.has(index):
		visited_scenes[index]=true
		if index>=3:
			if index==3 and not sunset_done:night.begin_scene()
			dialogue_phase="enter"
			_open_dialogue(sc.get("enter",[]))

func scenery_visible(index:int)->bool:
	if morning!=null and morning.active:return index==4
	if scene_index==2 and not sunset_done:return index==2
	if scene_index>=3 and sunset_done:return index>=3
	return index<2 if scene_index<2 else index>=2

func _draw_mist()->void:
	if morning!=null and morning.active:return
	if not playing or (grassland!=null and grassland.visible):return
	mist.draw(marker_canvas,self)

func _begin_grassland()->void:
	sensor.stop_voice()
	playing=false;moving=false;dialogue.clear();active_id="";near_point={};pending_intro_id="";action_override="";action_player.reset();pose="idle"
	dialogue_panel.hide();sensor.hide();hint.hide();progress.hide();chapter.hide()
	grassland.begin()

func _prepare_after_grassland()->void:
	for point in story.interactions:
		if int(point.scene)<=2:completed[point.id]=true
	_enter_scene(2);playing=false;dialogue_panel.hide();sensor.hide();hint.hide();chapter.hide()
	sensor.stop_voice()

func _finish_grassland()->void:
	playing=true;sensor.show();hint.show();_show_line()

func _begin_morning() -> void:
	if morning.active or morning.busy:return
	morning.muted=prologue.muted
	morning.weather=story.scene5_morning.weather.duplicate()
	playing=false;moving=false;pose="idle";action_override="";action_player.reset()
	sensor.stop_voice();sensor.hide();dialogue_panel.hide();hint.hide();chapter.hide();progress.hide();debug_editor.hide()
	for child in ui.get_children():
		if child is Button:child.hide()
	morning.begin_return()

func _prepare_morning() -> void:
	for key in morning.skin_textures:textures["psd_moon5_"+str(key)]=morning.skin_textures[key]
	scene_index=4;player_x=float(story.scenes[4].start)+640;camera_x=float(story.scenes[4].start)+200;facing=1;zoom=1;pose="idle";moving=false
	camera_anchor=Vector2(440,_ground());near_point={};pending_intro_id="";dialogue.clear();active_id="";night.fade=0
	queue_redraw()

func _arrive_morning() -> void:
	playing=true;hint.text="";hint.show();dialogue_phase="enter";_open_dialogue(story.scene5_morning.entry_lines)

func _recover_morning_glasses() -> void:
	actor_canvas.show()
	playing=true;sensor.show();hint.hide();active_id="s5-morning-glasses";dialogue_phase="response"
	var lines:Array=point_by_id(active_id).lines.duplicate(true)
	var memory:=_travel_memory_line()
	if not memory.is_empty():lines.insert(7,{"who":"我","tone":"me","text":memory,"source":"实际旅行互动记忆"})
	_open_dialogue(lines)

func _travel_memory_line()->String:
	if travel_memory.has("water") and travel_memory.has("flower"):return "我还记得那朵小花，还有溪水从指尖流过去的清凉。和你一起看过，我才发现这些。"
	if travel_memory.has("water"):return "我还记得溪水从指尖流过去的清凉。是你让我重新感觉到了它。"
	if travel_memory.has("birds"):return "我还记得我们一起听过的鸟鸣。原来这些细小的声音，也值得停下来。"
	if travel_memory.has("flower"):return "我还记得那朵在指尖旁轻轻晃动的小花。以后我会多留意一些这样的风景。"
	return ""

func _hear_morning_bird() -> void:
	playing=true;sensor.show();hint.hide();active_id="s5-morning-bird";dialogue_phase="response"
	sensor.sample({"sound":1.0,"vision":.2},"bird",Vector2(.7,-.3))
	_open_dialogue(point_by_id(active_id).lines.slice(2))

func _cancel_morning_interaction() -> void:
	playing=true;hint.show();actor_canvas.show()
	if morning.recovered:sensor.show()

func _begin_ending() -> void:
	if ending_entry.visible:return
	playing=false;finished=true;moving=false;active_id="";action_override="";pose="idle";sensor.stop_voice();sensor.hide();hint.hide();dialogue_panel.hide();chapter.hide();progress.hide()
	morning.fade_audio();ending_entry.begin({"fresh":true,"audio_enabled":not morning.muted,"entry_source":"scene5_morning","covered_by_transition":true})

func _return_from_ending() -> void:
	return_to_main_menu()

func nearest_unfinished_point()->Dictionary:
	var best:Dictionary={};var distance:=INF
	for point in points():
		if completed.has(point.id) or not point_available(point):continue
		var d:=absf(player_x-point_position(point).x)
		if d<distance:distance=d;best=point
	return best

func return_to_main_menu()->void:
	if narrative_audio!=null:narrative_audio.reset()
	if settings_menu!=null:settings_menu.close_menu()
	ChapterTransition.cancel()
	if AudioSettings.opened:AudioSettings.close_panel()
	get_tree().paused=false;playing=false;moving=false;dialogue.clear();active_id="";pending_intro_id="";action_override="";action_player.reset();water.reset()
	prologue._close_modal(false);prologue.hide()
	for page in grassland.page_controls:
		if page.has_method("set_active"):page.set_active(false)
	grassland.wind.stop();grassland.sound.stop();grassland.music.stop();grassland.hide()
	sunset.close();stone.close();morning.reset();ending_entry.close()
	if transparent_earth!=null:transparent_earth.close()
	dialogue_panel.hide();sensor.hide();chapter.hide();hint.hide();progress.hide();debug_editor.hide()
	title.show_menu();music_director.synchronize();get_viewport().set_input_as_handled()

func open_chapter(number:int)->void:
	return_to_main_menu();title.hide()
	match number:
		1:
			var shown:bool=await ChapterTransition.play(1,self,func():prologue.begin(true);prologue.intro_blocked=true;ChapterTransition.destination_ready(self))
			if shown:prologue.intro_blocked=false
		2:
			start_game();await ChapterTransition.play(2,self,func():ChapterTransition.destination_ready(self))
		3:
			_begin_ending()
		4:
			_begin_transparent_earth()

func _begin_transparent_earth()->void:
	if not ResourceLoader.exists("res://scripts/transparent_earth.gd"):return_to_main_menu();return
	playing=false;moving=false;title.hide();prologue.hide();grassland.hide();dialogue_panel.hide();sensor.hide();hint.hide()
	ending_entry.close()
	if transparent_earth==null:
		transparent_earth=load("res://scripts/transparent_earth.gd").new();transparent_earth.z_index=130;ui.add_child(transparent_earth);transparent_earth.return_to_title_requested.connect(return_to_main_menu)
	transparent_earth.begin()

func _on_audio_panel_toggled(opened:bool)->void:
	if not opened:return
	for action in ["move_left","move_right","slow_walk","interact","advance"]:
		if InputMap.has_action(action):Input.action_release(action)
	moving=false
	if active_id.is_empty() and not water.active and not action_player.busy():pose="idle"
	if grassland!=null and grassland.visible:grassland._release_hold(false)
	if morning!=null:morning.wiping=false

func _apply_subtitle_settings()->void:
	if grassland!=null:grassland.apply_subtitle_style(layout.subtitles())
	if morning!=null and morning.has_method("apply_subtitle_style"):morning.apply_subtitle_style(layout.subtitles())
	if stone!=null:stone.apply_subtitle_style(layout.subtitles())

func _subtitle_debug_visibility_changed()->void:
	if grassland!=null and grassland.visible and grassland._current!=null:
		var page=grassland._current
		if debug_editor.visible:subtitle_debug_was_paused=page.paused;page.debug_blocked=true;page.set_paused(true,false)
		else:page.debug_blocked=false;page.set_paused(subtitle_debug_was_paused,false)
	if morning!=null and "debug_blocked" in morning:morning.debug_blocked=debug_editor.visible
	if stone!=null:stone.debug_blocked=debug_editor.visible

func _complete_stone_placement()->void:
	playing=true;sensor.show();active_id="s5-willow";dialogue_phase="response";action_override="idle"
	_open_dialogue(point_by_id(active_id).lines.slice(4))

func _cancel_stone_placement()->void:
	playing=true;hint.show();sensor.show();near_point={}

func _remember_experience(kind:String)->void:
	var id:String={"creek":"water","listen":"birds"}.get(kind,kind)
	if id in ["flower","grass","birds","water","wind","panorama"]:travel_memory[id]=true

func _hold_world_for_sunset()->void:
	playing=false;moving=false;dialogue.clear();active_id="";near_point={};pending_intro_id="";action_override="";action_player.reset();pose="idle"
	sensor.stop_voice();sensor.hide();dialogue_panel.hide();hint.hide();chapter.hide();progress.hide();debug_editor.hide()
	marker_canvas.queue_redraw()
	for child in ui.get_children():
		if child is Button:child.hide()

func _begin_sunset()->void:
	if sunset.visible or sunset_done:return
	sunset_return_context={"player_x":player_x,"camera_x":camera_x,"facing":facing,"zoom":zoom,"camera_anchor":camera_anchor}
	_hold_world_for_sunset();sunset.begin({"kind":"sunset","audio_enabled":not prologue.muted})

func _begin_second_rest()->void:
	_hold_world_for_sunset();sunset.begin({"kind":"second_rest","audio_enabled":not prologue.muted})

func _prepare_moon_after_sunset()->void:
	completed["s3-sunset"]=true;sunset_done=true;await _prepare_night_world()

func _prepare_second_night()->void:
	second_night_ready=true;await _prepare_night_world()

func _prepare_night_world()->void:
	var token:int=sunset.serial
	_enter_scene(3);playing=false;dialogue.clear();dialogue_panel.hide();sensor.stop_voice();sensor.hide();hint.hide();night.fade=0
	player_x=float(story.scenes[3].start)+230;camera_x=float(story.scenes[3].start);camera_anchor=Vector2(230,_ground());facing=1;zoom=1
	marker_canvas.queue_redraw()
	queue_redraw();await get_tree().process_frame
	if DisplayServer.get_name()!="headless":await RenderingServer.frame_post_draw
	if sunset.visible and token==sunset.serial:sunset.acknowledge_moon_ready()

func _arrive_first_moon()->void:
	prologue.muted=sunset.muted;playing=true;sensor.show();hint.text="";hint.show();dialogue_phase="enter"
	_open_dialogue(story.scenes[3].get("enter",[]))

func _arrive_second_night()->void:
	prologue.muted=sunset.muted;playing=true;sensor.show();hint.text="";hint.show();dialogue_phase="enter";_open_dialogue([])

func _cancel_sunset()->void:
	if sunset_return_context.is_empty():return
	player_x=float(sunset_return_context.player_x);camera_x=float(sunset_return_context.camera_x);facing=float(sunset_return_context.facing)
	zoom=float(sunset_return_context.zoom);camera_anchor=sunset_return_context.camera_anchor
	prologue.muted=sunset.muted;playing=true;sensor.show();hint.show();check_approach()
