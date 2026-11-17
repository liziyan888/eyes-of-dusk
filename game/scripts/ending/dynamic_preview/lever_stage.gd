extends Node3D
var handle:Node3D
var camera:Camera3D
var value:=0.0
var knob:MeshInstance3D

func mat(color:Color)->StandardMaterial3D:
	var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=.65;m.metallic=.30;return m

func add_mesh(mesh:Mesh,at:Vector3,color:Color,parent:Node3D)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=mat(color);parent.add_child(node);return node

func _ready()->void:
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-25,0);light.light_color=Color("b4d5e9");light.light_energy=2.4;add_child(light)
	var rim:=OmniLight3D.new();rim.position=Vector3(-2,2,2);rim.light_color=Color("f29a75");rim.omni_range=7;rim.light_energy=2;add_child(rim)
	var base:=BoxMesh.new();base.size=Vector3(.95,.12,.45);add_mesh(base,Vector3(0,-.08,0),Color("424d5b"),self)
	handle=Node3D.new();add_child(handle)
	var rod:=CylinderMesh.new();rod.top_radius=.065;rod.bottom_radius=.09;rod.height=1.15;add_mesh(rod,Vector3(0,.56,0),Color("a6acb3"),handle)
	var grip:=CapsuleMesh.new();grip.radius=.14;grip.height=.48;knob=add_mesh(grip,Vector3(0,1.16,0),Color("384a5d"),handle);knob.rotation.z=PI/2
	var lamp:=BoxMesh.new();lamp.size=Vector3(.24,.04,.285);add_mesh(lamp,Vector3(0,1.24,0),Color("96d5e6"),handle)
	camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=2.50;camera.position=Vector3(2,2.3,5);add_child(camera);camera.look_at(Vector3(0,.55,0));camera.current=true
	set_value(0)

func set_value(v:float)->void:
	value=clampf(v,0,1)
	if handle!=null:handle.rotation.z=lerpf(.32,-.55,value)

func knob_uv()->Vector2:
	return camera.unproject_position(knob.global_position)/Vector2(get_viewport().size)
