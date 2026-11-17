extends Node3D
## Registered paintings surround the surviving model at separate real depths.
## The nearest two spherical volumes enclose the craft; no ship is drawn on a map.
const FRAME := Vector2(2560, 1440)
const START_CAMERA_Z := 8.8
const CORE_UV := Vector2(0.493, 0.502)
const MOTES = preload("res://assets/transparent-earth/mote-sprites-v2.png")
const DEPTH_PAINT = preload("res://shaders/painted_earth_depth.gdshader")
const VOLUME = preload("res://shaders/earth_core_volume.gdshader")
const CORE_HULL = preload("res://shaders/earth_core_ship.gdshader")

var globe: Node3D
var craft: Node3D
var heart: Sprite3D
var core_light: OmniLight3D
var camera: Camera3D
var rear_layer: MeshInstance3D
var front_layer: MeshInstance3D
var mist_layer: MeshInstance3D
var near_shell: MeshInstance3D
var core_volume: MeshInstance3D
var clock := 0.0
var reveal := 0.0
var ship_visibility := 0.0
var travellers: Array[Sprite3D] = []
var origins: Array[Vector3] = []
var hull_materials: Array[ShaderMaterial] = []
var detail_materials: Array[StandardMaterial3D] = []

func _texture(index: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = MOTES
	texture.region = Rect2((index % 4) * 512, (index / 4) * 512, 512, 512)
	return texture

func _sprite(index: int, pixel_size: float) -> Sprite3D:
	var node := Sprite3D.new()
	node.texture = _texture(index)
	node.pixel_size = pixel_size
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.no_depth_test = false
	node.render_priority = 8
	globe.add_child(node)
	return node

func _registered_plane(texture: Texture2D, depth_z: float, priority: int) -> MeshInstance3D:
	# Registration is measured once at the establishing camera position. Moving
	# the camera later creates genuine near/far parallax, without stretching art.
	var distance := START_CAMERA_Z - depth_z
	var top_left := camera.project_position(Vector2.ZERO, distance)
	var bottom_right := camera.project_position(FRAME, distance)
	var quad := QuadMesh.new()
	quad.size = Vector2(bottom_right.x - top_left.x, top_left.y - bottom_right.y)
	var material := ShaderMaterial.new()
	material.shader = DEPTH_PAINT
	material.set_shader_parameter("layer_texture", texture)
	material.set_shader_parameter("opacity", 0.0)
	material.render_priority = priority
	var node := MeshInstance3D.new()
	node.mesh = quad
	node.position = camera.project_position(FRAME * 0.5, distance)
	node.material_override = material
	add_child(node)
	return node

func _spherical_veil(at: Vector3, radius: float, tint: Color, priority: int) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 64
	sphere.rings = 40
	var material := ShaderMaterial.new()
	material.shader = VOLUME
	material.set_shader_parameter("volume_tint", tint)
	material.set_shader_parameter("radius", radius)
	material.render_priority = priority
	var node := MeshInstance3D.new()
	node.mesh = sphere
	node.position = at
	node.material_override = material
	add_child(node)
	return node

func _ready() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("94a9bc")
	environment.ambient_light_energy = 0.52
	world.environment = environment
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_color = Color("f8d9ab")
	key.light_energy = 0.95
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(25, 130, 20)
	rim.light_color = Color("98bdd9")
	rim.light_energy = 0.72
	add_child(rim)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0, START_CAMERA_Z)
	camera.fov = 41
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	globe = Node3D.new()
	globe.position = camera.project_position(CORE_UV * FRAME, START_CAMERA_Z)
	add_child(globe)

	rear_layer = _registered_plane(preload("res://assets/transparent-earth/core-rear-v3.png"), -2.6, -50)
	front_layer = _registered_plane(preload("res://assets/transparent-earth/core-front-v3.png"), 1.65, 35)
	front_layer.material_override.set_shader_parameter("interior_only", true)
	mist_layer = _registered_plane(preload("res://assets/transparent-earth/core-mist-v3.png"), 0.55, 40)
	near_shell = _spherical_veil(camera.project_position(Vector2(0.489, 0.45) * FRAME, START_CAMERA_Z), 2.55, Color("789dbd"), 20)
	core_volume = _spherical_veil(globe.position, 0.92, Color("677e91"), 25)

	var surface_points := [Vector2(0.61, 0.36), Vector2(0.37, 0.20), Vector2(0.52, 0.23), Vector2(0.34, 0.45), Vector2(0.59, 0.29)]
	for i in range(surface_points.size()):
		var surface_z: float = [1.10, -0.60, 0.65, -0.40, 0.90][i]
		origins.append(camera.project_position(surface_points[i] * FRAME, START_CAMERA_Z - surface_z) - globe.position)
	for i in range(75):
		travellers.append(_sprite(i % 16, 0.00019 + float(i % 4) * 0.000025))

	var ship_stage: Node3D = preload("res://scripts/ending/dynamic_preview/ship_stage.gd").new()
	add_child(ship_stage)
	craft = ship_stage.craft
	craft.reparent(globe)
	craft.position = Vector3.ZERO
	craft.scale = Vector3.ONE * 0.16
	craft.rotation = Vector3(0.08, -0.35, 0.18)
	for coating in ship_stage.coats:
		var original_parameters: Dictionary = {}
		for uniform_name in ["painted_reference", "hull_atlas", "use_atlas", "atlas_region", "base_color"]:
			original_parameters[uniform_name] = coating.get_shader_parameter(uniform_name)
		coating.shader = CORE_HULL
		for uniform_name in original_parameters:
			if original_parameters[uniform_name] != null:
				coating.set_shader_parameter(uniform_name, original_parameters[uniform_name])
		hull_materials.append(coating)
		coating.set_shader_parameter("craft_inverse", craft.global_transform.affine_inverse())
	# V12: the right-hand rear module is the lost engine, not the forward nose.
	for child in craft.get_children():
		if child is OmniLight3D:
			child.queue_free()
		elif child is MeshInstance3D:
			if int(child.get_meta("atlas_section", -1)) == 2 or child.position.x > 1.9:
				child.queue_free()
			elif child.material_override is StandardMaterial3D:
				var material: StandardMaterial3D = child.material_override
				material.emission_enabled = false
				material.albedo_color = Color("7f8a99")
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				detail_materials.append(material)
	ship_stage.camera.current = false
	remove_child(ship_stage)
	ship_stage.queue_free()
	camera.current = true
	heart = _sprite(0, 0.00029)
	heart.position = Vector3(0, -0.12, 0.12)
	core_light = OmniLight3D.new()
	core_light.position = Vector3(-0.3, 0.4, 0.9)
	core_light.light_color = Color("e9c494")
	core_light.omni_range = 3.0
	core_light.light_energy = 0.6
	globe.add_child(core_light)
	step(0.0)

func step(delta: float) -> void:
	clock += delta
	reveal = smoothstep(3.2, 8.7, clock)
	ship_visibility = smoothstep(6.6, 9.4, clock)
	var approach := smoothstep(6.0, 13.5, clock)
	var withdraw := smoothstep(22.0, 28.0, clock)
	var parallax := approach * (1.0 - withdraw * 0.6)
	camera.position = Vector3(0.11 * parallax, 0.06 * parallax, START_CAMERA_Z - 1.18 * approach + 0.76 * withdraw)
	camera.look_at(globe.position * (0.25 * approach))
	rear_layer.material_override.set_shader_parameter("opacity", reveal)
	front_layer.material_override.set_shader_parameter("opacity", 0.26 * reveal)
	mist_layer.material_override.set_shader_parameter("opacity", 0.42 * ship_visibility)
	near_shell.material_override.set_shader_parameter("opacity", 0.035 * reveal)
	core_volume.material_override.set_shader_parameter("opacity", 0.22 * ship_visibility)
	for node in [near_shell, core_volume]:
		node.material_override.set_shader_parameter("film_time", clock)
	craft.visible = ship_visibility > 0.001
	for material in hull_materials:
		material.set_shader_parameter("visibility", ship_visibility)
	for material in detail_materials:
		material.albedo_color.a = ship_visibility
	var beat := pow(maxf(0.0, sin(clock * TAU * 0.78)), 14.0)
	heart.scale = Vector3.ONE * (0.9 + beat * 0.3)
	heart.modulate.a = (0.15 + beat * 0.13) * ship_visibility
	core_light.light_energy = 0.54 + beat * 0.13
	for i in range(travellers.size()):
		var journey := fposmod(clock * 0.064 + float(i) * 0.137, 1.0)
		var origin: Vector3 = origins[i % 5] + Vector3(sin(float(i) * 5.1) * 0.045, cos(float(i) * 3.7) * 0.045, 0)
		travellers[i].position = origin.lerp(Vector3.ZERO, journey)
		travellers[i].modulate.a = sin(journey * PI) * (0.28 + float(i % 5) * 0.08) * ship_visibility
