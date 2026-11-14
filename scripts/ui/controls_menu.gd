class_name ControlsMenu
extends VBoxContainer
## The Controls page of the settings: one row per action, with a button for its keyboard/mouse
## input and one for its gamepad input. Choosing a button waits for the next input.

signal changed
signal back_chosen

const STICK_THRESHOLD := 0.6

var _action := ""
var _kind := ""
## An input that another action already uses, waiting for the player to choose swap or cancel.
var _pending: InputEvent
## The button last used, so the focus returns to it.
var _last_action := ""
var _last_kind := ""
var _status: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild()


func is_listening() -> bool:
	return _action != ""


func is_asking() -> bool:
	return _pending != null


## Starts waiting for an input to bind to the action.
func listen(action: String, kind: String) -> void:
	_action = action
	_kind = kind
	_pending = null
	_rebuild()


## Gives the page an input, as if the player had just pressed it. Returns whether it was used.
func offer(event: InputEvent) -> bool:
	if _pending != null:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
			answer_conflict(false)
			return true
		return false
	if not is_listening():
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_stop()
		return true
	var usable: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		usable = InputEventKey.new()
		usable.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	elif event is InputEventMouseButton and event.pressed:
		usable = InputEventMouseButton.new()
		usable.button_index = event.button_index
	elif event is InputEventJoypadButton and event.pressed:
		usable = InputEventJoypadButton.new()
		usable.button_index = event.button_index
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= STICK_THRESHOLD:
		usable = InputEventJoypadMotion.new()
		usable.axis = event.axis
		usable.axis_value = signf(event.axis_value)
	if usable == null or KeyBindings.kind_of(usable) != _kind:
		return usable != null or event is InputEventKey or event is InputEventMouseButton
	if KeyBindings.conflict(_action, usable) != "":
		_pending = usable
		_rebuild()
	else:
		KeyBindings.bind(_action, usable)
		_stop()
		changed.emit()
	return true


## Answers the question about an input that is already in use.
func answer_conflict(swap: bool) -> void:
	if _pending == null:
		return
	if swap:
		KeyBindings.bind(_action, _pending)
		changed.emit()
	_stop()


func reset_to_defaults() -> void:
	KeyBindings.reset()
	_stop()
	changed.emit()


func _input(event: InputEvent) -> void:
	if is_listening() and is_visible_in_tree() and offer(event):
		get_viewport().set_input_as_handled()


func _stop() -> void:
	_last_action = _action
	_last_kind = _kind
	_action = ""
	_kind = ""
	_pending = null
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.visible = false
	add_child(_status)
	if _pending != null:
		_build_conflict_question()
		return
	if is_listening():
		_status.visible = true
		_status.text = tr("UI_CONTROLS_LISTENING") % KeyBindings.action_name(_action)
	var focus: Control = null
	for action in KeyBindings.ACTIONS:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = KeyBindings.action_name(action)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_stretch_ratio = 0.8
		row.add_child(label)
		for kind in KeyBindings.KINDS:
			var button := Button.new()
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			var listening := action == _action and kind == _kind
			button.text = tr("UI_CONTROLS_PRESS") if listening else KeyBindings.event_text(KeyBindings.event_for(action, kind))
			button.pressed.connect(listen.bind(action, kind))
			button.tooltip_text = tr("UI_CONTROLS_KEYBOARD") if kind == KeyBindings.KEYBOARD else tr("UI_CONTROLS_GAMEPAD")
			row.add_child(button)
			if listening or (action == _last_action and kind == _last_kind) or (focus == null and _last_action == ""):
				focus = button
		add_child(row)
	var reset := Button.new()
	reset.text = tr("UI_CONTROLS_RESET")
	reset.pressed.connect(reset_to_defaults)
	add_child(reset)
	var back := Button.new()
	back.text = tr("UI_BACK")
	back.pressed.connect(back_chosen.emit)
	add_child(back)
	if focus != null:
		_focus_later.call_deferred(focus)


func _build_conflict_question() -> void:
	var other := KeyBindings.conflict(_action, _pending)
	_status.visible = true
	_status.text = tr("UI_CONTROLS_CONFLICT") % [KeyBindings.event_text(_pending), KeyBindings.action_name(other), KeyBindings.action_name(_action)]
	var swap := Button.new()
	swap.text = tr("UI_CONTROLS_SWAP")
	swap.pressed.connect(answer_conflict.bind(true))
	add_child(swap)
	var cancel := Button.new()
	cancel.text = tr("UI_CONTROLS_CANCEL")
	cancel.pressed.connect(answer_conflict.bind(false))
	add_child(cancel)
	_focus_later.call_deferred(cancel)


func _focus_later(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		control.grab_focus()
