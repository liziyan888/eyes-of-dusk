extends Control
## Screen-space dialogue: distant voice, narration, and character speech are separate.
const STAGE := Vector2(1280, 720)
const TYPE_SPEED := preload("res://scripts/reading_pace.gd").CHARACTERS_PER_SECOND
const Appearance=preload("res://scripts/dialogue_appearance.gd")
var current_tone := ""
var full_text := ""
var reveal := 0.0
var active_label: Label
var female: Control
var narrator: PanelContainer
var bubble: PanelContainer
var female_text: Label
var narrator_text: Label
var bubble_text: Label
var female_more: Label
var narrator_more: Label
var bubble_more: Label
var female_name: Label
var bubble_name: Label
var tip := Vector2.ZERO
var bubble_rect := Rect2()
var font: Font

func setup(dialogue_font: Font) -> void:
	font = dialogue_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = STAGE
	female = PanelContainer.new()
	female.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass := StyleBoxFlat.new()
	glass.bg_color = Color.TRANSPARENT
	glass.border_color = Color(0.68,0.94,0.91,0.62)
	glass.set_border_width_all(0)
	glass.set_corner_radius_all(14)
	glass.shadow_color = Color(0.01,0.04,0.05,0.18)
	glass.shadow_size = 0
	glass.content_margin_left = 22
	glass.content_margin_right = 22
	glass.content_margin_top = 13
	glass.content_margin_bottom = 12
	female.add_theme_stylebox_override("panel",glass)
	female.position=Vector2(190,76)
	add_child(female)
	var glass_column := VBoxContainer.new()
	glass_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	glass_column.add_theme_constant_override("separation",8)
	female.add_child(glass_column)
	female_name=label("女孩",12,Color("b9f4e6"),false)
	female_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	glass_column.add_child(female_name)
	var glass_rule:=HSeparator.new()
	glass_rule.modulate=Color(0.67,0.95,0.92,0.4)
	glass_column.add_child(glass_rule);glass_rule.hide()
	female_text=label("",24,Color("fff9ed"),false)
	preload("res://scripts/subtitle_style.gd").regular_font(female_text,24)
	female_text.name="FemaleDialogue";female_text.set_meta("text_frame",weakref(female));female_text.set_meta("text_frame_padding",Vector2(44,65))
	female_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	female_text.custom_minimum_size.x=470
	female_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	glass_column.add_child(female_text);Appearance.attach(female_text,"her")
	female_more=label("点击继续  ···",11,Color("abdcd2"),false)
	female_more.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	glass_column.add_child(female_more)
	female.size=Vector2(404,120)
	narrator = PanelContainer.new()
	narrator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrator.position = Vector2(190,98)
	narrator.size = Vector2(900,100)
	var narration_style = StyleBoxEmpty.new()
	narration_style.content_margin_left=34
	narration_style.content_margin_right=34
	narration_style.content_margin_top=0
	narrator.add_theme_stylebox_override("panel",narration_style)
	add_child(narrator)
	var narration_column = VBoxContainer.new()
	narration_column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	narration_column.add_theme_constant_override("separation",7)
	narrator.add_child(narration_column)
	var narration_name=label("旁白",12,Color("d7e3cd"))
	narration_name.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	narration_column.add_child(narration_name)
	narrator_text=label("",21,Color("f1f2e3"))
	narrator_text.name="Narration";narrator_text.set_meta("text_frame",weakref(narrator));narrator_text.set_meta("text_frame_padding",Vector2(68,54))
	narrator_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	narrator_text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	narrator_text.custom_minimum_size.x=832
	narration_column.add_child(narrator_text)
	narrator_more=label("点击继续  ···",11,Color("d0ddc8"))
	narrator_more.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	narration_column.add_child(narrator_more)
	bubble = PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.TRANSPARENT
	paper.border_color = Color("8c9384")
	paper.set_border_width_all(0)
	paper.set_corner_radius_all(16)
	paper.shadow_color = Color(0.02, 0.04, 0.02, 0.2)
	paper.shadow_size = 0
	paper.shadow_offset = Vector2(0, 3)
	paper.content_margin_left = 24
	paper.content_margin_right = 24
	paper.content_margin_top = 15
	paper.content_margin_bottom = 12
	bubble.add_theme_stylebox_override("panel", paper)
	add_child(bubble)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 7)
	bubble.add_child(column)
	bubble_name = label("我", 12, Color("ffb861"), false)
	column.add_child(bubble_name)
	bubble_text = label("", 24, Color("fff9ed"), false)
	preload("res://scripts/subtitle_style.gd").regular_font(bubble_text,24)
	bubble_text.name="MaleDialogue";bubble_text.set_meta("text_frame",weakref(bubble));bubble_text.set_meta("text_frame_padding",Vector2(48,65))
	bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_text.custom_minimum_size.x = 320
	column.add_child(bubble_text);Appearance.attach(bubble_text,"man")
	bubble_more = label("···   点击继续", 12, Color("dacdb2"), false)
	bubble_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(bubble_more)
	female.hide()
	narrator.hide()
	bubble.hide()
	hide()

func label(text: String, font_size: int, color: Color, shadow := true) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	if shadow:
		result.add_theme_color_override("font_shadow_color", Color(0.01, 0.03, 0.015, 0.85))
		result.add_theme_constant_override("shadow_offset_y", 1)
		result.add_theme_constant_override("shadow_outline_size", 0)
	return result

func show_line(line: Dictionary) -> void:
	current_tone = str(line.get("tone", "sys"))
	full_text = str(line.text)
	reveal = 0
	female.visible = current_tone == "her"
	narrator.visible = current_tone == "sys"
	bubble.visible = current_tone not in ["her", "sys"]
	if female.visible:
		active_label = female_text
		female_name.text = str(line.who)
		female.size=Vector2(514,0)
	elif narrator.visible:
		active_label = narrator_text
	else:
		active_label = bubble_text
		bubble_name.text = str(line.who)
		var width := 810.0
		bubble_text.custom_minimum_size.x = width
		bubble.size = Vector2(width + 48, 0)
	active_label.text = full_text
	var studio=get_node_or_null("/root/TextStudio")
	if studio!=null:studio.sync_node(active_label);full_text=active_label.text
	active_label.visible_characters = 0
	show()
	queue_redraw()

func update_text(delta: float) -> void:
	if not visible or active_label == null:
		return
	reveal = minf(reveal + delta * TYPE_SPEED, full_text.length())
	active_label.visible_characters = int(reveal)
	var ready := reveal >= full_text.length()
	female_more.visible = ready
	narrator_more.visible = ready
	bubble_more.visible = ready

func finish_typing() -> bool:
	if reveal < full_text.length():
		reveal = full_text.length()
		active_label.visible_characters = -1
		update_text(0)
		return true
	return false

func follow_head(_head:Vector2)->void:
	# Stable reading positions; TextStudio applies any authored frame position afterward.
	if not visible:return
	if female.visible:female.position=Vector2(710,76)
	if bubble.visible:bubble.position=Vector2(48, minf(552, 690-bubble.size.y))
