class_name HudLayout
extends CanvasLayer
## Places the HUD for the window's width. Narrow windows move the compass into a row of its own.

## Below this width, the compass overlaps the health bar and performance overlay in one row.
const NARROW_WIDTH := 1152.0
const EDGE := 16.0
const COMPASS_HALF_WIDTH := 200.0
const TOP_ROW := 12.0
const SECOND_ROW := 52.0
const HEALTH_INSET := 4.0
const STAMINA_GAP := 6.0
const OVERLAY_HEIGHT := 72.0
const OVERLAY_WIDTH := 344.0
const QUEST_WIDTH := 544.0
const QUEST_GAP := 8.0
const PROMPT_BOTTOM := 90.0
const PROMPT_GAP := 12.0

## The corner map, when there is one. The map controller sets it.
var minimap: Minimap
## How visible the sneaking player is, above the prompt.
var visibility_indicator: VisibilityIndicator

@onready var _compass: Control = $Compass
@onready var _health_bar: Control = $HealthBar
@onready var _stamina_bar: Control = $StaminaBar
@onready var _overlay: Control = $PerformanceOverlay
@onready var _quest: Label = $QuestLabel
@onready var _prompt: Control = $PromptLabel
@onready var _controls: Control = $ControlsLabel


func _ready() -> void:
	get_viewport().size_changed.connect(arrange)
	_controls.minimum_size_changed.connect(_place_prompt)
	_add_bar_pattern(_health_bar, BarPattern.Kind.STRIPES)
	_add_bar_pattern(_stamina_bar, BarPattern.Kind.DOTS)
	visibility_indicator = VisibilityIndicator.new()
	visibility_indicator.name = "VisibilityIndicator"
	add_child(visibility_indicator)
	arrange()
	refresh_accessibility()


## Makes the HUD follow the colour vision and high-contrast settings.
func refresh_accessibility() -> void:
	for label: Control in [_quest, _prompt, _controls, _overlay, get_node_or_null("MessageLabel")]:
		if label is Label or label is PromptLine:
			Accessibility.apply_label_settings(label.label_settings)
	for line: PromptLine in [_prompt, _controls]:
		line.rebuild()
	for bar: Control in [_health_bar, _stamina_bar]:
		var pattern := bar.get_node("Frame/Pattern") as BarPattern
		pattern.refresh()
	_compass.queue_redraw()
	visibility_indicator.queue_redraw()
	if minimap != null:
		minimap.queue_redraw()


func _add_bar_pattern(bar: Control, kind: BarPattern.Kind) -> void:
	var pattern := BarPattern.new(kind)
	pattern.name = "Pattern"
	bar.get_node("Frame").add_child(pattern)


func arrange() -> void:
	arrange_for(get_viewport().get_visible_rect().size.x)


## Public so tests can try window widths without resizing the window.
func arrange_for(width: float) -> void:
	var narrow := width < NARROW_WIDTH
	var half := minf(COMPASS_HALF_WIDTH, width / 2.0 - EDGE)
	_compass.offset_left = -half
	_compass.offset_right = half

	var row := SECOND_ROW if narrow else TOP_ROW
	var health_height := _health_bar.offset_bottom - _health_bar.offset_top
	_health_bar.offset_top = row + HEALTH_INSET
	_health_bar.offset_bottom = _health_bar.offset_top + health_height
	var stamina_height := _stamina_bar.offset_bottom - _stamina_bar.offset_top
	_stamina_bar.offset_top = _health_bar.offset_bottom + STAMINA_GAP
	_stamina_bar.offset_bottom = _stamina_bar.offset_top + stamina_height
	_overlay.offset_top = row
	_overlay.offset_bottom = row + OVERLAY_HEIGHT
	_overlay.offset_left = -EDGE - minf(OVERLAY_WIDTH, width - _health_bar.offset_right - EDGE * 2.0)

	# The quest plate leaves the minimap's corner free.
	var reserved := Minimap.side_for_text_size() + EDGE if minimap != null else 0.0
	_quest.offset_left = -EDGE - minf(minf(QUEST_WIDTH, width - EDGE * 2.0 - reserved), _quest_text_width())
	var quest_top := _overlay.offset_bottom + QUEST_GAP if _overlay.visible else row
	if not _overlay.visible and narrow:
		quest_top = (_stamina_bar if _stamina_bar.visible else _health_bar).offset_bottom + QUEST_GAP
	_quest.offset_top = quest_top
	_quest.offset_bottom = quest_top
	_place_prompt()
	if minimap != null:
		minimap.place(Vector2(EDGE, (_stamina_bar if _stamina_bar.visible else _health_bar).offset_bottom + QUEST_GAP))


## The quest's plate is only as wide as its text.
func _quest_text_width() -> float:
	var font := _quest.get_theme_default_font()
	var widest := 0.0
	for line in _quest.text.split("\n"):
		widest = maxf(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _quest.label_settings.font_size).x)
	return ceilf(widest) + _quest.get_theme_stylebox("normal").get_minimum_size().x


## Long control hints wrap in a narrow window, so the prompt stays above them.
func _place_prompt() -> void:
	var height := _controls.get_combined_minimum_size().y + absf(_controls.offset_bottom) + PROMPT_GAP
	_prompt.offset_bottom = -maxf(PROMPT_BOTTOM, height)
	_prompt.offset_top = _prompt.offset_bottom - _prompt.get_combined_minimum_size().y
	_place_visibility_indicator()


## Centered above the prompt line.
func _place_visibility_indicator() -> void:
	if visibility_indicator == null:
		return
	visibility_indicator.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	var box := VisibilityIndicator.SIZE
	visibility_indicator.offset_left = -box.x / 2.0
	visibility_indicator.offset_right = box.x / 2.0
	visibility_indicator.offset_bottom = _prompt.offset_top - PROMPT_GAP
	visibility_indicator.offset_top = visibility_indicator.offset_bottom - box.y
