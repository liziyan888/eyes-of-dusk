extends RefCounted
const SubtitleStyle=preload("res://scripts/subtitle_style.gd")
## One source of truth for rendering, interaction, proximity triggers, and persistence.
const FILE := "user://layout-v2.json"
var data := {"coordinate_revision":10,"layers":{},"grounds":{}, "points":{}, "player_scale":1.0, "offset_x":0.0, "offset_y":0.0, "overlap":12.0}
var source_layers: Dictionary={}
var layer_order: Array=[]
var layer_reference:=320.0
var scene_layer_orders: Dictionary = {}
var scene_references: Dictionary = {}
var scene_horizons: Dictionary = {}
var passage_layer_order: Array = []
var source_points: Dictionary = {}
var source_grounds: Dictionary = {}
var story: Dictionary

func setup(story_data: Dictionary, load_saved := true) -> void:
	story = story_data
	source_layers.clear();layer_order.clear();scene_layer_orders.clear();scene_references.clear();scene_horizons.clear()
	for index in range(story.scenes.size()):
		if story.scenes[index].has("horizon_y"):scene_horizons[index]=float(story.scenes[index].horizon_y)
		var manifest_path:=str(story.scenes[index].get("psd_manifest",""))
		if manifest_path.is_empty() or not FileAccess.file_exists(manifest_path):continue
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
		scene_references[index]=float(manifest.reference_camera)
		if manifest.has("horizon_y"):scene_horizons[index]=float(manifest.horizon_y)
		var order: Array=[]
		for entry in manifest.layers:
			entry=entry.duplicate(true)
			entry["scene_index"]=index
			source_layers[str(entry.id)]=entry
			order.append(str(entry.id))
		scene_layer_orders[index]=order
		if index==2:
			layer_reference=float(manifest.reference_camera)
			layer_order=order
	passage_layer_order.clear()
	var passage: Dictionary=story.world.get("passage12",{})
	if not passage.is_empty():
		var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(passage.psd_manifest))
		for source in manifest.layers:
			var entry: Dictionary=source.duplicate(true)
			entry["scene_index"]=0
			source_layers[str(entry.id)]=entry
			passage_layer_order.append(str(entry.id))
	for sc in story.scenes:
		source_grounds[str(int(sc.id))] = float(sc.get("ground", 566))
	for point in story.interactions:
		source_points[str(point.id)] = {"x":float(point.x),"y":float(point.get("y", source_grounds[str(int(point.scene))]))}
	if FileAccess.file_exists("res://data/web_layout_seed.json"):
		apply(JSON.parse_string(FileAccess.get_file_as_string("res://data/web_layout_seed.json")))
	if load_saved and FileAccess.file_exists(FILE):
		apply(JSON.parse_string(FileAccess.get_file_as_string(FILE)))

func ground(sc: Dictionary) -> float:
	return float(data.grounds.get(str(int(sc.id)), sc.get("ground", 566)))

func point_position(point: Dictionary,camera_x:=NAN) -> Vector2:
	var sc: Dictionary = story.scenes[int(point.scene)-1]
	var saved: Dictionary = data.points.get(str(point.id), {})
	var base:=Vector2(float(point.x),float(point.get("y",ground(sc))))
	var stored:=Vector2(float(saved.get("x",base.x)),float(saved.get("y",base.y)))
	return linked_base(point,camera_x)+stored-base if point.has("layer_id") else stored+Vector2(0,point_vertical_offset(point))

func point_vertical_offset(point: Dictionary) -> float:
	return 0.0 if point.has("layer_id") else float(story.scenes[int(point.scene)-1].get("point_offset_y",0))

func point_edit_max_y(point: Dictionary) -> float:
	var sc: Dictionary=story.scenes[int(point.scene)-1]
	return 720+maxf(0,float(sc.get("point_edit_margin",point_vertical_offset(point))))

func set_point(point: Dictionary, value: Vector2,camera_x:=NAN) -> void:
	if str(point.id)=="s5-morning-glasses":
		for shared in story.interactions:
			if str(shared.id)=="s5-willow":set_point(shared,value,camera_x);return
	var sc: Dictionary = story.scenes[int(point.scene)-1]
	value=Vector2(clampf(value.x,float(sc.start)+46,float(sc.end)-52),clampf(value.y,0,point_edit_max_y(point)))
	if point.has("layer_id"):
		value+=Vector2(float(point.x),float(point.get("y",ground(sc))))-linked_base(point,camera_x)
	else:value.y-=point_vertical_offset(point)
	data.points[str(point.id)] = {"x":value.x,"y":value.y}

func linked_base(point: Dictionary,camera_x:=NAN) -> Vector2:
	var entry:=layer_parameters(str(point.get("layer_id","")))
	if entry.is_empty():return Vector2(float(point.x),float(point.get("y",660)))
	var start:=float(entry.get("region_start",story.scenes[int(point.scene)-1].start))
	var anchor: Array=point.layer_anchor
	var drift: float=layer_drift(entry,camera_x) if is_finite(camera_x) else 0.0
	return layer_position(entry)+Vector2(start+float(anchor[0])*float(entry.scale)+drift,float(anchor[1])*float(entry.scale))

func horizon_y() -> float:
	return float(story.world.get("horizon_y",565.0))

func scene_vertical_offset(index: int) -> float:
	return horizon_y()-float(scene_horizons[index]) if scene_horizons.has(index) else 0.0

func layer_position(entry: Dictionary) -> Vector2:
	# Saved/editor coordinates stay in the source canvas; register once at rendering/linking.
	return Vector2(float(entry.x),float(entry.y)+scene_vertical_offset(int(entry.scene_index)))

func layer_parameters(id: String) -> Dictionary:
	if not source_layers.has(id):return {}
	var entry: Dictionary=source_layers[id].duplicate(true)
	entry.merge(data.layers.get(id,{}),true)
	return entry

func layers_for_scene(index: int) -> Array:
	return scene_layer_orders.get(index,[])

func reference_for_scene(index: int) -> float:
	return float(scene_references.get(index,320.0))

func layer_drift(entry: Dictionary,camera_x: float) -> float:
	var index:=int(entry.get("scene_index",2))
	var sc: Dictionary=story.scenes[index]
	var start:=float(entry.get("region_start",sc.start))
	var reference:=float(entry.get("reference_camera",reference_for_scene(index)))
	# Every layer keeps its authored coefficient throughout the horizontal world.
	return (1-float(entry.f))*(camera_x-start-reference)

func reset_scene_layers(index: int) -> void:
	for id in layers_for_scene(index):reset_layer(str(id))

func set_layer(id: String,field: String,value: Variant) -> bool:
	if not source_layers.has(id):return false
	var limits: Dictionary={"f":Vector2(0,1.5),"x":Vector2(-4000,6000),"y":Vector2(-2000,2500),"scale":Vector2(.1,3)}
	if field=="visible":
		if not value is bool:return false
	elif limits.has(field):
		if not (value is float or value is int) or not is_finite(float(value)):return false
		value=clampf(float(value),limits[field].x,limits[field].y)
	else:return false
	if not data.layers.has(id):data.layers[id]={}
	data.layers[id][field]=value
	return true

func reset_layer(id: String) -> void:data.layers.erase(id)

func apply(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	if value.has("subtitles"):data["subtitles"]=SubtitleStyle.normalize(value.subtitles)
	var legacy_creek_ground:=660.0
	if value.get("grounds") is Dictionary:
		var saved_ground: Variant=value.grounds.get("2",660.0)
		if (saved_ground is int or saved_ground is float) and is_finite(float(saved_ground)):
			legacy_creek_ground=clampf(float(saved_ground),400,700)
	if value.get("layers") is Dictionary:
		for id in value.layers:
			if value.layers[id] is Dictionary:
				for field in value.layers[id]:set_layer(str(id),str(field),value.layers[id][field])
	for key in ["player_scale","offset_x","offset_y","overlap"]:
		var v: Variant = value.get(key, data[key])
		if (v is float or v is int) and is_finite(float(v)):
			var limits := {"player_scale":Vector2(0.25,3),"offset_x":Vector2(-400,400),"offset_y":Vector2(-300,300),"overlap":Vector2(4,30)}
			data[key] = clampf(float(v), limits[key].x, limits[key].y)
	if value.get("grounds") is Dictionary:
		for sc in story.scenes:
			var v: Variant = value.grounds.get(str(int(sc.id)))
			if (v is int or v is float) and is_finite(float(v)):
				# Keep a legacy manual footline's offset from the old scene-two default.
				if int(sc.id)==2 and int(value.get("coordinate_revision",1))<4:v=float(v)+40.0
				if int(sc.id)==1 and int(value.get("coordinate_revision",1))<5:v=float(v)+40.0
				if int(sc.id) in [4,5] and int(value.get("coordinate_revision",1))<6:v=float(v)+134.0
				data.grounds[str(int(sc.id))] = clampf(float(v),400,740)
	if value.get("points") is Dictionary:
		for point in story.interactions:
			# The old stone anchor is no longer the prop support. Keep all other authored settings.
			if str(point.id) in ["s5-willow","s5-morning-glasses"] and int(value.get("coordinate_revision",1))<10:continue
			var v: Variant = value.points.get(str(point.id))
			if v is Dictionary and (v.get("x") is float or v.get("x") is int) and (v.get("y") is float or v.get("y") is int):
				if is_finite(float(v.x)) and is_finite(float(v.y)):
					var pos:=Vector2(float(v.x),float(v.y))
					var basis: Array=point.get("previous_scene12_position",[point.x,point.get("y",660)]) if int(value.get("coordinate_revision",1))<7 else [point.x,point.get("y",660)]
					if int(value.get("coordinate_revision",1))<2:
						var old_x: Dictionary={"s3-door":4510.0,"s3-dinner":4680.0,"s3-sunset":5140.0}
						if old_x.has(str(point.id)):
							pos.x+=float(basis[0])-float(old_x[str(point.id)])
							pos.y+=float(basis[1])-660
						elif int(point.scene)>3:pos.x+=320
					elif int(value.get("coordinate_revision",1))==2 and point.has("previous_psd_position"):
						pos+=Vector2(float(basis[0]),float(basis[1]))-Vector2(float(point.previous_psd_position[0]),float(point.previous_psd_position[1]))
					if int(point.scene)==2 and int(value.get("coordinate_revision",1))<4:
						# The old implicit point Y followed the old saved footline; freeze its source basis.
						pos.y+=660.0-legacy_creek_ground
					if int(value.get("coordinate_revision",1))<6 and point.has("previous_scene45_position"):
						var previous: Array=point.previous_scene45_position
						pos+=Vector2(float(basis[0]),float(basis[1]))-Vector2(float(previous[0]),float(previous[1]))
					if int(value.get("coordinate_revision",1))<7 and point.has("previous_scene12_position"):
						pos=Vector2(float(point.x)+(pos.x-float(basis[0]))*float(point.get("scene12_x_scale",1.)),float(point.get("y",660))+pos.y-float(basis[1]))
					if int(value.get("coordinate_revision",1))==7 and point.has("previous_prop_position"):
						var previous:Array=point.previous_prop_position
						pos+=Vector2(float(point.x)-float(previous[0]),float(point.get("y",660))-float(previous[1]))
					if int(value.get("coordinate_revision",1)) in [7,8] and point.has("previous_water_position"):
						var previous:Array=point.previous_water_position
						pos+=Vector2(float(point.x)-float(previous[0]),float(point.get("y",660))-float(previous[1]))
					data.points[str(point.id)]={"x":pos.x,"y":pos.y}
	return true

func save(path := FILE) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data,"\t"))
	return true

func reset() -> void:
	data = {"coordinate_revision":9,"layers":{},"grounds":{}, "points":{}, "player_scale":1.0, "offset_x":0.0, "offset_y":0.0, "overlap":12.0}

func offset() -> Vector2:
	return Vector2(data.offset_x,data.offset_y)

func subtitles()->Dictionary:return SubtitleStyle.normalize(data.get("subtitles",{}))

func set_subtitle(role:String,field:String,value:Variant)->void:
	if role not in ["her","man"] or not SubtitleStyle.defaults(role).has(field):return
	var styles:=subtitles();styles[role][field]=value
	if field in ["background_x","background_y","background_width","background_height"]:styles[role].background_auto=false
	data["subtitles"]=SubtitleStyle.normalize(styles)

func reset_subtitles(role:String)->void:
	var styles:=subtitles();styles[role]=SubtitleStyle.defaults(role);data["subtitles"]=styles
