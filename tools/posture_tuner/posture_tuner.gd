extends Node3D
## Shows three copies of one character side by side, playing their animation in place. Each has a
## different value of the chosen posture setting: lower than the base value, the base value, and higher.
## Every other setting has its base value in all three. Changes show at once, while they move.
## The table at the left lists every setting with its base value. Every change is saved to
## data/posture_tuning.json at once, and the game uses it.
##   Left / Right    choose the setting to compare
##   Up / Down       raise or lower its base value (with Shift: ten times as much)
##   [ / ]           make the gap between the three copies smaller or bigger
##   R               set the chosen setting back to its original value (with Shift: all settings)
##   P               print the saved values, and put them on the clipboard
##   A               change the animation: idle, walk, run
##   M               change the character
##   Q / E           turn the characters, to look at them from the front, the side, or the back
##   Z / X           move the camera closer or further away
##   Escape          quit
## Open tools/posture_tuner/posture_tuner.tscn in the editor and press F6, or run:
## godot --path . tools/posture_tuner/posture_tuner.tscn

const MODELS: Array[String] = [
	"res://assets/characters/player.glb",
	"res://assets/characters/bertram.glb",
	"res://assets/characters/brandt.glb",
	"res://assets/characters/greta.glb",
	"res://assets/characters/hedda.glb",
	"res://assets/characters/mira.glb",
]
## Name, the property of PostureModifier, how far the lower and higher copies are from the base value at a gap of x1, one step of the base value, and the limits.
const SETTINGS: Array[Dictionary] = [
	{"name": "Spine lean", "property": &"spine_lean", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Chest lean", "property": &"chest_lean", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Neck lean", "property": &"neck_lean", "unit": "°", "gap": 8.0, "step": 1.0, "min": -30.0, "max": 50.0},
	{"name": "Shoulder turn", "property": &"shoulder_turn_degrees", "unit": "°", "gap": 12.0, "step": 1.0, "min": -30.0, "max": 60.0},
	{"name": "Shoulder raise", "property": &"shoulder_raise_degrees", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 30.0},
	{"name": "Arm swing", "property": &"arm_swing_degrees", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Arm out", "property": &"arm_out_degrees", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Arm sway", "property": &"arm_sideways_damping", "unit": "", "gap": 0.25, "step": 0.05, "min": 0.0, "max": 1.0},
	{"name": "Arm twist", "property": &"arm_twist_degrees", "unit": "°", "gap": 15.0, "step": 1.0, "min": -80.0, "max": 80.0},
	{"name": "Hanging from", "property": &"hanging_from", "unit": "", "gap": 0.15, "step": 0.01, "min": 0.0, "max": 0.95},
	{"name": "Hanging to", "property": &"hanging_to", "unit": "", "gap": 0.1, "step": 0.01, "min": 0.05, "max": 1.0},
	{"name": "Hanging only", "property": &"arm_hanging_only", "unit": "", "gap": 0.5, "step": 0.1, "min": 0.0, "max": 1.0},
	{"name": "Thigh in", "property": &"thigh_in_degrees", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Thigh twist", "property": &"thigh_twist_degrees", "unit": "°", "gap": 8.0, "step": 1.0, "min": -50.0, "max": 50.0},
	{"name": "Shin in", "property": &"shin_in_degrees", "unit": "°", "gap": 6.0, "step": 1.0, "min": -30.0, "max": 40.0},
	{"name": "Foot in", "property": &"foot_in_degrees", "unit": "°", "gap": 8.0, "step": 1.0, "min": -40.0, "max": 40.0},
]
const COLUMN_NAMES: Array[String] = ["lower", "base", "higher"]
const ANIMATIONS: Array[Dictionary] = [
	{"name": "idle", "speed": 0.0},
	{"name": "walk", "speed": 2.5},
	{"name": "run", "speed": 6.0},
]
const SPACING := 1.4
const GAPS: Array[float] = [0.25, 0.5, 1.0, 1.5, 2.0, 3.0]
const COARSE := 10
const TURN_STEP := PI / 4.0
const CAMERA_HEIGHT := 1.1
const CAMERA_SHIFT := -1.1
const CAMERA_NEAREST := 2.5
const CAMERA_FURTHEST := 9.0

var _setting := 0
var _gap_index := 2
## The value of each setting, by its property.
var _base := {}
## The same, as written in PostureModifier, before any saved change.
var _game := {}
var _model_index := 0
var _animation_index := 0
var _turn := 0.0
var _distance := 5.5
var _characters: Array[CharacterModel] = []
var _captions: Array[Label3D] = []
var _camera: Camera3D
var _table: Label
var _resync := false


func _ready() -> void:
	var original := PostureModifier.new(false)
	var saved := PostureModifier.new()
	for setting in SETTINGS:
		_game[setting["property"]] = original.get(setting["property"])
		_base[setting["property"]] = saved.get(setting["property"])
	original.free()
	saved.free()
	_build_scene()
	_build_characters()
	_update_texts()


func _process(delta: float) -> void:
	var speed: float = ANIMATIONS[_animation_index]["speed"]
	for column in _characters.size():
		_characters[column].animate(speed, delta)
		_apply_values(column)
	if _resync:
		# Starts every copy at the same moment of the animation, so they can be compared.
		_resync = false
		for character in _characters:
			var player := character.find_child("Animations", true, false) as AnimationPlayer
			player.seek(0.0, true)
	_camera.position = Vector3(0.0, CAMERA_HEIGHT, -_distance)
	_camera.look_at(Vector3(0.0, CAMERA_HEIGHT - 0.1, 0.0))


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed():
		return
	var key := event as InputEventKey
	var repeatable := key.keycode in [KEY_UP, KEY_DOWN]
	if key.echo and not repeatable:
		return
	var setting := SETTINGS[_setting]
	match key.keycode:
		KEY_LEFT:
			_setting = posmod(_setting - 1, SETTINGS.size())
		KEY_RIGHT:
			_setting = posmod(_setting + 1, SETTINGS.size())
		KEY_UP:
			_change_base(setting, 1.0 * (COARSE if key.shift_pressed else 1))
		KEY_DOWN:
			_change_base(setting, -1.0 * (COARSE if key.shift_pressed else 1))
		KEY_BRACKETLEFT:
			_gap_index = maxi(_gap_index - 1, 0)
		KEY_BRACKETRIGHT:
			_gap_index = mini(_gap_index + 1, GAPS.size() - 1)
		KEY_R:
			_reset(key.shift_pressed)
		KEY_P:
			_print_values()
		KEY_A:
			_animation_index = (_animation_index + 1) % ANIMATIONS.size()
			_resync = true
		KEY_M:
			_model_index = (_model_index + 1) % MODELS.size()
			_build_characters()
		KEY_Q:
			_turn -= TURN_STEP
		KEY_E:
			_turn += TURN_STEP
		KEY_Z:
			_distance = maxf(_distance - 0.5, CAMERA_NEAREST)
		KEY_X:
			_distance = minf(_distance + 0.5, CAMERA_FURTHEST)
		KEY_ESCAPE:
			get_tree().quit()
		_:
			return
	for character in _characters:
		character.rotation.y = _turn
	_update_texts()


func _change_base(setting: Dictionary, steps: float) -> void:
	var property: StringName = setting["property"]
	_base[property] = clampf(snappedf(_base[property] + steps * setting["step"], setting["step"]), setting["min"], setting["max"])
	_save()


func _reset(everything: bool) -> void:
	if everything:
		_base = _game.duplicate()
		_save()
	else:
		var property: StringName = SETTINGS[_setting]["property"]
		_base[property] = _game[property]
	_save()


## The values that differ from the original ones, as they are written to the file.
func _changes() -> Dictionary:
	var changes := {}
	for setting in SETTINGS:
		var property: StringName = setting["property"]
		if not is_equal_approx(_base[property], _game[property]):
			changes[property] = snappedf(_base[property], 0.001)
	return changes


## Writes the file the game reads. Values back at their original are left out.
func _save() -> void:
	var file := FileAccess.open(PostureModifier.TUNING_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Can't write %s" % PostureModifier.TUNING_PATH)
		return
	file.store_string(JSON.stringify(_changes(), "\t") + "\n")


## Prints the saved values, and puts them on the clipboard.
func _print_values() -> void:
	var text := "%s\n%s" % [ProjectSettings.globalize_path(PostureModifier.TUNING_PATH), JSON.stringify(_changes(), "\t")]
	print(text)
	DisplayServer.clipboard_set(text)


## The value of a setting in one column: the base value, moved lower or higher for the chosen setting.
func _value(setting: Dictionary, column: int) -> float:
	var value: float = _base[setting["property"]]
	if setting != SETTINGS[_setting]:
		return value
	var gap: float = setting["gap"] * GAPS[_gap_index]
	return clampf(value + (column - 1) * gap, setting["min"], setting["max"])


## Posture measures the first pose it sees, so a new model starts over with fresh measurements.
func _build_characters() -> void:
	for character in _characters:
		character.queue_free()
	_characters.clear()
	for column in COLUMN_NAMES.size():
		var character := CharacterModel.new()
		character.load_model(MODELS[_model_index])
		character.position.x = (1 - column) * SPACING
		character.rotation.y = _turn
		add_child(character)
		_characters.append(character)
	_resync = true


func _apply_values(column: int) -> void:
	for setting in SETTINGS:
		_characters[column].posture.set(setting["property"], _value(setting, column))


func _update_texts() -> void:
	var lines: Array[String] = [
		"%s, %s" % [MODELS[_model_index].get_file().get_basename(), ANIMATIONS[_animation_index]["name"]],
		"",
		"%-15s %8s %8s %8s" % ["", COLUMN_NAMES[0], COLUMN_NAMES[1], COLUMN_NAMES[2]],
	]
	for index in SETTINGS.size():
		var setting := SETTINGS[index]
		var changed := not is_equal_approx(_base[setting["property"]], _game[setting["property"]])
		lines.append("%s%-14s %8s %8s %8s%s" % [
			">" if index == _setting else " ", setting["name"],
			_format(_value(setting, 0), setting), _format(_value(setting, 1), setting), _format(_value(setting, 2), setting),
			" *" if changed else "",
		])
	lines.append("")
	lines.append("* differs from the original, saved to data/posture_tuning.json")
	lines.append("Left/Right setting  Up/Down value (Shift x10)")
	lines.append("[ ] gap x%s  R reset (Shift: all)  P copy values" % GAPS[_gap_index])
	lines.append("A animation  M character  Q/E turn  Z/X zoom")
	_table.text = "\n".join(lines)
	for column in COLUMN_NAMES.size():
		_captions[column].text = "%s\n%s" % [COLUMN_NAMES[column], _format(_value(SETTINGS[_setting], column), SETTINGS[_setting])]


func _format(value: float, setting: Dictionary) -> String:
	if setting["unit"] == "":
		return "%.2f" % value
	return "%.0f%s" % [value, setting["unit"]]


func _build_scene() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.62, 0.7)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.85)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 160.0, 0.0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30.0, 30.0)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.32, 0.36, 0.3)
	ground.material_override = ground_material
	add_child(ground)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	# Moves the characters to the right, clear of the table.
	_camera.h_offset = CAMERA_SHIFT
	add_child(_camera)

	for column in COLUMN_NAMES.size():
		var caption := Label3D.new()
		caption.position = Vector3((1 - column) * SPACING, 2.05, 0.0)
		caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		caption.pixel_size = 0.004
		caption.font_size = 56
		caption.outline_size = 12
		caption.no_depth_test = true
		add_child(caption)
		_captions.append(caption)

	var layer := CanvasLayer.new()
	add_child(layer)
	_table = Label.new()
	_table.position = Vector2(16.0, 12.0)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["monospace"])
	_table.add_theme_font_override("font", font)
	_table.add_theme_font_size_override("font_size", 16)
	_table.add_theme_color_override("font_outline_color", Color.BLACK)
	_table.add_theme_constant_override("outline_size", 6)
	layer.add_child(_table)
