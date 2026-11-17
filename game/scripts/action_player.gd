extends RefCounted
## MiniMax entry -> matched hold loop -> authored return. Fixed-time, no sprite teleport.
var clips: Dictionary={}
var returning := ""
var return_time := 0.0
var return_from := 0
var reverse_entry := false
func setup() -> void:
	clips=JSON.parse_string(FileAccess.get_file_as_string("res://assets/actions/manifest.json"))
func contains(pose: String) -> bool:return clips.has(pose)
func busy() -> bool:return not returning.is_empty()
func frame(pose: String,time: float) -> int:
	var clip: Dictionary=clips[pose]
	if returning==pose:
		var steps:=int(return_time*float(clip.fps))
		return maxi(0,return_from-steps) if reverse_entry else mini(int(clip.exit_end),return_from+steps)
	var tick:=int(time*float(clip.fps))
	if tick<int(clip.loop_start):return tick
	return int(clip.loop_start)+(tick-int(clip.loop_start))%maxi(1,int(clip.loop_end)-int(clip.loop_start))
func finish(pose: String,time: float) -> void:
	if not contains(pose):return
	var clip: Dictionary=clips[pose]
	var visible_frame:=frame(pose,time)
	returning=pose
	return_time=0
	reverse_entry=visible_frame<int(clip.loop_start)
	return_from=visible_frame if reverse_entry else int(clip.exit_start)
func update(delta: float) -> void:
	if not busy():return
	return_time+=delta
	var clip: Dictionary=clips[returning]
	var steps:=int(return_time*float(clip.fps))
	if (reverse_entry and steps>return_from) or (not reverse_entry and return_from+steps>int(clip.exit_end)):
		returning=""
func reset() -> void:
	returning=""
	return_time=0
