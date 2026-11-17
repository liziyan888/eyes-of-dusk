extends Control
## Fixed receiver for her senses. No labels, meters or numbers.
const CHANNELS := ["sound", "touch", "vision", "smell"]
const RADIUS := 52.0
var levels := Vector4.ZERO
var targets := Vector4.ZERO
var clock := 0.0
var hold := 0.0
var profile := "voice"
var event_age := 99.0
var ring_clock := 0.0
var contact_direction := Vector2.RIGHT
var link_origin := Vector2.ZERO
var travel_speed := 0.0
var world_zoom := 1.0
var voice_left := 0.0
var voice_elapsed := 0.0
var voice_strength := 0.0
var voice_level := 0.0
var voice_from_her := false
var core: ColorRect
var core_material: ShaderMaterial

func setup(_font: Font) -> void:
	position=Vector2(1124,91)
	size=Vector2.ONE*104
	pivot_offset=Vector2.ONE*RADIUS
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade:=ColorRect.new()
	shade.size=Vector2(152,152)
	shade.position=Vector2(-24,-24)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shade_material:=ShaderMaterial.new()
	shade_material.shader=preload("res://shaders/orb_shade.gdshader")
	shade.material=shade_material
	add_child(shade)
	core=ColorRect.new()
	core.size=size
	core.mouse_filter=Control.MOUSE_FILTER_IGNORE
	core_material=ShaderMaterial.new()
	core_material.shader=preload("res://shaders/sensory_orb.gdshader")
	core.material=core_material
	add_child(core)

func transmit(values: Dictionary, timbre := "voice", strength := 1.0) -> void:
	profile=timbre
	for i in range(4):targets[i]=clampf(float(values.get(CHANNELS[i],0))*strength,0,1)
	hold=7.0

func start_voice(tone: String,characters: int,strength: float) -> void:
	voice_elapsed=0
	voice_left=clampf(float(characters)/30.0+0.3,0.8,12.0) if tone in ["her","me","zr"] else 0.0
	voice_strength=clampf(strength,0.3,1.0)
	voice_from_her=tone=="her"

func stop_voice() -> void:
	voice_left=0

func sample(values: Dictionary, timbre: String, direction: Vector2) -> void:
	transmit(values,timbre,1.0)
	event_age=0.0
	ring_clock=0.0
	contact_direction=direction.normalized() if direction.length()>0.01 else Vector2.RIGHT

func set_context(head: Vector2, speed: float, camera_zoom: float) -> void:
	link_origin=head
	travel_speed=clampf(speed/190.0,-1,1)
	world_zoom=camera_zoom
	var camera_scale:=lerpf(1,0.82,clampf((camera_zoom-1)/0.7,0,1))
	scale=Vector2(camera_scale*(1+absf(travel_speed)*0.08),camera_scale)

func sample_radius() -> float:
	if event_age<0.3:return lerpf(1,0.7,smoothstep(0,0.3,event_age))
	if event_age<0.65:return lerpf(0.7,1.0,smoothstep(0.3,0.65,event_age))
	return 1.0

func release_amount() -> float:
	if event_age<0.3 or event_age>=1.5:return 0.0
	return smoothstep(0.3,0.45,event_age)*(1-smoothstep(1.1,1.5,event_age))

func update_signal(delta: float) -> void:
	clock+=delta
	event_age+=delta
	voice_elapsed+=delta
	voice_left=maxf(0,voice_left-delta)
	var syllable:=0.35+0.65*absf(sin(voice_elapsed*6.0)+sin(voice_elapsed*12.5)*0.35)/1.35
	var voice_target:=syllable*(0.65+voice_strength*0.35) if voice_left>0 else 0.0
	voice_level=lerpf(voice_level,voice_target,1-exp(-delta*15))
	hold=maxf(0,hold-delta)
	if hold==0:targets=Vector4.ZERO
	levels=levels.lerp(targets,1-exp(-delta*5))
	ring_clock+=delta*(0.3+maxf(levels[0]*release_amount(),voice_level)*1.25+(0.25 if profile=="bird" else 0.0))
	if core_material!=null:
		var visible_senses:=levels
		visible_senses[0]=maxf(visible_senses[0],voice_level)
		core_material.set_shader_parameter("clock",clock)
		core_material.set_shader_parameter("senses",visible_senses)
		core_material.set_shader_parameter("sample_age",event_age)
		core_material.set_shader_parameter("sample_radius",sample_radius())
		core_material.set_shader_parameter("release_amount",release_amount())
		core_material.set_shader_parameter("contact",contact_direction)
		core_material.set_shader_parameter("bird",1.0 if profile=="bird" else 0.0)
		core_material.set_shader_parameter("ring_clock",ring_clock)
		core_material.set_shader_parameter("voice_amount",voice_level)
		core_material.set_shader_parameter("voice_from_her",1.0 if voice_from_her else 0.0)
	queue_redraw()

