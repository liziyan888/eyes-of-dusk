extends Node
## Owns the cover, world, vignettes and final-film score. The ending reader
## keeps its own continuous music through the embedded incident archive.
const CONFIG:="res://data/music_cues.json"
var game:Node
var cues:Dictionary={}
var players:Array[AudioStreamPlayer]=[]
var slot_cues:Array[String]=["",""]
var slot_parts:Array[String]=["",""]
var weights:Array[float]=[0.0,0.0]
var from_weights:Array[float]=[0.0,0.0]
var to_weights:Array[float]=[0.0,0.0]
var current_slot:=-1
var current_cue:=""
var score_owner:=""
var fade_time:=0.0
var fade_duration:=5.0
var duck_db:=0.0
var target_duck_db:=0.0
var context_db:=0.0
var target_context_db:=0.0
var paused:=false
var starts:Dictionary={}
var stream_cache:Dictionary={}
var diagnostics:Array[Dictionary]=[]
var manual_preview:=false

func setup(context:Node)->void:
	game=context

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	add_to_group("new_game_score")
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	if parsed is Dictionary:cues=parsed.get("cues",{})
	var delivered:="res://assets/audio-polish-v1/A01_transparent_earth_loop.wav"
	if ResourceLoader.exists(delivered):
		var stream:=load(delivered) as AudioStreamWAV
		cues["T01"]={"full":delivered,"loop":delivered,"full_seconds":stream.get_length(),"loop_seconds":stream.get_length(),"loop_frames":roundi(stream.get_length()*stream.mix_rate),"gain_db":-8.5,"fade_seconds":5.0,"intro_to_loop_crossfade_seconds":5.0}
	for i in range(2):
		var player:=AudioStreamPlayer.new();player.name="Score"+str(i);player.bus="Music";player.volume_db=-80;player.process_mode=Node.PROCESS_MODE_ALWAYS;add_child(player);players.append(player)
	if not manual_preview:synchronize()

func _stream(cue:String,part:String)->AudioStream:
	var key:=cue+":"+part
	if stream_cache.has(key):return stream_cache[key]
	var stream:=load(str(cues[cue][part])) as AudioStream
	if stream==null:return null
	stream=stream.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode=AudioStreamWAV.LOOP_FORWARD if part=="loop" else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin=0;stream.loop_end=int(cues[cue].loop_frames) if part=="loop" else 0
	stream_cache[key]=stream;return stream

func _begin_slot(index:int,cue:String,part:String)->bool:
	var stream:=_stream(cue,part)
	if stream==null:return false
	players[index].stop();players[index].stream=stream;players[index].volume_db=-80
	players[index].stream_paused=false;slot_cues[index]=cue;slot_parts[index]=part;players[index].play()
	starts[cue]=int(starts.get(cue,0))+1
	diagnostics.append({"cue":cue,"part":part,"slot":index,"at_ms":Time.get_ticks_msec()})
	if diagnostics.size()>100:diagnostics.pop_front()
	return true

func _fade_to(index:int,seconds:float)->void:
	from_weights.assign(weights);to_weights=[0.0,0.0]
	if index>=0:to_weights[index]=1.0
	fade_time=0;fade_duration=maxf(seconds,.01);current_slot=index

func select_cue(cue:String,source:String="",seconds:float=-1.0)->void:
	score_owner=source
	if cue==current_cue:return
	current_cue=cue
	if cue.is_empty():_fade_to(-1,4.5 if seconds<0 else seconds);return
	if not cues.has(cue):push_error("Unknown music cue: "+cue);current_cue="";_fade_to(-1,.5);return
	var slot:=-1
	for i in range(2):
		if slot_cues[i]==cue and players[i].playing:slot=i;break
	if slot<0:
		slot=0 if weights[0]<=weights[1] else 1
		if not _begin_slot(slot,cue,"full"):current_cue="";_fade_to(-1,.5);return
		weights[slot]=0
	_fade_to(slot,float(cues[cue].fade_seconds) if seconds<0 else seconds)

func synchronize()->void:
	if manual_preview or not is_instance_valid(game):return
	var wanted:="";var source:="";var attenuation:=0.0;var contextual:=0.0;var media_paused:=false
	if "transparent_earth" in game and game.transparent_earth!=null and game.transparent_earth.visible:
		wanted="T01" if cues.has("T01") else "M05";source="transparent_earth"
		if game.transparent_earth.reprise.playing:attenuation=-11
		if game.transparent_earth.finishing:wanted="";source="transparent_earth_end"
	elif game.ending_entry!=null and game.ending_entry.visible:
		source="existing_ending"
	elif game.morning!=null and game.morning.active:
		wanted="M06";source="morning"
		if game.morning.mode in ["listen","hearing"]:attenuation=-8
		elif game.morning.busy:attenuation=-3
	elif game.morning!=null and game.morning.busy:
		wanted="M05";source="morning_transition";contextual=-5
	elif game.sunset!=null and game.sunset.visible:
		wanted="M05" if game.sunset.kind=="second_rest" or game.sunset.phase in ["preparing_night","revealing_night"] else "M04";source="sunset"
		if game.sunset.wind_heard and game.sunset.phase=="dialogue":attenuation=-6
		elif not game.sunset.lines.is_empty():attenuation=-2
		if game.sunset.phase in ["rest_transition","preparing_night"]:contextual=-3
		media_paused=game.sunset.paused
	elif game.grassland!=null and game.grassland.visible:
		wanted="M03";source="six_vignettes"
		var page:Control=game.grassland._current
		if is_instance_valid(page):
			media_paused=bool(page.get("paused")) if "paused" in page else false
			var phase:=str(page.get("phase")) if "phase" in page else ""
			if game.grassland.page_index in [3,4,5] and phase=="action":attenuation=-6
			elif phase in ["invite","intro","response"]:attenuation=-2
		if game.grassland.transitioning:contextual=-5
	elif game.prologue!=null and game.prologue.visible:
		wanted="M01";source="prologue"
		if game.prologue.modal!=null:attenuation=-2
	elif game.title!=null and game.title.visible:
		wanted="M01";source="cover";contextual=-3
	else:
		wanted="M02" if game.scene_index<2 else "M04" if game.scene_index==2 else "M05";source="world"
	if source=="world" or source=="morning":
		if not game.dialogue.is_empty():attenuation=minf(attenuation,-2)
		if game.water.active:attenuation=minf(attenuation,-5)
		if game.active_id=="s4-moon":attenuation=minf(attenuation,-6)
		if game.stone!=null and game.stone.visible:attenuation=minf(attenuation,-4)
	var chapter=get_node_or_null("/root/ChapterTransition")
	if chapter!=null and chapter.active:
		if chapter.chapter_id==3:wanted="";source="existing_ending"
		elif chapter.chapter_id==2:
			if chapter.phase in ["title_out","waiting_for_destination","reveal"]:wanted="M02";source="chapter_two"
			else:wanted="M01";source="chapter_two_cover";contextual=-7
		elif chapter.chapter_id==1:contextual=-2
	var settings=get_node_or_null("/root/AudioSettings")
	if "narrative_audio" in game and game.narrative_audio!=null and game.narrative_audio.has_active_voice():attenuation=minf(attenuation,-8)
	# The volume panel must keep the score audible for adjustment.
	paused=media_paused and not (settings!=null and settings.opened)
	target_duck_db=attenuation;target_context_db=contextual
	select_cue(wanted,source,3.4 if source=="transparent_earth_end" else -1.0)

func _process(delta:float)->void:
	if not manual_preview:synchronize()
	for player in players:player.stream_paused=paused
	if paused:return
	duck_db=move_toward(duck_db,target_duck_db,20.0*delta if target_duck_db<duck_db else 6.0*delta)
	context_db=move_toward(context_db,target_context_db,12.0*delta)
	# Play the complete supplied arrangement first, then continue its loop body.
	if current_slot>=0 and not current_cue.is_empty() and fade_time>=fade_duration:
		var source:AudioStreamPlayer=players[current_slot]
		if slot_parts[current_slot]=="full":
			var overlap:=float(cues[current_cue].intro_to_loop_crossfade_seconds)
			var remaining:=float(cues[current_cue].full_seconds)-source.get_playback_position()
			if remaining<=overlap or not source.playing:
				var next:=1-current_slot
				if _begin_slot(next,current_cue,"loop"):weights[next]=0;_fade_to(next,overlap)
	fade_time=minf(fade_duration,fade_time+delta)
	var progress:=smoothstep(0.0,1.0,fade_time/fade_duration)
	for i in range(2):
		weights[i]=lerpf(from_weights[i],to_weights[i],progress)
		if weights[i]>.0001 and not slot_cues[i].is_empty():
			players[i].volume_db=float(cues[slot_cues[i]].gain_db)+duck_db+context_db+linear_to_db(weights[i])
		else:players[i].volume_db=-80
		if fade_time>=fade_duration and to_weights[i]<=0 and players[i].playing:
			players[i].stop();players[i].stream=null;slot_cues[i]="";slot_parts[i]=""

func close()->void:
	for player in players:player.stop();player.stream=null
	current_cue="";current_slot=-1;weights=[0.0,0.0];to_weights=[0.0,0.0];from_weights=[0.0,0.0]
	stream_cache.clear()

func _exit_tree()->void:close()
