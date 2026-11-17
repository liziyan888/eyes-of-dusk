extends Control
## Native paper geometry for the bottom-right corner; no next-page imagery is exposed at rest.
signal turn_requested
var backwards := false
var clock := 0.0
var lift := 0.0
var dragging := false
var drag_start := Vector2.ZERO
var pull := 0.0
var busy := false
var hovered := false
var fold_extent := 40.0
var turn_enabled := true
func _ready() -> void:
	position=Vector2(0,560) if backwards else Vector2(1120,560)
	size=Vector2(160,160)
	focus_mode=Control.FOCUS_ALL
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	tooltip_text=""
	gui_input.connect(_pointer)
	mouse_entered.connect(func():hovered=true)
	mouse_exited.connect(func():hovered=false)
func _process(delta: float) -> void:
	if not visible: return
	clock+=delta
	var near := turn_enabled and (hovered or has_focus())
	lift=move_toward(lift,1.0 if near or dragging else 0.0,delta*2.4)
	fold_extent=lerpf(fold_extent,42.0+lift*80.0+pull,1.0-exp(-delta*10.0))
	queue_redraw()
func _pointer(event: InputEvent) -> void:
	if not turn_enabled:
		if event is InputEventMouseButton:accept_event()
		return
	if busy:return
	if event is InputEventMouseMotion:hovered=true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging=true;drag_start=event.global_position;pull=0
		else:
			if dragging:_turn()
			dragging=false;pull=0
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		var offset:Vector2=drag_start-event.global_position
		if backwards:offset.x=-offset.x
		pull=clampf(offset.dot(Vector2(.707,.707)),0,180)
		accept_event()
	elif event.is_action_pressed("ui_accept"):
		_turn();accept_event()
func _turn() -> void:
	if busy or not turn_enabled:return
	busy=true;turn_requested.emit()
	_release_rejected.call_deferred()
func _release_rejected()->void:
	# Accepted turns hide the corner immediately. A rejected turn must not latch it.
	if is_visible_in_tree():busy=false
func _notification(what:int)->void:
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():reset()
func set_turn_enabled(value:bool)->void:
	if turn_enabled==value:return
	turn_enabled=value
	if not value:
		busy=false;dragging=false;pull=0
		if has_focus():release_focus()
	focus_mode=Control.FOCUS_ALL if value else Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND if value else Control.CURSOR_ARROW
	modulate.a=1.0 if value else .44
func reset() -> void:
	busy=false;dragging=false;pull=0;lift=0;fold_extent=42;hovered=false;queue_redraw()
func _bezier(a:Vector2,b:Vector2,c:Vector2,t:float) -> Vector2:
	return a*(1-t)*(1-t)+b*2*t*(1-t)+c*t*t
func _draw() -> void:
	draw_set_transform(Vector2(160,0) if backwards else Vector2.ZERO,0,Vector2(-1,1) if backwards else Vector2.ONE)
	var corner:=Vector2(160,160)
	var l:=fold_extent
	var a:=corner-Vector2(l,0)
	var b:=corner-Vector2(0,l)
	# The lifted lip is a bowed curve, with the paper rolling back toward the page center.
	var lip:=PackedVector2Array()
	for i in range(41):
		var t:=float(i)/40
		lip.append(_bezier(a,corner-Vector2(l*.68,l*.68),b,t))
	var back:=PackedVector2Array(lip)
	for i in range(1,41):
		var t:=float(i)/40
		back.append(_bezier(b,corner-Vector2(l*1.06,l*1.06),a,t))
	var shadow:=PackedVector2Array()
	for p in back:shadow.append(p+Vector2(-2,-1))
	draw_colored_polygon(shadow,Color(.06,.09,.12,.12+lift*.12))
	var colors:=PackedColorArray()
	for p in back:
		var shade:=clampf((corner-p).length()/maxf(l,1),.0,1)
		colors.append(Color(.94-shade*.13,.95-shade*.13,.96-shade*.12,1))
	draw_polygon(back,colors)
	# Cover the tucked corner with the same pale paper back, without leaking future art.
	var tucked:=PackedVector2Array([a,corner,b])
	draw_colored_polygon(tucked,Color(.93,.94,.95))
	# A curved white seam and a broad low-opacity halo emphasize the rolled lip.
	draw_polyline(lip,Color(1,1,1,.10+lift*.11),7.0,true)
	draw_polyline(lip,Color(1,1,1,.90),1.55,true)
	var rim:=PackedVector2Array()
	for i in range(1,41):rim.append(_bezier(b,corner-Vector2(l*1.06,l*1.06),a,float(i)/40))
	draw_polyline(rim,Color(1,1,1,.62+lift*.33),1.0,true)
