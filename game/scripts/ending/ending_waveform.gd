extends Control
## A restrained diegetic waveform, not a fake voice visualizer.  It can also
## flatten to a quiet straight line when the signal disappears.

var amplitude := 1.0
var line_color := Color(0.55, 0.80, 0.88, 0.85)
var playing := false
var clock := 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	clock += delta * (1.7 if playing else 0.22)
	queue_redraw()


func reset_wave() -> void:
	clock = 0.0
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	var mid := h * 0.5
	var points := PackedVector2Array()
	var n := 120
	for i in range(n + 1):
		var t := float(i) / float(n)
		var envelope := sin(t * PI)
		var wave := sin(t * 31.0 + clock * 2.2) * 0.55
		wave += sin(t * 17.0 - clock * 1.37) * 0.28
		wave += sin(t * 67.0 + clock * 0.73) * 0.10
		var x := t * w
		var y := mid + wave * envelope * amplitude * h * 0.42
		points.append(Vector2(x, y))
	# faint centre rail
	draw_line(Vector2(0, mid), Vector2(w, mid), Color(line_color, 0.14), 1.0, true)
	if points.size() > 1:
		draw_polyline(points, Color(line_color, 0.88), 1.4, true)
	# a very soft trailing glow, never bright enough to become a game meter
	if amplitude > 0.02:
		draw_polyline(points, Color(line_color, 0.18), 4.5, true)
