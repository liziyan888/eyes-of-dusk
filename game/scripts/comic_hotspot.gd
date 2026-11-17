extends Button
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
	clock += delta
	var active := is_hovered() or has_focus()
	pulse = move_toward(pulse,1.0 if active else 0.0,delta*4.0)
	queue_redraw()
func _draw() -> void:
	var center := size/2
	var r := radius*(1.0+pulse*(.08+.08*sin(clock*3.3)))
	var alpha := .58+pulse*.42
	if completed: alpha *= .36
	draw_arc(center+Vector2(0,1),r,0,TAU,48,Color(0.02,.06,.1,alpha*.35),2.6,true)
	if pulse>.02: draw_arc(center,r+3.5,0,TAU,48,Color(1,1,1,pulse*.14),3.0,true)
	draw_arc(center,r,0,TAU,48,Color(.98,1,.97,alpha),1.45,true)
