extends Node
## Optional delivery hooks. Missing commissioned recordings never become fake placeholders.
const ART:="res://assets/audio-polish-v1/"
var played:Dictionary={}
var voices:Array[AudioStreamPlayer]=[]
var pending_events:Array[String]=[]

func play_once(event:String)->bool:
	if played.has(event):return false
	var files:={"moon_hum":"A02_girl_moonlight_hum.wav","rain_sob":"A03_girl_rain_sob.wav"}
	if not files.has(event):return false
	var path:String=ART+files[event]
	if not ResourceLoader.exists(path):
		if not pending_events.has(event):pending_events.append(event)
		return false
	var voice:=AudioStreamPlayer.new();voice.bus="Voice";voice.stream=load(path);voice.volume_db=-4.0 if event=="moon_hum" else -2.0
	voice.set_meta("event",event);add_child(voice);voices.append(voice);played[event]=true
	voice.finished.connect(func():voices.erase(voice);voice.queue_free());voice.play();return true

func on_world_line(point_id:String,text:String)->bool:
	if text.contains("不哭了"):stop_event("rain_sob");return false
	if point_id=="s4-moon" and (text.contains("哼") or text.contains("吟唱")):return play_once("moon_hum")
	if point_id=="s5-morning-glasses" and (text.contains("抽泣") or text.contains("哭")):return play_once("rain_sob")
	return false

func stop_event(event:String)->void:
	for voice in voices:
		if str(voice.get_meta("event",""))!=event or voice.has_meta("fading"):continue
		voice.set_meta("fading",true);var fade:=voice.create_tween()
		fade.tween_method(func(value:float):voice.volume_db=linear_to_db(maxf(value,.0001)),db_to_linear(voice.volume_db),0.0,2.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		fade.tween_callback(func():voices.erase(voice);voice.queue_free())

func world_context(point_id:String,scene_index:=-1)->void:
	# Let the phrase finish while the player is still quietly beneath the moon.
	# Another interaction or leaving this scene fades it away.
	if (not point_id.is_empty() and point_id!="s4-moon") or (point_id.is_empty() and scene_index!=3):stop_event("moon_hum")
	if point_id!="s5-morning-glasses":stop_event("rain_sob")

func has_active_voice()->bool:
	for voice in voices:
		if is_instance_valid(voice) and voice.playing and voice.volume_db> -50:return true
	return false

func reset()->void:
	for voice in voices:voice.stop();voice.queue_free()
	voices.clear();played.clear();pending_events.clear()
