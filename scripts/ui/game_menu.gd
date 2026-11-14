class_name GameMenu
extends CanvasLayer
## The title and pause menus. The game world is paused while either is open.

signal continue_chosen(path: String)
signal new_game_chosen(path: String)
signal resume_chosen
signal quit_chosen
signal graphics_changed

const PANEL_WIDTH := 420.0
const ASSET_LIST_URL := "https://github.com/Gamperle/Erlenfall/blob/main/ASSETS.md"

## The save files to offer. Set before the title menu opens.
var slot_paths: Array[String] = []

var _panel: FittedPanel
var _title: Label
var _buttons: VBoxContainer
var _asset_note: VBoxContainer
var _message: Label
var _confirming := false
var _slot_screen := false
var _settings_open := false
var _leave_settings: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open_title() -> void:
	_confirming = false
	_settings_open = false
	_slot_screen = false
	_title.text = tr("UI_GAME_TITLE")
	_message.visible = false
	_clear_buttons()
	var latest := SaveGame.latest(slot_paths)
	if latest != "":
		_add_action("UI_CONTINUE_GAME", func() -> void: continue_chosen.emit(latest))
		_add_action("UI_LOAD_GAME", _open_load_slots)
		_add_action("UI_NEW_GAME", _open_new_game_slots)
	else:
		_add_action("UI_NEW_GAME", func() -> void: new_game_chosen.emit(slot_paths[0]))
	_add_action("UI_SETTINGS", open_settings.bind(open_title))
	_add_button("UI_QUIT", quit_chosen)
	_asset_note.visible = true
	_show()


func open_pause() -> void:
	_confirming = false
	_settings_open = false
	_slot_screen = false
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
	_slot_screen = false
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
	if is_open() and (_confirming or _slot_screen) and event.is_action_pressed("ui_cancel"):
		if _confirming:
			_open_new_game_slots()
		else:
			open_title()
		get_viewport().set_input_as_handled()
		return
	if is_open() and _title.text == tr("UI_PAUSED") and event.is_action_pressed("pause"):
		resume_chosen.emit()
		get_viewport().set_input_as_handled()


func _open_load_slots() -> void:
	_open_slots("UI_LOAD_GAME")
	for i in slot_paths.size():
		var path := slot_paths[i]
		var button := _add_slot_button(i)
		button.disabled = not SaveGame.exists(path)
		button.pressed.connect(func() -> void: continue_chosen.emit(path))
	_add_action("UI_BACK", open_title)
	_show()


func _open_new_game_slots() -> void:
	_open_slots("UI_NEW_GAME")
	for i in slot_paths.size():
		var path := slot_paths[i]
		var button := _add_slot_button(i)
		if SaveGame.exists(path) or SaveGame.is_too_new(path):
			button.pressed.connect(_open_new_game_warning.bind(path))
		else:
			button.pressed.connect(func() -> void: new_game_chosen.emit(path))
	_add_action("UI_BACK", open_title)
	_show()


func _open_slots(title_key: String) -> void:
	_confirming = false
	_slot_screen = true
	_title.text = tr(title_key)
	_message.visible = false
	_asset_note.visible = false
	_clear_buttons()


func _add_slot_button(index: int) -> Button:
	var path := slot_paths[index]
	var state := tr("UI_SLOT_EMPTY")
	if SaveGame.is_too_new(path):
		state = tr("UI_SLOT_TOO_NEW")
	elif SaveGame.is_damaged(path):
		state = tr("UI_SLOT_DAMAGED_BACKUP") if SaveGame.has_backup(path) else tr("UI_SLOT_DAMAGED")
	elif SaveGame.exists(path):
		state = SaveGame.saved_at_text(path)
	var button := Button.new()
	button.text = tr("UI_SLOT") % [index + 1, state]
	_buttons.add_child(button)
	return button


## Starting over in a used slot overwrites it, so ask first. The safe choice has the focus.
func _open_new_game_warning(path: String) -> void:
	_confirming = true
	_slot_screen = false
	_title.text = tr("UI_NEW_GAME")
	_message.text = tr("UI_NEW_GAME_WARNING")
	_message.visible = true
	_clear_buttons()
	_add_action("UI_BACK", _open_new_game_slots)
	_add_action("UI_OVERWRITE_SAVE", func() -> void: new_game_chosen.emit(path))
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
	for child in parent.get_children():
		var control: Control = child.get_child(1) if child is HBoxContainer else child
		if not (control is Button and control.disabled):
			return control
	return parent.get_child(0)


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
	_panel = FittedPanel.new(PANEL_WIDTH)
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_panel)

	var column := _panel.content
	column.add_theme_constant_override("separation", 12)

	_title = Label.new()
	_title.theme_type_variation = &"TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	column.add_child(HSeparator.new())

	_message = Label.new()
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_message)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	column.add_child(_buttons)

	_asset_note = VBoxContainer.new()
	column.add_child(_asset_note)

	# Set as keys, so that these follow a change of language on their own.
	var note := Label.new()
	note.text = "UI_AI_ASSETS_NOTE"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_asset_note.add_child(note)

	var link := LinkButton.new()
	link.text = "UI_AI_ASSETS_LINK"
	link.uri = ASSET_LIST_URL
	link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_asset_note.add_child(link)
