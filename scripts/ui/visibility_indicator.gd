class_name VisibilityIndicator
extends Control
## Shows how visible the sneaking player is (#207): an eye above a short bar and a word. The three
## levels differ by shape and pattern as well as colour: a closed eye with a dotted bar (hidden), a
## half open eye with a striped bar (cautious), and a wide open eye with rays and a solid bar (seen).
## Colours come from the colour vision palette, and high contrast draws it in black and white.
## Shown while sneaking (or always with `sneak_indicator_always`), and off with the `sneak_indicator` flag.

const SIZE := Vector2(120.0, 62.0)
const FONT_SIZE := 15
const EYE_CENTER := Vector2(60.0, 16.0)
const EYE_HALF_WIDTH := 22.0
const EYE_OPEN := [0.0, 8.0, 13.0]
const BAR_RECT := Rect2(10.0, 36.0, 100.0, 8.0)
const LEVEL_KEYS := ["UI_SNEAK_HIDDEN", "UI_SNEAK_CAUTIOUS", "UI_SNEAK_SEEN"]
const LEVEL_COLORS := ["stamina", "objective", "warning"]
const INK := Color(0.0, 0.0, 0.0, 0.85)
const OUTLINE_SIZE := 4

var level := 0
var amount := 0.0
var _player: Player


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var shown := _player != null and FeatureFlags.enabled("sneak_indicator") \
			and (_player.is_sneaking() or bool(FeatureFlags.value("sneak_indicator_always", false)))
	if shown:
		update_from(Noticing.level(_player), Noticing.visibility(_player))
	visible = shown


## Public so tests can set a level without a player.
func update_from(new_level: int, new_amount: float) -> void:
	if new_level != level or not is_equal_approx(new_amount, amount):
		level = new_level
		amount = new_amount
		queue_redraw()


## The colour for a level, from the palette.
func level_color(for_level: int) -> Color:
	return Color.WHITE if Settings.high_contrast else Accessibility.color(LEVEL_COLORS[for_level])


func _draw() -> void:
	var color := level_color(level)
	var plate := Rect2(Vector2.ZERO, size)
	draw_rect(plate, Accessibility.HC_PLATE_COLOR if Settings.high_contrast else Color(0.05, 0.05, 0.08, 0.55))
	_draw_eye(color)
	_draw_bar(color)
	var font := get_theme_default_font()
	var text := tr(LEVEL_KEYS[level])
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var at := Vector2((size.x - width) / 2.0, size.y - 6.0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, OUTLINE_SIZE, INK)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Accessibility.HC_TEXT_COLOR if Settings.high_contrast else color)


func _draw_eye(color: Color) -> void:
	var open: float = EYE_OPEN[level]
	var left := EYE_CENTER + Vector2(-EYE_HALF_WIDTH, 0.0)
	var right := EYE_CENTER + Vector2(EYE_HALF_WIDTH, 0.0)
	if level == 0:
		# Closed: a curved lid with lashes.
		var lid := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0
			lid.append(left.lerp(right, t) + Vector2(0.0, sin(t * PI) * 4.0))
		draw_polyline(lid, color, 3.0)
		for t: float in [0.2, 0.5, 0.8]:
			var base: Vector2 = left.lerp(right, t) + Vector2(0.0, sin(t * PI) * 4.0)
			draw_line(base, base + Vector2(0.0, 5.0), color, 2.0)
		return
	var outline := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		var x := lerpf(-EYE_HALF_WIDTH, EYE_HALF_WIDTH, t)
		outline.append(EYE_CENTER + Vector2(x, -sin(t * PI) * open))
	for i in range(24, -1, -1):
		var t := float(i) / 24.0
		var x := lerpf(-EYE_HALF_WIDTH, EYE_HALF_WIDTH, t)
		outline.append(EYE_CENTER + Vector2(x, sin(t * PI) * open))
	draw_colored_polygon(outline, Color(0.0, 0.0, 0.0, 0.5))
	draw_polyline(outline + PackedVector2Array([outline[0]]), color, 2.5)
	draw_circle(EYE_CENTER, open * 0.55, color)
	draw_circle(EYE_CENTER, open * 0.22, INK)
	if level == 2:
		# Rays: the eye is looking at you.
		for angle: float in [-0.9, -0.45, 0.0, 0.45, 0.9]:
			var direction := Vector2(sin(angle), -cos(angle))
			draw_line(EYE_CENTER + direction * 19.0 + Vector2(0.0, -2.0), EYE_CENTER + direction * 25.0 + Vector2(0.0, -2.0), color, 2.0)


func _draw_bar(color: Color) -> void:
	draw_rect(BAR_RECT, Color(0.12, 0.1, 0.1))
	var fill := Rect2(BAR_RECT.position, Vector2(BAR_RECT.size.x * clampf(amount, 0.0, 1.0), BAR_RECT.size.y))
	draw_rect(fill, color)
	# The pattern follows the level: dots, stripes, or solid.
	if level == 0:
		var x := fill.position.x + 4.0
		while x < fill.end.x:
			draw_circle(Vector2(x, BAR_RECT.get_center().y), 1.5, INK)
			x += 8.0
	elif level == 1:
		var x := fill.position.x
		while x < fill.end.x:
			draw_line(Vector2(x, BAR_RECT.end.y), Vector2(minf(x + BAR_RECT.size.y, fill.end.x), BAR_RECT.position.y + maxf(0.0, x + BAR_RECT.size.y - fill.end.x)), INK, 2.0)
			x += 8.0
	draw_rect(BAR_RECT, color, false, 1.0)
