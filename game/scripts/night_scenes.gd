extends RefCounted
## Moonlit atmosphere and the approved prop feedback; no new character animation is implied.
var fade := 0.0
var hang_progress := 0.0
var placement:Dictionary={}
var prop=preload("res://scripts/sensor_glasses.gd").new()

func reset() -> void:
	fade=0;hang_progress=0;placement.clear()

func place(_game:Node,orientation:float)->void:
	placement={"placed":true,"support":"branch","point_id":"s5-willow","orientation":clampf(orientation,0,1)};hang_progress=1

func support_position(game:Node)->Vector2:
	var point:=glasses_point(game)
	return game.layout.point_position(point,game.camera_x) if not point.is_empty() else Vector2.ZERO

func begin_scene() -> void:
	fade=1.0

func update(delta: float,game: Node) -> void:
	fade=maxf(0,fade-delta*1.2)
	if game.active_id=="s5-willow" and game.line_index>=2:hang_progress=minf(1,hang_progress+delta/1.8)
	elif game.completed.has("s5-willow"):hang_progress=1
	else:hang_progress=0

func glasses_point(game: Node) -> Dictionary:
	for point in game.story.interactions:
		if point.id=="s5-willow":return point
	return {}

func draw(canvas: CanvasItem,game: Node) -> void:
	if game.morning!=null and game.morning.active:return
	if game.scene_index>=game.continuous_count():return
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	for index in [3,4]:
		if not game.scenery_visible(index):continue
		var sc: Dictionary=game.story.scenes[index]
		var left:=maxf(0,float(sc.start)-game.camera_x)
		var right:=minf(1280,float(sc.end)-game.camera_x)
		if right<=left:continue
		var entry: Dictionary=game.layout.layer_parameters("moon%d_ground"%[index+1])
		if entry.is_empty() or not bool(entry.visible):continue
		var rect: Rect2=game.panorama.psd_rect(game,entry)
		var scale: float=entry.scale
		# Low-contrast cloud shadows drift across the painted ground.
		var shade:=.022+.018*sin(game.elapsed*.25)
		canvas.draw_polygon(PackedVector2Array([Vector2(left,570),Vector2(right,570),Vector2(right,720),Vector2(left,720)]),PackedColorArray([Color(0.04,.09,.16,0),Color(.04,.09,.16,0),Color(.04,.09,.16,shade),Color(.04,.09,.16,shade)]))
		for i in range(27 if index==3 else 18):
			var phase: float=game.elapsed*(.42+float(i%4)*.06)+float(i)*2.39
			var x:=rect.position.x+(70+fposmod(float(i)*137.3,1770)+sin(phase*.7)*17)*scale
			var y:=rect.position.y+(80+float(i%5)*17+sin(phase)*12)*scale
			if x<left+3 or x>right-3:continue
			var amount:=pow(.5+.5*sin(phase),2)*.62+.08
			var p:=Vector2(x,y)
			canvas.draw_circle(p,7*scale,Color(.81,.89,.49,amount*.045))
			canvas.draw_circle(p,3*scale,Color(.93,.93,.58,amount*.17))
			canvas.draw_circle(p,1.15*scale,Color(1,.97,.70,amount))

func draw_glasses(canvas:CanvasItem,game:Node)->void:
	if game.morning!=null and game.morning.active:return
	var point:=glasses_point(game)
	if point.is_empty() or not game.layout.layer_parameters("moon5_tree").visible:return
	if not bool(placement.get("placed",false)) and not game.completed.has("s5-willow"):return
	var target:Vector2=support_position(game)-Vector2(game.camera_x,0)
	prop.draw_hanging(canvas,game,target,0,Color(.68,.76,.90,.94))

func draw_transition(canvas: CanvasItem) -> void:
	if fade<=0:return
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	canvas.draw_rect(Rect2(0,0,1280,720),Color(.025,.035,.065,fade))
