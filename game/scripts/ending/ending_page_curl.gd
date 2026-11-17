extends Control
## Native paper corner, 42 px at rest and about 120 px on hover/focus.
## It never reveals next-page artwork.  Only the bottom corner accepts input.

signal turn_requested

var backwards := false
var clock := 0.0
var lift := 0.0
var fold_extent := 42.0
var hovered := false
var dragging := false
var drag_start := Vector2.ZERO
var pull := 0.0
var busy := false


func _ready() -> void:
	position = Vector2(0, 560) if backwards else Vector2(1120, 560)
	size = Vector2(160, 160)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = ""
	gui_input.connect(_pointer)
	mouse_entered.connect(func(): hovered = true)
	mouse_exited.connect(func(): hovered = false)


func _has_point(point: Vector2) -> bool:
	# Do not let the transparent 160x160 box swallow read-frame hotspots.
	# The left-hand curl is drawn mirrored, so mirror hit-testing too.
	var p := point
	if backwards:
		p.x = 160.0 - p.x
	var c := Vector2(160, 160)
	var reach := maxf(58.0, fold_extent + 18.0)
	return (c.x - p.x) + (c.y - p.y) < reach and p.x > c.x - reach and p.y > c.y - reach


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	var near := hovered or has_focus()
	lift = move_toward(lift, 1.0 if near or dragging else 0.0, delta * 2.4)
	fold_extent = lerpf(fold_extent, 42.0 + lift * 80.0 + pull, 1.0 - exp(-delta * 10.0))
	queue_redraw()


func _pointer(event: InputEvent) -> void:
	if busy:
		return
	if event is InputEventMouseMotion and hovered:
		hovered = true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			drag_start = event.global_position
			pull = 0.0
		else:
			if dragging:
				_turn()
			dragging = false
			pull = 0.0
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var offset: Vector2 = drag_start - event.global_position
		if backwards:
			offset.x = -offset.x
		pull = clampf(offset.dot(Vector2(0.707, 0.707)), 0.0, 170.0)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_turn()
		accept_event()


func _turn() -> void:
	if busy:
		return
	busy = true
	turn_requested.emit()
	_release_rejected.call_deferred()


func _release_rejected()->void:
	if is_visible_in_tree():busy=false


func reset() -> void:
	busy = false
	dragging = false
	pull = 0.0
	lift = 0.0
	fold_extent = 42.0
	queue_redraw()


func _bezier(a: Vector2, b: Vector2, c: Vector2, t: float) -> Vector2:
	return a * (1.0 - t) * (1.0 - t) + b * 2.0 * t * (1.0 - t) + c * t * t


func _draw() -> void:
	draw_set_transform(Vector2(160, 0) if backwards else Vector2.ZERO, 0.0, Vector2(-1, 1) if backwards else Vector2.ONE)
	var corner := Vector2(160, 160)
	var l := fold_extent
	var a := corner - Vector2(l, 0)
	var b := corner - Vector2(0, l)
	var lip := PackedVector2Array()
	for i in range(41):
		var t := float(i) / 40.0
		lip.append(_bezier(a, corner - Vector2(l * 0.68, l * 0.68), b, t))
	var back := PackedVector2Array(lip)
	for i in range(1, 41):
		var t := float(i) / 40.0
		back.append(_bezier(b, corner - Vector2(l * 1.06, l * 1.06), a, t))
	var shadow := PackedVector2Array()
	for p in back:
		shadow.append(p + Vector2(-2, -1))
	draw_colored_polygon(shadow, Color(0.06, 0.09, 0.12, 0.11 + lift * 0.12))
	var colors := PackedColorArray()
	for p in back:
		var shade := clampf((corner - p).length() / maxf(l, 1.0), 0.0, 1.0)
		colors.append(Color(0.94 - shade * 0.13, 0.95 - shade * 0.13, 0.96 - shade * 0.12, 1.0))
	draw_polygon(back, colors)
	var tucked := PackedVector2Array([a, corner, b])
	draw_colored_polygon(tucked, Color(0.93, 0.94, 0.95))
	draw_polyline(lip, Color(1, 1, 1, 0.10 + lift * 0.11), 7.0, true)
	draw_polyline(lip, Color(1, 1, 1, 0.90), 1.55, true)
	var rim := PackedVector2Array()
	for i in range(1, 41):
		rim.append(_bezier(b, corner - Vector2(l * 1.06, l * 1.06), a, float(i) / 40.0))
	draw_polyline(rim, Color(1, 1, 1, 0.62 + lift * 0.34), 1.0, true)
