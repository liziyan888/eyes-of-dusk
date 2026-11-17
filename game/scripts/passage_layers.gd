extends RefCounted
## Keep original artwork and parallax; extend only its rendered coverage.
const HORIZONTAL_FILL := ["passage12_sky","passage12_clouds","passage12_far","passage12_forest","passage12_ground"]
const FOG_FADE := 500.0
var sky_colors: Dictionary = {}
const FogShader = preload("res://shaders/passage_fog.gdshader")
var fog_mesh: ArrayMesh
var fog_material: ShaderMaterial
var fog_mesh_key: Array=[]
var fog_mesh_builds:=0

func draw(canvas: CanvasItem,game: Node,stage: String) -> void:
	var passage: Dictionary=game.story.world.get("passage12",{})
	if passage.is_empty() or game.scene_index>=game.continuous_count():return
	var view:=Rect2(-800,0,2880,720)
	for id in game.layout.passage_layer_order:
		var entry: Dictionary=game.layout.layer_parameters(str(id))
		if not bool(entry.visible):continue
		var phase:=str(entry.render_stage)
		if phase=="back":phase="middle" if str(id)=="passage12_trees" else ("ground" if str(id)=="passage12_ground" else "landscape")
		if phase!=stage and not (stage=="back" and str(entry.render_stage)=="back"):continue
		var rect: Rect2=game.panorama.psd_rect(game,entry)
		var texture: Texture2D=game.textures["psd_"+str(id)]
		canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
		if phase=="fog":
			draw_fog(canvas,game,texture,rect,float(entry.opacity),view)
		elif str(id) in HORIZONTAL_FILL:
			var body:=Rect2(float(passage.start)-game.camera_x,0,float(passage.end)-float(passage.start),720).intersection(view)
			if not body.has_area():continue
			var sky:=str(id)=="passage12_sky"
			if sky:canvas.draw_rect(body,sky_color(texture))
			draw_mirrored(canvas,texture,rect,body,float(entry.opacity),sky,24. if str(id)=="passage12_forest" else 0.)
		else:
			# 05 and 08 retain their full silhouette on both sides of the join.
			if str(id)=="passage12_trees":draw_tree(canvas,texture,rect,view,float(entry.opacity))
			else:draw_plain(canvas,texture,rect,rect.intersection(view),float(entry.opacity))

func sky_color(texture: Texture2D) -> Color:
	var key:=texture.get_instance_id()
	if sky_colors.has(key):return sky_colors[key]
	var pixels:=texture.get_image()
	var total:=Color(0,0,0,0)
	var count:=0
	for i in range(24):
		var color:=pixels.get_pixel(clampi(int((i+.5)*pixels.get_width()/24.),0,pixels.get_width()-1),0)
		if color.a>.9:total+=color;count+=1
	var result:=Color(.51,.74,.86,1)
	if count>0:result=Color(total.r/count,total.g/count,total.b/count,1)
	sky_colors[key]=result
	return result

func quad(canvas: CanvasItem,texture: Texture2D,rect: Rect2,uv: Rect2,alpha_left: float,alpha_right: float,bottom_left: float=-1.,bottom_right: float=-1.) -> void:
	if rect.size.x<.01 or rect.size.y<.01:return
	canvas.draw_polygon(PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)]),
		PackedColorArray([Color(1,1,1,alpha_left),Color(1,1,1,alpha_right),Color(1,1,1,alpha_right if bottom_right<0 else bottom_right),Color(1,1,1,alpha_left if bottom_left<0 else bottom_left)]),
		PackedVector2Array([uv.position,Vector2(uv.end.x,uv.position.y),uv.end,Vector2(uv.position.x,uv.end.y)]),texture)

func draw_plain(canvas: CanvasItem,texture: Texture2D,original: Rect2,clip: Rect2,opacity: float) -> void:
	if not clip.has_area():return
	var uv:=Rect2((clip.position-original.position)/original.size,clip.size/original.size)
	quad(canvas,texture,clip,uv,opacity,opacity)

func draw_mirrored(canvas: CanvasItem,texture: Texture2D,source: Rect2,bounds: Rect2,opacity: float,fill_y: bool,inset_pixels: float=0.) -> void:
	var inset:=inset_pixels/texture.get_width()
	# The forest's final source columns contain a straight alpha cut; repeat the painted interior.
	var original:=Rect2(source.position+Vector2(source.size.x*inset,0),Vector2(source.size.x*(1-2*inset),source.size.y))
	if original.size.x<=0 or original.size.y<=0:return
	var top: float=bounds.position.y if fill_y else maxf(bounds.position.y,original.position.y)
	var bottom: float=bounds.end.y if fill_y else minf(bounds.end.y,original.end.y)
	if bottom<=top:return
	# Split at the original Y edges, preserving scale inside the source rectangle.
	var ys: Array[float]=[top]
	for y in [original.position.y,original.end.y]:
		if y>top and y<bottom:ys.append(y)
	ys.append(bottom)
	var first:=int(floor((bounds.position.x-original.position.x)/original.size.x))
	var last:=int(ceil((bounds.end.x-original.position.x)/original.size.x))
	for tile in range(first,last):
		var x: float=original.position.x+tile*original.size.x
		var left:=maxf(bounds.position.x,x)
		var right:=minf(bounds.end.x,x+original.size.x)
		if right<=left:continue
		var u0: float=(left-x)/original.size.x
		var u1: float=(right-x)/original.size.x
		if tile%2!=0:u0=1-u0;u1=1-u1
		u0=inset+u0*(1-2*inset);u1=inset+u1*(1-2*inset)
		for i in range(ys.size()-1):
			var v0:=clampf((ys[i]-original.position.y)/original.size.y,0,1)
			var v1:=clampf((ys[i+1]-original.position.y)/original.size.y,0,1)
			quad(canvas,texture,Rect2(left,ys[i],right-left,ys[i+1]-ys[i]),Rect2(u0,v0,u1-u0,v1-v0),opacity,opacity)

func draw_tree(canvas: CanvasItem,texture: Texture2D,original: Rect2,view: Rect2,opacity: float) -> void:
	var clip:=original.intersection(view)
	if not clip.has_area():return
	# The PS cutout ends through foliage/trunks; soften that old cut edge as it emerges.
	var feather:=minf(32.,original.size.x*.08)
	var xs: Array[float]=[clip.position.x,clip.end.x]
	for i in range(1,5):
		for x in [original.position.x+feather*i/4.,original.end.x-feather*i/4.]:
			if x>clip.position.x and x<clip.end.x:xs.append(x)
	xs.sort()
	for i in range(xs.size()-1):
		var x0:=xs[i]
		var x1:=xs[i+1]
		if x1-x0<.001:continue
		var a0:=opacity*smoothstep(0.,feather,x0-original.position.x)*smoothstep(0.,feather,original.end.x-x0)
		var a1:=opacity*smoothstep(0.,feather,x1-original.position.x)*smoothstep(0.,feather,original.end.x-x1)
		var part:=Rect2(x0,clip.position.y,x1-x0,clip.size.y)
		quad(canvas,texture,part,Rect2((part.position-original.position)/original.size,part.size/original.size),a0,a1)

func tree_envelope(game: Node) -> Vector2:
	var passage: Dictionary=game.story.world.passage12
	var body:=Vector2(float(passage.start),float(passage.end))
	var tree: Dictionary=game.layout.layer_parameters("passage12_trees")
	if tree.is_empty() or not bool(tree.visible):return body
	var start:=float(tree.region_start)
	var reference:=float(tree.reference_camera)
	var factor:=float(tree.f)
	var width: float=float(tree.w)*float(tree.scale)
	var screen_at_zero: float=start+float(tree.x)-(1-factor)*(start+reference)
	var first:=0.0
	var last: float=maxf(0,float(game.story.scenes[game.continuous_count()-1].end)-1280)
	if factor>.000001:
		first=maxf(first,(screen_at_zero-1280)/factor)
		last=minf(last,(screen_at_zero+width)/factor)
	elif screen_at_zero>=1280 or screen_at_zero+width<=0:return body
	if first>last:return body
	var a: float=start+float(tree.x)+game.layout.layer_drift(tree,first)
	var b: float=start+float(tree.x)+game.layout.layer_drift(tree,last)
	return Vector2(minf(a,b),maxf(a,b)+width)

func fog_bounds(game: Node) -> Vector4:
	var passage: Dictionary=game.story.world.passage12
	var trees:=tree_envelope(game)
	var left:=float(passage.start)
	var right:=float(passage.end)
	return Vector4(minf(left-FOG_FADE,trees.x-160.),left,right,maxf(right+FOG_FADE,trees.y+160.))

func fog_strength(world_x: float,bounds: Vector4) -> float:
	return smoothstep(bounds.x,bounds.y,world_x)*(1-smoothstep(bounds.z,bounds.w,world_x))

func fog_density(world_x: float,world_y: float,bounds: Vector4) -> float:
	var core:=smoothstep(bounds.y-120.,bounds.y+80.,world_x)*(1-smoothstep(bounds.z-80.,bounds.z+120.,world_x))
	var ground_haze:=lerpf(.30,.74,smoothstep(340.,710.,world_y))
	var edge_noise:=sin(world_y*.018+world_x*.002)*12.+sin(world_y*.041-world_x*.003)*6.
	var variation:=.96+.04*sin(world_x*.011+world_y*.017)*sin(world_x*.004-world_y*.013)
	return fog_strength(world_x+edge_noise*(1-core),bounds)*lerpf(ground_haze*variation,1.,core)

func draw_fog(canvas: CanvasItem,game: Node,texture: Texture2D,original: Rect2,opacity: float,view: Rect2) -> void:
	var bounds:=fog_bounds(game)
	var left: float=maxf(view.position.x,bounds.x-game.camera_x)
	var right: float=minf(view.end.x,bounds.w-game.camera_x)
	if right<=left:return
	var entry: Dictionary=game.layout.layer_parameters("passage12_fog")
	# Layout edits invalidate geometry; camera motion and texture parallax do not.
	var key: Array=[bounds,entry.x,entry.y,entry.w,entry.h,entry.scale,original.position.y,original.size.y]
	if fog_mesh==null or key!=fog_mesh_key:
		build_fog_mesh(bounds,original,float(entry.region_start)+float(entry.x),float(entry.w)*float(entry.scale))
		fog_mesh_key=key
	if fog_material==null:
		fog_material=ShaderMaterial.new();fog_material.shader=FogShader
	if canvas.material!=fog_material:canvas.material=fog_material
	fog_material.set_shader_parameter("texture_origin",Vector2(original.position.x+game.camera_x,original.position.y))
	fog_material.set_shader_parameter("texture_extent",original.size)
	fog_material.set_shader_parameter("layer_opacity",opacity)
	canvas.draw_set_transform(game._world_origin()-Vector2(game.camera_x,0)*game.zoom,0,Vector2.ONE*game.zoom)
	canvas.draw_mesh(fog_mesh,texture)

func build_fog_mesh(bounds: Vector4,original: Rect2,texture_left: float,texture_width: float) -> void:
	# Identical world-space grid/density, submitted as one reusable mesh instead of hundreds of polygons.
	var xs: Array[float]=[bounds.x,bounds.w]
	for x in [bounds.y,bounds.z,texture_left,texture_left+texture_width]:
		if x>bounds.x and x<bounds.w:xs.append(x)
	for i in range(int(floor(bounds.x/32.))+1,int(ceil(bounds.w/32.))):xs.append(i*32.)
	xs.sort()
	var unique_xs: Array[float]=[]
	for x in xs:
		if unique_xs.is_empty() or x-unique_xs[-1]>.001:unique_xs.append(x)
	xs=unique_xs
	var ys: Array[float]=[0.]
	for y in [original.position.y,original.end.y]:
		if y>0 and y<720:ys.append(y)
	for y in range(60,720,60):ys.append(float(y))
	ys.append(720.)
	ys.sort()
	var unique_ys: Array[float]=[]
	for y in ys:
		if unique_ys.is_empty() or y-unique_ys[-1]>.001:unique_ys.append(y)
	ys=unique_ys
	var vertices:=PackedVector2Array()
	var colors:=PackedColorArray()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for y in ys:
		for x in xs:
			vertices.append(Vector2(x,y));colors.append(Color(1,1,1,fog_density(x,y,bounds)));uvs.append(Vector2.ZERO)
	for j in range(ys.size()-1):
		for i in range(xs.size()-1):
			var tl:=j*xs.size()+i
			var tr:=tl+1
			var bl:=tl+xs.size()
			var br:=bl+1
			indices.append_array(PackedInt32Array([bl,tl,tr,tr,br,bl]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colors
	arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	fog_mesh=ArrayMesh.new()
	fog_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	fog_mesh_builds+=1
