class_name CreditsMenu
extends VBoxContainer
## The credits and licenses page: the third-party and generated assets from ASSETS.md, then the
## texts of the project's licenses. Scrolls with the wheel, the arrow keys, the D-pad, and the
## right stick.

signal back_chosen

const SCROLL_STEP := 60.0
const PAGE_STEP := 300.0
const STICK_SPEED := 900.0
const STICK_DEADZONE := 0.3
const VIEW_FRACTION := 0.6

var _scroll := ScrollContainer.new()
var _list := VBoxContainer.new()
var _back: Button


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 10)
	_scroll.add_child(_list)
	add_child(_scroll)
	_build_list()
	_back = Button.new()
	_back.text = "UI_BACK"
	_back.pressed.connect(back_chosen.emit)
	add_child(_back)
	get_viewport().size_changed.connect(_fit)
	_fit()
	_back.grab_focus.call_deferred()


## Scrolls by the given amount, up when it is negative.
func scroll_by(amount: float) -> void:
	_scroll.scroll_vertical = clampi(_scroll.scroll_vertical + roundi(amount), 0, maxi(0, roundi(_list.size.y)))


func scroll_position() -> int:
	return _scroll.scroll_vertical


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	for pad in Input.get_connected_joypads():
		var axis := Input.get_joy_axis(pad, JOY_AXIS_RIGHT_Y)
		if absf(axis) > STICK_DEADZONE:
			scroll_by(axis * STICK_SPEED * delta)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_pressed():
		return
	var step := 0.0
	if event.is_action("ui_down"):
		step = SCROLL_STEP
	elif event.is_action("ui_up"):
		step = -SCROLL_STEP
	elif event.is_action("ui_page_down"):
		step = PAGE_STEP
	elif event.is_action("ui_page_up"):
		step = -PAGE_STEP
	if step != 0.0:
		scroll_by(step)
		get_viewport().set_input_as_handled()


func _fit() -> void:
	_scroll.custom_minimum_size.y = maxf(120.0, get_viewport_rect().size.y * VIEW_FRACTION)


func _build_list() -> void:
	_add_text("UI_CREDITS_INTRO")
	var data := CreditsData.load_assets()
	_add_heading("UI_CREDITS_ASSETS")
	var entries: Array = data["entries"]
	if entries.is_empty():
		_add_text("UI_CREDITS_MISSING")
	for entry: Dictionary in entries:
		var box := VBoxContainer.new()
		_add_text(entry["source"], true, box)
		_add_text("%s, %s" % [entry["author"], entry["license"]], true, box, true)
		_add_text(CreditsData.files_text(entry["files"]), true, box, true)
		_list.add_child(box)
	for note: String in data["notes"]:
		_add_text(note, true)
	_add_heading("UI_CREDITS_LICENSES")
	for path: String in CreditsData.PROJECT_LICENSES:
		var text := CreditsData.read_text(path).strip_edges()
		if text != "":
			_add_text(text, true)
			_list.add_child(HSeparator.new())


## Headings are keys, which the label translates by itself, so they follow a change of language.
func _add_heading(key: String) -> void:
	var heading := Label.new()
	heading.text = key
	heading.theme_type_variation = &"TitleLabel"
	_list.add_child(heading)


## A wrapped text: a key to translate, or (literal) text from a file that is shown as it is.
func _add_text(text: String, literal := false, parent: Control = null, dim := false) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.custom_minimum_size.x = 1.0
	if literal:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if dim:
		label.modulate = Color(1, 1, 1, 0.75)
	(parent if parent != null else _list).add_child(label)
