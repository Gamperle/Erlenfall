class_name KeyBindings
extends RefCounted
## The player's keyboard/mouse and gamepad bindings for every action. Each action has one
## keyboard (or mouse) input and one gamepad input. The Input Map in project.godot holds the
## defaults, and the player's changes are kept in the settings file.

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
const MOUSE_NAMES: Dictionary = { 1: "UI_MOUSE_LEFT", 2: "UI_MOUSE_RIGHT", 3: "UI_MOUSE_MIDDLE" }

## What each action is bound to: { action: { "keyboard": InputEvent or null, "gamepad": InputEvent or null } }.
static var _defaults: Dictionary = {}
static var _current: Dictionary = {}


## The input an action has in the given slot, or null when it has none.
static func event_for(action: String, kind: String) -> InputEvent:
	_ensure_loaded()
	return _current[action][kind]


static func default_event_for(action: String, kind: String) -> InputEvent:
	_ensure_loaded()
	return _defaults[action][kind]


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
		if other != action and same(_current[other][kind], event):
			return other
	return ""


## Binds the input. If another action uses it, that action gets what this one had (a swap).
static func bind(action: String, event: InputEvent) -> void:
	_ensure_loaded()
	var kind := kind_of(event)
	if kind == "":
		return
	var other := conflict(action, event)
	if other != "":
		_current[other][kind] = _current[action][kind]
	_current[action][kind] = event
	apply()


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
			var event: InputEvent = _current[action][kind]
			if event != null:
				InputMap.action_add_event(action, event)


## The bindings as plain data for the settings file.
static func to_data() -> Dictionary:
	_ensure_loaded()
	var data := {}
	for action in ACTIONS:
		data[action] = {}
		for kind in KINDS:
			data[action][kind] = _event_to_data(_current[action][kind])
	return data


## Reads saved bindings. Anything missing or invalid keeps its default, and if two actions end up
## sharing an input the defaults are restored, since the Controls page never allows that.
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
				if saved[kind] == null:
					_current[action][kind] = null
					continue
				var event := _event_from_data(saved[kind], kind)
				if event != null:
					_current[action][kind] = event
	if _has_duplicates():
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
		_defaults[action] = { KEYBOARD: null, GAMEPAD: null }
		if not InputMap.has_action(action):
			continue
		for event in InputMap.action_get_events(action):
			var kind := kind_of(event)
			if kind != "" and _defaults[action][kind] == null:
				_defaults[action][kind] = _normalized(event)
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
		copy[action] = { KEYBOARD: bindings[action][KEYBOARD], GAMEPAD: bindings[action][GAMEPAD] }
	return copy


static func _has_duplicates() -> bool:
	for kind in KINDS:
		var seen: Array[InputEvent] = []
		for action in ACTIONS:
			var event: InputEvent = _current[action][kind]
			if event == null:
				continue
			for other in seen:
				if same(other, event):
					return true
			seen.append(event)
	return false


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
