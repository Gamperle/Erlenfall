class_name InputDevice
extends Node
## Tracks whether the player last used the keyboard and mouse or a gamepad, so prompts can show
## only the matching inputs. Add one to the scene; everything else reads the static state.

signal changed(kind: String)

const AXIS_THRESHOLD := 0.5
## Nodes in this group have a refresh_prompts() that rebuilds text showing inputs.
const PROMPT_GROUP := "device_prompt_users"

## KeyBindings.KEYBOARD or KeyBindings.GAMEPAD.
static var active: String = KeyBindings.KEYBOARD


## The kinds of input to show in prompts: only the active device, or both when the feature is off.
static func shown_kinds() -> Array[String]:
	if FeatureFlags.enabled("device_prompts"):
		return [active]
	return KeyBindings.KINDS


## Which device an input event shows the player is using, or "" when it says nothing.
static func kind_for_event(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		return KeyBindings.GAMEPAD if absf(event.axis_value) >= AXIS_THRESHOLD else ""
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		return KeyBindings.kind_of(event) if event.is_pressed() else ""
	if event is InputEventMouseMotion:
		return KeyBindings.KEYBOARD if event.relative.length() > 0.0 else ""
	return ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var kind := kind_for_event(event)
	if kind != "":
		use(kind)


## Marks a device as the active one. Public so tests share the path.
func use(kind: String) -> void:
	if kind == active:
		return
	active = kind
	changed.emit(kind)
	if is_inside_tree():
		get_tree().call_group(PROMPT_GROUP, "refresh_prompts")
