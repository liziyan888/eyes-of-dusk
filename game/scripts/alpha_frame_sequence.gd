extends Control
## Baked RGBA frames, registered on the original full video canvas.
## Atlas trimming changes storage only; it never changes a pose's world pivot.
signal finished
var manifest:Dictionary={}
var sheets:Array[Texture2D]=[]
var frame_index:=0
var elapsed:=0.0
var playing:=false

func configure(path:String)->void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	manifest=JSON.parse_string(FileAccess.get_file_as_string(path))
	for sheet in manifest.sheets:
		sheets.append(load(path.get_base_dir().path_join(str(sheet))))
	mouse_filter=MOUSE_FILTER_IGNORE
	queue_redraw()

func play()->void:
	elapsed=0.0;frame_index=0;playing=true;queue_redraw()

func stop()->void:
	playing=false

func reset()->void:
	playing=false;elapsed=0.0;frame_index=0;queue_redraw()

func hold_end()->void:
	playing=false;elapsed=float(manifest.duration);frame_index=int(manifest.frameCount)-1;queue_redraw()

func advance(delta:float)->void:
	if not playing:return
	elapsed+=delta
	var next:=mini(int(elapsed*float(manifest.fps)),int(manifest.frameCount)-1)
	if next!=frame_index:frame_index=next;queue_redraw()
	if elapsed>=float(manifest.duration):playing=false;finished.emit()

func _draw()->void:
	if manifest.is_empty() or sheets.is_empty():return
	var frame:Dictionary=manifest.frames[frame_index]
	var source:Array=manifest.canvas
	var factor:=size/Vector2(float(source[0]),float(source[1]))
	var offset:Array=frame.offset
	var region:Array=frame.region
	var destination:=Rect2(Vector2(float(offset[0]),float(offset[1]))*factor,Vector2(float(region[2]),float(region[3]))*factor)
	draw_texture_rect_region(sheets[int(frame.sheet)],destination,Rect2(float(region[0]),float(region[1]),float(region[2]),float(region[3])))
