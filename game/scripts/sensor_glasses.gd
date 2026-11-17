extends RefCounted
const IMAGE=preload("res://assets/props/sensor_glasses_v2/hang.png")
const REST_IMAGE=preload("res://assets/props/sensor_glasses_v2/rest.png")
var definition:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/props/sensor_glasses_v2.json"))

func draw_hanging(canvas:CanvasItem,game:Node,position:Vector2,rotation_value:=0.0,tint:=Color.WHITE)->void:
	var width:float=definition.hang.width_logical
	var extent:=Vector2(width,width*IMAGE.get_height()/float(IMAGE.get_width()))
	var pivot:Array=definition.hang.pivot_uv
	canvas.draw_set_transform(game._world_origin()+position*game.zoom,rotation_value,Vector2.ONE*game.zoom)
	canvas.draw_texture_rect(IMAGE,Rect2(-Vector2(pivot[0],pivot[1])*extent,extent),false,tint)
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)

func draw_resting(canvas:CanvasItem,game:Node,position:Vector2,tint:=Color.WHITE,settled:=1.0)->void:
	var width:float=definition.rest.width_logical
	var extent:=Vector2(width,width*REST_IMAGE.get_height()/float(REST_IMAGE.get_width()))
	var pivot:Array=definition.rest.pivot_uv
	# The contact shadow is kept on the painted stone, underneath the prop.
	canvas.draw_set_transform(game._world_origin()+position*game.zoom,0,Vector2(game.zoom,game.zoom*.18))
	canvas.draw_circle(Vector2(0,2),width*.29,Color(.035,.045,.07,.13*settled))
	canvas.draw_set_transform(game._world_origin()+position*game.zoom,0,Vector2.ONE*game.zoom)
	canvas.draw_texture_rect(REST_IMAGE,Rect2(-Vector2(pivot[0],pivot[1])*extent,extent),false,tint)
	canvas.draw_set_transform(game._world_origin(),0,Vector2.ONE*game.zoom)
