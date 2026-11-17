extends RefCounted
## Original media stays intact. Every reader resolves the same measured mix assets.
static var assets:Dictionary={}
static func stream(path:String)->AudioStream:
	if assets.is_empty():
		var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/audio_mix.json"))
		if parsed is Dictionary:assets=parsed.get("assets",{})
	var resolved:=str(assets.get(path,path))
	var source:=load(resolved) as AudioStream
	if source==null:return null
	# Loop flags belong to each player; a one-shot must never inherit an ambient loop.
	var copy:=source.duplicate() as AudioStream;copy.set_meta("mix_source",path);copy.set_meta("mix_path",resolved);return copy
