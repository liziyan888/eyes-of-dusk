extends Node3D
## Three consistent craft sections, lit and rendered live. No video or keyed image.
var craft:Node3D
var camera:Camera3D
var nose_light:OmniLight3D
var heat_under:OmniLight3D
var heat_rear:OmniLight3D
var joint:Node3D
var turn:=0.0
var strain:=0.0
var time:=0.0
var coats:Array[ShaderMaterial]=[]
var atlas_sections:Array[int]=[]
const PaintShader=preload("res://scripts/ending/dynamic_preview/painted_ship.gdshader")
const Reference=preload("res://assets/ending/panels/e18.png")

func paint(color:Color,glow:=0.0)->Material:
	if glow<=0:
		var coating:=ShaderMaterial.new();coating.shader=PaintShader;coating.set_shader_parameter("painted_reference",Reference);coating.set_shader_parameter("base_color",color);coats.append(coating);return coating
	var material:=StandardMaterial3D.new()
	material.albedo_color=color;material.roughness=.92;material.metallic=.22
	if glow>0:
		material.emission_enabled=true;material.emission=color;material.emission_energy_multiplier=glow
	return material

func piece(mesh:Mesh,at:Vector3,material:Material,parent:Node3D)->MeshInstance3D:
	var node:=MeshInstance3D.new();node.mesh=mesh;node.position=at;node.material_override=material;parent.add_child(node);return node

func cylinder(x:float,length:float,radius:float,color:Color,parent:Node3D,top_radius:float=-1)->MeshInstance3D:
	var mesh:=CylinderMesh.new();mesh.height=length;mesh.top_radius=radius if top_radius<0 else top_radius;mesh.bottom_radius=radius;mesh.radial_segments=48
	var coating:=paint(color) as ShaderMaterial
	var section:=3 if parent!=craft else (1 if x< -1.5 else (2 if x>=2.0 else 0))
	var regions:=[Vector4(0,0,.5,.5),Vector4(.5,0,.5,.5),Vector4(0,.5,.5,.5),Vector4(.5,.5,.5,.5)]
	coating.set_shader_parameter("hull_atlas",load("res://assets/ending/dynamic-preview/ship-atlas-2k.png"));coating.set_shader_parameter("use_atlas",true);coating.set_shader_parameter("atlas_region",regions[section]);atlas_sections.append(section)
	var node:=piece(mesh,Vector3(x,0,0),coating,parent);node.rotation.z=PI/2;node.set_meta("atlas_section",section);return node

func ring(x:float,radius:float,width:float,color:Color,parent:Node3D)->void:
	var mesh:=TorusMesh.new();mesh.inner_radius=radius-width;mesh.outer_radius=radius+width;mesh.rings=48;mesh.ring_segments=8
	var node:=piece(mesh,Vector3(x,0,0),paint(color),parent);node.rotation.z=PI/2

func box(at:Vector3,size_value:Vector3,color:Color,parent:Node3D)->MeshInstance3D:
	var mesh:=BoxMesh.new();mesh.size=size_value;return piece(mesh,at,paint(color),parent)

func _ready()->void:
	var environment:=WorldEnvironment.new();var setting:=Environment.new()
	setting.background_mode=Environment.BG_CLEAR_COLOR;setting.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;setting.ambient_light_color=Color("69565e");setting.ambient_light_energy=.27
	setting.tonemap_mode=Environment.TONE_MAPPER_FILMIC;environment.environment=setting;add_child(environment)
	var key:=DirectionalLight3D.new();key.rotation_degrees=Vector3(-42,-25,0);key.light_color=Color("aab3c7");key.light_energy=.65;add_child(key)
	var rim:=DirectionalLight3D.new();rim.rotation_degrees=Vector3(30,125,-20);rim.light_color=Color("ff703a");rim.light_energy=1.3;add_child(rim)
	heat_under=OmniLight3D.new();heat_under.position=Vector3(-1.5,-3.0,2.8);heat_under.light_color=Color("ff793b");heat_under.omni_range=12;heat_under.light_energy=3.1;add_child(heat_under)
	heat_rear=OmniLight3D.new();heat_rear.position=Vector3(4.5,.8,-2.0);heat_rear.light_color=Color("ffae78");heat_rear.omni_range=10;heat_rear.light_energy=1.8;add_child(heat_rear)
	craft=Node3D.new();add_child(craft)
	var gray:=Color("929eae");var pale:=Color("c7cbd0");var dark:=Color("263344")
	# Front melting engine at negative X, main cabin, rear propulsion.
	cylinder(-2.67,2.25,.76,gray,craft)
	cylinder(-4.10,.72,.74,pale,craft,0.1)
	cylinder(.35,2.75,1.01,pale,craft)
	cylinder(2.03,.70,.80,gray,craft,.62)
	cylinder(3.12,1.60,.60,gray,craft)
	for x in [-3.67,-3.20,-2.40,-1.65]:ring(x,.79,.055,pale,craft)
	for x in [-1.0,1.65]:ring(x,1.035,.075,gray,craft)
	for x in [2.40,2.75,3.60,3.96]:ring(x,.63,.055,pale,craft)
	for angle in range(8):
		var a:=float(angle)*TAU/8.0
		var panel:=box(Vector3(.35,cos(a)*1.01,sin(a)*1.01),Vector3(2.10,.045,.48),gray if angle%2==0 else Color("707f91"),craft);panel.rotation.x=a
		var inset:=box(Vector3(.15,cos(a)*1.045,sin(a)*1.045),Vector3(.75,.025,.21),dark,craft);inset.rotation.x=a
		var rail:=box(Vector3(-2.66,cos(a)*.78,sin(a)*.78),Vector3(1.7,.055,.09),dark,craft);rail.rotation.x=a
		var bar:=box(Vector3(-3.97,cos(a)*.41,sin(a)*.41),Vector3(.90,.065,.065),pale,craft);bar.rotation.z=-sin(a)*.38;bar.rotation.y=cos(a)*.38
		var lit:=box(Vector3(-.91,cos(a)*1.07,sin(a)*1.07),Vector3(.10,.025,.25),Color("75bfd8"),craft);lit.rotation.x=a
	joint=Node3D.new();joint.position.x=-1.34;craft.add_child(joint)
	cylinder(0,.28,.56,dark,joint)
	for i in range(6):
		var a:=float(i)*TAU/6
		var brace:=box(Vector3(0,cos(a)*.69,sin(a)*.69),Vector3(.45,.09,.09),Color("a2a6ad"),joint);brace.rotation.x=a
	var core:=SphereMesh.new();core.radius=.44;core.height=.88
	piece(core,Vector3(-4.04,0,0),paint(Color("d57a2e"),.35),craft).scale=Vector3(.46,1,1)
	var hot_tip:=CylinderMesh.new();hot_tip.height=.035;hot_tip.top_radius=.15;hot_tip.bottom_radius=.15
	var tip:=piece(hot_tip,Vector3(-4.47,0,0),paint(Color("e28a33"),1.0),craft);tip.rotation.z=PI/2
	var rear:=CylinderMesh.new();rear.top_radius=.43;rear.bottom_radius=.43;rear.height=.035
	var exhaust:=piece(rear,Vector3(3.98,0,0),paint(Color("75c9ed"),1.2),craft);exhaust.rotation.z=PI/2
	nose_light=OmniLight3D.new();nose_light.position=Vector3(-4.1,.5,1);nose_light.light_color=Color("ff6636");nose_light.omni_range=9;nose_light.light_energy=2.0;craft.add_child(nose_light)
	camera=Camera3D.new();camera.position=Vector3(-3.1,2.3,10.5);camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=12.5;add_child(camera);camera.look_at(Vector3.ZERO);camera.current=true

func update_pose(delta:float)->void:
	time+=delta
	craft.rotation=Vector3(.09+sin(time*.65)*.012,.08+turn*.33,lerpf(.10,-.44,turn)+sin(time*19)*strain*.009)
	craft.position.y=sin(time*.8)*.05
	joint.rotation.x=sin(time*27)*strain*.018
	nose_light.light_energy=2.0+sin(time*15)*strain*.65
	heat_under.position.x=-1.5+sin(time*.7)*1.5;heat_under.light_energy=2.6+sin(time*1.3)*.55+strain*.45
	heat_rear.light_energy=1.7+sin(time*.9+.8)*.35
	camera.size=lerpf(12.5,15.3,strain)
	for coating in coats:
		coating.set_shader_parameter("craft_inverse",craft.global_transform.affine_inverse());coating.set_shader_parameter("heat_clock",time);coating.set_shader_parameter("heat_pressure",strain)
