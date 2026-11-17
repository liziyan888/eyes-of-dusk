extends RefCounted
## Mix original layers at one fixed world boundary; authored transforms stay intact.
const PAIR_SHADER=preload("res://shaders/night_pair.gdshader")
var backdrop:Node2D
var layers:Array[Node2D]=[]

func setup(game:Node)->void:
	backdrop=Node2D.new();backdrop.z_index=-1;game.add_child(backdrop)
	for key in ["sky","clouds","far","forest","ground"]:
		var node:=Node2D.new();var material:=ShaderMaterial.new();material.shader=PAIR_SHADER;node.material=material
		backdrop.add_child(node);layers.append(node)
		node.draw.connect(func():draw_pair(node,game,key,false))
	var tree:=Node2D.new();backdrop.add_child(tree)
	tree.draw.connect(func():game.panorama.draw_scene_layer(tree,game,4,"moon5_tree"))
	layers.append(tree);backdrop.hide()

func active(game:Node)->bool:
	return game.scene_index>=3 and game.scene_index<game.continuous_count() and not game.morning.active and game.scenery_visible(3) and game.scenery_visible(4)

func refresh(game:Node)->void:
	if backdrop==null:return
	backdrop.visible=active(game)
	if backdrop.visible:
		for node in layers:node.queue_redraw()

func draw_pair(canvas:CanvasItem,game:Node,key:String,front:bool)->void:
	if not active(game):return
	var left:Dictionary=game.layout.layer_parameters("moon4_"+key)
	var right:Dictionary=game.layout.layer_parameters("moon5_"+key)
	var material:ShaderMaterial=canvas.material
	if material.shader!=PAIR_SHADER:material.shader=PAIR_SHADER
	var left_rect:Rect2=game.panorama.psd_rect(game,left)
	var right_rect:Rect2=game.panorama.psd_rect(game,right)
	# Identical distant plates represent one sky, not a second displaced moon.
	# This changes only the shared origin; each authored coefficient still moves freely.
	if key in ["sky","clouds","far"] and same_parameters(left,right):right_rect=left_rect
	material.set_shader_parameter("left_image",game.textures["psd_moon4_"+key])
	material.set_shader_parameter("right_image",game.textures["psd_moon5_"+key])
	material.set_shader_parameter("left_rect",Vector4(left_rect.position.x,left_rect.position.y,left_rect.size.x,left_rect.size.y))
	material.set_shader_parameter("right_rect",Vector4(right_rect.position.x,right_rect.position.y,right_rect.size.x,right_rect.size.y))
	material.set_shader_parameter("left_source_position",game.layout.layer_position(left))
	material.set_shader_parameter("right_source_position",game.layout.layer_position(right))
	material.set_shader_parameter("left_visible",bool(left.visible));material.set_shader_parameter("right_visible",bool(right.visible))
	material.set_shader_parameter("left_extend_top",bool(left.get("extend_top",false)));material.set_shader_parameter("right_extend_top",bool(right.get("extend_top",false)))
	material.set_shader_parameter("camera_x",game.camera_x)
	material.set_shader_parameter("world_begin",float(game.story.scenes[3].start));material.set_shader_parameter("world_end",float(game.story.scenes[4].end))
	material.set_shader_parameter("seam",float(game.story.scenes[4].start));material.set_shader_parameter("cover_only",front)
	material.set_shader_parameter("continuous_landscape",key in ["forest","ground"])
	material.set_shader_parameter("ground_left",game.layout.ground(game.story.scenes[3]));material.set_shader_parameter("ground_right",game.layout.ground(game.story.scenes[4]))
	material.set_shader_parameter("overlap",float(game.layout.data.overlap))
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
	canvas.draw_rect(Rect2(-300,-300,1880,1320),Color.WHITE)

func draw_front(canvas:CanvasItem,game:Node)->void:
	draw_pair(canvas,game,"ground",true)

func same_parameters(left:Dictionary,right:Dictionary)->bool:
	for field in ["x","y","w","h","scale","f","visible"]:
		if left.get(field)!=right.get(field):return false
	return true
