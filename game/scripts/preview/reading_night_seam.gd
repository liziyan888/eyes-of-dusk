extends "res://scripts/night_seam.gd"
const CONTINUOUS=preload("res://shaders/reading_night_pair_preview.gdshader")
func draw_pair(canvas:CanvasItem,game:Node,key:String,front:bool)->void:
	super.draw_pair(canvas,game,key,front)
	if not active(game):return
	canvas.material.shader=CONTINUOUS
	canvas.material.set_shader_parameter("continuous_landscape",key in ["forest","ground"])
