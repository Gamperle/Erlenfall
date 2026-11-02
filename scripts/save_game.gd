class_name SaveGame
extends RefCounted
## Writes and reads progress as JSON. A missing or damaged file counts as no save.

const BELOW_GROUND_MARGIN := 1.5
const DEFAULT_PATH := "user://save.json"
const VERSION := 1


static func exists(path: String) -> bool:
	return not _read(path).is_empty()


static func write(path: String, player: Player, day_night: DayNight, village: Village) -> void:
	var data := {
		"version": VERSION,
		"position": [player.position.x, player.position.y, player.position.z],
		"health": player.health.current,
		"inventory": player.inventory.to_data(),
		"known_recipes": player.known_recipes.keys(),
		"torch_given": player.torch_given,
		"torch_lit": player.torch_lit,
		"torch_burned_seconds": player.torch_burned_seconds,
		"quests": player.quests.to_data(),
		"hour": day_night.hour,
		"world": village.to_data(),
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Could not save the game: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


## Applies a saved game and reports whether there was one to apply.
static func apply(path: String, player: Player, day_night: DayNight, village: Village) -> bool:
	var data := _read(path)
	if data.is_empty():
		return false
	var saved_position: Array = data["position"]
	player.position = Vector3(saved_position[0], saved_position[1], saved_position[2])
	# Saves can come from before the land changed shape.
	var ground: float = village.terrain.height_at(player.position.x, player.position.z)
	if player.position.y < ground - BELOW_GROUND_MARGIN:
		player.position.y = ground
	player.health.current = data["health"]
	player.health.changed.emit()
	player.inventory.load_data(data["inventory"])
	player.known_recipes.clear()
	for recipe_id: String in data["known_recipes"]:
		player.known_recipes[recipe_id] = true
	# Games saved before torches existed don't have these.
	player.torch_given = data.get("torch_given", false)
	player.torch_burned_seconds = data.get("torch_burned_seconds", 0.0)
	var can_light: bool = FeatureFlags.enabled("torches") and player.inventory.count(Player.TORCH_ITEM) > 0
	player.set_torch_lit(data.get("torch_lit", false) and can_light)
	day_night.hour = data["hour"]
	# Games saved before enemies and gathering spots were saved don't have this.
	if data.has("world"):
		village.load_data(data["world"])
	# Last, because quest changes trigger an autosave.
	player.quests.load_data(data["quests"])
	return true


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary and data.get("version") == VERSION:
		return data
	return {}
