extends Button
const Breathing=preload("res://scripts/hotspot_pulse.gd")
## A small diegetic marker. Text appears as an outcome after clicking, never as a hover tooltip.
var pulse := 0.0
var clock := 0.0
var completed := false
var radius := 8.0
func _ready() -> void:
	custom_minimum_size = Vector2(40,40)
	size = Vector2(40,40)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	tooltip_text = ""
	set_process(true)
func _process(delta: float) -> void:
	if not is_visible_in_tree():return
	clock += delta
	var active := is_hovered() or has_focus()
	pulse = move_toward(pulse,1.0 if active else 0.0,delta*4.0)
	queue_redraw()
func _draw() -> void:
	var center := size/2
	var appearance:=Breathing.appearance(clock,pulse,radius,.60,.98,.36 if completed else 1.0)
	var r:=appearance.x
	var alpha:=appearance.y
	draw_arc(center+Vector2(0,1),r,0,TAU,48,Color(0.02,.06,.1,alpha*.35),2.6,true)
	draw_arc(center,r+3.5,0,TAU,48,Color(1,1,1,appearance.z),3.0,true)
	draw_arc(center,r,0,TAU,48,Color(.98,1,.97,alpha),1.45,true)
