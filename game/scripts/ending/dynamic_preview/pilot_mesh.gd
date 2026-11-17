extends Node2D
## A weighted textured mesh bends the torso around the collar instead of moving
## a rectangular cutout. Large changes of pose still require authored drawings.
var skeleton:Skeleton2D
var chest:Bone2D
var head:Bone2D
var cloth:Polygon2D
var clock:=0.0
var stress:=0.0

func _ready()->void:
	var texture:=load("res://assets/ending/dynamic-preview/navigator-2k.png") as Texture2D
	var shape:=Vector2(520,624)
	skeleton=Skeleton2D.new();add_child(skeleton)
	chest=Bone2D.new();chest.name="Chest";chest.position=Vector2(260,530);chest.set_autocalculate_length_and_angle(false);chest.set_length(150);chest.set_bone_angle(-PI/2);skeleton.add_child(chest)
	head=Bone2D.new();head.name="NeckAndHead";head.position=Vector2(0,-200);head.set_autocalculate_length_and_angle(false);head.set_length(200);head.set_bone_angle(-PI/2);chest.add_child(head)
	chest.rest=chest.transform;head.rest=head.transform
	cloth=Polygon2D.new();cloth.texture=texture;cloth.antialiased=true;add_child(cloth);cloth.skeleton=cloth.get_path_to(skeleton)
	var points:=PackedVector2Array();var uv:=PackedVector2Array();var polygons:Array[PackedInt32Array]=[]
	var chest_weights:=PackedFloat32Array();var head_weights:=PackedFloat32Array()
	var columns:=20;var rows:=24
	for y in range(rows+1):
		for x in range(columns+1):
			var p:=Vector2(float(x)/columns,float(y)/rows)
			points.append(p*shape);uv.append(p*texture.get_size())
			var weight:=1.0-smoothstep(.35,.64,p.y);head_weights.append(weight);chest_weights.append(1.0-weight)
	for y in rows:
		for x in columns:
			var i:=y*(columns+1)+x
			polygons.append(PackedInt32Array([i,i+1,i+columns+2,i+columns+1]))
	cloth.polygon=points;cloth.uv=uv;cloth.polygons=polygons
	cloth.add_bone(skeleton.get_path_to(chest),chest_weights);cloth.add_bone(skeleton.get_path_to(head),head_weights)

func update_pose(delta:float)->void:
	clock+=delta
	chest.scale=Vector2(1.0+sin(clock*2.3)*.0025,1.0+sin(clock*2.3)*.004)
	chest.rotation=sin(clock*1.8)*.003+sin(clock*16)*stress*.006
	head.rotation=-sin(clock*1.8)*.003+sin(clock*11)*stress*.008
