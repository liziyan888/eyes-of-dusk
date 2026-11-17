extends TextureRect
## Supplied complete poses, registered by grip/contact point, at one uniform scale.
## The source drawings are only translated and cross-dissolved; no limb is deformed.
const SHADER = preload("res://shaders/ending/qte_authored_pose.gdshader")
const BASE = Vector2(1280,720)
const SOURCE_SCALE = 2.0 / 3.0
const GRIP_POINTS = [Vector2(1041,667.5), Vector2(1194,671.5263), Vector2(1326,675)]
const GRIP_MID = 153.0 / 285.0
var kind := "key"
var drawings: Dictionary = {}
var active_poses: Array[String] = []
var pose_offsets: Array[Vector2] = []
var blend_value := 0.0
var contact := Vector2.ZERO
var selected_pose := ""
var previous_pose := ""
var transition_clock := 1.0
var offsets: Dictionary = {}
const POSE_TRANSITION := 0.045

func configure(directory: String, action: String) -> void:
	kind = action
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	size = BASE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var names := ["hand-grip", "hand-grip-mid", "hand-grip-end"] if kind == "lever" else ["hand-reach", "hand-hover", "hand-press", "hand-recoil"]
	for id in names: drawings[id] = load(directory + id + ".png")
	texture = drawings[names[0]]
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	material = mat
	pose(0)

func show_pair(a: String, b: String, offset_a: Vector2, offset_b: Vector2, amount: float) -> void:
	offsets[a]=offset_a;offsets[b]=offset_b
	var next := b if amount>=.5 else a
	if selected_pose.is_empty():
		selected_pose=next;previous_pose=next;transition_clock=POSE_TRANSITION
	elif next!=selected_pose:
		previous_pose=selected_pose;selected_pose=next;transition_clock=0
	_sync_material()

func _process(delta:float)->void:
	# Time-based two-frame change, not a dissolve proportional to pointer travel.
	# A player holding the lever at 25%/75% must never be stuck with two ghost arms.
	if transition_clock<POSE_TRANSITION:
		transition_clock=minf(POSE_TRANSITION,transition_clock+delta)
		_sync_material()

func settle()->void:
	transition_clock=POSE_TRANSITION
	previous_pose=selected_pose
	_sync_material()

func _sync_material()->void:
	if selected_pose.is_empty():return
	if kind=="lever":
		var names:=["hand-grip","hand-grip-mid","hand-grip-end"]
		for i in names.size():offsets[names[i]]=contact-GRIP_POINTS[i]*SOURCE_SCALE
	active_poses.assign([previous_pose,selected_pose])
	pose_offsets.assign([offsets.get(previous_pose,Vector2.ZERO),offsets.get(selected_pose,Vector2.ZERO)])
	blend_value=smoothstep(0,POSE_TRANSITION,transition_clock)
	material.set_shader_parameter("pose_a",drawings[previous_pose])
	material.set_shader_parameter("pose_b",drawings[selected_pose])
	material.set_shader_parameter("offset_a",pose_offsets[0]/BASE)
	material.set_shader_parameter("offset_b",pose_offsets[1]/BASE)
	material.set_shader_parameter("blend_amount",blend_value)

func pose(value: float, recoil := 0.0) -> void:
	var p := clampf(value,0,1)
	if kind == "lever":
		# One shared physical path; supplied intermediate grip is at 53.7% of travel.
		contact = GRIP_POINTS[0] * SOURCE_SCALE + Vector2(190,5) * p
		var first := p <= GRIP_MID
		var left := 0 if first else 1
		var right := left + 1
		var local := p / GRIP_MID if first else (p-GRIP_MID)/(1-GRIP_MID)
		var names := ["hand-grip","hand-grip-mid","hand-grip-end"]
		show_pair(names[left],names[right],contact-GRIP_POINTS[left]*SOURCE_SCALE,contact-GRIP_POINTS[right]*SOURCE_SCALE,smoothstep(.25,.75,local))
	elif recoil > 0:
		show_pair("hand-hover","hand-recoil",Vector2.ZERO,Vector2.ZERO,smoothstep(0,.65,recoil))
	else:
		# Authored 05E supplies the bent index. A rigid contact registration places its
		# pad on the depressed key; the hover image is never bent into a press image.
		var hover_tip := Vector2(1140,702)*SOURCE_SCALE
		var press_tip := Vector2(1140,808)*SOURCE_SCALE
		var target := hover_tip.lerp(Vector2(777,515),p)
		contact = target
		show_pair("hand-hover","hand-press",target-hover_tip,target-press_tip,smoothstep(.38,.72,p))

func reach(value: float) -> void:
	var p := clampf(value,0,1)
	var start_tip := Vector2(909,773)*SOURCE_SCALE
	var end_tip := Vector2(1140,702)*SOURCE_SCALE
	var target := start_tip.lerp(end_tip,p)
	contact = target
	show_pair("hand-reach","hand-hover",target-start_tip,target-end_tip,smoothstep(.3,.8,p))
