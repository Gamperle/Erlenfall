class_name ChargeIndicator
extends Control
## A small bar that fills while the attack button is held for a heavy swing. Tick marks show the
## progress without colour, and a diamond at each end shows a full charge, so it reads in any mode.

const BAR_SIZE := Vector2(120.0, 12.0)
const TICKS := 4
const BACK_COLOR := Color(0.05, 0.05, 0.08, 0.75)
const FRAME_COLOR := Color(0.96, 0.91, 0.8, 1.0)
const TICK_COLOR := Color(0.0, 0.0, 0.0, 0.6)
const DIAMOND_RADIUS := 7.0
const BELOW_CENTRE := 72.0

## How full the charge is, from 0 to 1.
var fraction := 0.0
## Whether the charge is full.
var full := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = BAR_SIZE
	size = BAR_SIZE
	position = Vector2(-BAR_SIZE.x * 0.5, BELOW_CENTRE)
	visible = false


## Shows the charge, or hides the bar for a negative fraction.
func set_charge(new_fraction: float) -> void:
	visible = new_fraction >= 0.0
	fraction = clampf(new_fraction, 0.0, 1.0)
	full = new_fraction >= 1.0
	queue_redraw()


func _draw() -> void:
	var color := Accessibility.color("warning")
	if Settings.high_contrast:
		color = Accessibility.HC_TEXT_COLOR
	var rect := Rect2(Vector2.ZERO, BAR_SIZE)
	draw_rect(rect, BACK_COLOR)
	draw_rect(Rect2(Vector2.ZERO, Vector2(BAR_SIZE.x * fraction, BAR_SIZE.y)), color)
	for i in range(1, TICKS):
		var x := BAR_SIZE.x * i / TICKS
		draw_line(Vector2(x, 0.0), Vector2(x, BAR_SIZE.y), TICK_COLOR, 2.0)
	draw_rect(rect, FRAME_COLOR, false, 3.0 if full else 1.5)
	if full:
		for x in [-DIAMOND_RADIUS - 4.0, BAR_SIZE.x + DIAMOND_RADIUS + 4.0]:
			var middle := Vector2(x, BAR_SIZE.y * 0.5)
			var points := PackedVector2Array([
				middle + Vector2(0.0, -DIAMOND_RADIUS), middle + Vector2(DIAMOND_RADIUS, 0.0),
				middle + Vector2(0.0, DIAMOND_RADIUS), middle + Vector2(-DIAMOND_RADIUS, 0.0)])
			draw_colored_polygon(points, color)
			draw_polyline(PackedVector2Array(points + PackedVector2Array([points[0]])), FRAME_COLOR, 1.5)
