extends RefCounted
## Authored panorama chapters share one horizontal world. All seam clipping uses world X.
const WIDTH := 1697.0
const PassageLayers = preload("res://scripts/passage_layers.gd")
var passage_layers := PassageLayers.new()

func draw_back(canvas: CanvasItem, game: Node) -> void:
	var near_layers: Array=[]
	for scene in range(game.continuous_count()):
		if not game.scenery_visible(scene):continue
		if scene in [3,4] and game.night_seam.active(game):continue
		var sc: Dictionary=game.story.scenes[scene]
		var left: float=float(sc.start)-game.camera_x
		var right: float=float(sc.get("visual_end",sc.end))-game.camera_x
		if right < -800 or left>2080:continue
		var local: float=game.camera_x-float(sc.start)
		if scene==0 and game.layout.layers_for_scene(0).is_empty():
			var dy: float=game.layout.scene_vertical_offset(scene)
			for key in ["sky","far","mid","ground"]:
				if key=="sky" and dy>0:
					draw_first_sky(canvas,game,local*float(sc.layers.sky.f),left,right,dy)
					continue
				if key=="mid":
					canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
					canvas.draw_rect(Rect2(left,480+dy,right-left,240),Color("7b9748"))
				layer(canvas,game,game.textures[key],local*float(sc.layers[key].f),left,right,0,720,1697,720,dy)
			layer(canvas,game,game.textures.near,local,left,right,0,minf(720,game.layout.ground(sc)+float(game.layout.data.overlap)),1697,720,dy)
		else:
			for id in game.layout.layers_for_scene(scene):
				if str(id) in ["meadow1_ground","meadow1_near","creek2_ground"]:
					near_layers.append([scene,str(id)])
				else:draw_scene_layer(canvas,game,scene,str(id))
	draw_passage(canvas,game,"landscape")
	draw_passage(canvas,game,"middle")
	for item in near_layers:draw_scene_layer(canvas,game,int(item[0]),str(item[1]))
	draw_passage(canvas,game,"ground")
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)

func draw_scene_layer(canvas: CanvasItem,game: Node,index: int,id: String) -> void:
	var sc: Dictionary=game.story.scenes[index]
	var left: float=float(sc.start)-game.camera_x
	var right: float=float(sc.get("visual_end",sc.end))-game.camera_x
	var entry: Dictionary=game.layout.layer_parameters(id)
	if not bool(entry.visible):return
	var rectangle:=psd_rect(game,entry)
	var texture: Texture2D=game.textures["psd_"+id]
	if bool(entry.get("extend_top",false)):draw_sky_extension(canvas,game,texture,rectangle,left,right)
	var clip:=rectangle.intersection(Rect2(left,0,right-left,720))
	if not clip.has_area():return
	var uv:=Rect2((clip.position-rectangle.position)/rectangle.size*texture.get_size(),clip.size/rectangle.size*texture.get_size())
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	canvas.draw_texture_rect_region(texture,clip,uv,Color(1,1,1,float(entry.get("opacity",1))))

func draw_first_sky(canvas: CanvasItem,game: Node,offset: float,left: float,right: float,dy: float) -> void:
	# Keep original sky pixels above the shifted artwork and fade between the two placements.
	var texture: Texture2D=game.textures.sky
	layer(canvas,game,texture,offset,left,right)
	var fade_height:=minf(120,720-dy)
	if fade_height<=0:return
	layer(canvas,game,texture,offset,left,right,dy+fade_height,720,1697,720,dy)
	var first:=int(floor(offset/WIDTH))-1
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	for tile in range(first,first+5):
		var x:=float(tile)*WIDTH-offset
		var begin:=maxf(left,x)
		var end:=minf(right,x+WIDTH)
		if end<=begin:continue
		var u0:=(begin-x)/WIDTH
		var u1:=(end-x)/WIDTH
		if tile%2!=0:u0=1-u0;u1=1-u1
		var points:=PackedVector2Array([Vector2(begin,dy),Vector2(end,dy),Vector2(end,dy+fade_height),Vector2(begin,dy+fade_height)])
		var colors:=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0),Color.WHITE,Color.WHITE])
		var uv:=PackedVector2Array([Vector2(u0,0),Vector2(u1,0),Vector2(u1,fade_height/720),Vector2(u0,fade_height/720)])
		canvas.draw_polygon(points,colors,uv,texture)

func draw_front(canvas: CanvasItem,game: Node) -> void:
	if not game.layout.layers_for_scene(0).is_empty():
		var id:=str(game.story.scenes[0].get("foreground_layer","meadow1_near"))
		var entry: Dictionary=game.layout.layer_parameters(id)
		if not entry.is_empty() and bool(entry.visible):draw_psd_ground_cover(canvas,game,entry)
		return
	# Scene one keeps its original material; scenes two/three use their own PSB textures.
	for scene in range(1):
		var sc: Dictionary=game.story.scenes[scene]
		var left: float=float(sc.start)-game.camera_x
		var right: float=float(sc.end)-game.camera_x
		if right < -800 or left>2080:continue
		var texture: Texture2D=game.textures.near if scene==0 else game.textures.creek_bank
		layer(canvas,game,texture,game.camera_x-float(sc.start),left,right,0,720,1697,720,game.layout.scene_vertical_offset(scene))

func psd_rect(game: Node,entry: Dictionary) -> Rect2:
	var index:=int(entry.get("scene_index",2))
	var start:=float(entry.get("region_start",game.story.scenes[index].start))
	var x: float=start+float(entry.x)-game.camera_x+game.layout.layer_drift(entry,game.camera_x)
	return Rect2(Vector2(x,game.layout.layer_position(entry).y),Vector2(float(entry.w),float(entry.h))*float(entry.scale))

func draw_passage(canvas: CanvasItem,game: Node,stage: String) -> void:
	passage_layers.draw(canvas,game,stage)

func draw_sky_extension(canvas: CanvasItem,game: Node,texture: Texture2D,rectangle: Rect2,left: float,right: float) -> void:
	# Reflect only beyond the sky's original top edge; original pixels/scale are untouched.
	if rectangle.position.y<=0:return
	var begin:=maxf(left,rectangle.position.x)
	var end:=minf(right,rectangle.end.x)
	if end<=begin:return
	var first:=int(floor(-rectangle.position.y/rectangle.size.y))
	for tile in range(first,0):
		var y:=rectangle.position.y+float(tile)*rectangle.size.y
		var top:=maxf(0,y)
		var bottom:=minf(720,y+rectangle.size.y)
		if bottom<=top:continue
		var source_y:=(top-y)/rectangle.size.y*texture.get_height()
		var source_h:=(bottom-top)/rectangle.size.y*texture.get_height()
		var uv:=Rect2((begin-rectangle.position.x)/rectangle.size.x*texture.get_width(),source_y,(end-begin)/rectangle.size.x*texture.get_width(),source_h)
		if tile%2!=0:
			uv.position.y=texture.get_height()-source_y-source_h
			canvas.draw_set_transform(game._world_origin()+Vector2(0,bottom)*game.zoom,0,Vector2(game.zoom,-game.zoom))
			canvas.draw_texture_rect_region(texture,Rect2(begin,0,end-begin,bottom-top),uv)
		else:
			canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
			canvas.draw_texture_rect_region(texture,Rect2(begin,top,end-begin,bottom-top),uv)

func draw_psd_ground_cover(canvas: CanvasItem,game: Node,entry: Dictionary) -> void:
	var sc: Dictionary=game.story.scenes[int(entry.get("scene_index",2))]
	var rectangle:=psd_rect(game,entry)
	var clip:=rectangle.intersection(Rect2(float(sc.start)-game.camera_x,0,float(sc.get("visual_end",sc.end))-float(sc.start),720))
	if not clip.has_area():return
	var texture: Texture2D=game.textures["psd_"+str(entry.id)]
	var uv:=Rect2((clip.position-rectangle.position)/rectangle.size*texture.get_size(),clip.size/rectangle.size*texture.get_size())
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	canvas.draw_texture_rect_region(texture,clip,uv)

func layer(canvas: CanvasItem,game: Node,texture: Texture2D,offset: float,left: float,right: float,top:=0.0,bottom:=720.0,width:=1697.0,height:=720.0,oy:=0.0) -> void:
	var first:=int(floor(offset/width))-1
	var y0:=maxf(top,oy)
	var y1:=minf(bottom,oy+height)
	if y1<=y0:return
	var source_y:=(y0-oy)/height*texture.get_height()
	var source_h:=(y1-y0)/height*texture.get_height()
	for tile in range(first,first+5):
		var x:=tile*width-offset
		var begin:=maxf(left,x)
		var end:=minf(right,x+width)
		if end<=begin:continue
		var source_left:=(begin-x)/width*texture.get_width()
		var source_width:=(end-begin)/width*texture.get_width()
		if tile%2!=0:
			canvas.draw_set_transform(game._world_origin()+Vector2(end,0)*game.zoom,0,Vector2(-game.zoom,game.zoom))
			canvas.draw_texture_rect_region(texture,Rect2(0,y0,end-begin,y1-y0),Rect2(texture.get_width()-source_left-source_width,source_y,source_width,source_h))
		else:
			canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
			canvas.draw_texture_rect_region(texture,Rect2(begin,y0,end-begin,y1-y0),Rect2(source_left,source_y,source_width,source_h))
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)

func draw_trees(canvas: CanvasItem,game: Node) -> void:
	if game.scene_index>=game.continuous_count():return
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	for border in range(game.continuous_count()-1):
		if border==1:continue
		# The inn-to-moonlight border no longer uses an opaque foreground grove.
		if border in [2,3]:continue
		if border==0 and game.story.world.has("passage12"):continue
		var seam: float=float(game.story.scenes[border].end)-game.camera_x
		if seam < -700 or seam>1980:continue
		if border>=1:
			var tint:=Color.WHITE if border==1 else Color(.57,.64,.79,1)
			canvas.draw_texture_rect(game.textures.transition_grove,Rect2(seam-330,-100,660,850),false,tint)
		else:
			canvas.draw_texture_rect(game.textures.transition_tree,Rect2(seam-180,-95,360,850),false,Color(0.65,0.73,0.66,1))
			canvas.draw_texture_rect(game.textures.transition_tree,Rect2(seam+178,-110,150,850),false,Color(0.48,0.59,0.51,0.91))
