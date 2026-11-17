extends Control
## Decoded first/last posters prevent blank frames at either end of the movie.
signal playback_finished
var video:VideoStreamPlayer
var poster:TextureRect
var note:Label
var phase:="enter"
var manually_paused:=false
var suspended:=false
var done:=false
var decode_time:=0.0
var motion_tween:Tween
var last_frame:Texture2D

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS;size=Vector2(1280,720);mouse_filter=MOUSE_FILTER_STOP
	var background:=ColorRect.new();background.size=size;background.color=Color("101a29");background.mouse_filter=MOUSE_FILTER_IGNORE;add_child(background)
	poster=TextureRect.new();poster.size=size;poster.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;poster.stretch_mode=TextureRect.STRETCH_SCALE;poster.mouse_filter=MOUSE_FILTER_IGNORE;add_child(poster)
	video=VideoStreamPlayer.new();video.size=size;video.expand=true;video.bus="Effects";video.volume_db=-60;video.mouse_filter=MOUSE_FILTER_IGNORE;video.finished.connect(_movie_finished);add_child(video);video.hide()
	note=Label.new();note.text="已暂停 · Esc 继续";note.position=Vector2(40,665);note.size=Vector2(300,28);note.mouse_filter=MOUSE_FILTER_IGNORE
	var font:=WebSystemFont.new();font.font_names=PackedStringArray(["KaiTi","Microsoft YaHei"]);note.add_theme_font_override("font",font);note.add_theme_font_size_override("font_size",17);add_child(note);note.hide()
	modulate.a=0

func begin(spec:Dictionary)->void:
	poster.texture=load(str(spec.first_frame));last_frame=load(str(spec.last_frame));video.stream=load(str(spec.stream))
	phase="enter";motion_tween=create_tween();motion_tween.tween_property(self,"modulate:a",1.0,.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await motion_tween.finished
	if done:return
	phase="decode";video.play()

func toggle_pause()->void:manually_paused=not manually_paused

func _process(delta:float)->void:
	var volume=get_node_or_null("/root/AudioSettings")
	var should_pause:bool=manually_paused or get_tree().paused or Engine.time_scale==0 or (volume!=null and volume.opened)
	if should_pause!=suspended:
		suspended=should_pause;video.paused=suspended
		if motion_tween!=null and motion_tween.is_valid():
			if suspended:motion_tween.pause()
			else:motion_tween.play()
	note.visible=manually_paused
	if suspended or done:return
	if phase=="decode":
		decode_time+=delta
		var texture:=video.get_video_texture()
		if video.stream_position>1.0/48.0 and texture!=null and texture.get_width()>0:
			phase="playing";video.modulate.a=0;video.show();motion_tween=create_tween().set_parallel(true)
			motion_tween.tween_property(video,"modulate:a",1.0,.12)
			# The reader owns the continuous score. Movie audio contains another
			# mixed soundtrack; distinct QTE effects have their own players.
			video.volume_db=-80.0
		elif decode_time>6.0:
			push_warning("Ending memory movie could not decode; continuing the reader.");_movie_finished()

func _movie_finished()->void:
	if done:return
	poster.texture=last_frame;poster.show();video.hide();video.stop();phase="hold";done=true;playback_finished.emit()

func reveal_next_page()->void:
	phase="leave";motion_tween=create_tween();motion_tween.tween_property(self,"modulate:a",0.0,.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await motion_tween.finished

func close()->void:
	if motion_tween!=null and motion_tween.is_valid():motion_tween.kill()
	video.stop();hide()
	if not done:done=true;playback_finished.emit()
