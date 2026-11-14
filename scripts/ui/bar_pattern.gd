class_name BarPattern
extends Control
## Marks the filled part of a bar with a pattern, so that bars differ by more than color: stripes for
## health and dots for stamina. Shown for the colour vision modes and high contrast.

enum Kind { STRIPES, DOTS }

const STEP := 8.0
const PATTERN_COLOR := Color(0.0, 0.0, 0.0, 0.55)
const PATTERN_WIDTH := 2.0

var kind := Kind.STRIPES
var _bar: ProgressBar


func _init(new_kind: Kind = Kind.STRIPES) -> void:
	kind = new_kind
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_bar = get_parent().get_parent() as ProgressBar
	if _bar != null:
		_bar.value_changed.connect(func(_value: float) -> void: queue_redraw())
	resized.connect(queue_redraw)
	refresh()


## Whether the current settings ask for patterns.
static func wanted() -> bool:
	return Settings.colour_vision != "off" or Settings.high_contrast


func refresh() -> void:
	visible = wanted()
	queue_redraw()


func _draw() -> void:
	if _bar == null or _bar.max_value <= _bar.min_value:
		return
	var width := size.x * clampf((_bar.value - _bar.min_value) / (_bar.max_value - _bar.min_value), 0.0, 1.0)
	var height := size.y
	if width <= 0.0:
		return
	if kind == Kind.STRIPES:
		# Diagonal lines from bottom left to top right, cut off at the end of the fill.
		var x := -height
		while x < width:
			var start := Vector2(maxf(x, 0.0), height + minf(x, 0.0))
			var end := Vector2(minf(x + height, width), maxf(0.0, height - (width - x)) if x + height > width else 0.0)
			draw_line(start, end, PATTERN_COLOR, PATTERN_WIDTH)
			x += STEP
	else:
		var x := STEP * 0.5
		while x < width:
			draw_circle(Vector2(x, height * 0.5), maxf(height * 0.2, 1.0), PATTERN_COLOR)
			x += STEP
