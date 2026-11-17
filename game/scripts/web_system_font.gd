class_name WebSystemFont
extends FontVariation
## Embedded counterparts of the desktop fonts, with the same authoring fields.
const SONG = "res://assets/web-fonts/SimSun.ttf"
const KAI = "res://assets/web-fonts/KaiTi.ttf"
const SANS = "res://assets/web-fonts/MicrosoftYaHei.ttf"
const SANS_BOLD = "res://assets/web-fonts/MicrosoftYaHei-Bold.ttf"
const ADOBE_SONG = "res://assets/web-fonts/AdobeSongStd-Light.otf"
const CJK_FALLBACK = "res://assets/web-fonts/NotoSansCJKsc-Regular.otf"
static var embedded_files: Dictionary = {}
static func _embedded(path: String) -> FontFile:
	if not embedded_files.has(path):embedded_files[path]=load(path) as FontFile
	return embedded_files[path]
var font_names: PackedStringArray = PackedStringArray(["Microsoft YaHei"]):
	set(value):
		font_names = value
		_refresh_face()
var font_weight: int = 400:
	set(value):
		font_weight = value
		_refresh_face()
var font_italic: bool = false:
	set(value):
		font_italic = value
		_refresh_face()
func _init() -> void:
	_refresh_face()
func _refresh_face() -> void:
	var family := str(font_names[0]).to_lower() if not font_names.is_empty() else "microsoft yahei"
	var face: FontFile = _embedded(SANS_BOLD if font_weight >= 600 else SANS)
	var already_bold := font_weight >= 600
	if family.contains("adobe") and (family.contains("song") or family.contains("宋")):
		face = _embedded(ADOBE_SONG)
		already_bold = false
	elif family.contains("kaiti") or family.contains("kai") or family.contains("楷"):
		face = _embedded(KAI)
		already_bold = false
	elif family.contains("simsun") or family.contains("serif") or family.contains("宋"):
		face = _embedded(SONG)
		already_bold = false
	elif family.contains("noto sans"):
		face = _embedded(CJK_FALLBACK)
		already_bold = false
	base_font = face
	# A tall fallback RID changes Label line height even for available glyphs.
	# Each bundled face includes all story glyphs and common Han characters.
	fallbacks = []
	variation_embolden = 0.6 if font_weight >= 600 and not already_bold else 0.0
	variation_transform = Transform2D(Vector2(1, 0), Vector2(0.20 if font_italic else 0.0, 1), Vector2.ZERO)
