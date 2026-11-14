class_name DialogueUI
extends CanvasLayer
## Shows a conversation with its reply options.

const PANEL_WIDTH := 760.0
const BOTTOM_MARGIN := 90.0
const SPEAKER_FONT_SIZE := 24

var _player: Player
var _runner: DialogueRunner

var _panel: FittedPanel
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _hint: Label


func _ready() -> void:
	add_to_group(Npc.UI_GROUP)
	add_to_group(InputDevice.PROMPT_GROUP)
	_build()
	_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _panel.visible


## `talker` is whoever is being spoken to, if it reacts to effects like calming (see EnemyTalk).
func open_conversation(npc_id: String, speaker: String, player: Player, talker: Object = null) -> void:
	_player = player
	_runner = DialogueRunner.new(npc_id, player, talker)
	_speaker.text = speaker
	refresh_style()
	_panel.visible = true
	_player.set_busy(true)
	refresh_prompts()
	_show_line()


## Applies the text size and panel opacity settings. High contrast makes the panel opaque.
func refresh_style() -> void:
	_speaker.add_theme_font_size_override("font_size", Settings.scaled_font_size(SPEAKER_FONT_SIZE))
	# High contrast needs a solid panel, whatever the opacity setting says.
	_panel.self_modulate.a = 1.0 if Settings.high_contrast else Settings.dialogue_opacity


## Answers with the given reply. Public so buttons, keys, and tests share one path.
func choose(index: int) -> void:
	_runner.advance(index)
	if _runner.is_finished():
		_panel.visible = false
		_player.set_busy(false)
		_player.end_conversation()
	else:
		_show_line()


## Shows the choose hint with the inputs of the device in use.
func refresh_prompts() -> void:
	_hint.text = tr("UI_DIALOGUE_HINT") % KeyBindings.label_for("interact")


func _input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("interact"):
		var focused := get_viewport().gui_get_focus_owner() as Button
		if focused != null:
			focused.pressed.emit()
		get_viewport().set_input_as_handled()


func _show_line() -> void:
	_text.text = tr(_runner.text_key())
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()

	var keys := _runner.choice_keys()
	if keys.is_empty():
		_add_choice(tr("UI_CONTINUE"), 0)
	for i in keys.size():
		_add_choice(tr(keys[i]), i)
	_choices.get_child(0).grab_focus()


func _add_choice(text: String, index: int) -> void:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(choose.bind(index))
	_choices.add_child(button)


func _build() -> void:
	_panel = FittedPanel.new(PANEL_WIDTH, BOTTOM_MARGIN)
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.offset_bottom = -BOTTOM_MARGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var column := _panel.content
	column.add_theme_constant_override("separation", 10)

	_speaker = Label.new()
	_speaker.theme_type_variation = &"TitleLabel"
	column.add_child(_speaker)

	var page := PanelContainer.new()
	page.theme_type_variation = &"ParchmentPanel"
	column.add_child(page)

	_text = Label.new()
	_text.theme_type_variation = &"InkLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_text)

	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	column.add_child(_choices)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hint)
