class_name FittedPanel
extends PanelContainer
## A panel that narrows to fit a small window. Its content scrolls when it's too tall.

const WINDOW_MARGIN := 8.0

## Add the panel's controls here.
var content := VBoxContainer.new()

var _width: float
var _reserved_height: float
var _scroll := ScrollContainer.new()


## Keeps the given height free in the window, for a panel that isn't centered.
func _init(width: float, reserved_height := 0.0) -> void:
	_width = width
	_reserved_height = reserved_height
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.minimum_size_changed.connect(_fit)
	_scroll.add_child(content)


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_node_ready() and visible:
		_fit()


func _fit() -> void:
	var room := get_viewport_rect().size - Vector2.ONE * WINDOW_MARGIN * 2.0
	var frame := get_theme_stylebox("panel").get_minimum_size()
	custom_minimum_size.x = minf(_width, room.x)
	_scroll.custom_minimum_size.y = minf(content.get_combined_minimum_size().y, room.y - _reserved_height - frame.y)
