extends Button
## Small diegetic empty circle.  It is a real Button, so its click is isolated
## from the parent panel and keyboard focus can live here without leaking.

var pulse := 0.0
var clock := 0.0
var completed := false
var radius := 8.0
var accessible_name := ""


func _ready() -> void:
	custom_minimum_size = Vector2(40, 40)
	size = Vector2(40, 40)
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tooltip_text = ""
	if not accessible_name.is_empty():
		accessibility_name = accessible_name
	set_process(true)


func _process(delta: float) -> void:
	clock += delta
	var active := is_hovered() or has_focus()
	pulse = move_toward(pulse, 1.0 if active else 0.0, delta * 4.2)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var r := radius * (1.0 + pulse * (0.08 + 0.08 * sin(clock * 3.3)))
	var alpha := 0.58 + pulse * 0.38
	if completed:alpha *= 0.36
	draw_arc(center + Vector2(0, 1), r, 0.0, TAU, 48, Color(0.02, 0.055, 0.09, alpha * 0.36), 2.7, true)
	if pulse > 0.02:
		draw_arc(center, r + 3.8, 0.0, TAU, 48, Color(1, 1, 1, pulse * 0.13), 3.0, true)
	draw_arc(center, r, 0.0, TAU, 48, Color(0.985, 1.0, 0.975, alpha), 1.45, true)
