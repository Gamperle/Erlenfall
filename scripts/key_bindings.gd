class_name KeyBindings
extends RefCounted
## The player's keyboard/mouse and gamepad bindings for every action. Each action has up to
## MAX_PER_KIND keyboard/mouse inputs (keys, mouse buttons and the mouse wheel) and up to as many
## gamepad inputs. The first of each is the one shown in prompts. The Input Map in project.godot
## holds the defaults (one input of each kind), and the player's changes are kept in the settings
## file.
##
## Esc: it can be bound to a gameplay action, but the pause menu must always keep a keyboard key
## (Esc itself, or another one). Esc always closes menus and screens, whatever it is bound to,
## and while a binding is being chosen it cancels. The Controls page has an explicit "Use Esc"
## button, since pressing Esc there cancels.

const KEYBOARD := "keyboard"
const GAMEPAD := "gamepad"
const KINDS: Array[String] = [KEYBOARD, GAMEPAD]
## Every action that can be remapped, in the order the Controls page lists them.
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "look_up", "look_down", "look_left", "look_right",
	"jump", "sprint", "sneak", "dodge", "attack", "block", "shoot", "throw",
	"interact", "inventory", "toggle_torch", "toggle_camera", "fast_forward_time", "map", "journal", "pause",
]
const MAX_KEY := 0x7FFFFFFF
const MAX_MOUSE_BUTTON := 9
## How many inputs one action can have for each kind of device.
const MAX_PER_KIND := 3
## The index that adds an input instead of replacing one.
const ADD := -1
const MAX_JOY_BUTTON := 20
const MAX_JOY_AXIS := 5
const JOY_DPAD_UP_INDEX := 11
## Which action and text to show for each entry of the on-screen controls line.
const HINTS: Array = [
	["move_forward", "UI_HINT_WALK"], ["look_left", "UI_HINT_LOOK"], ["sprint", "UI_HINT_SPRINT"],
	["sneak", "UI_HINT_SNEAK"], ["jump", "UI_HINT_JUMP"], ["attack", "UI_HINT_ATTACK"],
	["block", "UI_HINT_BLOCK"], ["dodge", "UI_HINT_DODGE"], ["interact", "UI_HINT_USE"],
	["inventory", "UI_HINT_INVENTORY"], ["toggle_camera", "UI_HINT_CAMERA"], ["toggle_torch", "UI_HINT_TORCH"],
	["fast_forward_time", "UI_HINT_TIME"], ["shoot", "UI_HINT_SHOOT"], ["throw", "UI_HINT_THROW"],
	["map", "UI_HINT_MAP"], ["journal", "UI_HINT_JOURNAL"], ["pause", "UI_HINT_MENU"],
]
const JOY_BUTTON_NAMES: Array[String] = ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB"]
const JOY_DPAD_KEYS: Array[String] = ["UI_PAD_UP", "UI_PAD_DOWN", "UI_PAD_LEFT", "UI_PAD_RIGHT"]
## Translation keys for the keys whose name differs between the languages.
const KEY_NAMES: Dictionary = {
	KEY_SPACE: "UI_KEY_SPACE", KEY_SHIFT: "UI_KEY_SHIFT", KEY_CTRL: "UI_KEY_CTRL", KEY_ESCAPE: "UI_KEY_ESCAPE",
}
const MOUSE_NAMES: Dictionary = {
	1: "UI_MOUSE_LEFT", 2: "UI_MOUSE_RIGHT", 3: "UI_MOUSE_MIDDLE",
	MOUSE_BUTTON_WHEEL_UP: "UI_MOUSE_WHEEL_UP", MOUSE_BUTTON_WHEEL_DOWN: "UI_MOUSE_WHEEL_DOWN",
	MOUSE_BUTTON_WHEEL_LEFT: "UI_MOUSE_WHEEL_LEFT", MOUSE_BUTTON_WHEEL_RIGHT: "UI_MOUSE_WHEEL_RIGHT",
}
## The action that must keep a keyboard key, so the player can always open the pause menu.
const PAUSE_ACTION := "pause"

## What each action is bound to: { action: { "keyboard": Array of InputEvent, "gamepad": Array of InputEvent } }.
static var _defaults: Dictionary = {}
static var _current: Dictionary = {}


## The first input an action has for the kind of device (the one prompts show), or null.
static func event_for(action: String, kind: String) -> InputEvent:
	_ensure_loaded()
	var list: Array = _current[action][kind]
	return list[0] if not list.is_empty() else null


## Every input an action has for the kind of device, in order.
static func events_for(action: String, kind: String) -> Array:
	_ensure_loaded()
	return _current[action][kind].duplicate()


static func default_event_for(action: String, kind: String) -> InputEvent:
	_ensure_loaded()
	var list: Array = _defaults[action][kind]
	return list[0] if not list.is_empty() else null


## Which kind of slot an input belongs in, or "" when it can't be bound.
static func kind_of(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton:
		return KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return GAMEPAD
	return ""


static func same(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null or a.get_class() != b.get_class():
		return false
	if a is InputEventKey:
		return a.physical_keycode == b.physical_keycode
	if a is InputEventMouseButton or a is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


## The other action that already uses this input in the same kind of slot, or "".
static func conflict(action: String, event: InputEvent) -> String:
	_ensure_loaded()
	var kind := kind_of(event)
	if kind == "":
		return ""
	for other in ACTIONS:
		if other != action and _index_in(_current[other][kind], event) >= 0:
			return other
	return ""


## Whether binding the input at the index would give the other action that uses it the input
## being replaced (a swap). When adding, the other action just loses it.
static func is_swap(action: String, event: InputEvent, index: int) -> bool:
	_ensure_loaded()
	var list: Array = _current[action][kind_of(event)]
	return index >= 0 and index < list.size() and conflict(action, event) != ""


## "" when the input can be bound, otherwise the translation key of why it can't (the pause menu
## would be left without a keyboard key, or the action has no room for another input).
static func problem(action: String, event: InputEvent, index: int = 0) -> String:
	_ensure_loaded()
	if kind_of(event) == "":
		return "UI_CONTROLS_FULL"
	var next := _copy(_current)
	return _place(next, action, event, index)


## Binds the input. Index 0 (the default) replaces the action's first input of that kind, or
## adds one when it has none; a larger index replaces that one; ADD adds another. If another
## action uses the input it loses it: it gets the input that was replaced (a swap) when there was
## one. Returns whether it was bound (see problem).
static func bind(action: String, event: InputEvent, index: int = 0) -> bool:
	_ensure_loaded()
	if kind_of(event) == "":
		return false
	var next := _copy(_current)
	if _place(next, action, event, index) != "":
		return false
	_current = next
	apply()
	return true


## Removes one of the action's inputs. The pause menu keeps its last keyboard key. Returns
## whether something was removed.
static func unbind(action: String, kind: String, index: int) -> bool:
	_ensure_loaded()
	var list: Array = _current[action][kind]
	if index < 0 or index >= list.size() or not can_unbind(action, kind):
		return false
	list.remove_at(index)
	apply()
	return true


## Whether an input of the action can be removed (the pause menu keeps one keyboard key).
static func can_unbind(action: String, kind: String) -> bool:
	_ensure_loaded()
	return not (action == PAUSE_ACTION and kind == KEYBOARD and _current[action][kind].size() <= 1)


static func reset() -> void:
	_ensure_loaded()
	_current = _copy(_defaults)
	apply()


## Makes the Input Map match the bindings.
static func apply() -> void:
	_ensure_loaded()
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		InputMap.action_erase_events(action)
		for kind in KINDS:
			for event: InputEvent in _current[action][kind]:
				InputMap.action_add_event(action, event)


## The bindings as plain data for the settings file.
static func to_data() -> Dictionary:
	_ensure_loaded()
	var data := {}
	for action in ACTIONS:
		data[action] = {}
		for kind in KINDS:
			var list: Array = []
			for event: InputEvent in _current[action][kind]:
				list.append(_event_to_data(event))
			data[action][kind] = list
	return data


## Reads saved bindings. Each kind is a list of inputs, or (older files) a single input or null
## for none. Anything missing or invalid keeps its default, an invalid input in a list is skipped,
## and if two actions end up sharing an input, or the pause menu has no keyboard key, the
## defaults are restored, since the Controls page never allows that.
static func load_data(data: Variant) -> void:
	_ensure_loaded()
	_current = _copy(_defaults)
	if data is Dictionary:
		for action in ACTIONS:
			var saved: Variant = data.get(action)
			if not saved is Dictionary:
				continue
			for kind in KINDS:
				if not saved.has(kind):
					continue
				var loaded: Variant = _list_from_data(saved[kind], kind)
				if loaded != null:
					_current[action][kind] = loaded
	if _has_duplicates() or not _valid(_current):
		_current = _copy(_defaults)
	apply()


## Short text for an input, such as "Space", "Left click", "LB" or "Left stick up".
static func event_text(event: InputEvent) -> String:
	if event == null:
		return "-"
	if event is InputEventKey:
		var key: Key = event.physical_keycode
		# Shows the letter the key has on the player's layout, when the system can tell.
		if DisplayServer.get_name() != "headless":
			key = DisplayServer.keyboard_get_keycode_from_physical(key)
		if KEY_NAMES.has(key):
			return TranslationServer.translate(KEY_NAMES[key])
		return OS.get_keycode_string(key)
	if event is InputEventMouseButton:
		if MOUSE_NAMES.has(event.button_index):
			return TranslationServer.translate(MOUSE_NAMES[event.button_index])
		return TranslationServer.translate("UI_MOUSE_OTHER") % event.button_index
	if event is InputEventJoypadButton:
		var index: int = event.button_index
		if index < JOY_BUTTON_NAMES.size():
			return JOY_BUTTON_NAMES[index]
		if index >= JOY_DPAD_UP_INDEX and index - JOY_DPAD_UP_INDEX < JOY_DPAD_KEYS.size():
			return TranslationServer.translate(JOY_DPAD_KEYS[index - JOY_DPAD_UP_INDEX])
		return TranslationServer.translate("UI_PAD_BUTTON") % index
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		if event.axis == JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
		var direction := ["UI_PAD_LEFT", "UI_PAD_RIGHT"] if event.axis % 2 == 0 else ["UI_PAD_UP", "UI_PAD_DOWN"]
		return "%s %s" % [stick_text(event), TranslationServer.translate(direction[0 if event.axis_value < 0.0 else 1])]
	return "-"


## "Left stick" or "Right stick" for a stick input, otherwise the usual text.
static func stick_text(event: InputEvent) -> String:
	if event is InputEventJoypadMotion and event.axis <= JOY_AXIS_RIGHT_Y:
		return TranslationServer.translate("UI_STICK_LEFT" if event.axis <= JOY_AXIS_LEFT_Y else "UI_STICK_RIGHT")
	return event_text(event)


## The action's inputs for display: only the active device's ("E" or "X"), or both ("E / X")
## when the device_prompts flag is off.
static func label_for(action: String) -> String:
	var parts := PackedStringArray()
	for kind in InputDevice.shown_kinds():
		var event := event_for(action, kind)
		if event != null:
			parts.append(event_text(event))
	return " / ".join(parts) if not parts.is_empty() else "-"


static func action_name(action: String) -> String:
	return TranslationServer.translate("ACTION_" + action.to_upper())


## The line of on-screen control hints, built from the current bindings.
static func controls_hint() -> String:
	var entries := PackedStringArray()
	for hint: Array in HINTS:
		entries.append("%s: %s" % [_hint_inputs(hint[0]), TranslationServer.translate(hint[1])])
	return "   ".join(entries)


## Like label_for, as segments for a PromptLine: glyph specs for the inputs and " / " between them.
static func segments_for(action: String) -> Array:
	var segments: Array = []
	for kind in InputDevice.shown_kinds():
		var event := event_for(action, kind)
		if event != null:
			if not segments.is_empty():
				segments.append(" / ")
			segments.append(InputGlyph.spec_for(event))
	return segments if not segments.is_empty() else ["-"]


## Like controls_hint, as segments for a PromptLine. Its plain text is the same as controls_hint.
static func controls_segments() -> Array:
	var segments: Array = []
	for i in HINTS.size():
		if i > 0:
			segments.append("   ")
		segments.append_array(_hint_segments(HINTS[i][0]))
		segments.append(": %s" % TranslationServer.translate(HINTS[i][1]))
	return segments


static func _hint_segments(action: String) -> Array:
	if action != "move_forward" and action != "look_left":
		return segments_for(action)
	var segments: Array = []
	var pad_action := "move_left" if action == "move_forward" else "look_left"
	for kind in InputDevice.shown_kinds():
		if kind == KEYBOARD:
			if not segments.is_empty():
				segments.append(" / ")
			if action == "move_forward":
				segments.append_array(_walk_segments())
			else:
				segments.append({ "shape": "key", "text": TranslationServer.translate("UI_MOUSE") })
		elif event_for(pad_action, GAMEPAD) != null:
			if not segments.is_empty():
				segments.append(" / ")
			segments.append(InputGlyph.stick_spec(event_for(pad_action, GAMEPAD)))
	return segments if not segments.is_empty() else ["-"]


static func _walk_segments() -> Array:
	var segments: Array = []
	var keys := PackedStringArray()
	for part in ["move_forward", "move_left", "move_back", "move_right"]:
		keys.append(event_text(event_for(part, KEYBOARD)))
	var joined := _all_single_characters(keys)
	for part in ["move_forward", "move_left", "move_back", "move_right"]:
		if not segments.is_empty() and not joined:
			segments.append("/")
		segments.append(InputGlyph.spec_for(event_for(part, KEYBOARD)))
	return segments


static func _hint_inputs(action: String) -> String:
	if action == "move_forward" or action == "look_left":
		var parts := PackedStringArray()
		var pad_action := "move_left" if action == "move_forward" else "look_left"
		for kind in InputDevice.shown_kinds():
			if kind == KEYBOARD:
				parts.append(_walk_keys() if action == "move_forward" else TranslationServer.translate("UI_MOUSE"))
			elif event_for(pad_action, GAMEPAD) != null:
				parts.append(stick_text(event_for(pad_action, GAMEPAD)))
		return " / ".join(parts) if not parts.is_empty() else "-"
	return label_for(action)


static func _walk_keys() -> String:
	var keys := PackedStringArray()
	for part in ["move_forward", "move_left", "move_back", "move_right"]:
		keys.append(event_text(event_for(part, KEYBOARD)))
	return "".join(keys) if _all_single_characters(keys) else "/".join(keys)


static func _all_single_characters(texts: PackedStringArray) -> bool:
	for text in texts:
		if text.length() != 1:
			return false
	return true


static func _ensure_loaded() -> void:
	if not _defaults.is_empty():
		return
	for action in ACTIONS:
		_defaults[action] = { KEYBOARD: [], GAMEPAD: [] }
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var kind := kind_of(event)
			if kind != "" and _defaults[action][kind].is_empty():
				_defaults[action][kind].append(_normalized(event))
	_current = _copy(_defaults)


## A fresh input with only what matters for matching, so a key works whatever the layout.
static func _normalized(event: InputEvent) -> InputEvent:
	if event is InputEventKey:
		var key := InputEventKey.new()
		key.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return key
	return event.duplicate()


static func _copy(bindings: Dictionary) -> Dictionary:
	var copy := {}
	for action: String in bindings:
		copy[action] = { KEYBOARD: bindings[action][KEYBOARD].duplicate(), GAMEPAD: bindings[action][GAMEPAD].duplicate() }
	return copy


static func _has_duplicates() -> bool:
	for kind in KINDS:
		var seen: Array = []
		for action in ACTIONS:
			for event: InputEvent in _current[action][kind]:
				if _index_in(seen, event) >= 0:
					return true
				seen.append(event)
	return false


## Whether the bindings follow the rules: not too many inputs, and a keyboard key for pause.
static func _valid(bindings: Dictionary) -> bool:
	for action in ACTIONS:
		for kind in KINDS:
			if bindings[action][kind].size() > MAX_PER_KIND:
				return false
	return not bindings[PAUSE_ACTION][KEYBOARD].is_empty()


static func _index_in(list: Array, event: InputEvent) -> int:
	for i in list.size():
		if same(list[i], event):
			return i
	return -1


## Puts the input into the bindings (a copy being tried). Returns "" or why it can't be done.
static func _place(bindings: Dictionary, action: String, event: InputEvent, index: int) -> String:
	var kind := kind_of(event)
	var list: Array = bindings[action][kind]
	var own := _index_in(list, event)
	if own >= 0 and (index == own or index == ADD or (index == 0 and list.size() == 1)):
		return ""
	var old: InputEvent = list[index] if index >= 0 and index < list.size() else null
	if own >= 0:
		list.remove_at(own)
		if index > own:
			index -= 1
	for other in ACTIONS:
		if other == action:
			continue
		var other_list: Array = bindings[other][kind]
		var found := _index_in(other_list, event)
		if found >= 0:
			if old != null and _index_in(other_list, old) < 0:
				other_list[found] = old
			else:
				other_list.remove_at(found)
	if index >= 0 and index < list.size():
		list[index] = event
	else:
		list.append(event)
	if list.size() > MAX_PER_KIND:
		return "UI_CONTROLS_FULL"
	if not _valid(bindings):
		return "UI_CONTROLS_PAUSE_KEY"
	return ""


static func _event_to_data(event: InputEvent) -> Variant:
	if event is InputEventKey:
		return { "type": "key", "code": event.physical_keycode }
	if event is InputEventMouseButton:
		return { "type": "mouse", "button": event.button_index }
	if event is InputEventJoypadButton:
		return { "type": "pad_button", "button": event.button_index }
	if event is InputEventJoypadMotion:
		return { "type": "pad_axis", "axis": event.axis, "direction": 1 if event.axis_value >= 0.0 else -1 }
	return null


## The inputs from saved data, or null when none of it is usable (so the default stays).
static func _list_from_data(saved: Variant, kind: String) -> Variant:
	if saved == null:
		return []
	var entries: Array = saved if saved is Array else [saved]
	if entries.is_empty():
		return []
	var list: Array = []
	for entry: Variant in entries:
		var event := _event_from_data(entry, kind)
		if event != null and _index_in(list, event) < 0 and list.size() < MAX_PER_KIND:
			list.append(event)
	return list if not list.is_empty() else null


static func _event_from_data(data: Variant, kind: String) -> InputEvent:
	if not data is Dictionary:
		return null
	var type: Variant = data.get("type")
	if kind == KEYBOARD and type == "key":
		var code := _whole_number(data.get("code"), 1, MAX_KEY)
		if code > 0:
			var key := InputEventKey.new()
			key.physical_keycode = code as Key
			return key
	elif kind == KEYBOARD and type == "mouse":
		var button := _whole_number(data.get("button"), 1, MAX_MOUSE_BUTTON)
		if button > 0:
			var click := InputEventMouseButton.new()
			click.button_index = button as MouseButton
			return click
	elif kind == GAMEPAD and type == "pad_button":
		var index := _whole_number(data.get("button"), 0, MAX_JOY_BUTTON)
		if index >= 0:
			var pad_button := InputEventJoypadButton.new()
			pad_button.button_index = index as JoyButton
			return pad_button
	elif kind == GAMEPAD and type == "pad_axis":
		var axis := _whole_number(data.get("axis"), 0, MAX_JOY_AXIS)
		var direction := _whole_number(data.get("direction"), -1, 1)
		if axis >= 0 and (direction == 1 or direction == -1):
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis as JoyAxis
			motion.axis_value = float(direction)
			return motion
	return null


## The value as an int when it is a whole number in range, otherwise -2 (below any valid minimum).
static func _whole_number(value: Variant, low: int, high: int) -> int:
	if (value is int or value is float) and is_equal_approx(float(value), roundf(float(value))):
		var number := int(value)
		if number >= low and number <= high:
			return number
	return -2
