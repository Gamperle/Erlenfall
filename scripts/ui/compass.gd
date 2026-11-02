class_name Compass
extends Control
## A strip across the top of the screen showing the directions ahead. North is -Z and east is +X.

const VISIBLE_DEGREES := 90.0
const TICK_DEGREES := 15
const FADE_START := 0.7
const FONT_SIZE := 15
const MAJOR_FONT_SIZE := 20
const OUTLINE_SIZE := 4
const BACKGROUND_COLOR := Color(0.1, 0.08, 0.08, 0.55)
const TICK_COLOR := Color(0.9, 0.87, 0.8)
const NORTH_COLOR := Color(0.95, 0.55, 0.15)
const CENTER_MARK_SIZE := 6.0
const OBJECTIVE_COLOR := Color(1.0, 0.85, 0.3)
const OBJECTIVE_SIZE := 7.0
const POINTS: Dictionary = {
	0: "UI_COMPASS_N", 45: "UI_COMPASS_NE", 90: "UI_COMPASS_E", 135: "UI_COMPASS_SE",
	180: "UI_COMPASS_S", 225: "UI_COMPASS_SW", 270: "UI_COMPASS_W", 315: "UI_COMPASS_NW",
}

## The direction being faced, in degrees clockwise from north.
var heading := 0.0:
	set(new_heading):
		if new_heading != heading:
			heading = new_heading
			queue_redraw()


## The directions of the current objectives, in degrees clockwise from north.
var objective_bearings := PackedFloat32Array():
	set(new_bearings):
		if new_bearings != objective_bearings:
			objective_bearings = new_bearings
			queue_redraw()


## Returns the direction from one place to another, each given as x and z.
static func bearing_between(from: Vector2, to: Vector2) -> float:
	var offset := to - from
	return fposmod(rad_to_deg(atan2(offset.x, -offset.y)), 360.0)


## Returns where a direction appears, from -1 at the left edge to 1 at the right.
func offset_of(bearing: float) -> float:
	return wrapf(bearing - heading, -180.0, 180.0) / VISIBLE_DEGREES


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var font := ThemeDB.fallback_font
	for bearing in range(0, 360, TICK_DEGREES):
		var offset := offset_of(bearing)
		if absf(offset) >= 1.0:
			continue
		var x := (offset + 1.0) * size.x / 2.0
		var fade := 1.0 - smoothstep(FADE_START, 1.0, absf(offset))
		if POINTS.has(bearing):
			var major := bearing % 90 == 0
			var font_size := MAJOR_FONT_SIZE if major else FONT_SIZE
			var color := NORTH_COLOR if bearing == 0 else TICK_COLOR
			color.a = fade
			var text := tr(POINTS[bearing])
			var at := Vector2(x - font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x / 2.0, size.y / 2.0 + font_size * 0.36)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, OUTLINE_SIZE, Color(0.0, 0.0, 0.0, fade * 0.8))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		else:
			var tick := TICK_COLOR
			tick.a = fade * 0.7
			draw_line(Vector2(x, size.y * 0.35), Vector2(x, size.y * 0.65), tick, 1.0)
	# An objective outside the strip stays at the nearest edge, to show which way to turn.
	for bearing in objective_bearings:
		var x := (clampf(offset_of(bearing), -1.0, 1.0) + 1.0) * size.x / 2.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, size.y / 2.0 - OBJECTIVE_SIZE),
			Vector2(x + OBJECTIVE_SIZE, size.y / 2.0),
			Vector2(x, size.y / 2.0 + OBJECTIVE_SIZE),
			Vector2(x - OBJECTIVE_SIZE, size.y / 2.0),
		]), OBJECTIVE_COLOR)
	var middle := size.x / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(middle - CENTER_MARK_SIZE, size.y + CENTER_MARK_SIZE),
		Vector2(middle + CENTER_MARK_SIZE, size.y + CENTER_MARK_SIZE),
		Vector2(middle, size.y),
	]), TICK_COLOR)
