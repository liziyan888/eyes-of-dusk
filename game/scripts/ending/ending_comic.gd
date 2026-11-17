extends Control
const Mix=preload("res://scripts/audio_mix.gd")
## Independent "落日六号" ending reader.  This script intentionally does not
## reference the formal game, its main.gd, story.json or prologue save.

signal ready_to_reveal
signal ending_completed(result: Dictionary)
signal return_to_title_requested
signal fullscreen_requested
signal transparent_earth_requested

const ART := "res://assets/ending/"
const DATA_PATH := "res://data/ending.json"
const VOICE_PATH := "res://assets/ending/audio/voice_last_recording.wav"
const SAVE_DEFAULT := "user://ending-v1.json"
const PAPER := Color("fbfaf7")
const INK := Color("f1eee5")
const DIALOGUE_INK := Color("293b46")

const ART_SHADER = preload("res://shaders/ending/ending_art.gdshader")
const RESTORE_SHADER = preload("res://shaders/ending/ending_restore.gdshader")
const OBSERVE_SHADER = preload("res://shaders/ending/ending_observation.gdshader")
const TURN_SHADER = preload("res://shaders/ending/ending_page_turn.gdshader")
const SCRIM_TEXTURE = preload("res://assets/ending/transitions/scrim_soft.png")
const Hotspot = preload("res://scripts/ending/ending_hotspot.gd")
const PageCurl = preload("res://scripts/ending/ending_page_curl.gd")
const ComicPanel = preload("res://scripts/ending/ending_panel.gd")
const Waveform = preload("res://scripts/ending/ending_waveform.gd")
const MemoryVideo = preload("res://scripts/ending/ending_memory_video.gd")
const ArchiveSequence = preload("res://scripts/ending/ending_archive_sequence.gd")

var data: Dictionary = {}
var flat: Array[Dictionary] = []
var pages: Array = []
var page_index := 0
var frontier := -1
var discoveries: Dictionary = {}
var records: Dictionary = {}
var muted := false
var complete := false
var save_path := SAVE_DEFAULT
var test_mode := false

var serial := 0
var page_root: Control
var paper: ColorRect
var curl: Control
var back_curl: Control
var modal: Control
var modal_kind := ""
var final_layer: Control
var transition_layer: Control
var page_turning := false
var transitioning := false
var final_running := false
var final_emitted := false
var input_locked := false
var clock := 0.0
var particles_clock := 0.0

var ui_font: Font
var serif_font: Font

var panels: Array[Dictionary] = []
var active_tweens: Array[Tween] = []
var audio_tweens: Array[Tween] = []
var ambience_tweens:Array[Tween]=[]
var music_tween:Tween
var ambience_a: AudioStreamPlayer
var ambience_b: AudioStreamPlayer
var music: AudioStreamPlayer
var music_old: AudioStreamPlayer
var music_old_tween:Tween
var effects: Array[AudioStreamPlayer] = []
var current_music := ""
var music_gain_db:=-5.0
var current_ambience := ""
var current_ambience_file := ""
var current_ambience_volume := -11.0
var record_player: AudioStreamPlayer
var voice_player: AudioStreamPlayer
var record_wave: Control
var record_lines_label: Label
var record_button: Button
var record_playing := false
var record_has_audio := false
var page_video:Control


func _ready() -> void:
	position = Vector2.ZERO
	mouse_filter = MOUSE_FILTER_STOP
	ui_font = WebSystemFont.new()
	ui_font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	serif_font = WebSystemFont.new()
	serif_font.font_names = PackedStringArray(["Noto Serif CJK SC", "Source Han Serif SC", "SimSun", "Microsoft YaHei"])
	_load_data()
	paper = ColorRect.new()
	paper.color = PAPER
	paper.position = Vector2.ZERO
	paper.size = size
	paper.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(paper)
	page_root = Control.new()
	page_root.position = Vector2.ZERO
	page_root.size = size
	page_root.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(page_root)
	back_curl = PageCurl.new()
	back_curl.backwards = true
	back_curl.z_index = 9
	back_curl.turn_requested.connect(func(): turn_page(-1))
	add_child(back_curl)
	back_curl.hide()
	curl = PageCurl.new()
	curl.z_index = 9
	curl.turn_requested.connect(func(): turn_page(1))
	add_child(curl)
	curl.hide()
	ambience_a = AudioStreamPlayer.new()
	ambience_a.bus = "Ambience"
	ambience_a.volume_db = -60
	add_child(ambience_a)
	ambience_b = AudioStreamPlayer.new()
	ambience_b.bus = "Ambience"
	ambience_b.volume_db = -60
	add_child(ambience_b)
	music = AudioStreamPlayer.new()
	music.bus = "Music"
	music.volume_db = -60
	add_child(music)
	record_player = AudioStreamPlayer.new()
	record_player.bus = "Voice"
	record_player.volume_db = -2
	add_child(record_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	voice_player.volume_db = -60
	voice_player.finished.connect(_on_final_voice_finished)
	add_child(voice_player)
	for i in range(4):
		var effect := AudioStreamPlayer.new()
		effect.bus = "Effects"
		effect.volume_db = -8
		add_child(effect)
		effects.append(effect)
	hide()


func _load_data() -> void:
	var text := FileAccess.get_file_as_string(DATA_PATH)
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_error("ending data could not be parsed: " + DATA_PATH)
		return
	data = parsed
	pages = data.get("pages", [])
	flat.clear()
	for p in range(pages.size()):
		var page: Dictionary = pages[p]
		var items: Array = page.get("panels", [])
		for i in range(items.size()):
			var item: Dictionary = items[i]
			item["_page"] = p
			item["_local"] = i
			item["_index"] = flat.size()
			flat.append(item)


func _reset_state() -> void:
	page_index = 0
	frontier = -1
	discoveries.clear()
	records.clear()
	complete = false
	final_emitted = false


func _save() -> void:
	if test_mode:
		return
	var read_ids: Array[String] = []
	for i in range(min(frontier + 1, flat.size())):
		read_ids.append(str(flat[i].get("id", "")))
	var page_id := ""
	if page_index >= 0 and page_index < pages.size():
		page_id = str(pages[page_index].get("id", ""))
	var payload := {
		"schema_version": 1,
		"script_version": str(data.get("script_version", "")),
		"read_ids": read_ids,
		"page_id": page_id,
		"last_source_id": str(flat[frontier].get("source_id", "")) if frontier >= 0 and frontier < flat.size() else "",
		"discoveries": discoveries,
		"records": records,
		"muted": muted,
		"complete": complete,
	}
	var dir := save_path.get_base_dir()
	if dir.begins_with("user://"):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload, "\t", false))
		f.close()


func _load_save() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (parsed is Dictionary):
		return false
	muted = false # Global preference is stored by AudioSettings.
	discoveries = parsed.get("discoveries", {})
	records = parsed.get("records", {})
	complete = bool(parsed.get("complete", false))
	var ids: Array = parsed.get("read_ids", [])
	frontier = -1
	for id in ids:
		var idx := _index_of_id(str(id))
		if idx == frontier + 1:
			frontier = idx
		elif idx > frontier + 1:
			break
	if frontier < 0 and parsed.has("frontier"):
		frontier = clampi(int(parsed.get("frontier", -1)), -1, flat.size() - 1)
	if complete:
		frontier = flat.size() - 1
		page_index = max(0, pages.size() - 1)
	elif frontier >= 0:
		page_index = int(flat[frontier].get("_page", 0))
	else:
		page_index = 0
	# Preserve the page actually open when saving, including the unread page
	# immediately after the archive. The frontier alone points at skipped art.
	var saved_page:=_page_by_id(str(parsed.get("page_id","")))
	if not complete and saved_page>=0:
		var saved_items:Array=pages[saved_page].get("panels",[])
		if not saved_items.is_empty() and int(saved_items[0].get("_index",0))<=frontier+1:
			page_index=saved_page
	page_index = clampi(page_index, 0, max(0, pages.size() - 1))
	# Old saves inside the replaced accident pages resume at the recap entrance.
	for p in range(pages.size()):
		var resume_id:=str(pages[p].get("exit_video",{}).get("resume_page",""))
		if resume_id.is_empty():continue
		var destination:=_page_by_id(resume_id)
		if destination>p and page_index>p and page_index<destination:page_index=p
	return true


func _index_of_id(id: String) -> int:
	for i in range(flat.size()):
		if str(flat[i].get("id", "")) == id:
			return i
	return -1


func begin(context: Dictionary = {}) -> void:
	serial += 1
	var token := serial
	_close_page_video()
	_final_cleanup()
	_close_modal(false)
	_cancel_tweens()
	_cancel_audio_tweens()
	_stop_all_audio()
	transitioning = false
	page_turning = false
	final_running = false
	input_locked = false
	final_emitted = false
	if is_instance_valid(final_layer):
		final_layer.queue_free()
	final_layer = null
	if is_instance_valid(transition_layer):
		transition_layer.queue_free()
	transition_layer = null
	var fresh := bool(context.get("fresh", false))
	if fresh:
		_reset_state()
	else:
		if not _load_save():
			_reset_state()
	if test_mode and "--preview-collapse-video" in OS.get_cmdline_user_args():
		get_window().title="带上她的眼睛 · 落日六号事故回放预览"
		var index:=_index_of_id("e012")
		if index>=0:page_index=int(flat[index]._page);frontier=index-1
	if context.has("audio_enabled"):
		muted = not bool(context.get("audio_enabled"))
	paper.show()
	page_root.show()
	show()
	_set_sound_levels()
	_build_page()
	_save()
	_emit_after_first_frame(token)


func _emit_after_first_frame(token: int) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if token != serial or not is_inside_tree():
		return
	ready_to_reveal.emit()


func close() -> void:
	serial += 1
	_close_page_video()
	_cancel_tweens()
	_cancel_audio_tweens()
	_stop_all_audio()
	_final_cleanup()
	_close_modal(false)
	_clear_page()
	if is_instance_valid(transition_layer):
		transition_layer.queue_free()
	transition_layer = null
	hide()


func _clear_page() -> void:
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()
	panels.clear()
	input_locked = false


func _build_page() -> void:
	# Tweens that point at the outgoing page must not fire into freed nodes.
	# The page-turn tween is created only after this rebuild.
	_cancel_tweens()
	_close_modal(false)
	for child in page_root.get_children():
		page_root.remove_child(child)
		child.queue_free()
	panels.clear()
	page_root.show()
	if page_index < 0 or page_index >= pages.size():
		return
	var page: Dictionary = pages[page_index]
	_ambient(str(page.get("ambience", "room")))
	_set_music(str(page.get("music", "")))
	var items: Array = page.get("panels", [])
	for i in range(items.size()):
		var item: Dictionary = items[i]
		var r := _rect_from_array(item.get("rect", [0, 0, 1280, 720]))
		var node := ComicPanel.new()
		node.set_meta("text_scope","ending-panel-"+str(item.get("source_id",item.get("id",i))))
		node.position = r.position
		node.size = r.size
		node.mouse_filter = MOUSE_FILTER_STOP
		node.clip_contents = false
		node.accessibility_name = "第%s格" % str(item.get("source_id", ""))
		page_root.add_child(node)
		var poly := _polygon_for(item, r.size)
		node.hit_polygon = poly
		var clip := Polygon2D.new()
		clip.polygon = poly
		clip.color = Color(1, 1, 1, 1)
		clip.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		node.add_child(clip)
		var texture := _load_panel_texture(item)
		var atlas := _atlas_for(texture, r.size, _vec2(item.get("focus", [0.5, 0.5])), item.get("crop", null))
		var region: Rect2 = atlas.region
		var image := TextureRect.new()
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_SCALE
		image.texture = atlas
		image.position = Vector2.ZERO
		image.size = r.size
		image.mouse_filter = MOUSE_FILTER_IGNORE
		var mat := ShaderMaterial.new()
		mat.shader = ART_SHADER
		mat.set_shader_parameter("rect_size", r.size)
		mat.set_shader_parameter("reveal", 0.0)
		mat.set_shader_parameter("grade_sat", float(item.get("grade_sat", 1.0)))
		_apply_local_patch(mat,item)
		image.material = mat
		clip.add_child(image)
		var entry := {
			"node": node,
			"data": item,
			"index": i,
			"flat_index": int(item.get("_index", -1)),
			"image": image,
			"material": mat,
			"texture": texture,
			"region": region,
			"texts": [],
			"buttons": [],
			"overlay": null,
			"overlay_material": null,
			"foreground": null,
			"reveal_tween": null,
			"scene_type": str(item.get("scene_type", "reality")),
		}
		_add_foreground_layer(entry, clip)
		_add_texts(entry)
		_add_interaction(entry)
		var idx := i
		node.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				unlock(idx, event.position / r.size)
				node.accept_event()
			elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SPACE, KEY_ENTER]:
				unlock(idx, Vector2(0.5, 0.5))
				node.accept_event())
		panels.append(entry)
	_refresh_panels()
	if complete:
		call_deferred("_show_complete_card", false)
	elif frontier >= flat.size() - 1 and page_index == pages.size() - 1 and not final_running:
		call_deferred("_start_final_sequence", true)


func _load_panel_texture(item: Dictionary) -> Texture2D:
	var layers = item.get("layers", {})
	if layers is Dictionary:
		var clean_path := str(layers.get("clean", ""))
		if not clean_path.is_empty() and ResourceLoader.exists(clean_path):
			return load(clean_path)
	var path := str(item.get("source_file", ""))
	if path.is_empty():
		var sid := str(item.get("source_id", ""))
		path = ART + "panels/e%s.png" % sid
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("missing panel art: " + path)
	var image := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	image.fill(Color(0.12, 0.14, 0.17))
	return ImageTexture.create_from_image(image)


func _atlas_for(texture: Texture2D, target: Vector2, focus: Vector2, crop_data) -> AtlasTexture:
	var source_size := texture.get_size()
	var src := Rect2(Vector2.ZERO, source_size)
	if crop_data is Array and crop_data.size() == 4:
		src = Rect2(
			float(crop_data[0]) * source_size.x,
			float(crop_data[1]) * source_size.y,
			float(crop_data[2]) * source_size.x,
			float(crop_data[3]) * source_size.y)
	var ratio := target.x / target.y
	if src.size.x / src.size.y > ratio:
		var width := src.size.y * ratio
		src.position.x += clampf(focus.x * src.size.x - width / 2.0, 0.0, src.size.x - width)
		src.size.x = width
	else:
		var height := src.size.x / ratio
		src.position.y += clampf(focus.y * src.size.y - height / 2.0, 0.0, src.size.y - height)
		src.size.y = height
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = src
	return atlas


func _rect_from_array(a) -> Rect2:
	if a is Array and a.size() == 4:
		return Rect2(float(a[0]), float(a[1]), float(a[2]), float(a[3]))
	return Rect2(0, 0, 1280, 720)


func _vec2(a) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2(0.5, 0.5)


func _polygon_for(item: Dictionary, s: Vector2) -> PackedVector2Array:
	var shape = item.get("shape", null)
	var result := PackedVector2Array()
	if shape is Array and shape.size() >= 3:
		for p in shape:
			if p is Array and p.size() >= 2:
				result.append(Vector2(float(p[0]) * s.x, float(p[1]) * s.y))
	if result.size() < 3:
		result = PackedVector2Array([Vector2.ZERO, Vector2(s.x, 0), s, Vector2(0, s.y)])
	return result


func _add_foreground_layer(entry: Dictionary, clip: Node) -> void:
	var layers = entry.data.get("layers", null)
	if not (layers is Dictionary):
		return
	var clean_path := str(layers.get("clean", ""))
	var fg_path := str(layers.get("foreground", ""))
	if clean_path.is_empty() or fg_path.is_empty():
		return
	if not ResourceLoader.exists(clean_path) or not ResourceLoader.exists(fg_path):
		return
	var fg_tex: Texture2D = load(fg_path)
	var atlas := _atlas_for(fg_tex, entry.node.size, _vec2(entry.data.get("focus", [0.5, 0.5])), entry.data.get("crop", null))
	var is_pencil:bool=str(entry.data.get("interaction",{}).get("type",""))=="pencil"
	var object_bounds:=Rect2(Vector2.ZERO,fg_tex.get_size())
	if is_pencil:
		var object_image:=fg_tex.get_image()
		if object_image.is_compressed():object_image.decompress()
		object_bounds=Rect2(object_image.get_used_rect())
	var fg := TextureRect.new()
	fg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fg.stretch_mode = TextureRect.STRETCH_SCALE
	fg.texture = atlas
	fg.position = Vector2.ZERO
	fg.size = entry.node.size
	var pivot := _source_point(entry, _vec2(layers.get("pivot_uv", [0.5, 0.5])))
	if is_pencil:
		var scale_to_panel:Vector2=entry.node.size/entry.region.size
		var uniform:float=entry.texture.get_width()*.61*scale_to_panel.x/maxf(object_bounds.size.x,1.0)
		fg.texture=fg_tex
		fg.size=fg_tex.get_size()*uniform
		fg.position=pivot-object_bounds.get_center()*uniform
		entry.material.set_shader_parameter("object_edge_cleanup",false)
		entry["foreground_source_bounds"]=object_bounds
		entry["foreground_base"]=fg.position
	fg.pivot_offset = pivot-fg.position
	fg.mouse_filter = MOUSE_FILTER_IGNORE
	fg.material = entry.material
	if is_pencil:fg.material=null
	fg.visible = false
	clip.add_child(fg)
	entry["foreground"] = fg


func _source_point(entry: Dictionary, asset_uv: Vector2) -> Vector2:
	var tex_size: Vector2 = entry.texture.get_size()
	var region: Rect2 = entry.region
	return Vector2(
		(asset_uv.x * tex_size.x - region.position.x) / maxf(region.size.x, 1.0) * entry.node.size.x,
		(asset_uv.y * tex_size.y - region.position.y) / maxf(region.size.y, 1.0) * entry.node.size.y)


func _add_texts(entry: Dictionary) -> void:
	var item: Dictionary = entry.data
	var list: Array = item.get("texts", [])
	if list.is_empty() and item.has("text"):
		list = [{"kind": "narration", "text": str(item.get("text", ""))}]
	var node: Control = entry.node
	for raw in list:
		var spec: Dictionary = raw
		var kind := str(spec.get("kind", "narration"))
		if kind == "speech":
			_add_bubble(entry, spec)
		elif kind == "center":
			_add_center(entry, spec)
		else:
			_add_narration(entry, spec)


func _add_narration(entry: Dictionary, spec: Dictionary) -> void:
	var node: Control = entry.node
	var s: Vector2 = node.size
	var b: Array = spec.get("box", [0.045, 0.70, 0.91, 0.25])
	var box := Rect2(float(b[0]) * s.x, float(b[1]) * s.y, float(b[2]) * s.x, float(b[3]) * s.y)
	var fs := int(spec.get("size", 20))
	var pad := 10.0
	var text := str(spec.get("text", ""))
	var measured: Vector2 = serif_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, fs)
	var available := s.y - box.position.y - 6.0
	while fs > 16 and measured.y + pad * 2.0 + 4.0 > available:
		fs -= 1
		measured = serif_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, fs)
	box.size.y = minf(available, ceil(measured.y) + pad * 2.0 + 4.0)
	box.position.y = clampf(box.position.y, 0.0, s.y - box.size.y)
	var holder := Control.new()
	holder.position = box.position
	holder.size = box.size
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	node.add_child(holder)
	var shade := TextureRect.new()
	shade.texture = SCRIM_TEXTURE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2(-18, -28)
	shade.size = Vector2(box.size.x + 36, box.size.y + 38)
	shade.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(shade)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", serif_font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", Color(INK, float(spec.get("alpha", 1.0))))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.80))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.36))
	label.add_theme_constant_override("outline_size", 2)
	label.text = text
	label.position = Vector2(pad, pad)
	label.size = Vector2(box.size.x - pad * 2.0, box.size.y - pad * 2.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(label)
	label.set_meta("text_frame",weakref(holder));label.set_meta("text_frame_padding",holder.size-label.size);label.set_meta("text_backdrop",weakref(shade));label.set_meta("text_backdrop_padding",Vector2(36,38))
	entry.texts.append({"node": holder, "label": label, "kind": "narration"})


func _add_bubble(entry: Dictionary, spec: Dictionary) -> void:
	var node: Control = entry.node
	var s: Vector2 = node.size
	var b: Array = spec.get("box", [0.06, 0.62, 0.44, 0.30])
	var max_w := minf(float(b[2]) * s.x, 380.0)
	var fs := int(spec.get("size", 19))
	var pad_x := 16.0
	var pad_y := 13.0
	var text := str(spec.get("text", ""))
	var measured: Vector2 = serif_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w - pad_x * 2.0, fs)
	var who := str(spec.get("who", ""))
	var who_h := 17.0 if not who.is_empty() else 0.0
	while fs > 15 and measured.y + pad_y * 2.0 + who_h > s.y - 20.0:
		fs -= 1
		measured = serif_font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, max_w - pad_x * 2.0, fs)
	var box := Rect2(float(b[0]) * s.x, float(b[1]) * s.y, max_w, ceil(measured.y) + pad_y * 2.0 + who_h)
	box.position.x = clampf(box.position.x, 8.0, s.x - box.size.x - 8.0)
	box.position.y = clampf(box.position.y, 8.0, s.y - box.size.y - 8.0)
	var bubble := Panel.new()
	bubble.position = box.position
	bubble.size = box.size
	bubble.mouse_filter = MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color(0.26, 0.33, 0.38, 0.44)
	style.set_border_width_all(0)
	style.corner_radius_top_left = 23
	style.corner_radius_top_right = 28
	style.corner_radius_bottom_left = 26
	style.corner_radius_bottom_right = 20
	style.shadow_color = Color(0.01, 0.02, 0.03, 0.18)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0, 2)
	bubble.add_theme_stylebox_override("panel", style)
	node.add_child(bubble)
	if not who.is_empty():
		var who_label := Label.new()
		who_label.add_theme_font_override("font", ui_font)
		who_label.add_theme_font_size_override("font_size", 11)
		who_label.add_theme_color_override("font_color", Color("9ec8ed") if who in ["她","女孩"] else Color("ffce8d"))
		who_label.text = who
		who_label.position = Vector2(pad_x, 6)
		who_label.size = Vector2(box.size.x - pad_x * 2.0, 14)
		who_label.mouse_filter = MOUSE_FILTER_IGNORE
		bubble.add_child(who_label)
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", serif_font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", Color("fff9ed"))
	label.text = text
	label.position = Vector2(pad_x, 6 + who_h)
	label.size = Vector2(box.size.x - pad_x * 2.0, box.size.y - who_h - 10.0)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	bubble.add_child(label)
	preload("res://scripts/dialogue_appearance.gd").attach(label,"her" if who in ["她","女孩"] else "man")
	label.set_meta("text_frame",weakref(bubble));label.set_meta("text_frame_padding",bubble.size-label.size)
	entry.texts.append({"node": bubble, "label": label, "kind": "speech"})


func _add_center(entry: Dictionary, spec: Dictionary) -> void:
	var holder := Control.new()
	holder.position = Vector2.ZERO
	holder.size = entry.node.size
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	entry.node.add_child(holder)
	var label := Label.new()
	label.text = str(spec.get("text", ""))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", serif_font)
	label.add_theme_font_size_override("font_size", int(spec.get("size", 30)))
	label.add_theme_color_override("font_color", INK)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.78))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.position = Vector2(0, float(spec.get("y", 0.78)) * holder.size.y)
	label.size = Vector2(holder.size.x, 60)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(label)
	entry.texts.append({"node": holder, "label": label, "kind": "center"})


func _add_interaction(entry: Dictionary) -> void:
	var inter = entry.data.get("interaction", null)
	if not (inter is Dictionary):
		return
	var itype := str(inter.get("type", ""))
	var point_uv := _vec2(inter.get("asset_uv", [0.5, 0.5]))
	match itype:
		"green_restore":
			var overlay_tex: Texture2D = entry.texture
			var atlas := _atlas_for(overlay_tex, entry.node.size, _vec2(entry.data.get("focus", [0.5, 0.5])), entry.data.get("crop", null))
			var ov := TextureRect.new()
			ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ov.stretch_mode = TextureRect.STRETCH_SCALE
			ov.texture = atlas
			ov.position = Vector2.ZERO
			ov.size = entry.node.size
			ov.mouse_filter = MOUSE_FILTER_IGNORE
			var rm := ShaderMaterial.new()
			rm.shader = RESTORE_SHADER
			rm.set_shader_parameter("center_uv", point_uv)
			rm.set_shader_parameter("radius", 0.02)
			rm.set_shader_parameter("active", 0.0)
			rm.set_shader_parameter("saturation", float(inter.get("saturation", 1.38)))
			ov.material = rm
			ov.visible = false
			# Insert above the base image but below text.
			var clip: Node = entry.node.get_child(0)
			clip.add_child(ov)
			entry.overlay = ov
			entry.overlay_material = rm
			_add_hotspot(entry, str(inter.get("id", "green")), point_uv, itype, inter)
		"structure":
			var points: Array = inter.get("points", [])
			for p in points:
				_add_hotspot(entry, str(p.get("id", "part")), _vec2(p.get("asset_uv", [0.5, 0.5])), "structure", p)
		_:
			_add_hotspot(entry, str(inter.get("id", itype)), point_uv, itype, inter)


func _add_hotspot(entry: Dictionary, id: String, asset_uv: Vector2, itype: String, spec: Dictionary) -> void:
	var p := _source_point(entry, asset_uv)
	p.x = clampf(p.x, 22.0, entry.node.size.x - 22.0)
	p.y = clampf(p.y, 22.0, entry.node.size.y - 22.0)
	var button := Hotspot.new()
	button.position = p - Vector2(20, 20)
	button.accessible_name = str(spec.get("label", spec.get("accessibility", "查看")))
	button.pressed.connect(func(): _activate_hotspot(entry, id, itype, spec, p))
	entry.node.add_child(button)
	entry.buttons.append({"button": button, "id": id, "type": itype, "spec": spec, "point": p})


func _activate_hotspot(entry: Dictionary, id: String, itype: String, spec: Dictionary, p: Vector2) -> void:
	if not _input_allowed() or entry.flat_index > frontier:
		return
	match itype:
		"green_restore":
			_do_green_restore(entry, spec)
		"screen":
			_do_observation(entry, spec, p, "控制台的蓝光短暂地亮了一格。")
		"seed":
			_do_seed(entry, spec, p)
		"wind":
			_do_wind(entry, spec, p)
		"pencil":
			_do_pencil(entry, spec, p)
		"structure":
			_do_structure(entry, spec, p)
		"alarm":
			_do_alarm(entry, spec, p)
		"fracture":
			_do_fracture(entry, spec, p)
		"signal":
			_do_signal(entry, spec, p)
		"lens":
			_do_lens(entry, spec, p)
		"compare":
			_open_compare(entry, spec)
		"record":
			_open_record(entry, spec)
		"final":
			_start_final_sequence(false)
		_:
			_do_observation(entry, spec, p, str(spec.get("feedback", "")))


func _discovery_key(id: String) -> String:
	return id


func _do_observation(entry: Dictionary, spec: Dictionary, p: Vector2, feedback: String, feedback_at := Vector2(-1, -1)) -> void:
	var id := str(spec.get("id", "observation"))
	discoveries[id] = true
	# A full-panel observation overlay would cover the independent seed/pencil
	# foreground.  Those panels already animate the real layer; skip the overlay.
	if entry.foreground == null:
		var glow := _make_observe_overlay(entry)
		if glow:
			glow.set_shader_parameter("clue_point", p)
			glow.set_shader_parameter("clue_glow", 1.0)
			var tw := create_tween()
			active_tweens.append(tw)
			tw.tween_method(func(v: float): glow.set_shader_parameter("clue_glow", v), 1.0, 0.0, 1.6)
	_mark_button(entry, id)
	_show_feedback(entry, feedback, p if feedback_at.x < 0.0 else feedback_at)
	_sfx("unlock")
	records["interaction_" + id] = true
	_save()


func _make_observe_overlay(entry: Dictionary) -> ShaderMaterial:
	if entry.overlay_material != null:
		return entry.overlay_material
	var atlas := _atlas_for(entry.texture, entry.node.size, _vec2(entry.data.get("focus", [0.5, 0.5])), entry.data.get("crop", null))
	var ov := TextureRect.new()
	ov.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ov.stretch_mode = TextureRect.STRETCH_SCALE
	ov.texture = atlas
	ov.position = Vector2.ZERO
	ov.size = entry.node.size
	ov.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = OBSERVE_SHADER
	_apply_local_patch(mat,entry.data)
	mat.set_shader_parameter("scan_point", Vector2(-1000, -1000))
	mat.set_shader_parameter("clue_point", Vector2(-1000, -1000))
	ov.material = mat
	entry.node.get_child(0).add_child(ov)
	entry.overlay = ov
	entry.overlay_material = mat
	return mat

func _apply_local_patch(material:ShaderMaterial,item:Dictionary)->void:
	var patch:Dictionary=item.get("local_patch",{})
	if patch.is_empty():return
	var bounds:Array=patch.rect_uv
	material.set_shader_parameter("local_patch_enabled",true)
	material.set_shader_parameter("local_patch",load(str(patch.path)))
	material.set_shader_parameter("patch_rect",Vector4(bounds[0],bounds[1],bounds[2],bounds[3]))
	material.set_shader_parameter("patch_feather",float(patch.get("feather",.02)))


func _do_green_restore(entry: Dictionary, spec: Dictionary) -> void:
	if entry.overlay_material == null:
		return
	var id := str(spec.get("id", "green"))
	var already := discoveries.has(id)
	discoveries[id] = true
	entry.overlay.show()
	entry.overlay.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	active_tweens.append(tw)
	tw.tween_property(entry.overlay_material, "shader_parameter/radius", 0.30, 0.85).set_trans(Tween.TRANS_SINE)
	tw.tween_property(entry.overlay_material, "shader_parameter/active", 1.0, 0.65)
	if not already:
		_show_feedback(entry, "这时我才注意到，路边有一点很浅的绿。", Vector2(entry.node.size.x * 0.62, entry.node.size.y * 0.24))
	_mark_button(entry, id)
	_sfx("unlock")
	records["interaction_" + id] = true
	_save()


func _do_seed(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	if entry.foreground != null:
		var fg: TextureRect = entry.foreground
		var base: Vector2 = fg.position
		var tw := create_tween().set_parallel(true)
		active_tweens.append(tw)
		tw.tween_property(fg, "position", base + Vector2(1.5, -2.2), 0.16).set_trans(Tween.TRANS_SINE)
		tw.tween_property(fg, "rotation", 0.018, 0.16).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_property(fg, "position", base, 0.5).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(fg, "rotation", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_do_observation(entry, spec, p, "草籽在指腹下轻轻滚了一下。")


func _do_pencil(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	if entry.foreground != null:
		var fg: TextureRect = entry.foreground
		var running:Tween=entry.get("pencil_tween",null)
		if running!=null and running.is_valid() and running.is_running():return
		var base: Vector2 = entry.get("foreground_base",fg.position)
		var rot: float = 0.0
		fg.position=base;fg.rotation=0.0
		var tw := create_tween().set_parallel(true)
		entry["pencil_tween"]=tw
		active_tweens.append(tw)
		tw.tween_property(fg, "rotation", rot + 0.08, 0.95).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(fg, "position", base + Vector2(5.0, -7.0), 0.55).set_trans(Tween.TRANS_SINE)
		tw.chain().tween_property(fg, "position", base, 0.85).set_trans(Tween.TRANS_SINE)
		tw.parallel().tween_property(fg, "rotation", rot, 0.85).set_trans(Tween.TRANS_SINE)
	_do_observation(entry, spec, p, "铅笔缓缓转动，仍然没有落下。", Vector2(entry.node.size.x * 0.5, entry.node.size.y * 0.12))


func _do_wind(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	discoveries[str(spec.get("id", "wind"))] = true
	var mat := _make_observe_overlay(entry)
	mat.set_shader_parameter("scan_point", p)
	mat.set_shader_parameter("scan_strength", 1.0)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_method(func(v: float): mat.set_shader_parameter("scan_strength", v), 1.0, 0.0, 1.5)
	var drift := create_tween()
	active_tweens.append(drift)
	drift.tween_property(entry.image, "position:x", 4.0, 0.7).set_trans(Tween.TRANS_SINE)
	drift.tween_property(entry.image, "position:x", -2.0, 0.9).set_trans(Tween.TRANS_SINE)
	drift.tween_property(entry.image, "position:x", 0.0, 0.8).set_trans(Tween.TRANS_SINE)
	_show_feedback(entry, "晚风从桥面吹过，衣领轻轻动了一下。", p)
	_sfx("wind_once")
	_save()


func _do_structure(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	var id := str(spec.get("id", "part"))
	discoveries["structure_" + id] = true
	var mat := _make_observe_overlay(entry)
	mat.set_shader_parameter("clue_point", p)
	mat.set_shader_parameter("clue_glow", 1.0)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_method(func(v: float): mat.set_shader_parameter("clue_glow", v), 1.0, 0.0, 2.2)
	_mark_button(entry, id)
	var label_text := str(spec.get("label", id))
	var detail := str(spec.get("text", ""))
	_show_feedback(entry, label_text + ("\n" + detail if not detail.is_empty() else ""), p + Vector2(0, 30), 3.6)
	_sfx("unlock")
	_save()
	if discoveries.has("structure_front") and discoveries.has("structure_cabin") and discoveries.has("structure_rear"):
		_show_feedback(entry, "前部切开物质，中部承载船员，后部推动它继续下沉。", Vector2(entry.node.size.x * 0.5, entry.node.size.y * 0.18), 4.0)


func _do_alarm(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	discoveries[str(spec.get("id", "alarm"))] = true
	var flash := ColorRect.new()
	flash.color = Color(0.72, 0.06, 0.04, 0.0)
	flash.position = Vector2.ZERO
	flash.size = entry.node.size
	flash.mouse_filter = MOUSE_FILTER_IGNORE
	entry.node.add_child(flash)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(flash, "color:a", 0.26, 0.10)
	tw.tween_property(flash, "color:a", 0.02, 0.25)
	tw.tween_property(flash, "color:a", 0.22, 0.12)
	tw.tween_property(flash, "color:a", 0.0, 0.55)
	_show_feedback(entry, "警报响了一次，随后只剩下雷达的低鸣。", p)
	_sfx("alarm")
	_mark_button(entry, str(spec.get("id", "alarm")))
	_save()


func _do_fracture(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	discoveries[str(spec.get("id", "fracture"))] = true
	input_locked = true
	var base: Vector2 = entry.node.position
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(entry.node, "position", base + Vector2(5, -2), 0.06)
	tw.tween_property(entry.node, "position", base + Vector2(-4, 2), 0.07)
	tw.tween_property(entry.node, "position", base + Vector2(2, 0), 0.08)
	tw.tween_property(entry.node, "position", base, 0.12)
	tw.tween_callback(func(): input_locked = false)
	_show_feedback(entry, "结合部发出一声低沉的断裂声。", p)
	_mark_button(entry, str(spec.get("id", "fracture")))
	_sfx("fracture")
	_save()


func _do_signal(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	discoveries[str(spec.get("id", "signal"))] = true
	var wave := Waveform.new()
	wave.position = Vector2(entry.node.size.x * 0.12, entry.node.size.y * 0.10)
	wave.size = Vector2(entry.node.size.x * 0.76, entry.node.size.y * 0.28)
	wave.amplitude = 1.0
	wave.line_color = Color(0.47, 0.82, 0.90, 0.9)
	wave.mouse_filter = MOUSE_FILTER_IGNORE
	entry.node.add_child(wave)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(wave, "amplitude", 0.0, 4.0).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _show_feedback(entry, "最后的语音和数据联系，在一个深夜里中断了。", p, 4.0))
	_sfx("signal")
	_mark_button(entry, str(spec.get("id", "signal")))
	_save()


func _do_lens(entry: Dictionary, spec: Dictionary, p: Vector2) -> void:
	discoveries[str(spec.get("id", "lens"))] = true
	var mat := _make_observe_overlay(entry)
	mat.set_shader_parameter("scan_point", p)
	mat.set_shader_parameter("scan_strength", 1.0)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_method(func(v: float): mat.set_shader_parameter("scan_strength", v), 1.0, 0.0, 2.4)
	_show_feedback(entry, "镜片里的草原短暂地亮了一下。舱室仍然封闭。", p + Vector2(0, 24), 4.0)
	_sfx("wind_once")
	_mark_button(entry, str(spec.get("id", "lens")))
	_save()


func _mark_button(entry: Dictionary, id: String) -> void:
	for b in entry.buttons:
		if str(b.get("id")) == id:
			b.button.completed = true


func _show_feedback(entry: Dictionary, text: String, at: Vector2, duration := 3.2) -> void:
	if text.is_empty():
		return
	var holder := Control.new()
	holder.position = Vector2(0, 0)
	holder.size = entry.node.size
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	entry.node.add_child(holder)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", serif_font)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.90, 0.98))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := minf(entry.node.size.x - 24.0, 360.0)
	label.size = Vector2(w, 60)
	label.position = Vector2(clampf(at.x - w / 2.0, 12.0, entry.node.size.x - w - 12.0), clampf(at.y, 8.0, entry.node.size.y - 70.0))
	label.modulate.a = 0.0
	holder.add_child(label)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(label, "modulate:a", 1.0, 0.25)
	tw.tween_interval(duration)
	tw.tween_property(label, "modulate:a", 0.0, 0.65)
	tw.tween_callback(func():
		if is_instance_valid(holder):
			holder.queue_free())


func _refresh_panels() -> void:
	var next_idx := frontier + 1
	for entry in panels:
		var fi := int(entry.flat_index)
		var unlocked := fi <= frontier
		var is_next := fi == next_idx
		if entry.reveal_tween != null and entry.reveal_tween.is_valid():
			entry.reveal_tween.kill()
		entry.material.set_shader_parameter("reveal", 1.0 if unlocked else 0.0)
		entry.material.set_shader_parameter("eligible", 1.0 if is_next and not final_running else 0.0)
		entry.material.set_shader_parameter("hovered", 0.0)
		for item in entry.texts:
			item.node.visible = unlocked
			if unlocked:
				item.node.modulate.a = 1.0
		for b in entry.buttons:
			var enabled := unlocked and not final_running
			b.button.visible = enabled
			b.button.disabled = not enabled
		entry.node.focus_mode = FOCUS_ALL if is_next and not final_running else FOCUS_NONE
		entry.node.mouse_default_cursor_shape = CURSOR_POINTING_HAND if is_next and not final_running else CURSOR_ARROW
		if entry.overlay != null:
			entry.overlay.visible = unlocked
		if entry.foreground != null:
			entry.foreground.visible = unlocked
	_update_curls()


func _update_curls() -> void:
	if not is_instance_valid(curl) or not is_instance_valid(back_curl):
		return
	var blocked := modal != null or transitioning or page_turning or final_running or complete
	if is_instance_valid(back_curl):
		back_curl.visible = visible and page_index > 0 and not blocked
		if not back_curl.visible:
			back_curl.reset()
	if is_instance_valid(curl):
		curl.visible = visible and _page_ready() and page_index < pages.size() - 1 and not blocked
		if not curl.visible:
			curl.reset()


func _page_ready() -> bool:
	if page_index < 0 or page_index >= pages.size():
		return false
	var page: Dictionary = pages[page_index]
	var items: Array = page.get("panels", [])
	if items.is_empty():
		return true
	var last_flat := int(items[items.size() - 1].get("_index", -1))
	if frontier < last_flat:
		return false
	for required in page.get("required", []):
		if not discoveries.has(str(required)):
			return false
	return true


func unlock(index: int, origin := Vector2(0.5, 0.5)) -> bool:
	if not _input_allowed():
		return false
	var entry: Dictionary = {}
	for p in panels:
		if int(p.index) == index:
			entry = p
			break
	if entry.is_empty():
		return false
	if int(entry.flat_index) != frontier + 1:
		return false
	frontier = int(entry.flat_index)
	_refresh_panels()
	entry.material.set_shader_parameter("reveal_origin", origin)
	entry.material.set_shader_parameter("reveal", 0.0)
	if entry.overlay != null and entry.overlay_material != null:
		entry.overlay.visible = false
	var tw := create_tween()
	entry.reveal_tween = tw
	active_tweens.append(tw)
	tw.tween_property(entry.material, "shader_parameter/reveal", 1.0, 0.54).set_trans(Tween.TRANS_SINE)
	for item in entry.texts:
		item.node.modulate.a = 0.0
	var tt := create_tween().set_parallel(true)
	active_tweens.append(tt)
	tt.tween_property(entry.node, "modulate:a", 1.0, 0.0)
	for item in entry.texts:
		tt.tween_property(item.node, "modulate:a", 1.0, 0.30).set_delay(0.12)
	if entry.overlay != null and str(entry.data.get("interaction", {}).get("type", "")) == "green_restore":
		entry.overlay.show()
		entry.overlay_material.set_shader_parameter("active", 0.0)
		entry.overlay_material.set_shader_parameter("radius", 0.02)
	_sfx("unlock")
	_save()
	get_viewport().gui_release_focus()
	if frontier >= flat.size() - 1 and page_index == pages.size() - 1:
		call_deferred("_start_final_sequence", false)
	return true


func advance() -> void:
	if not _input_allowed():
		return
	var next := _next_local_index()
	if next >= 0:
		unlock(next)
	elif _page_ready():
		if page_index < pages.size() - 1:
			turn_page(1)
		elif not final_running and not complete:
			_start_final_sequence(false)


func _next_local_index() -> int:
	for p in panels:
		if int(p.flat_index) == frontier + 1:
			return int(p.index)
	return -1


func previous() -> void:
	if _input_allowed() and page_index > 0:
		turn_page(-1)


func _page_by_id(id:String)->int:
	for p in range(pages.size()):
		if str(pages[p].get("id",""))==id:return p
	return -1

func _previous_page_index()->int:
	var current_id:=str(pages[page_index].get("id",""))
	for p in range(page_index):
		if str(pages[p].get("exit_video",{}).get("resume_page",""))==current_id:return p
	return page_index-1

func turn_page(direction: int) -> void:
	if not _input_allowed():
		return
	if direction > 0 and (not _page_ready() or page_index >= pages.size() - 1):
		return
	if direction < 0 and page_index <= 0:
		return
	var exit_movie:Dictionary=pages[page_index].get("exit_video",{})
	if direction>0 and not exit_movie.is_empty() and ResourceLoader.exists(str(exit_movie.get("stream",""))):
		_play_page_video(exit_movie)
		return
	page_turning = true
	curl.hide()
	back_curl.hide()
	get_viewport().gui_release_focus()
	var token := serial
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if token != serial:
		return
	var img := get_viewport().get_texture().get_image()
	var layer: TextureRect
	if img != null and not img.is_empty():
		var snapshot := ImageTexture.create_from_image(img)
		layer = TextureRect.new()
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.texture = snapshot
		layer.size = size
		layer.mouse_filter = MOUSE_FILTER_STOP
		layer.z_index = 20
		var mat := ShaderMaterial.new()
		mat.shader = TURN_SHADER
		mat.set_shader_parameter("direction", float(direction))
		mat.set_shader_parameter("progress", 0.0)
		layer.material = mat
		add_child(layer)
	else:
		layer = TextureRect.new()
		layer.size = size
		layer.mouse_filter = MOUSE_FILTER_STOP
		layer.z_index = 20
		layer.modulate = Color(1, 1, 1, 0)
		add_child(layer)
	page_index = _previous_page_index() if direction<0 else page_index+1
	_build_page()
	curl.hide()
	back_curl.hide()
	var tw := create_tween()
	active_tweens.append(tw)
	if layer.material is ShaderMaterial:
		tw.tween_method(func(v: float): layer.material.set_shader_parameter("progress", v), 0.0, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		tw.tween_property(layer, "modulate:a", 0.0, 0.35)
	await tw.finished
	if is_instance_valid(layer):
		layer.hide()
		layer.mouse_filter=MOUSE_FILTER_IGNORE
		layer.queue_free()
	if token != serial:
		return
	page_turning = false
	_update_curls()
	_save()


func _play_page_video(spec:Dictionary)->void:
	page_turning=true;transitioning=true;curl.hide();back_curl.hide();get_viewport().gui_release_focus()
	var token:=serial
	if music_tween!=null and music_tween.is_valid():music_tween.kill()
	music_tween=create_tween();audio_tweens.append(music_tween)
	music_tween.tween_property(music,"volume_db",-60.0 if muted else music_gain_db,1.5)
	var clip:Control=ArchiveSequence.new() if spec.has("archive") else MemoryVideo.new()
	clip.name="AfterCollapseVideo";clip.z_index=40;add_child(clip);page_video=clip
	if spec.has("archive"):
		clip.archive_opening.connect(_page_video_audio.bind(music_gain_db,true))
		clip.launch_started.connect(_page_video_audio.bind(music_gain_db,false))
	clip.begin(spec)
	await clip.playback_finished
	if token!=serial or not is_inside_tree() or page_video!=clip:return
	# Rebuild under the held last frame, so the collapsed panel never flashes back.
	var resume:=_page_by_id(str(spec.get("resume_page","")))
	if resume>page_index:
		page_index=resume
		var items:Array=pages[page_index].get("panels",[])
		if not items.is_empty():frontier=maxi(frontier,int(items[0].get("_index",0))-1)
		if clip.get("archive_results") is Dictionary:records["sunset6_descent"]=clip.archive_results.duplicate(true)
	else:page_index+=1
	# The incident recollection and the following pages share this music and
	# its playhead; a page rebuild must not substitute another loop at the seam.
	if page_index<pages.size():pages[page_index]["music"]=current_music
	_build_page();curl.hide();back_curl.hide()
	if current_music==str(pages[page_index].get("music","")) and music.playing:
		if music_tween!=null and music_tween.is_valid():music_tween.kill()
		music_tween=create_tween();audio_tweens.append(music_tween);music_tween.tween_property(music,"volume_db",-60.0 if muted else music_gain_db,2.5)
	await clip.reveal_next_page()
	if token!=serial or page_video!=clip:return
	page_video=null;clip.queue_free();page_turning=false;transitioning=false;_update_curls();_save()

func _page_video_audio(level:float,quiet_room:bool)->void:
	if music_tween!=null and music_tween.is_valid():music_tween.kill()
	music_tween=create_tween();audio_tweens.append(music_tween);music_tween.tween_property(music,"volume_db",-60.0 if muted else level,2.5)
	if quiet_room:
		for player in [ambience_a,ambience_b]:
			var fade:=create_tween();audio_tweens.append(fade);fade.tween_property(player,"volume_db",-60.0,.8)
		# Force the following history page to resolve its ambience again.
		current_ambience="";current_ambience_file=""

func _close_page_video()->void:
	if not is_instance_valid(page_video):page_video=null;return
	var clip:=page_video;page_video=null;clip.close();clip.queue_free()


func _input_allowed() -> bool:
	return visible and modal == null and not transitioning and not page_turning and not final_running and not input_locked


func _process(delta: float) -> void:
	if not visible:
		return
	clock += delta
	particles_clock += delta
	var next := _next_local_index()
	for entry in panels:
		var hovered := false
		if int(entry.index) == next:
			hovered = entry.node.get_global_rect().has_point(get_global_mouse_position()) or entry.node.has_focus()
		entry.material.set_shader_parameter("hovered", 1.0 if hovered else 0.0)
	# Pagination curls only appear when the page and any required beats are done.
	_update_curls()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if is_instance_valid(page_video) and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		page_video.toggle_pause();get_viewport().set_input_as_handled();return
	if is_instance_valid(page_video) and page_video.has_method("handle_input"):
		page_video.handle_input(event)
		# Its full-screen Control blocks the reader; let GUI buttons receive clicks.
		return
	if transitioning or page_turning:
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_M:
			_toggle_sound()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_F or key == KEY_F11:
			fullscreen_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if key == KEY_ESCAPE:
			if modal != null:
				_close_modal()
			elif final_running:
				pass
			else:
				_open_pause()
			get_viewport().set_input_as_handled()
			return
		if final_running:
			get_viewport().set_input_as_handled()
			return
		if modal != null:
			# Let focused buttons/sliders receive activation and arrow keys.
			if key == KEY_TAB:
				_cycle_focus(event.shift_pressed)
				get_viewport().set_input_as_handled()
			return
		if key == KEY_TAB:
			_cycle_focus(event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
		var focus: Control = get_viewport().gui_get_focus_owner()
		if focus == back_curl and key in [KEY_SPACE, KEY_ENTER]:
			previous()
			get_viewport().set_input_as_handled()
			return
		if focus == curl and key in [KEY_SPACE, KEY_ENTER]:
			turn_page(1)
			get_viewport().set_input_as_handled()
			return
		if focus is Button and key in [KEY_SPACE, KEY_ENTER]:
			return
		if key in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			advance()
			get_viewport().set_input_as_handled()
		elif key == KEY_LEFT:
			previous()
			get_viewport().set_input_as_handled()


func _cycle_focus(backwards: bool) -> void:
	var candidates := _focus_candidates()
	if candidates.is_empty():
		get_viewport().gui_release_focus()
		return
	var current := candidates.find(get_viewport().gui_get_focus_owner())
	var idx := 0
	if current >= 0:
		idx = posmod(current + (-1 if backwards else 1), candidates.size())
	else:
		idx = candidates.size() - 1 if backwards else 0
	candidates[idx].grab_focus()


func _focus_candidates() -> Array[Control]:
	var list: Array[Control] = []
	if modal != null:
		for child in modal.find_children("*", "Button", true, false):
			if child is Button and child.visible and not child.disabled:
				list.append(child)
		for child in modal.find_children("*", "HSlider", true, false):
			if child is HSlider and child.visible:
				list.append(child)
		return list
	var n := _next_local_index()
	if n >= 0:
		for p in panels:
			if int(p.index) == n:
				list.append(p.node)
	for entry in panels:
		for b in entry.buttons:
			if b.button.visible and not b.button.disabled:
				list.append(b.button)
	if is_instance_valid(curl) and curl.visible:
		list.append(curl)
	if is_instance_valid(back_curl) and back_curl.visible:
		list.append(back_curl)
	return list


func _open_pause() -> void:
	if modal != null:
		return
	_modal_shell("pause")
	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.045, 0.065, 0.965)
	bg.position = Vector2.ZERO
	bg.size = size
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(bg)
	_label(modal, "暂停阅读", Rect2(440, 128, 400, 58), 30, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button(modal, "继续阅读", Rect2(460, 226, 360, 52), _close_modal)
	_button(modal, "整体音量", Rect2(460, 294, 360, 52), AudioSettings.open_panel)
	_button(modal, "从头阅读", Rect2(460, 362, 360, 52), func():
		_close_modal(false)
		begin({"fresh": true, "audio_enabled": not muted}))
	_button(modal, "返回封面", Rect2(460, 430, 360, 52), func():
		_close_modal(false)
		return_to_title_requested.emit())
	_label(modal, "阅读进度会保留；从头阅读会重置本模块存档。", Rect2(414, 512, 460, 46), 15, Color(0.83, 0.85, 0.82, 0.78), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	get_viewport().gui_release_focus()


func _modal_shell(kind: String) -> void:
	_close_modal(false)
	modal = Control.new()
	modal.position = Vector2.ZERO
	modal.size = size
	modal.mouse_filter = MOUSE_FILTER_STOP
	modal.z_index = 30
	modal_kind = kind
	add_child(modal)
	modal.gui_input.connect(_modal_pointer)
	_update_curls()


func _label(parent: Node, text: String, r: Rect2, fs: int, color := INK, serif := true) -> Label:
	var label := Label.new()
	label.text = text
	label.position = r.position
	label.size = r.size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", serif_font if serif else ui_font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, r: Rect2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = r.position
	button.size = r.size
	button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", Color(1, 0.98, 0.90))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxEmpty.new()
		button.add_theme_stylebox_override(state, style)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.10, 0.13, 0.15, 0.25)
	focus_style.border_color = Color(1, 1, 1, 0.7)
	focus_style.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", focus_style)
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _modal_pointer(event: InputEvent) -> void:
	if modal == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_close_modal()
		get_viewport().set_input_as_handled()


func _close_modal(refocus := true) -> void:
	if is_instance_valid(record_wave):
		record_wave.visible = false
	record_playing = false
	if is_instance_valid(record_player):
		record_player.stop()
	if is_instance_valid(modal):
		modal.queue_free()
	modal = null
	modal_kind = ""
	record_wave = null
	record_lines_label = null
	record_button = null
	record_has_audio = false
	if refocus:
		get_viewport().gui_release_focus()
	_update_curls()


func _open_compare(entry: Dictionary, spec: Dictionary) -> void:
	_modal_shell("compare")
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.030, 0.040, 0.94)
	bg.size = size
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(bg)
	var tex := _load_panel_texture(entry.data)
	var photo := TextureRect.new()
	photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photo.texture = tex
	photo.position = Rect2(90, 56, 1100, 470).position
	photo.size = Rect2(90, 56, 1100, 470).size
	photo.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(photo)
	var left := _label(modal, "地幔\n6.3 g/cm³", Rect2(90, 530, 310, 72), 21, INK, true)
	left.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var right := _label(modal, "液态铁镍\n9.5 g/cm³", Rect2(880, 530, 310, 72), 21, INK, true)
	right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = 0.53
	slider.position = Vector2(200, 614)
	slider.size = Vector2(880, 34)
	slider.add_theme_font_override("font", ui_font)
	slider.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	modal.add_child(slider)
	var marker := ColorRect.new()
	marker.color = Color(0.92, 0.97, 1.0, 0.55)
	marker.position = Vector2(200, 56)
	marker.size = Vector2(1, 470)
	marker.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(marker)
	slider.value_changed.connect(func(v: float):
		marker.position.x = lerpf(200.0, 1072.0, v))
	_label(modal, "拖动，比较同一深度的岩层与液态金属。", Rect2(90, 666, 900, 34), 16, Color(0.88, 0.9, 0.87, 0.8), true)
	var close := _button(modal, "收回视线", Rect2(1080, 650, 120, 40), _close_modal)
	close.add_theme_font_size_override("font_size", 16)
	discoveries["density_compressed"] = true
	_save()
	slider.grab_focus()


func _open_record(entry: Dictionary, spec: Dictionary) -> void:
	_modal_shell("record")
	var bg := ColorRect.new()
	bg.color = Color(0.018, 0.028, 0.038, 0.96)
	bg.size = size
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(bg)
	var title := _label(modal, "保存的录音 · 档案字幕", Rect2(100, 92, 1080, 42), 26, INK, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(modal, "录音在三个月前中断；这里只有保存下来的文字与波形。", Rect2(100, 140, 1080, 34), 16, Color(0.80, 0.84, 0.82, 0.78), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var wave := Waveform.new()
	wave.position = Vector2(180, 226)
	wave.size = Vector2(920, 190)
	wave.amplitude = 0.34
	wave.line_color = Color(0.53, 0.78, 0.86, 0.86)
	wave.mouse_filter = MOUSE_FILTER_IGNORE
	modal.add_child(wave)
	record_wave = wave
	var transcript := str(spec.get("transcript", ""))
	record_lines_label = _label(modal, transcript, Rect2(170, 430, 940, 114), 22, INK, true)
	record_lines_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	record_lines_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	record_button = _button(modal, "播放字幕", Rect2(460, 566, 170, 48), func():
		_record_toggle())
	_button(modal, "重听", Rect2(650, 566, 120, 48), func():
		_record_restart())
	_button(modal, "收回", Rect2(790, 566, 130, 48), _close_modal)
	_label(modal, "无配音阶段以字幕和波形呈现，不伪造实时通话。", Rect2(100, 646, 1080, 28), 14, Color(0.78, 0.81, 0.80, 0.66), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var audio_path := str(spec.get("audio", ""))
	if not muted and not audio_path.is_empty() and ResourceLoader.exists(audio_path):
		record_player.stream = Mix.stream(audio_path)
		record_player.play()
		record_has_audio = true
		record_playing = true
		record_wave.playing = true
		if record_button:
			record_button.text = "暂停"
	discoveries[str(spec.get("id", "record_opened"))] = true
	_save()
	record_button.grab_focus()


func _record_toggle() -> void:
	if not is_instance_valid(record_wave):
		return
	if record_has_audio and record_player.stream != null:
		if record_player.playing:
			record_player.pause()
			record_playing = false
		else:
			record_player.play()
			record_playing = true
	else:
		record_playing = not record_playing
	record_wave.playing = record_playing
	if record_button:
		record_button.text = "暂停" if record_playing else "继续"
	if record_playing:
		record_wave.amplitude = 0.55
		var tw := create_tween()
		active_tweens.append(tw)
		tw.tween_property(record_wave, "amplitude", 0.75, 0.5)
		tw.tween_property(record_wave, "amplitude", 0.42, 1.1)
		tw.tween_property(record_wave, "amplitude", 0.62, 0.8)
		tw.tween_property(record_wave, "amplitude", 0.34, 1.0)
	else:
		record_wave.amplitude = 0.28


func _record_restart() -> void:
	if is_instance_valid(record_wave):
		record_wave.reset_wave()
		record_wave.playing = false
	record_playing = false
	if record_has_audio and record_player.stream != null:
		record_player.stop()
		record_player.seek(0.0)
	if record_button:
		record_button.text = "播放字幕"


func _start_final_sequence(restored: bool) -> void:
	if final_running or complete:
		return
	if page_index != pages.size() - 1:
		return
	if frontier < flat.size() - 1:
		return
	final_running = true
	input_locked = true
	curl.hide()
	back_curl.hide()
	if is_instance_valid(final_layer):
		final_layer.queue_free()
	final_layer = Control.new()
	final_layer.size = size
	final_layer.mouse_filter = MOUSE_FILTER_IGNORE
	final_layer.z_index = 18
	add_child(final_layer)
	_ambient("farewell")
	var final_scrim := TextureRect.new()
	final_scrim.texture = SCRIM_TEXTURE
	final_scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	final_scrim.stretch_mode = TextureRect.STRETCH_SCALE
	final_scrim.position = Vector2(0, 406)
	final_scrim.size = Vector2(1280, 314)
	final_scrim.mouse_filter = MOUSE_FILTER_IGNORE
	final_layer.add_child(final_scrim)
	var line1 := _final_text("我现在已适应这里，不再觉得狭窄和封闭了。", 0.74, 24)
	var line2 := _final_text("整个世界都围着我呀，我闭上眼睛就能看见上面的大草原，还可以清楚地看见每一朵我起了名字的小花呢。", 0.84, 23)
	var goodbye := _final_text("再见。", 0.50, 32)
	for n in [line1, line2, goodbye]:
		n.modulate.a = 0.0
	var voice_ok := not muted and ResourceLoader.exists(VOICE_PATH)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_interval(0.8 if not restored else 0.15)
	tw.tween_property(line1, "modulate:a", 1.0, 0.8)
	if voice_ok:
		voice_player.stream = Mix.stream(VOICE_PATH)
		voice_player.volume_db = 0.0
		voice_player.play()
		tw.tween_interval(3.4)
		tw.tween_property(line2, "modulate:a", 1.0, 0.9)
		tw.tween_interval(8.6)
		tw.tween_property(line1, "modulate:a", 0.55, 1.0)
		tw.tween_property(line2, "modulate:a", 0.45, 1.0)
		tw.tween_property(goodbye, "modulate:a", 1.0, 1.2)
	else:
		tw.tween_interval(2.9)
		tw.tween_property(line2, "modulate:a", 1.0, 0.9)
		tw.tween_interval(4.0)
		tw.tween_property(line1, "modulate:a", 0.55, 1.0)
		tw.tween_property(line2, "modulate:a", 0.45, 1.0)
		tw.tween_property(goodbye, "modulate:a", 1.0, 1.2)
		tw.tween_interval(2.6)
		tw.tween_callback(_fade_final_to_black)
		_sfx("final")


func _on_final_voice_finished() -> void:
	if not final_running or complete:
		return
	await get_tree().create_timer(2.6).timeout
	if final_running and not complete and is_instance_valid(final_layer):
		_fade_final_to_black()


func _final_text(text: String, y: float, fs: int) -> Label:
	var holder := Control.new()
	holder.position = Vector2.ZERO
	holder.size = size
	holder.mouse_filter = MOUSE_FILTER_IGNORE
	final_layer.add_child(holder)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", serif_font)
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", Color(1, 0.985, 0.93, 0.98))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.88))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.38))
	label.add_theme_constant_override("outline_size", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(150, y * 720.0)
	label.size = Vector2(980, 110)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	holder.add_child(label)
	return label


func _fade_final_to_black() -> void:
	if not is_instance_valid(final_layer):
		return
	_fade_music_out()
	for player in [ambience_a,ambience_b]:
		var fall:=create_tween();audio_tweens.append(fall);fall.tween_property(player,"volume_db",-60.0,2.0)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.size = size
	black.mouse_filter = MOUSE_FILTER_STOP
	black.z_index = 40
	final_layer.add_child(black)
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(black, "color:a", 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	await tw.finished
	if not is_instance_valid(final_layer):
		return
	_stop_all_audio()
	complete = true
	_save()
	if not final_emitted:
		final_emitted = true
		ending_completed.emit({
			"complete": true,
			"skipped": false,
			"last_source_id": "41",
			"discoveries": discoveries.duplicate(),
		})
	await get_tree().create_timer(1.2).timeout
	if transparent_earth_requested.get_connections().size()>0:transparent_earth_requested.emit()
	else:_show_end_card(black)


func _show_complete_card(from_save := true) -> void:
	if not complete:
		return
	_stop_all_audio()
	final_running = true
	input_locked = true
	curl.hide()
	back_curl.hide()
	if is_instance_valid(final_layer):
		final_layer.queue_free()
	final_layer = Control.new()
	final_layer.size = size
	final_layer.mouse_filter = MOUSE_FILTER_IGNORE
	final_layer.z_index = 40
	add_child(final_layer)
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.size = size
	black.mouse_filter = MOUSE_FILTER_STOP
	final_layer.add_child(black)
	_show_end_card(black)


func _show_end_card(black: ColorRect) -> void:
	var card := Control.new()
	card.size = size
	card.mouse_filter = MOUSE_FILTER_IGNORE
	black.add_child(card)
	var title := _label(card, "谢谢体验", Rect2(0, 248, 1280, 56), 28, Color(0.91, 0.92, 0.88, 0.92), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label(card, "她还在那个星球的最深处。", Rect2(0, 312, 1280, 32), 16, Color(0.76, 0.80, 0.78, 0.72), true)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _button(card, "返回封面", Rect2(540, 382, 200, 48), func():
		return_to_title_requested.emit())
	b.add_theme_font_size_override("font_size", 17)
	card.modulate.a = 0.0
	var tw := create_tween()
	active_tweens.append(tw)
	tw.tween_property(card, "modulate:a", 1.0, 1.1)


func _final_cleanup() -> void:
	final_running = false
	if is_instance_valid(final_layer):
		final_layer.queue_free()
	final_layer = null


func _ambient(name: String) -> void:
	for tween in ambience_tweens:
		if tween.is_valid():tween.kill()
	ambience_tweens.clear()
	# The constant cabin/wind drone obscured the score. Incident effects and
	# recordings keep their separate, event-driven players.
	ambience_a.stop();ambience_b.stop();ambience_a.stream=null;ambience_b.stream=null
	current_ambience=name;current_ambience_file="";current_ambience_volume=-80


func _set_music(cue: String) -> void:
	if cue.is_empty():
		_fade_music_out()
		return
	var wav_path := "res://assets/ending/audio/%s.wav" % cue
	var mp3_path := "res://assets/ending/audio/%s.mp3" % cue
	var replacements:={"bgm_memory":"A01_ending_memory_loop.wav","bgm_depth":"A01_ending_depth_loop.wav","bgm_farewell":"A01_ending_farewell_loop.wav"}
	if replacements.has(cue):
		var delivered:String="res://assets/audio-polish-v1/"+replacements[cue]
		if ResourceLoader.exists(delivered):wav_path=delivered
	if not ResourceLoader.exists(wav_path) and not ResourceLoader.exists(mp3_path):
		# The layer is intentionally silent if a generated track is absent.
		_fade_music_out()
		return
	if cue == current_music and music.playing:
		return
	if music_tween!=null and music_tween.is_valid():music_tween.kill()
	# Preserve the previous playhead while the new cue enters softly.
	if music_old==null:
		music_old=AudioStreamPlayer.new();music_old.bus="Music";add_child(music_old)
	if music_old_tween!=null and music_old_tween.is_valid():music_old_tween.kill()
	if music.playing and (not music_old.playing or music.volume_db>=music_old.volume_db):
		music_old.stream=music.stream;music_old.volume_db=music.volume_db;music_old.play(music.get_playback_position())
	if music_old.playing:
		music_old_tween=create_tween();audio_tweens.append(music_old_tween)
		music_old_tween.tween_method(func(value:float):music_old.volume_db=linear_to_db(maxf(value,.0001)),db_to_linear(music_old.volume_db),0.0,4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		music_old_tween.tween_callback(music_old.stop)
	current_music = cue
	music_gain_db=(-7.0 if cue=="bgm_farewell" else -8.0) if wav_path.contains("audio-polish-v1") else -5.0
	var stream:AudioStreamWAV=Mix.stream(wav_path if ResourceLoader.exists(wav_path) else mp3_path)
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=roundi(stream.get_length()*stream.mix_rate)
	music.stream = stream
	music.volume_db = -60.0
	music.play()
	var tw := create_tween()
	music_tween=tw
	audio_tweens.append(tw)
	tw.tween_method(func(value:float):music.volume_db=linear_to_db(maxf(value,.0001)),0.0,0.0 if muted else db_to_linear(music_gain_db),5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _fade_music_out() -> void:
	if is_instance_valid(music) and music.playing:
		if music_tween!=null and music_tween.is_valid():music_tween.kill()
		var tw := create_tween()
		music_tween=tw
		audio_tweens.append(tw)
		tw.tween_property(music, "volume_db", -60.0, 1.8)
		tw.tween_callback(music.stop)
	if is_instance_valid(music_old) and music_old.playing:
		if music_old_tween!=null and music_old_tween.is_valid():music_old_tween.kill()
		music_old_tween=create_tween();audio_tweens.append(music_old_tween)
		music_old_tween.tween_property(music_old,"volume_db",-60.0,1.8);music_old_tween.tween_callback(music_old.stop)
	current_music = ""


func _stop_all_audio() -> void:
	_cancel_audio_tweens()
	ambience_a.stop()
	ambience_b.stop()
	music.stop()
	if is_instance_valid(music_old):music_old.stop();music_old.volume_db=-60.0
	record_player.stop()
	voice_player.stop()
	ambience_a.volume_db = -60.0
	ambience_b.volume_db = -60.0
	music.volume_db = -60.0
	record_player.volume_db = -60.0
	voice_player.volume_db = -60.0
	for effect in effects:
		effect.stop()
		effect.volume_db = -60.0
	current_ambience = ""
	current_music = ""


func _cancel_audio_tweens() -> void:
	for t in audio_tweens:
		if t.is_valid():
			t.kill()
	audio_tweens.clear()
	ambience_tweens.clear();music_tween=null;music_old_tween=null


func _set_sound_levels() -> void:
	_cancel_audio_tweens()
	var target := -60.0
	if not muted:
		target = current_ambience_volume
	ambience_a.volume_db = target
	ambience_b.volume_db = -60.0
	music.volume_db = -60.0 if muted else music_gain_db
	if is_instance_valid(music_old):music_old.stop();music_old.volume_db=-60.0
	for effect in effects:
		effect.volume_db = -60.0 if muted else -8.0
	record_player.volume_db = -60.0 if muted else 0.0
	voice_player.volume_db = -60.0 if muted else 0.0


func _toggle_sound() -> void:
	AudioSettings.toggle_mute()


func _sfx(name: String) -> void:
	if muted:
		return
	var file := "page-minimax.wav"
	var volume := -8.0
	var max_seconds := 0.0
	match name:
		"wind_once":
			file = "wind-minimax.wav"
			volume = -11.0
		"alarm":
			file = "sfx_alarm.wav"
			volume = -3.0
			max_seconds = 3.0
		"signal":
			file = "sfx_signal.wav"
			volume = -5.0
			max_seconds = 3.2
		"fracture":
			file = "sfx_fracture.wav"
			volume = -3.0
			max_seconds = 2.6
		"final":
			file = "transition-minimax.wav"
			volume = -3.0
		_:
			file = "page-minimax.wav"
			volume = -8.0
	var stream: AudioStream = null
	var wav_path := ART + "audio/" + file
	var mp3_path := wav_path.get_basename() + ".mp3"
	if ResourceLoader.exists(wav_path):
		stream = Mix.stream(wav_path)
	elif ResourceLoader.exists(mp3_path):
		stream = Mix.stream(mp3_path)
	if stream == null:
		return
	for effect in effects:
		if not effect.playing:
			effect.stream = stream
			effect.volume_db = volume
			effect.play()
			if max_seconds > 0.0:
				var token := Time.get_ticks_msec()
				effect.set_meta("sfx_token", token)
				get_tree().create_timer(max_seconds).timeout.connect(func():
					if is_instance_valid(effect) and effect.playing and int(effect.get_meta("sfx_token", -1)) == token:
						effect.stop())
			return


func _cancel_tweens() -> void:
	for t in active_tweens:
		if t.is_valid():
			t.kill()
	active_tweens.clear()


func _sfx_stop_all() -> void:
	for effect in effects:
		effect.stop()
