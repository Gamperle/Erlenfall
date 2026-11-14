class_name InputGlyph
extends Control
## One input drawn in code for a prompt: a rounded rectangle with the key's name, a circle with the
## letter of a gamepad button, a cross for the d-pad, a bumper or trigger, or a stick. It is built
## from a spec (see `spec_for`) and sized from the font size of the text around it.
##
## Looks follow the accessibility settings (see Accessibility.glyph_look): high contrast draws plain
## black and white, and the colour vision modes drop the face button colours. Every glyph carries its
## name as text, so no meaning rests on colour.

enum Shape { KEY, ROUND, BUMPER, TRIGGER, PILL, DPAD, STICK }

const SHAPE_NAMES: Array[String] = ["key", "round", "bumper", "trigger", "pill", "dpad", "stick"]
const HEIGHT_FACTOR := 1.5
const SIDE_PADDING_FACTOR := 0.4
const GAP := 2.0
const KEY_RADIUS := 4
const MAX_WIDTH := 400.0

var spec: Dictionary = {}
var font_size := 16
var _font: Font


## The spec for an input: { "shape": name, "text": what it reads as plain text, and optionally
## "face": the letter of a coloured button, "letter": text drawn instead of "text", and "dir": a
## Vector2i for a d-pad arm or the way a stick is pushed }.
static func spec_for(event: InputEvent) -> Dictionary:
	var text := KeyBindings.event_text(event)
	if event is InputEventJoypadButton:
		var index: int = event.button_index
		if index <= JOY_BUTTON_Y:
			return { "shape": "round", "text": text, "face": text }
		if index == JOY_BUTTON_LEFT_SHOULDER or index == JOY_BUTTON_RIGHT_SHOULDER:
			return { "shape": "bumper", "text": text }
		if index == JOY_BUTTON_LEFT_STICK or index == JOY_BUTTON_RIGHT_STICK:
			return { "shape": "round", "text": text }
		if index >= KeyBindings.JOY_DPAD_UP_INDEX and index - KeyBindings.JOY_DPAD_UP_INDEX < 4:
			var arms: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
			return { "shape": "dpad", "text": text, "dir": arms[index - KeyBindings.JOY_DPAD_UP_INDEX] }
		return { "shape": "pill", "text": text }
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT or event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return { "shape": "trigger", "text": text }
		var push := int(signf(event.axis_value))
		var direction := Vector2i(push, 0) if event.axis % 2 == 0 else Vector2i(0, push)
		return { "shape": "stick", "text": text, "letter": "L" if event.axis <= JOY_AXIS_LEFT_Y else "R", "dir": direction }
	return { "shape": "key", "text": text }


## The spec for a whole stick with no direction, as the walk and look hints show it.
static func stick_spec(event: InputEvent) -> Dictionary:
	if event is InputEventJoypadMotion and event.axis <= JOY_AXIS_RIGHT_Y:
		return { "shape": "stick", "text": KeyBindings.stick_text(event), "letter": "L" if event.axis <= JOY_AXIS_LEFT_Y else "R" }
	return spec_for(event)


## Whether the spec describes something this class can draw.
static func can_draw(glyph_spec: Dictionary) -> bool:
	return SHAPE_NAMES.has(glyph_spec.get("shape", "")) and str(glyph_spec.get("text", "")) != ""


func _init(new_spec: Dictionary = {}, new_font_size: int = 16) -> void:
	spec = new_spec
	font_size = new_font_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tooltip_text = str(spec.get("text", ""))


func _ready() -> void:
	_font = get_theme_default_font()


func _get_minimum_size() -> Vector2:
	var width := _height()
	if _shape() in [Shape.KEY, Shape.BUMPER, Shape.TRIGGER, Shape.PILL]:
		width = maxf(width, _text_width() + font_size * SIDE_PADDING_FACTOR * 2.0)
	return Vector2(minf(width, MAX_WIDTH) + GAP * 2.0, _height())


func _draw() -> void:
	var look := Accessibility.glyph_look(str(spec.get("face", "")))
	var box := Rect2(Vector2(GAP, 0.0), size - Vector2(GAP * 2.0, 0.0))
	var shape := _shape()
	if shape == Shape.DPAD:
		_draw_dpad(box, look)
		return
	var style := StyleBoxFlat.new()
	style.bg_color = look["fill"]
	style.border_color = look["border"]
	style.set_border_width_all(look["border_width"])
	var half := int(box.size.y / 2.0)
	var top := KEY_RADIUS
	var bottom := KEY_RADIUS
	match shape:
		Shape.ROUND, Shape.STICK, Shape.PILL:
			top = half
			bottom = half
		Shape.BUMPER:
			top = half
			bottom = 2
		Shape.TRIGGER:
			top = half
			bottom = 3
	style.corner_radius_top_left = top
	style.corner_radius_top_right = top
	style.corner_radius_bottom_left = bottom
	style.corner_radius_bottom_right = bottom
	draw_style_box(style, box)
	if shape == Shape.STICK:
		_draw_stick_direction(box, look)
	_draw_text(box, look)


func _draw_text(box: Rect2, look: Dictionary) -> void:
	if _font == null:
		return
	var text := str(spec.get("letter", spec.get("text", "")))
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var x := box.position.x + (box.size.x - text_size.x) / 2.0
	var y := box.position.y + (box.size.y - text_size.y) / 2.0 + _font.get_ascent(font_size)
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, look["text"])


## A small triangle at the edge of the circle, pointing the way the stick is pushed.
func _draw_stick_direction(box: Rect2, look: Dictionary) -> void:
	var direction: Vector2i = spec.get("dir", Vector2i.ZERO)
	if direction == Vector2i.ZERO:
		return
	var forward := Vector2(direction)
	var side := Vector2(-forward.y, forward.x)
	var reach := box.size.y * 0.5
	var tip := box.get_center() + forward * (reach - 1.0)
	var base := box.get_center() + forward * (reach - box.size.y * 0.2)
	draw_colored_polygon(PackedVector2Array([tip, base + side * box.size.y * 0.12, base - side * box.size.y * 0.12]), look["border"])


## A cross, with the arm for the input drawn solid and the others dim.
func _draw_dpad(box: Rect2, look: Dictionary) -> void:
	var centre := box.get_center()
	var reach := box.size.y / 2.0
	var arm := box.size.y / 3.0
	var direction: Vector2i = spec.get("dir", Vector2i.ZERO)
	var dim: Color = look["border"]
	dim.a *= 0.35
	var length := reach - arm / 2.0 + 1.0
	var arms := {
		Vector2i.UP: Rect2(centre.x - arm / 2.0, centre.y - reach, arm, length),
		Vector2i.DOWN: Rect2(centre.x - arm / 2.0, centre.y + arm / 2.0 - 1.0, arm, length),
		Vector2i.LEFT: Rect2(centre.x - reach, centre.y - arm / 2.0, length, arm),
		Vector2i.RIGHT: Rect2(centre.x + arm / 2.0 - 1.0, centre.y - arm / 2.0, length, arm),
	}
	draw_rect(Rect2(centre - Vector2(arm, arm) / 2.0, Vector2(arm, arm)), dim)
	for arm_direction: Vector2i in arms:
		draw_rect(arms[arm_direction], look["border"] if arm_direction == direction else dim)


func _shape() -> Shape:
	return maxi(0, SHAPE_NAMES.find(str(spec.get("shape", "key")))) as Shape


func _height() -> float:
	return roundf(font_size * HEIGHT_FACTOR)


func _text_width() -> float:
	if _font == null:
		_font = get_theme_default_font()
	if _font == null:
		return 0.0
	return _font.get_string_size(str(spec.get("letter", spec.get("text", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
