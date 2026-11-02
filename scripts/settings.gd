class_name Settings
extends RefCounted
## The player's options, kept apart from saved games.

const DEFAULT_PATH := "user://settings.json"
const LANGUAGES: Array[String] = ["", "en", "de"]
const GRAPHICS_LEVELS: Dictionary = {
	"low": { "name": "UI_GRAPHICS_LOW", "render_scale": 0.7, "shadows": false },
	"medium": { "name": "UI_GRAPHICS_MEDIUM", "render_scale": 0.85, "shadows": true },
	"high": { "name": "UI_GRAPHICS_HIGH", "render_scale": 1.0, "shadows": true },
}
const MIN_LOOK_SPEED := 0.25
const MAX_LOOK_SPEED := 2.5

static var path := DEFAULT_PATH
## Empty follows the system's language.
static var language := ""
static var look_speed := 1.0
static var graphics := "high"


## Reads the saved options. Anything missing or invalid keeps its default.
static func load_saved() -> void:
	language = ""
	look_speed = 1.0
	graphics = "high"
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			if data.get("language") in LANGUAGES:
				language = data["language"]
			if data.get("look_speed") is float:
				look_speed = clampf(data["look_speed"], MIN_LOOK_SPEED, MAX_LOOK_SPEED)
			if GRAPHICS_LEVELS.has(data.get("graphics")):
				graphics = data["graphics"]
	apply_language()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the settings: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({ "language": language, "look_speed": look_speed, "graphics": graphics }, "\t"))


static func apply_language() -> void:
	TranslationServer.set_locale(language if language != "" else OS.get_locale_language())


static func render_scale() -> float:
	return GRAPHICS_LEVELS[graphics]["render_scale"]


static func shadows() -> bool:
	return GRAPHICS_LEVELS[graphics]["shadows"]
