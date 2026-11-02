class_name DialogueUI
extends CanvasLayer
## Shows a conversation with its reply options.

const PANEL_WIDTH := 760.0
const BOTTOM_MARGIN := 90.0

var _player: Player
var _runner: DialogueRunner

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _choices: VBoxContainer


func _ready() -> void:
	add_to_group(Npc.UI_GROUP)
	_build()
	_panel.visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_open() -> bool:
	return _panel.visible


func open_conversation(npc_id: String, speaker: String, player: Player) -> void:
	_player = player
	_runner = DialogueRunner.new(npc_id, player)
	_speaker.text = speaker
	_panel.visible = true
	_player.set_busy(true)
	_show_line()


## Answers with the given reply. Public so buttons, keys, and tests share one path.
func choose(index: int) -> void:
	_runner.advance(index)
	if _runner.is_finished():
		_panel.visible = false
		_player.set_busy(false)
		_player.end_conversation()
	else:
		_show_line()


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
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.offset_bottom = -BOTTOM_MARGIN
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 22)
	column.add_child(_speaker)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_text)

	_choices = VBoxContainer.new()
	column.add_child(_choices)
