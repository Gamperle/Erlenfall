class_name Settings
extends RefCounted
## The player's options, kept apart from saved games.

const DEFAULT_PATH := "user://settings.json"
const LANGUAGES: Array[String] = ["", "en", "de"]
const GRAPHICS_LEVELS: Dictionary = {
	"low": { "name": "UI_GRAPHICS_LOW", "render_scale": 0.7, "shadows": false, "water_ripples": 0, "ambient_occlusion": false },
	"medium": { "name": "UI_GRAPHICS_MEDIUM", "render_scale": 0.85, "shadows": true, "water_ripples": 4, "shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS, "ambient_occlusion": false },
	"high": { "name": "UI_GRAPHICS_HIGH", "render_scale": 1.0, "shadows": true, "water_ripples": 8, "shadow_splits": DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "ambient_occlusion": true },
}
## Text size choices, as a share of the normal size.
const TEXT_SIZES: Array[float] = [1.0, 1.25, 1.5, 2.0]
const BASE_FONT_SIZE := 17
const BASE_TITLE_FONT_SIZE := 32
const MIN_DIALOGUE_OPACITY := 0.3
const MIN_LOOK_SPEED := 0.25
const MAX_LOOK_SPEED := 2.5
const DEFAULT_VOLUME := 0.8

static var path := DEFAULT_PATH
## Empty follows the system's language.
static var language := ""
static var look_speed := 1.0
static var graphics := "high"
static var text_size := 1.0
## How solid the dialogue panel's frame is, from MIN_DIALOGUE_OPACITY to 1.
static var dialogue_opacity := 1.0
## Volume per audio bus (see AudioBuses), from 0 to 1.
static var volumes: Dictionary = default_volumes()


## Reads the saved options. Anything missing or invalid keeps its default.
static func load_saved() -> void:
	language = ""
	look_speed = 1.0
	graphics = "high"
	text_size = 1.0
	dialogue_opacity = 1.0
	volumes = default_volumes()
	if FileAccess.file_exists(path):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			if data.get("language") in LANGUAGES:
				language = data["language"]
			if data.get("look_speed") is float:
				look_speed = clampf(data["look_speed"], MIN_LOOK_SPEED, MAX_LOOK_SPEED)
			if GRAPHICS_LEVELS.has(data.get("graphics")):
				graphics = data["graphics"]
			if data.get("text_size") is float and TEXT_SIZES.has(data["text_size"]):
				text_size = data["text_size"]
			if data.get("dialogue_opacity") is float:
				dialogue_opacity = clampf(data["dialogue_opacity"], MIN_DIALOGUE_OPACITY, 1.0)
			var saved_volumes: Variant = data.get("volumes")
			if saved_volumes is Dictionary:
				for bus_name: String in AudioBuses.ALL:
					var value: Variant = saved_volumes.get(bus_name)
					if (value is float or value is int) and is_finite(value):
						volumes[bus_name] = clampf(value, 0.0, 1.0)
	apply_language()
	apply_volumes()
	apply_text_size()


static func save() -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the settings: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"language": language, "look_speed": look_speed, "graphics": graphics,
		"text_size": text_size, "dialogue_opacity": dialogue_opacity,
		"volumes": volumes,
	}, "\t"))


static func default_volumes() -> Dictionary:
	var result := {}
	for bus_name: String in AudioBuses.ALL:
		result[bus_name] = DEFAULT_VOLUME
	return result


static func set_volume(bus_name: String, value: float) -> void:
	volumes[bus_name] = clampf(value, 0.0, 1.0)
	AudioBuses.set_volume(bus_name, volumes[bus_name])


static func apply_volumes() -> void:
	for bus_name: String in AudioBuses.ALL:
		AudioBuses.set_volume(bus_name, volumes[bus_name])


static func apply_language() -> void:
	TranslationServer.set_locale(language if language != "" else OS.get_locale_language())


## A font size made bigger or smaller by the text size setting.
static func scaled_font_size(base: int) -> int:
	return roundi(base * text_size)


## Makes the menus, dialogue, crafting, and other themed text follow the text size setting.
static func apply_text_size() -> void:
	var theme := ThemeDB.get_project_theme()
	if theme == null:
		return
	theme.default_font_size = scaled_font_size(BASE_FONT_SIZE)
	theme.set_font_size("font_size", "TitleLabel", scaled_font_size(BASE_TITLE_FONT_SIZE))


static func render_scale() -> float:
	return GRAPHICS_LEVELS[graphics]["render_scale"]


static func grass_draw_scale() -> float:
	return FeatureFlags.value("grass_draw_scale_" + graphics, 1.0)


## How many people wading in the river stir the water on screen. 0 skips the ripple work.
static func water_ripples() -> int:
	return GRAPHICS_LEVELS[graphics]["water_ripples"]


static func shadows() -> bool:
	return GRAPHICS_LEVELS[graphics]["shadows"]


## Whether corners and the ground under things are darkened on screen. The feature flag can turn it off.
static func ambient_occlusion() -> bool:
	return GRAPHICS_LEVELS[graphics]["ambient_occlusion"] and FeatureFlags.enabled("screen_ambient_occlusion")


static func shadow_splits() -> DirectionalLight3D.ShadowMode:
	return GRAPHICS_LEVELS[graphics].get("shadow_splits", DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS)
