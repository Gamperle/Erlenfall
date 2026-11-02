class_name GameMenu
extends CanvasLayer
## The title and pause menus. The game world is paused while either is open.

signal continue_chosen
signal new_game_chosen
signal resume_chosen
signal quit_chosen
signal graphics_changed

const PANEL_WIDTH := 360.0
const ASSET_LIST_URL := "https://github.com/Gamperle/Erlenfall/blob/main/ASSETS.md"

var _panel: PanelContainer
var _title: Label
var _buttons: VBoxContainer
var _asset_note: VBoxContainer
var _message: Label
var _confirming := false
var _can_continue := false
var _settings_open := false
var _leave_settings: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open_title(can_continue: bool) -> void:
	_can_continue = can_continue
	_confirming = false
	_settings_open = false
	_title.text = tr("UI_GAME_TITLE")
	_message.visible = false
	_clear_buttons()
	if can_continue:
		_add_button("UI_CONTINUE_GAME", continue_chosen)
		_add_action("UI_NEW_GAME", _open_new_game_warning)
	else:
		_add_button("UI_NEW_GAME", new_game_chosen)
	_add_action("UI_SETTINGS", open_settings.bind(open_title.bind(can_continue)))
	_add_button("UI_QUIT", quit_chosen)
	_asset_note.visible = true
	_show()


func open_pause() -> void:
	_confirming = false
	_settings_open = false
	_title.text = tr("UI_PAUSED")
	_message.visible = false
	_clear_buttons()
	_add_button("UI_RESUME", resume_chosen)
	_add_action("UI_SETTINGS", open_settings.bind(open_pause))
	_add_button("UI_SAVE_AND_QUIT", quit_chosen)
	_asset_note.visible = false
	_show()


## Shows the options, and calls the given function to go back to the menu they were opened from.
func open_settings(leave: Callable) -> void:
	_leave_settings = leave
	_confirming = false
	_settings_open = true
	_title.text = tr("UI_SETTINGS")
	_message.visible = false
	_asset_note.visible = false
	_clear_buttons()

	var languages := OptionButton.new()
	languages.add_item(tr("UI_LANGUAGE_SYSTEM"))
	languages.add_item("English")
	languages.add_item("Deutsch")
	languages.selected = Settings.LANGUAGES.find(Settings.language)
	languages.item_selected.connect(_choose_language)
	_add_setting("UI_LANGUAGE", languages)

	var look_speed := HSlider.new()
	look_speed.min_value = Settings.MIN_LOOK_SPEED
	look_speed.max_value = Settings.MAX_LOOK_SPEED
	look_speed.step = 0.05
	look_speed.value = Settings.look_speed
	look_speed.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	look_speed.value_changed.connect(_choose_look_speed)
	_add_setting("UI_LOOK_SPEED", look_speed)

	var graphics := OptionButton.new()
	for level: String in Settings.GRAPHICS_LEVELS:
		graphics.add_item(tr(Settings.GRAPHICS_LEVELS[level]["name"]))
	graphics.selected = Settings.GRAPHICS_LEVELS.keys().find(Settings.graphics)
	graphics.item_selected.connect(_choose_graphics)
	_add_setting("UI_GRAPHICS", graphics)

	_add_action("UI_BACK", _close_settings)
	_show()


func close() -> void:
	_settings_open = false
	_panel.visible = false
	get_tree().paused = false


func _input(event: InputEvent) -> void:
	if is_open() and _settings_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		_close_settings()
		get_viewport().set_input_as_handled()
		return
	if is_open() and _confirming and event.is_action_pressed("ui_cancel"):
		open_title(_can_continue)
		get_viewport().set_input_as_handled()
		return
	if is_open() and _title.text == tr("UI_PAUSED") and event.is_action_pressed("pause"):
		resume_chosen.emit()
		get_viewport().set_input_as_handled()


## A new game overwrites the only save, so ask first. The safe choice has the focus.
func _open_new_game_warning() -> void:
	_confirming = true
	_title.text = tr("UI_NEW_GAME")
	_message.text = tr("UI_NEW_GAME_WARNING")
	_message.visible = true
	_clear_buttons()
	_add_action("UI_BACK", open_title.bind(_can_continue))
	_add_button("UI_OVERWRITE_SAVE", new_game_chosen)
	_asset_note.visible = false
	_show()


func _close_settings() -> void:
	Settings.save()
	_leave_settings.call()


func _choose_language(index: int) -> void:
	Settings.language = Settings.LANGUAGES[index]
	Settings.apply_language()
	Settings.save()
	# The options' own text was set when they were built.
	open_settings.call_deferred(_leave_settings)


func _choose_look_speed(value: float) -> void:
	Settings.look_speed = value


func _choose_graphics(index: int) -> void:
	Settings.graphics = Settings.GRAPHICS_LEVELS.keys()[index]
	Settings.save()
	graphics_changed.emit()


func _add_setting(text_key: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = tr(text_key)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_stretch_ratio = 0.8
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	_buttons.add_child(row)


func _show() -> void:
	_panel.visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_first_focusable(_buttons).grab_focus()


func _first_focusable(parent: Node) -> Control:
	var first := parent.get_child(0)
	return first.get_child(1) if first is HBoxContainer else first


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()


func _add_button(text_key: String, chosen: Signal) -> void:
	_add_action(text_key, func() -> void: chosen.emit())


func _add_action(text_key: String, action: Callable) -> void:
	var button := Button.new()
	button.text = tr(text_key)
	button.pressed.connect(action)
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

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)

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
