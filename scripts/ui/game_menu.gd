class_name GameMenu
extends CanvasLayer
## The title and pause menus. The game world is paused while either is open.

signal continue_chosen
signal new_game_chosen
signal resume_chosen
signal quit_chosen

const PANEL_WIDTH := 360.0
const ASSET_LIST_URL := "https://github.com/Gamperle/Erlenfall/blob/main/ASSETS.md"

var _panel: PanelContainer
var _title: Label
var _buttons: VBoxContainer
var _asset_note: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open_title(can_continue: bool) -> void:
	_title.text = tr("UI_GAME_TITLE")
	_clear_buttons()
	if can_continue:
		_add_button("UI_CONTINUE_GAME", continue_chosen)
	_add_button("UI_NEW_GAME", new_game_chosen)
	_add_button("UI_QUIT", quit_chosen)
	_asset_note.visible = true
	_show()


func open_pause() -> void:
	_title.text = tr("UI_PAUSED")
	_clear_buttons()
	_add_button("UI_RESUME", resume_chosen)
	_add_button("UI_SAVE_AND_QUIT", quit_chosen)
	_asset_note.visible = false
	_show()


func close() -> void:
	_panel.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if is_open() and _title.text == tr("UI_PAUSED") and event.is_action_pressed("pause"):
		resume_chosen.emit()
		get_viewport().set_input_as_handled()


func _show() -> void:
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_buttons.get_child(0).grab_focus()


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _add_button(text_key: String, chosen: Signal) -> void:
	var button := Button.new()
	button.text = tr(text_key)
	button.pressed.connect(func() -> void: chosen.emit())
	_buttons.add_child(button)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size.x = PANEL_WIDTH
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	column.add_child(_buttons)

	_asset_note = VBoxContainer.new()
	column.add_child(_asset_note)

	var note := Label.new()
	note.text = tr("UI_AI_ASSETS_NOTE")
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_asset_note.add_child(note)

	var link := LinkButton.new()
	link.text = tr("UI_AI_ASSETS_LINK")
	link.uri = ASSET_LIST_URL
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_asset_note.add_child(link)
