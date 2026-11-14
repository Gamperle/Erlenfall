class_name ReadingUI
extends CanvasLayer
## The panel that shows a sign, note, or book (see Readable). It pauses the game like the inventory.
## Reading something for the first time adds it to the journal's Notes tab, and may set a story flag.
##
## The panel is a FittedPanel and a ParchmentPanel with ink text, so the text size and the high contrast
## settings apply. The close button has the focus, so the keyboard, mouse and controller all close it,
## and the up and down inputs scroll a long text.

const GROUP := "reading_ui"
const PANEL_WIDTH := 640.0
const TITLE_FONT_SIZE := 26
const SCROLL_STEP := 60

var _player: Player
var _panel: FittedPanel
var _title: Label
var _text: Label
var _close_button: Button
var _hint: PromptLine


## Makes the panel under `parent`, or returns null when the `readables` flag is off.
static func create(parent: Node) -> ReadingUI:
	if not FeatureFlags.enabled("readables"):
		return null
	var ui := ReadingUI.new()
	ui.name = "ReadingUI"
	parent.add_child(ui)
	return ui


func _init() -> void:
	layer = 2
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(InputDevice.PROMPT_GROUP)
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


## Shows a text and notes it in the journal. Does nothing for an unknown text.
func open_note(note_id: String, player: Player) -> void:
	if not Readables.has(note_id) or is_open():
		return
	_player = player
	var entry := Readables.entry(note_id)
	_title.text = tr(entry["title"])
	_text.text = tr(entry["text"])
	refresh_style()
	refresh_prompts()
	_panel.visible = true
	_player.set_busy(true)
	if player.notes.add(note_id, entry["title"], entry["text"]):
		_player.notice.emit(tr("UI_NOTE_ADDED") % tr(entry["title"]))
	if entry.has("sets_flag") and not player.quests.flags.has(entry["sets_flag"]):
		player.quests.flags[entry["sets_flag"]] = true
		player.quests.changed.emit()
	_close_button.grab_focus()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	_player.set_busy(false)


## Applies the text size setting.
func refresh_style() -> void:
	_title.add_theme_font_size_override("font_size", Settings.scaled_font_size(TITLE_FONT_SIZE))
	if _hint.get_child_count() > 0:
		_hint.rebuild()


## Shows the close hint with the inputs of the device in use.
func refresh_prompts() -> void:
	_hint.set_template(tr("UI_READING_HINT"), [KeyBindings.segments_for("interact")])


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _close_button != null:
		_close_button.text = tr("UI_READING_CLOSE")
		refresh_prompts()


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var scroll := _panel.content.get_parent() as ScrollContainer
		scroll.scroll_vertical += SCROLL_STEP if event.is_action_pressed("ui_down") else -SCROLL_STEP
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel = FittedPanel.new(PANEL_WIDTH)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var column := _panel.content
	column.add_theme_constant_override("separation", 10)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)

	var page := PanelContainer.new()
	page.theme_type_variation = &"ParchmentPanel"
	column.add_child(page)

	_text = Label.new()
	_text.theme_type_variation = &"InkLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_text)

	_close_button = Button.new()
	_close_button.text = tr("UI_READING_CLOSE")
	_close_button.focus_mode = Control.FOCUS_ALL
	_close_button.pressed.connect(close)
	column.add_child(_close_button)

	_hint = PromptLine.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)
