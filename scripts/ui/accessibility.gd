class_name Accessibility
extends RefCounted
## Colour vision palettes and the high-contrast look. Shapes and patterns carry every meaning that a
## color carries, so the palettes only make things easier to tell apart.

const MODES: Array[String] = ["off", "deuteranopia", "protanopia", "tritanopia"]

## Colors per mode. Deuteranopia and protanopia confuse red and green, so they use orange and blue.
## Tritanopia confuses blue and yellow, so it uses red, teal, and pink.
const PALETTES: Dictionary = {
	"off": {
		"health": Color(0.74, 0.14, 0.1), "stamina": Color(0.85, 0.7, 0.2),
		"objective": Color(1.0, 0.85, 0.3), "player": Color(0.95, 0.35, 0.2),
		"enemy": Color(0.85, 0.15, 0.1), "warning": Color(0.95, 0.35, 0.1), "target": Color(0.85, 0.55, 0.2),
	},
	"deuteranopia": {
		"health": Color(0.9, 0.45, 0.0), "stamina": Color(0.35, 0.7, 0.95),
		"objective": Color(0.95, 0.9, 0.25), "player": Color(0.4, 0.75, 1.0),
		"enemy": Color(0.9, 0.45, 0.0), "warning": Color(0.95, 0.9, 0.25), "target": Color(0.35, 0.7, 0.95),
	},
	"protanopia": {
		"health": Color(1.0, 0.6, 0.1), "stamina": Color(0.3, 0.65, 1.0),
		"objective": Color(0.95, 0.9, 0.25), "player": Color(0.5, 0.8, 1.0),
		"enemy": Color(1.0, 0.6, 0.1), "warning": Color(0.95, 0.9, 0.25), "target": Color(0.3, 0.65, 1.0),
	},
	"tritanopia": {
		"health": Color(0.85, 0.1, 0.2), "stamina": Color(0.0, 0.65, 0.5),
		"objective": Color(1.0, 0.55, 0.75), "player": Color(0.95, 0.4, 0.15),
		"enemy": Color(0.85, 0.1, 0.2), "warning": Color(1.0, 0.55, 0.75), "target": Color(0.0, 0.65, 0.5),
	},
}
const HC_TEXT_COLOR := Color(1.0, 1.0, 1.0)
const HC_TITLE_COLOR := Color(1.0, 0.95, 0.55)
const HC_INK_COLOR := Color(0.0, 0.0, 0.0)
const HC_PLATE_COLOR := Color(0.05, 0.05, 0.08)
## Input glyph colors, and the tints of the gamepad face buttons (used only with the normal look).
const GLYPH_FILL := Color(0.1, 0.1, 0.12, 0.88)
const GLYPH_BORDER := Color(0.96, 0.91, 0.8, 1.0)
const GLYPH_FACE_TINTS: Dictionary = {
	"A": Color(0.2, 0.5, 0.25, 0.95), "B": Color(0.62, 0.17, 0.17, 0.95),
	"X": Color(0.18, 0.34, 0.65, 0.95), "Y": Color(0.62, 0.5, 0.1, 0.95),
}
const HC_OUTLINE_SIZE := 6
const HC_OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 1.0)
## Theme text colors made plain white in high contrast: [type, name].
const HC_TEXT_ENTRIES: Array = [
	["Label", "font_color"], ["Button", "font_color"], ["Button", "font_hover_color"],
	["Button", "font_pressed_color"], ["Button", "font_focus_color"], ["Button", "font_hover_pressed_color"],
	["OptionButton", "font_color"], ["OptionButton", "font_hover_color"], ["OptionButton", "font_pressed_color"],
	["OptionButton", "font_focus_color"], ["OptionButton", "font_hover_pressed_color"],
	["PopupMenu", "font_color"], ["PopupMenu", "font_hover_color"], ["LinkButton", "font_color"],
]
## Styleboxes darkened in high contrast: [type, name].
const HC_DARK_STYLES: Array = [
	["PanelContainer", "panel"], ["PopupMenu", "panel"], ["HudPlate", "normal"],
	["CompassStrip", "panel"], ["ProgressBar", "background"],
]

static var _original_colors: Dictionary = {}
static var _original_modulates: Dictionary = {}


static func color(key: String) -> Color:
	return PALETTES[Settings.colour_vision][key]


## How an input glyph is drawn: { fill, border, border_width, text }. High contrast is plain black
## and white. The face button tint (by letter, "" for none) only shows with the normal colour vision
## mode, since the letter carries the meaning and the colours only help.
static func glyph_look(face: String = "") -> Dictionary:
	if Settings.high_contrast:
		return { "fill": HC_INK_COLOR, "border": HC_TEXT_COLOR, "border_width": 2, "text": HC_TEXT_COLOR }
	var fill := GLYPH_FILL
	if Settings.colour_vision == "off" and GLYPH_FACE_TINTS.has(face):
		fill = GLYPH_FACE_TINTS[face]
	return { "fill": fill, "border": GLYPH_BORDER, "border_width": 1, "text": GLYPH_BORDER }


## Changes the theme's colors for the colour vision mode and high contrast, and puts them back when off.
static func apply_theme() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	var high := Settings.high_contrast
	for entry: Array in HC_TEXT_ENTRIES:
		_set_color(theme, entry[0], entry[1], HC_TEXT_COLOR if high else null)
	_set_color(theme, "TitleLabel", "font_color", HC_TITLE_COLOR if high else null)
	_set_color(theme, "InkLabel", "font_color", HC_INK_COLOR if high else null)
	for entry: Array in HC_DARK_STYLES:
		_set_modulate(theme, entry[0], entry[1], HC_PLATE_COLOR if high else null)
	# The fills always follow the palette.
	_set_modulate(theme, "ProgressBar", "fill", color("health"))
	_set_modulate(theme, "StaminaBar", "fill", color("stamina"))
	# The forging target follows the palette, and the forging bar's trough goes dark in high contrast.
	_set_modulate(theme, "ForgeTarget", "panel", color("target"))
	_set_modulate(theme, "BarTrough", "panel", HC_PLATE_COLOR if high else null)


## A null value puts the theme's own color back.
static func _set_color(theme: Theme, type: String, color_name: String, value: Variant) -> void:
	var key := type + "/" + color_name
	if not _original_colors.has(key):
		_original_colors[key] = theme.get_color(color_name, type) if theme.has_color(color_name, type) else null
	var original: Variant = _original_colors[key]
	if value == null:
		value = original
	if value == null:
		if theme.has_color(color_name, type):
			theme.clear_color(color_name, type)
	else:
		theme.set_color(color_name, type, value)


static func _set_modulate(theme: Theme, type: String, style_name: String, value: Variant) -> void:
	var style := theme.get_stylebox(style_name, type) as StyleBoxTexture
	if style == null:
		return
	var key := type + "/" + style_name
	if not _original_modulates.has(key):
		_original_modulates[key] = style.modulate_color
	style.modulate_color = _original_modulates[key] if value == null else value


## Makes a label's outline and text color follow high contrast.
static func apply_label_settings(settings: LabelSettings) -> void:
	if settings == null:
		return
	if not settings.has_meta("normal_look"):
		settings.set_meta("normal_look", [settings.outline_size, settings.outline_color, settings.font_color])
	var normal: Array = settings.get_meta("normal_look")
	if Settings.high_contrast:
		settings.outline_size = HC_OUTLINE_SIZE
		settings.outline_color = HC_OUTLINE_COLOR
		settings.font_color = HC_TEXT_COLOR
	else:
		settings.outline_size = normal[0]
		settings.outline_color = normal[1]
		settings.font_color = normal[2]
