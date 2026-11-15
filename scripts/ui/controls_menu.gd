class_name ControlsMenu
extends VBoxContainer
## The Controls page of the settings: one row per action, with a button for its keyboard/mouse
## inputs and one for its gamepad inputs. Choosing a button opens the inputs of that action, where
## each can be changed or removed, another can be added, or (keyboard) Esc can be used, since
## pressing Esc while waiting for an input cancels. Changing or adding waits for the next input.

signal changed
signal back_chosen

const STICK_THRESHOLD := 0.6
## A wait for a gamepad input ends by itself after this long, since every gamepad button
## (including back) is a valid binding and a player on a gamepad alone could not cancel otherwise.
const GAMEPAD_WAIT_SECONDS := 5.0

var _action := ""
var _kind := ""
## Which of the action's inputs is being replaced, or KeyBindings.ADD.
var _index := 0
## The action and kind whose inputs are open, or "" when the list of actions shows.
var _editing_action := ""
var _editing_kind := ""
## Why the last change did not happen.
var _notice := ""
## An input that another action already uses, waiting for the player to choose swap or cancel.
var _pending: InputEvent
## The button last used, so the focus returns to it.
var _last_action := ""
var _last_kind := ""
var _status: Label
var _waited := 0.0
## Which input of the edited action the focus returns to.
var _last_index := 0


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	_rebuild()


func is_listening() -> bool:
	return _action != ""


func is_asking() -> bool:
	return _pending != null


func is_editing() -> bool:
	return _editing_action != ""


## Opens the action's inputs for one kind of device.
func edit(action: String, kind: String) -> void:
	_editing_action = action
	_editing_kind = kind
	_notice = ""
	_last_index = 0
	_rebuild()


## Back from the action's inputs to the list.
func finish_editing() -> void:
	_last_action = _editing_action
	_last_kind = _editing_kind
	_editing_action = ""
	_editing_kind = ""
	_notice = ""
	_rebuild()


## Starts waiting for an input to bind to the action. Index 0 replaces its first input (or adds
## one when it has none), another index replaces that input, and KeyBindings.ADD adds one.
func listen(action: String, kind: String, index: int = 0) -> void:
	_action = action
	_kind = kind
	_index = index
	_pending = null
	_waited = 0.0
	_notice = ""
	_rebuild()


## Uses Esc for the action being edited, as an added input.
func use_escape() -> void:
	if not is_editing() or _editing_kind != KeyBindings.KEYBOARD:
		return
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	listen(_editing_action, _editing_kind, KeyBindings.ADD)
	_submit(escape)


## Removes one of the edited action's inputs.
func remove_input(index: int) -> void:
	if is_editing() and KeyBindings.unbind(_editing_action, _editing_kind, index):
		_last_index = clampi(index, 0, maxi(KeyBindings.events_for(_editing_action, _editing_kind).size() - 1, 0))
		changed.emit()
	_rebuild()


## Gives the page an input, as if the player had just pressed it. Returns whether it was used.
func offer(event: InputEvent) -> bool:
	if _pending != null:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
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
	_submit(usable)
	return true


## Binds the input chosen for the action being listened for, asking first if it is in use.
func _submit(usable: InputEvent) -> void:
	var problem := KeyBindings.problem(_action, usable, _index)
	if problem != "":
		_notice = _problem_text(problem, usable)
		_stop()
	elif KeyBindings.conflict(_action, usable) != "":
		_pending = usable
		_rebuild()
	else:
		_apply(_action, usable, _index)
		_stop()


## Answers the question about an input that is already in use.
func answer_conflict(swap: bool) -> void:
	if _pending == null:
		return
	if swap:
		_apply(_action, _pending, _index)
	_stop()


func reset_to_defaults() -> void:
	KeyBindings.reset()
	_editing_action = ""
	_editing_kind = ""
	_stop()
	changed.emit()


func _apply(action: String, event: InputEvent, index: int) -> void:
	if KeyBindings.bind(action, event, index):
		_last_index = index if index >= 0 else KeyBindings.events_for(action, KeyBindings.kind_of(event)).size() - 1
		changed.emit()
	else:
		_notice = _problem_text(KeyBindings.problem(action, event, index), event)


func _problem_text(problem: String, event: InputEvent) -> String:
	if problem == "UI_CONTROLS_PAUSE_KEY":
		return tr(problem) % [KeyBindings.event_text(event), KeyBindings.action_name(KeyBindings.PAUSE_ACTION)]
	return tr(problem)


func _process(delta: float) -> void:
	wait(delta)


## Counts time spent waiting for a gamepad input and gives up when it runs out.
func wait(delta: float) -> void:
	if _kind != KeyBindings.GAMEPAD or _pending != null:
		return
	_waited += delta
	if _waited >= GAMEPAD_WAIT_SECONDS:
		_stop()


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
		if _kind == KeyBindings.GAMEPAD:
			_status.text = tr("UI_CONTROLS_LISTENING_PAD") % [KeyBindings.action_name(_action), roundi(GAMEPAD_WAIT_SECONDS)]
		else:
			_status.text = tr("UI_CONTROLS_LISTENING") % KeyBindings.action_name(_action)
		if is_editing():
			var cancel := Button.new()
			cancel.text = tr("UI_CONTROLS_CANCEL")
			cancel.pressed.connect(_stop)
			add_child(cancel)
			return
	if is_editing() and not is_listening():
		_build_inputs()
		return
	if _notice != "" and not is_listening():
		_status.visible = true
		_status.text = _notice
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
			button.text = tr("UI_CONTROLS_PRESS") if listening else inputs_text(action, kind)
			button.pressed.connect(edit.bind(action, kind))
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


## The page for one action's inputs of one kind: each can be changed or removed, and another added.
func _build_inputs() -> void:
	var is_keyboard := _editing_kind == KeyBindings.KEYBOARD
	_status.visible = true
	_status.text = tr("UI_CONTROLS_EDITING") % [KeyBindings.action_name(_editing_action), tr("UI_CONTROLS_KEYBOARD" if is_keyboard else "UI_CONTROLS_GAMEPAD")]
	if _notice != "":
		_status.text += "\n" + _notice
	var events := KeyBindings.events_for(_editing_action, _editing_kind)
	var focus: Control = null
	for i in events.size():
		var row := HBoxContainer.new()
		var change := Button.new()
		change.text = tr("UI_CONTROLS_CHANGE") % KeyBindings.event_text(events[i])
		change.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		change.clip_text = true
		change.pressed.connect(listen.bind(_editing_action, _editing_kind, i))
		row.add_child(change)
		var remove := Button.new()
		remove.text = tr("UI_CONTROLS_REMOVE")
		remove.disabled = not KeyBindings.can_unbind(_editing_action, _editing_kind)
		remove.pressed.connect(remove_input.bind(i))
		row.add_child(remove)
		add_child(row)
		if i == _last_index or focus == null:
			focus = change
	var add := Button.new()
	add.text = tr("UI_CONTROLS_ADD")
	add.disabled = events.size() >= KeyBindings.MAX_PER_KIND
	add.pressed.connect(listen.bind(_editing_action, _editing_kind, KeyBindings.ADD))
	add_child(add)
	if is_keyboard:
		var escape := Button.new()
		escape.text = tr("UI_CONTROLS_USE_ESC")
		escape.disabled = events.size() >= KeyBindings.MAX_PER_KIND or events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_ESCAPE)
		escape.pressed.connect(use_escape)
		add_child(escape)
	var done := Button.new()
	done.text = tr("UI_CONTROLS_DONE")
	done.pressed.connect(finish_editing)
	add_child(done)
	if focus == null:
		focus = add if not add.disabled else done
	_focus_later.call_deferred(focus)


## All of the action's inputs for the kind of device, as the list button shows them.
static func inputs_text(action: String, kind: String) -> String:
	var parts := PackedStringArray()
	for event: InputEvent in KeyBindings.events_for(action, kind):
		parts.append(KeyBindings.event_text(event))
	return ", ".join(parts) if not parts.is_empty() else "-"


func _build_conflict_question() -> void:
	var other := KeyBindings.conflict(_action, _pending)
	_status.visible = true
	var swapping := KeyBindings.is_swap(_action, _pending, _index)
	_status.text = tr("UI_CONTROLS_CONFLICT" if swapping else "UI_CONTROLS_CONFLICT_MOVE") % [KeyBindings.event_text(_pending), KeyBindings.action_name(other), KeyBindings.action_name(_action)]
	var swap := Button.new()
	swap.text = tr("UI_CONTROLS_SWAP" if swapping else "UI_CONTROLS_MOVE")
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
